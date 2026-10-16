import 'package:runningtext_app/core/services/device_identity_service.dart';

class FakeDeviceIdentityService extends DeviceIdentityService {
  String? bleKeyToReturn = 'fake-ble-key';
  String? deviceTokenToReturn = 'fake-device-token';

  @override
  Future<String?> getBleKey() async => bleKeyToReturn;

  @override
  Future<String?> getDeviceToken() async => deviceTokenToReturn;
}
