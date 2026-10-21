import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/panel_credential.dart';
import 'ble_payload_cipher.dart';

/// Hasil pengiriman paket ke panel.
enum BleSendResult {
  /// Panel membalas "OK".
  ok,
  notConnected,
  writeFailed,

  /// Panel gagal membuka paket: kredensial tidak cocok dengan kunci panel
  /// (mis. kunci panel diganti) atau paket diubah di jalan.
  rejectedPacket,

  /// Paket sah tapi isinya ditolak (mis. rute terlalu panjang).
  rejectedPayload,

  /// Timestamp tidak lebih baru dari paket terakhir yang diterima panel.
  rejectedReplay,

  /// Kredensial sudah lewat masa berlakunya menurut waktu paket.
  rejectedExpired,

  /// Data terkirim tapi panel tidak membalas dalam batas waktu.
  noAck,
}

class BleService {
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String characteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  /// Karakteristik status di firmware (read + notify): "OK", "ERR_PACKET",
  /// "ERR_JSON", "ERR_REPLAY", atau "ERR_EXPIRED" setelah setiap penulisan.
  static const String statusCharacteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a9";

  static const Duration ackTimeout = Duration(seconds: 3);

  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? targetCharacteristic;
  BluetoothCharacteristic? statusCharacteristic;

  /// Nama BLE panel yang terhubung = nama panel di server (mis. P5-BUS-01).
  String? connectedPanelName;

  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  final _disconnections = StreamController<void>.broadcast();

  /// Memancarkan event saat panel terputus tanpa diminta (mati, keluar
  /// jangkauan, firmware restart, atau panel memutus karena tidak ada salam).
  /// Tidak dipancarkan oleh [disconnect].
  Stream<void> get disconnections => _disconnections.stream;

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      // Beberapa HP gagal konek kalau scan masih berjalan.
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }

      await device.connect(autoConnect: false);
      connectedDevice = device;
      connectedPanelName = device.platformName;

      // Didengarkan setelah connect: stream langsung memancarkan state saat ini,
      // jadi event pertamanya "connected", bukan "disconnected" sisa sebelumnya.
      await _connectionStateSubscription?.cancel();
      _connectionStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          handlePanelDisconnected();
        }
      });

      if (Platform.isAndroid) {
        await device.requestMtu(512);
      }

      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString() == serviceUuid) {
          for (var characteristic in service.characteristics) {
            final uuid = characteristic.uuid.toString();
            if (uuid == characteristicUuid) {
              targetCharacteristic = characteristic;
            } else if (uuid == statusCharacteristicUuid) {
              statusCharacteristic = characteristic;
            }
          }
        }
      }

      if (targetCharacteristic == null || statusCharacteristic == null) {
        throw StateError(
          'Perangkat ${device.platformName} bukan panel P5 atau firmware-nya '
          'versi lama (karakteristik BLE tidak lengkap).',
        );
      }
      await statusCharacteristic!.setNotifyValue(true);
    } catch (e) {
      debugPrint('Gagal terhubung ke BLE: $e');
      disconnect();
      rethrow;
    }
  }

  void disconnect() {
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    connectedDevice?.disconnect();
    _clearConnection();
  }

  @protected
  void handlePanelDisconnected() {
    debugPrint('Koneksi BLE ke panel terputus.');
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    _clearConnection();
    _disconnections.add(null);
  }

  void _clearConnection() {
    connectedDevice = null;
    targetCharacteristic = null;
    statusCharacteristic = null;
    connectedPanelName = null;
  }

  @visibleForTesting
  static BleSendResult resultForStatus(String status) {
    switch (status.trim()) {
      case 'OK':
        return BleSendResult.ok;
      case 'ERR_PACKET':
        return BleSendResult.rejectedPacket;
      case 'ERR_REPLAY':
        return BleSendResult.rejectedReplay;
      case 'ERR_EXPIRED':
        return BleSendResult.rejectedExpired;
      default:
        return BleSendResult.rejectedPayload;
    }
  }

  /// Paket "salam" tanpa isi tampilan. Panel memutus koneksi yang tidak
  /// mengirim paket sah dalam beberapa detik, dan salam ini sekaligus
  /// memastikan kredensial cocok sebelum operator mengirim apa pun.
  Future<BleSendResult> sendHello({
    required PanelCredential credential,
    required String deviceId,
  }) {
    return _sendMessage(
      const {'hello': true},
      credential: credential,
      deviceId: deviceId,
    );
  }

  Future<BleSendResult> sendPayload(
    Map<String, dynamic> payload, {
    required PanelCredential credential,
    required String deviceId,
  }) {
    return _sendMessage(
      {'payload': payload},
      credential: credential,
      deviceId: deviceId,
    );
  }

  Future<BleSendResult> _sendMessage(
    Map<String, dynamic> message, {
    required PanelCredential credential,
    required String deviceId,
  }) async {
    final target = targetCharacteristic;
    final status = statusCharacteristic;
    if (target == null || status == null || connectedDevice == null) {
      debugPrint('BLE belum terhubung atau karakteristik tidak ditemukan.');
      return BleSendResult.notConnected;
    }

    // Didengarkan sebelum menulis supaya balasan panel tidak terlewat.
    // Timeout/error langsung diubah jadi null supaya tidak pernah menjadi
    // error yang tak tertangani selama penulisan masih berjalan.
    final Future<String?> ack = status.onValueReceived
        .map((value) => utf8.decode(value, allowMalformed: true))
        .first
        .timeout(ackTimeout)
        .then<String?>((reply) => reply, onError: (Object e) {
          debugPrint('Balasan panel tidak diterima: $e');
          return null;
        });

    try {
      final bytes = BlePayloadCipher.encrypt(
        message: message,
        credential: credential,
        deviceId: deviceId,
      );

      // allowLongWrite: di iOS MTU ~185 byte, sedangkan paket bisa sampai
      // ~400 byte. Paket lalu dikirim bertahap (prepare/execute write) dan
      // firmware ESP32 menggabungkannya sebelum onWrite dipanggil.
      await target.write(bytes, withoutResponse: false, allowLongWrite: true);
    } catch (e) {
      debugPrint('Gagal mengirim data via BLE: $e');
      return BleSendResult.writeFailed;
    }

    final reply = await ack;
    if (reply == null) return BleSendResult.noAck;
    debugPrint('Balasan panel: $reply');
    return resultForStatus(reply);
  }
}
