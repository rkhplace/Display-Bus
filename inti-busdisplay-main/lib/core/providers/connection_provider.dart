import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/operation_result.dart';
import '../services/api_service.dart';
import '../services/bluetooth_service.dart';
import '../services/device_identity_service.dart';

class ConnectionProvider extends ChangeNotifier {
  final ApiService _apiService;
  final BleService _bleService;
  final DeviceIdentityService _deviceIdentity;

  ConnectionProvider({
    ApiService? apiService,
    BleService? bleService,
    DeviceIdentityService? deviceIdentity,
    @visibleForTesting bool debugInitiallyConnected = false,
  }) : _apiService = apiService ?? ApiService.instance,
       _bleService = bleService ?? BleService(),
       _deviceIdentity = deviceIdentity ?? DeviceIdentityService(),
       _isBleConnected = debugInitiallyConnected {
    _disconnectSubscription = _bleService.disconnections.listen(
      (_) => _onPanelDisconnected(),
    );
  }

  bool _isBleConnected;
  String _bleDeviceName = 'Belum Terhubung';
  bool _isScanning = false;
  List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  late final StreamSubscription<void> _disconnectSubscription;
  bool _lastApiSyncFailed = false;
  String? _scanError;

  static const Duration scanDuration = Duration(seconds: 4);

  bool get isBleConnected => _isBleConnected;
  String get connectionText => _bleDeviceName;
  bool get isScanning => _isScanning;
  List<ScanResult> get scanResults => _scanResults;
  bool get lastApiSyncFailed => _lastApiSyncFailed;

  /// Alasan scan terakhir gagal (Bluetooth mati, izin ditolak), atau null.
  String? get scanError => _scanError;

  Future<void> startBleScan() async {
    _isScanning = true;
    _scanResults = [];
    _scanError = null;
    notifyListeners();

    try {
      if (!await FlutterBluePlus.isSupported) {
        _scanError = 'HP ini tidak mendukung Bluetooth LE.';
        return;
      }
      if (!await _ensureBluetoothOn()) {
        _scanError = 'Bluetooth mati. Nyalakan Bluetooth lalu pindai ulang.';
        return;
      }

      await _scanSubscription?.cancel();

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _scanResults = results
            .where((r) => r.device.platformName.isNotEmpty)
            .toList();
        notifyListeners();
      });

      await FlutterBluePlus.startScan(timeout: scanDuration);
      await Future.delayed(scanDuration);
    } catch (e) {
      debugPrint("Scan error: $e");
      _scanError =
          'Gagal memindai. Pastikan izin Bluetooth / Perangkat sekitar '
          'diizinkan untuk aplikasi ini.';
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<bool> _ensureBluetoothOn() async {
    // State awal bisa "unknown" sebentar setelah app dibuka.
    final state = await FlutterBluePlus.adapterState
        .where((s) => s != BluetoothAdapterState.unknown)
        .first
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () => FlutterBluePlus.adapterStateNow,
        );
    if (state == BluetoothAdapterState.on) return true;

    // Android bisa menampilkan dialog sistem untuk menyalakan Bluetooth.
    if (Platform.isAndroid) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (e) {
        debugPrint('Bluetooth tidak dinyalakan: $e');
      }
    }
    return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      await _bleService.connectToDevice(device);
      _isBleConnected = true;
      _bleDeviceName = device.platformName;
      notifyListeners();
      return true;
    } catch (e) {
      _isBleConnected = false;
      notifyListeners();
      return false;
    }
  }

  void disconnectBle() {
    _bleService.disconnect();
    _isBleConnected = false;
    _bleDeviceName = 'Belum Terhubung';
    notifyListeners();
  }

  void _onPanelDisconnected() {
    if (!_isBleConnected) return;
    _isBleConnected = false;
    _bleDeviceName = 'Belum Terhubung';
    notifyListeners();
  }

  Future<OperationResult<void>> sendPayload(
    Map<String, dynamic> payload,
  ) async {
    if (!_isBleConnected) {
      return OperationResult.failure(
        'Silakan hubungkan Bluetooth ke Panel P5 terlebih dahulu.',
      );
    }

    final bleKey = await _deviceIdentity.getBleKey();
    final deviceToken = await _deviceIdentity.getDeviceToken();

    final bleResult = await _bleService.sendPayload(
      payload,
      bleKey: bleKey,
      deviceToken: deviceToken,
    );

    // Server hanya disinkronkan kalau panel benar-benar menampilkan data ini.
    final failureMessage = _messageForBleFailure(bleResult);
    if (failureMessage != null) {
      return OperationResult.failure(failureMessage);
    }

    bool apiSynced = true;
    try {
      final apiResult = await _apiService.sendDisplayConfig(payload);
      apiSynced = apiResult.success;
      if (!apiSynced) {
        debugPrint(
          'Sinkronisasi API gagal setelah BLE sukses: ${apiResult.message}',
        );
      }
    } catch (e) {
      apiSynced = false;
      debugPrint('Error saat sinkronisasi API setelah BLE sukses: $e');
    }

    _lastApiSyncFailed = !apiSynced;
    notifyListeners();

    return OperationResult.success(
      null,
      apiSynced
          ? 'Berhasil mengirim ke P5 Panel via Bluetooth!'
          : 'Berhasil mengirim ke panel via Bluetooth, tapi gagal sinkron '
                'ke server. Data di server mungkin tidak sesuai kondisi panel.',
    );
  }

  static String? _messageForBleFailure(BleSendResult result) {
    switch (result) {
      case BleSendResult.ok:
        return null;
      case BleSendResult.notConnected:
      case BleSendResult.writeFailed:
        return 'Gagal mengirim data. Pastikan dekat dengan panel dan coba lagi.';
      case BleSendResult.noKey:
        return 'Gagal mengirim data: kunci enkripsi belum ada. Lakukan pairing '
            'ulang.';
      case BleSendResult.rejectedPacket:
        return 'Panel menolak data: kunci enkripsi tidak cocok. Pastikan '
            'BLE_KEY panel sama dengan server, lalu pairing ulang.';
      case BleSendResult.rejectedPayload:
        return 'Panel menolak data: format tidak valid (mis. nama rute terlalu '
            'panjang).';
      case BleSendResult.rejectedReplay:
        return 'Panel menolak data: jam HP lebih lambat dari pengiriman '
            'terakhir. Aktifkan tanggal & waktu otomatis di HP.';
      case BleSendResult.noAck:
        return 'Panel tidak membalas, data mungkin belum tampil. Coba kirim '
            'ulang.';
    }
  }

  void acknowledgeApiSyncFailure() {
    if (!_lastApiSyncFailed) return;
    _lastApiSyncFailed = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _disconnectSubscription.cancel();
    super.dispose();
  }
}
