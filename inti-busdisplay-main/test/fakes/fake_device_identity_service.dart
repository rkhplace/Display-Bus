import 'package:runningtext_app/core/models/panel_credential.dart';
import 'package:runningtext_app/core/services/device_identity_service.dart';

class FakeDeviceIdentityService extends DeviceIdentityService {
  String deviceIdToReturn = '3f2b1c4e-0000-4000-8000-000000000001';
  String? deviceTokenToReturn = 'fake-device-token';
  final Map<String, PanelCredential> savedCredentials = {};

  @override
  Future<String> getOrCreateDeviceId() async => deviceIdToReturn;

  @override
  Future<String?> getDeviceToken() async => deviceTokenToReturn;

  @override
  Future<PanelCredential?> getPanelCredential(String panel) async =>
      savedCredentials[panel.toUpperCase()];

  @override
  Future<void> savePanelCredential(PanelCredential credential) async {
    savedCredentials[credential.panel.toUpperCase()] = credential;
  }
}
