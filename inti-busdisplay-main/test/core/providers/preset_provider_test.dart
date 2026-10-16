import 'package:flutter_test/flutter_test.dart';
import 'package:runningtext_app/core/models/operation_result.dart';
import 'package:runningtext_app/core/providers/preset_provider.dart';

import '../../fakes/fake_preset_repository.dart';

void main() {
  late FakePresetRepository fakeRepo;
  late PresetProvider provider;

  final samplePayload = {
    'route': 'B1 • Bandung - Garut',
    'direction': 'Pergi',
    'animation': 'Scroll Left',
    'speed': 50,
    'brightness': 80,
    'fontSize': 16,
  };

  setUp(() {
    fakeRepo = FakePresetRepository();
    provider = PresetProvider(presetRepository: fakeRepo);
  });

  group('PresetProvider - state awal', () {
    test('hasLoadedPreset false ketika belum ada preset dimuat', () {
      expect(provider.hasLoadedPreset, isFalse);
      expect(provider.loadedPresetId, isNull);
      expect(provider.loadedPresetName, isNull);
    });
  });

  group('PresetProvider.saveCurrentPreset', () {
    test('meneruskan nama dan payload apa adanya ke repository', () async {
      fakeRepo.saveResult = OperationResult.success(
        null,
        'Preset berhasil disimpan!',
      );

      final result = await provider.saveCurrentPreset(
        'Preset Pagi',
        samplePayload,
      );

      expect(result.success, isTrue);
      expect(fakeRepo.lastSavedName, 'Preset Pagi');
      expect(fakeRepo.lastSavedPayload, samplePayload);
    });
  });

  group('PresetProvider.overwriteLoadedPreset', () {
    test(
      'gagal tanpa memanggil repository ketika belum ada preset yang dimuat',
      () async {
        final result = await provider.overwriteLoadedPreset(samplePayload);

        expect(result.success, isFalse);
        expect(result.message, contains('Tidak ada preset yang sedang dimuat'));
        expect(fakeRepo.lastUpdatedId, isNull);
      },
    );

    test(
      'mendelegasikan ke overwritePreset dengan id & nama preset yang sedang dimuat',
      () async {
        provider.markLoadedPreset(
          presetId: 'preset-123',
          presetName: 'Preset Sore',
        );
        fakeRepo.updateResult = OperationResult.success(
          null,
          'Preset berhasil ditimpa!',
        );

        final result = await provider.overwriteLoadedPreset(samplePayload);

        expect(result.success, isTrue);
        expect(fakeRepo.lastUpdatedId, 'preset-123');
        expect(fakeRepo.lastUpdatedName, 'Preset Sore');
        expect(fakeRepo.lastUpdatedPayload, samplePayload);
      },
    );

    test(
      'menggunakan nama fallback "Preset" ketika loadedPresetName null',
      () async {
        provider.markLoadedPreset(presetId: 'preset-999', presetName: null);
        fakeRepo.updateResult = OperationResult.success(null);

        await provider.overwriteLoadedPreset(samplePayload);

        expect(fakeRepo.lastUpdatedName, 'Preset');
      },
    );
  });

  group(
    'PresetProvider.overwritePreset (langsung, tanpa markLoadedPreset)',
    () {
      test('bisa dipanggil langsung dengan id/nama eksplisit', () async {
        fakeRepo.updateResult = OperationResult.success(null);

        final result = await provider.overwritePreset(
          presetId: 'explicit-id',
          presetName: 'Explicit Name',
          payload: samplePayload,
        );

        expect(result.success, isTrue);
        expect(fakeRepo.lastUpdatedId, 'explicit-id');
        expect(fakeRepo.lastUpdatedName, 'Explicit Name');
      });
    },
  );

  group('PresetProvider - markLoadedPreset & clearLoadedPreset', () {
    test('markLoadedPreset mengubah hasLoadedPreset menjadi true', () {
      provider.markLoadedPreset(presetId: 'id-1', presetName: 'Nama');

      expect(provider.hasLoadedPreset, isTrue);
      expect(provider.loadedPresetId, 'id-1');
      expect(provider.loadedPresetName, 'Nama');
    });

    test('clearLoadedPreset mengembalikan state ke kosong', () {
      provider.markLoadedPreset(presetId: 'id-1', presetName: 'Nama');
      provider.clearLoadedPreset();

      expect(provider.hasLoadedPreset, isFalse);
      expect(provider.loadedPresetId, isNull);
      expect(provider.loadedPresetName, isNull);
    });
  });

  group('PresetProvider.getSavedPresets', () {
    test('meneruskan hasil dari repository apa adanya', () async {
      fakeRepo.presetsToReturn = [
        {'id': '1', 'name': 'Preset A'},
        {'id': '2', 'name': 'Preset B'},
      ];

      final result = await provider.getSavedPresets();

      expect(result.length, 2);
      expect(result.first['name'], 'Preset A');
    });
  });
}
