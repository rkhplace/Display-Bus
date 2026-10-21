import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:runningtext_app/core/models/panel_credential.dart';
import 'package:runningtext_app/core/services/bluetooth_service.dart';

class FakeBleService extends BleService {
  /// Hasil default kirim payload; [payloadResults] (antrean) didahulukan.
  BleSendResult sendPayloadResult = BleSendResult.ok;
  final List<BleSendResult> payloadResults = [];

  /// Antrean hasil salam; kosong = OK.
  final List<BleSendResult> helloResults = [];

  bool connectThrows = false;
  String panelNameOnConnect = 'P5-BUS-01';

  Map<String, dynamic>? lastPayload;
  PanelCredential? lastCredential;
  String? lastDeviceId;
  int sendPayloadCallCount = 0;
  int helloCallCount = 0;
  int disconnectCallCount = 0;

  @override
  Future<void> connectToDevice(BluetoothDevice device) async {
    if (connectThrows) throw StateError('bukan panel P5');
    connectedPanelName = panelNameOnConnect;
  }

  @override
  void disconnect() {
    disconnectCallCount++;
    connectedPanelName = null;
  }

  @override
  Future<BleSendResult> sendHello({
    required PanelCredential credential,
    required String deviceId,
  }) async {
    helloCallCount++;
    lastCredential = credential;
    lastDeviceId = deviceId;
    return helloResults.isNotEmpty ? helloResults.removeAt(0) : BleSendResult.ok;
  }

  @override
  Future<BleSendResult> sendPayload(
    Map<String, dynamic> payload, {
    required PanelCredential credential,
    required String deviceId,
  }) async {
    sendPayloadCallCount++;
    lastPayload = payload;
    lastCredential = credential;
    lastDeviceId = deviceId;
    return payloadResults.isNotEmpty
        ? payloadResults.removeAt(0)
        : sendPayloadResult;
  }

  void simulatePanelDisconnected() => handlePanelDisconnected();
}
