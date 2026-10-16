import 'package:flutter_test/flutter_test.dart';
import 'package:runningtext_app/core/models/operation_result.dart';
import 'package:runningtext_app/core/providers/connection_provider.dart';
import 'package:runningtext_app/core/services/bluetooth_service.dart';

import '../../fakes/fake_ble_service.dart';
import '../../fakes/fake_device_identity_service.dart';
import '../../fakes/fake_api_service_for_connection.dart';

void main() {
  late FakeBleService fakeBle;
  late FakeDeviceIdentityService fakeDeviceIdentity;
  late FakeApiServiceForConnection fakeApi;

  final samplePayload = {'route': 'B1 • Bandung - Garut', 'speed': 50};

  setUp(() {
    fakeBle = FakeBleService();
    fakeDeviceIdentity = FakeDeviceIdentityService();
    fakeApi = FakeApiServiceForConnection();
  });

  ConnectionProvider buildProvider({bool connected = true}) {
    return ConnectionProvider(
      apiService: fakeApi,
      bleService: fakeBle,
      deviceIdentity: fakeDeviceIdentity,
      debugInitiallyConnected: connected,
    );
  }

  group('ConnectionProvider.sendPayload - belum terhubung BLE', () {
    test('gagal tanpa memanggil BleService/ApiService sama sekali', () async {
      final provider = buildProvider(connected: false);

      final result = await provider.sendPayload(samplePayload);

      expect(result.success, isFalse);
      expect(result.message, contains('hubungkan Bluetooth'));
      expect(fakeBle.sendPayloadCallCount, 0);
      expect(fakeApi.lastSentPayload, isNull);
    });
  });

  group('ConnectionProvider.sendPayload - BLE gagal', () {
    test(
      'mengembalikan failure dan TIDAK memanggil sendDisplayConfig ke API',
      () async {
        fakeBle.sendPayloadResult = BleSendResult.writeFailed;
        final provider = buildProvider();

        final result = await provider.sendPayload(samplePayload);

        expect(result.success, isFalse);
        expect(result.message, contains('Gagal mengirim data'));
        expect(fakeBle.sendPayloadCallCount, 1);
        expect(fakeApi.lastSentPayload, isNull);
        expect(provider.lastApiSyncFailed, isFalse);
      },
    );
  });

  group('ConnectionProvider.sendPayload - BLE sukses, API sukses', () {
    test(
      'mengembalikan success penuh dan lastApiSyncFailed tetap false',
      () async {
        fakeBle.sendPayloadResult = BleSendResult.ok;
        fakeApi.sendDisplayConfigResult = OperationResult.success(null);
        final provider = buildProvider();

        final result = await provider.sendPayload(samplePayload);

        expect(result.success, isTrue);
        expect(result.message, contains('Berhasil mengirim ke P5 Panel'));
        expect(fakeApi.lastSentPayload, samplePayload);
        expect(provider.lastApiSyncFailed, isFalse);
      },
    );

    test(
      'meneruskan bleKey dan deviceToken dari DeviceIdentityService',
      () async {
        fakeDeviceIdentity.bleKeyToReturn = 'my-ble-key';
        fakeDeviceIdentity.deviceTokenToReturn = 'my-token';
        fakeBle.sendPayloadResult = BleSendResult.ok;
        fakeApi.sendDisplayConfigResult = OperationResult.success(null);
        final provider = buildProvider();

        await provider.sendPayload(samplePayload);

        expect(fakeBle.lastBleKey, 'my-ble-key');
        expect(fakeBle.lastDeviceToken, 'my-token');
      },
    );
  });

  group(
    'ConnectionProvider.sendPayload - BLE sukses, API gagal (state drift)',
    () {
      test(
        'tetap mengembalikan success (data sudah sampai di panel) tapi '
        'menandai lastApiSyncFailed dan menyertakan pesan peringatan',
        () async {
          fakeBle.sendPayloadResult = BleSendResult.ok;
          fakeApi.sendDisplayConfigResult = OperationResult.failure(
            'Server sedang down',
          );
          final provider = buildProvider();

          final result = await provider.sendPayload(samplePayload);

          expect(result.success, isTrue);
          expect(result.message, contains('gagal sinkron'));
          expect(provider.lastApiSyncFailed, isTrue);
        },
      );

      test(
        'exception saat memanggil API juga dianggap gagal sinkron, bukan crash',
        () async {
          fakeBle.sendPayloadResult = BleSendResult.ok;
          fakeApi.sendDisplayConfigThrows = true;
          final provider = buildProvider();

          final result = await provider.sendPayload(samplePayload);

          expect(result.success, isTrue);
          expect(provider.lastApiSyncFailed, isTrue);
        },
      );
    },
  );

  group('ConnectionProvider.acknowledgeApiSyncFailure', () {
    test(
      'mereset lastApiSyncFailed ke false dan memberi tahu listener',
      () async {
        fakeBle.sendPayloadResult = BleSendResult.ok;
        fakeApi.sendDisplayConfigResult = OperationResult.failure('gagal');
        final provider = buildProvider();
        await provider.sendPayload(samplePayload);
        expect(provider.lastApiSyncFailed, isTrue);

        var notified = false;
        provider.addListener(() => notified = true);
        provider.acknowledgeApiSyncFailure();

        expect(provider.lastApiSyncFailed, isFalse);
        expect(notified, isTrue);
      },
    );

    test('tidak melakukan apa-apa jika sudah false (tidak notify sia-sia)', () {
      final provider = buildProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      provider.acknowledgeApiSyncFailure();

      expect(notified, isFalse);
    });
  });

  group('ConnectionProvider - panel terputus sendiri', () {
    test('status berubah ke terputus dan listener diberi tahu', () async {
      final provider = buildProvider(connected: true);
      var notified = false;
      provider.addListener(() => notified = true);

      fakeBle.simulatePanelDisconnected();
      await Future<void>.delayed(Duration.zero);

      expect(provider.isBleConnected, isFalse);
      expect(provider.connectionText, 'Belum Terhubung');
      expect(notified, isTrue);
    });

    test('kirim setelah panel terputus ditolak tanpa memanggil BLE', () async {
      final provider = buildProvider(connected: true);

      fakeBle.simulatePanelDisconnected();
      await Future<void>.delayed(Duration.zero);
      final result = await provider.sendPayload(samplePayload);

      expect(result.success, isFalse);
      expect(fakeBle.sendPayloadCallCount, 0);
    });

    test('tidak notify jika memang sudah terputus', () async {
      final provider = buildProvider(connected: false);
      var notified = false;
      provider.addListener(() => notified = true);

      fakeBle.simulatePanelDisconnected();
      await Future<void>.delayed(Duration.zero);

      expect(notified, isFalse);
    });
  });

  group('ConnectionProvider.sendPayload - panel menolak atau tidak membalas', () {
    final cases = {
      BleSendResult.rejectedPacket: 'kunci enkripsi tidak cocok',
      BleSendResult.rejectedPayload: 'format tidak valid',
      BleSendResult.rejectedReplay: 'jam HP',
      BleSendResult.noAck: 'tidak membalas',
      BleSendResult.noKey: 'pairing',
    };

    cases.forEach((bleResult, expectedMessage) {
      test('$bleResult: gagal dan TIDAK sinkron ke server', () async {
        fakeBle.sendPayloadResult = bleResult;
        final provider = buildProvider();

        final result = await provider.sendPayload(samplePayload);

        expect(result.success, isFalse);
        expect(result.message, contains(expectedMessage));
        expect(fakeApi.lastSentPayload, isNull);
      });
    });

    test(
      'banner gagal-sinkron dari pengiriman sebelumnya tidak hilang karena '
      'pengiriman berikutnya gagal di BLE',
      () async {
        fakeApi.sendDisplayConfigResult = OperationResult.failure('down');
        final provider = buildProvider();
        await provider.sendPayload(samplePayload);
        expect(provider.lastApiSyncFailed, isTrue);

        fakeBle.sendPayloadResult = BleSendResult.writeFailed;
        final result = await provider.sendPayload(samplePayload);

        expect(result.success, isFalse);
        expect(provider.lastApiSyncFailed, isTrue);
      },
    );
  });

  group('BleService.resultForStatus', () {
    test('memetakan balasan firmware', () {
      expect(BleService.resultForStatus('OK'), BleSendResult.ok);
      expect(BleService.resultForStatus('OK\n'), BleSendResult.ok);
      expect(
        BleService.resultForStatus('ERR_PACKET'),
        BleSendResult.rejectedPacket,
      );
      expect(
        BleService.resultForStatus('ERR_REPLAY'),
        BleSendResult.rejectedReplay,
      );
      expect(
        BleService.resultForStatus('ERR_JSON'),
        BleSendResult.rejectedPayload,
      );
      expect(
        BleService.resultForStatus('apa saja'),
        BleSendResult.rejectedPayload,
      );
    });
  });
}
