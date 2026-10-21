import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/operation_result.dart';
import '../models/panel_credential.dart';
import '../repositories/panel_credential_repository.dart';
import '../services/api_service.dart';
import '../services/bluetooth_service.dart';
import '../services/device_identity_service.dart';

class ConnectionProvider extends ChangeNotifier {
  final ApiService _apiService;
  final BleService _bleService;
  final DeviceIdentityService _deviceIdentity;
  final PanelCredentialRepository _credentials;

  ConnectionProvider({
    ApiService? apiService,
    BleService? bleService,
    DeviceIdentityService? deviceIdentity,
    PanelCredentialRepository? credentials,
    @visibleForTesting bool debugInitiallyConnected = false,
    @visibleForTesting String debugPanelName = 'P5-TEST',
  }) : _apiService = apiService ?? ApiService.instance,
       _bleService = bleService ?? BleService(),
       _deviceIdentity = deviceIdentity ?? DeviceIdentityService(),
       _credentials =
           credentials ??
           PanelCredentialRepository(
             apiService: apiService,
             deviceIdentity: deviceIdentity,
           ),
       _isBleConnected = debugInitiallyConnected,
       _panelName = debugInitiallyConnected ? debugPanelName : null {
    _disconnectSubscription = _bleService.disconnections.listen(
      (_) => _onPanelDisconnected(),
    );
  }

  bool _isBleConnected;
  String? _panelName;
  bool _isScanning = false;
  List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  late final StreamSubscription<void> _disconnectSubscription;
  bool _lastApiSyncFailed = false;
  String? _scanError;

  static const Duration scanDuration = Duration(seconds: 4);

  bool get isBleConnected => _isBleConnected;
  String get connectionText => _panelName ?? 'Belum Terhubung';
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

  /// Menghubungkan ke panel lalu langsung mengirim salam terenkripsi. Koneksi
  /// dianggap berhasil hanya bila panel menerima salam itu, jadi kredensial
  /// yang salah ketahuan sekarang, bukan saat operator menekan Kirim.
  Future<OperationResult<void>> connectToDevice(BluetoothDevice device) async {
    try {
      await _bleService.connectToDevice(device);
    } catch (e) {
      _setDisconnected();
      return OperationResult.failure(
        'Gagal terhubung. Pastikan yang dipilih adalah panel P5 dan posisinya '
        'dekat.',
      );
    }

    final panel = _bleService.connectedPanelName ?? device.platformName;
    final hello = await _sendWithCredential(
      panel,
      (credential, deviceId) =>
          _bleService.sendHello(credential: credential, deviceId: deviceId),
    );
    if (!hello.success) {
      _bleService.disconnect();
      _setDisconnected();
      return hello;
    }

    _isBleConnected = true;
    _panelName = panel;
    notifyListeners();
    return OperationResult.success(null, 'Terhubung ke panel $panel.');
  }

  void disconnectBle() {
    _bleService.disconnect();
    _setDisconnected();
  }

  void _setDisconnected() {
    _isBleConnected = false;
    _panelName = null;
    notifyListeners();
  }

  void _onPanelDisconnected() {
    if (!_isBleConnected) return;
    _setDisconnected();
  }

  /// Mengambil kredensial [panel], mengirim lewat [send], dan bila panel
  /// menolak karena kredensial (kedaluwarsa / kunci panel diganti), meminta
  /// kredensial baru ke server lalu mencoba sekali lagi.
  Future<OperationResult<void>> _sendWithCredential(
    String panel,
    Future<BleSendResult> Function(PanelCredential credential, String deviceId)
    send,
  ) async {
    final deviceId = await _deviceIdentity.getOrCreateDeviceId();

    var credential = await _credentials.credentialFor(panel);
    if (!credential.success || credential.data == null) {
      return OperationResult.failure(credential.message ?? _noCredentialMessage);
    }

    var result = await send(credential.data!, deviceId);

    if (result == BleSendResult.rejectedExpired ||
        result == BleSendResult.rejectedPacket) {
      credential = await _credentials.credentialFor(panel, forceRefresh: true);
      if (!credential.success || credential.data == null) {
        return OperationResult.failure(
          credential.message ?? _messageForBleFailure(result)!,
        );
      }
      result = await send(credential.data!, deviceId);
    }

    final failure = _messageForBleFailure(result);
    return failure == null
        ? OperationResult.success(null)
        : OperationResult.failure(failure);
  }

  static const _noCredentialMessage =
      'Kunci akses panel tidak tersedia. Hubungkan HP ke server lalu coba lagi.';

  Future<OperationResult<void>> sendPayload(
    Map<String, dynamic> payload,
  ) async {
    final panel = _panelName;
    if (!_isBleConnected || panel == null) {
      return OperationResult.failure(
        'Silakan hubungkan Bluetooth ke Panel P5 terlebih dahulu.',
      );
    }

    final bleResult = await _sendWithCredential(
      panel,
      (credential, deviceId) => _bleService.sendPayload(
        payload,
        credential: credential,
        deviceId: deviceId,
      ),
    );

    // Server hanya disinkronkan kalau panel benar-benar menampilkan data ini.
    if (!bleResult.success) return bleResult;

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
      case BleSendResult.rejectedPacket:
        return 'Panel menolak kunci akses HP ini. Pastikan panel sudah '
            'di-flash dengan kunci dari server (panels:secrets), lalu coba lagi.';
      case BleSendResult.rejectedPayload:
        return 'Panel menolak data: format tidak valid (mis. nama rute terlalu '
            'panjang).';
      case BleSendResult.rejectedReplay:
        return 'Panel menolak data karena waktunya lebih lama dari pengiriman '
            'terakhir. Coba kirim ulang.';
      case BleSendResult.rejectedExpired:
        return 'Kunci akses panel sudah kedaluwarsa dan server tidak bisa '
            'dihubungi untuk memperbaruinya.';
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
