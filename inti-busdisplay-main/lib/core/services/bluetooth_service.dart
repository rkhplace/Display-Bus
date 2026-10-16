import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_payload_cipher.dart';

/// Hasil pengiriman payload ke panel.
enum BleSendResult {
  /// Panel membalas "OK": data sudah tampil.
  ok,
  notConnected,
  noKey,
  writeFailed,

  /// Panel gagal mendekripsi (kunci di panel beda dengan bleKey device).
  rejectedPacket,

  /// Dekripsi berhasil tapi isi payload ditolak (mis. rute terlalu panjang).
  rejectedPayload,

  /// Timestamp tidak lebih baru dari paket terakhir (jam HP mundur).
  rejectedReplay,

  /// Data terkirim tapi panel tidak membalas dalam batas waktu.
  noAck,
}

class BleService {
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String characteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  /// Karakteristik status di firmware (read + notify): "OK", "ERR_PACKET",
  /// "ERR_JSON", atau "ERR_REPLAY" setelah setiap penulisan.
  static const String statusCharacteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a9";

  static const Duration ackTimeout = Duration(seconds: 3);

  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? targetCharacteristic;
  BluetoothCharacteristic? statusCharacteristic;

  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  final _disconnections = StreamController<void>.broadcast();

  /// Memancarkan event saat panel terputus tanpa diminta (mati, keluar
  /// jangkauan, firmware restart). Tidak dipancarkan oleh [disconnect].
  Stream<void> get disconnections => _disconnections.stream;

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      // Beberapa HP gagal konek kalau scan masih berjalan.
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }

      await device.connect(autoConnect: false);
      connectedDevice = device;

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
              debugPrint('Karakteristik BLE ditemukan siap untuk ditulisi.');
            } else if (uuid == statusCharacteristicUuid) {
              statusCharacteristic = characteristic;
            }
          }
        }
      }

      if (targetCharacteristic == null) {
        throw StateError(
          'Perangkat ${device.platformName} bukan panel P5 '
          '(karakteristik BLE tidak ditemukan).',
        );
      }

      if (statusCharacteristic != null) {
        await statusCharacteristic!.setNotifyValue(true);
      } else {
        debugPrint(
          'Firmware panel tidak punya karakteristik status; '
          'pengiriman tidak bisa dikonfirmasi.',
        );
      }
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
      default:
        return BleSendResult.rejectedPayload;
    }
  }

  Future<BleSendResult> sendPayload(
    Map<String, dynamic> payload, {
    String? bleKey,
    String? deviceToken,
  }) async {
    final target = targetCharacteristic;
    if (target == null || connectedDevice == null) {
      debugPrint('BLE belum terhubung atau karakteristik tidak ditemukan.');
      return BleSendResult.notConnected;
    }

    final keySource = bleKey ?? deviceToken;
    if (keySource == null || keySource.isEmpty) {
      debugPrint(
        'Tidak ada bleKey/deviceToken untuk enkripsi. Payload TIDAK dikirim '
        'demi mencegah pengiriman plaintext.',
      );
      return BleSendResult.noKey;
    }

    final status = statusCharacteristic;
    // Didengarkan sebelum menulis supaya balasan panel tidak terlewat.
    // Timeout/error langsung diubah jadi null supaya tidak pernah menjadi
    // error yang tak tertangani selama penulisan masih berjalan.
    final Future<String?>? ack = status?.onValueReceived
        .map((value) => utf8.decode(value, allowMalformed: true))
        .first
        .timeout(ackTimeout)
        .then<String?>((reply) => reply, onError: (Object e) {
          debugPrint('Balasan panel tidak diterima: $e');
          return null;
        });

    try {
      final bytes = BlePayloadCipher.encryptPayload(
        payload: payload,
        keySource: keySource,
        keySourceIsRawKey: bleKey != null,
      );

      await target.write(bytes, withoutResponse: false);
    } catch (e) {
      debugPrint('Gagal mengirim data via BLE: $e');
      return BleSendResult.writeFailed;
    }

    // Firmware lama tanpa karakteristik status: hanya bisa percaya penulisan.
    if (ack == null) return BleSendResult.ok;

    final reply = await ack;
    if (reply == null) return BleSendResult.noAck;
    debugPrint('Balasan panel: $reply');
    return resultForStatus(reply);
  }
}
