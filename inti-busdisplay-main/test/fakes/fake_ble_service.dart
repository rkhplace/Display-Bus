import 'package:runningtext_app/core/services/bluetooth_service.dart';

class FakeBleService extends BleService {
  BleSendResult sendPayloadResult = BleSendResult.ok;
  Map<String, dynamic>? lastPayload;
  String? lastBleKey;
  String? lastDeviceToken;
  int sendPayloadCallCount = 0;

  @override
  Future<BleSendResult> sendPayload(
    Map<String, dynamic> payload, {
    String? bleKey,
    String? deviceToken,
  }) async {
    sendPayloadCallCount++;
    lastPayload = payload;
    lastBleKey = bleKey;
    lastDeviceToken = deviceToken;
    return sendPayloadResult;
  }

  void simulatePanelDisconnected() => handlePanelDisconnected();
}
