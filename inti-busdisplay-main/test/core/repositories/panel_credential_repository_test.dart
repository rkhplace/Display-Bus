import 'package:flutter_test/flutter_test.dart';
import 'package:runningtext_app/core/models/operation_result.dart';
import 'package:runningtext_app/core/models/panel_credential.dart';
import 'package:runningtext_app/core/repositories/panel_credential_repository.dart';
import '../../fakes/fake_api_service_for_connection.dart';
import '../../fakes/fake_device_identity_service.dart';
import '../../fakes/test_credentials.dart';

void main() {
  late FakeApiServiceForConnection api;
  late FakeDeviceIdentityService identity;
  late PanelCredentialRepository repo;

  setUp(() {
    api = FakeApiServiceForConnection();
    identity = FakeDeviceIdentityService();
    repo = PanelCredentialRepository(apiService: api, deviceIdentity: identity);
  });

  test('kredensial tersimpan yang masih lama berlaku dipakai tanpa ke server', () async {
    final cached = testCredential(validFor: const Duration(days: 5));
    identity.savedCredentials['P5-BUS-01'] = cached;

    final result = await repo.credentialFor('p5-bus-01');

    expect(result.data, same(cached));
    expect(api.fetchCredentialCallCount, 0);
  });

  test('hampir kedaluwarsa (< 1 hari): minta baru ke server dan simpan', () async {
    identity.savedCredentials['P5-BUS-01'] =
        testCredential(validFor: const Duration(hours: 5));

    final result = await repo.credentialFor('P5-BUS-01');

    expect(api.fetchCredentialCallCount, 1);
    expect(result.success, isTrue);
    expect(identity.savedCredentials['P5-BUS-01'], same(result.data));
  });

  test('server tidak terjangkau: tetap pakai cache yang masih berlaku', () async {
    final cached = testCredential(validFor: const Duration(hours: 5));
    identity.savedCredentials['P5-BUS-01'] = cached;
    api.credentialResult = OperationResult.failure('Tidak dapat terhubung ke server.');

    final result = await repo.credentialFor('P5-BUS-01');

    expect(result.data, same(cached));
  });

  test('server tidak terjangkau dan cache sudah kedaluwarsa: gagal', () async {
    identity.savedCredentials['P5-BUS-01'] =
        testCredential(validFor: const Duration(hours: -1));
    api.credentialResult = OperationResult.failure('Tidak dapat terhubung ke server.');

    final result = await repo.credentialFor('P5-BUS-01');

    expect(result.success, isFalse);
    expect(result.message, contains('server'));
  });

  test('forceRefresh: cache tidak dipakai sebagai cadangan bila server gagal', () async {
    identity.savedCredentials['P5-BUS-01'] = testCredential();
    api.credentialResult = OperationResult.failure('Device sudah dicabut oleh admin.');

    final result = await repo.credentialFor('P5-BUS-01', forceRefresh: true);

    expect(result.success, isFalse);
    expect(result.message, contains('dicabut'));
  });

  group('PanelCredential', () {
    test('selisih jam dihitung dari serverTime saat diterima', () {
      final received = DateTime.utc(2026, 10, 21, 10);
      final cred = PanelCredential.fromApi({
        'panel': 'P5-BUS-01',
        'key': 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=',
        'expiresAt': 1800000000,
        'serverTime': received.millisecondsSinceEpoch + 90000,
      }, receivedAt: received);

      expect(cred.clockOffsetMs, 90000);
      expect(cred.serverNowMs(received), received.millisecondsSinceEpoch + 90000);
    });

    test('simpan dan muat ulang tidak mengubah isi', () {
      final cred = testCredential(clockOffsetMs: -1234);
      final restored = PanelCredential.fromJson(cred.toJson());

      expect(restored.key, cred.key);
      expect(restored.expiresAt, cred.expiresAt);
      expect(restored.clockOffsetMs, -1234);
    });
  });
}
