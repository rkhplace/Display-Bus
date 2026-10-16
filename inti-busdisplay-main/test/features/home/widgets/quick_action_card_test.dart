import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:runningtext_app/core/models/operation_result.dart';
import 'package:runningtext_app/core/providers/display_settings_provider.dart';
import 'package:runningtext_app/core/providers/preset_provider.dart';
import 'package:runningtext_app/core/providers/route_provider.dart';
import 'package:runningtext_app/features/home/widgets/quick_action_card.dart';
import '../../../fakes/fake_preset_repository.dart';
import '../../../fakes/fake_route_repository.dart';

Widget _wrap({
  required RouteProvider routeProvider,
  required DisplaySettingsProvider settingsProvider,
  required PresetProvider presetProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<RouteProvider>.value(value: routeProvider),
      ChangeNotifierProvider<DisplaySettingsProvider>.value(
        value: settingsProvider,
      ),
      ChangeNotifierProvider<PresetProvider>.value(value: presetProvider),
    ],
    child: const MaterialApp(home: Scaffold(body: QuickActionCard())),
  );
}

void main() {
  late FakeRouteRepository fakeRouteRepo;
  late FakePresetRepository fakePresetRepo;
  late RouteProvider routeProvider;
  late DisplaySettingsProvider settingsProvider;
  late PresetProvider presetProvider;

  setUp(() {
    fakeRouteRepo = FakeRouteRepository()..routesToReturn = [];
    fakePresetRepo = FakePresetRepository();
    routeProvider = RouteProvider(routeRepository: fakeRouteRepo);
    settingsProvider = DisplaySettingsProvider();
    presetProvider = PresetProvider(presetRepository: fakePresetRepo);
  });

  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        routeProvider: routeProvider,
        settingsProvider: settingsProvider,
        presetProvider: presetProvider,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('QuickActionCard - simpan preset', () {
    testWidgets(
      'mengirim nama & payload sesuai pengaturan saat ini ke repository, lalu menutup dialog',
      (tester) async {
        fakePresetRepo.saveResult = OperationResult.success(
          null,
          'Preset berhasil disimpan!',
        );

        await pumpCard(tester);

        await tester.tap(find.text('Simpan Preset'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'Preset Pagi');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(fakePresetRepo.lastSavedName, 'Preset Pagi');
        expect(
          fakePresetRepo.lastSavedPayload?['route'],
          routeProvider.selectedRoute.fullDisplayName,
        );
        expect(fakePresetRepo.lastSavedPayload?['animation'], 'Scroll Left');
        expect(fakePresetRepo.lastSavedPayload?['speed'], 50);
        expect(find.text('Preset berhasil disimpan!'), findsOneWidget);
      },
    );

    testWidgets('tidak memanggil repository ketika nama preset dikosongkan', (
      tester,
    ) async {
      await pumpCard(tester);

      await tester.tap(find.text('Simpan Preset'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(fakePresetRepo.lastSavedName, isNull);
    });
  });

  group('QuickActionCard - muat preset', () {
    testWidgets(
      'menerapkan preset terpilih dari bottom sheet ke seluruh provider',
      (tester) async {
        fakePresetRepo.presetsToReturn = [
          {
            'id': 'p1',
            'name': 'Preset Sore',
            'payload': {
              'route': routeProvider.routes[1].fullDisplayName,
              'direction': 'Pulang',
              'animation': 'Blink',
              'speed': 70,
              'brightness': 60,
              'fontSize': 20,
            },
          },
        ];

        await pumpCard(tester);

        await tester.tap(find.text('Muat Preset'));
        await tester.pumpAndSettle();

        expect(find.text('Preset Sore'), findsOneWidget);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Pilih'));
        await tester.pumpAndSettle();

        expect(routeProvider.selectedRoute.code, 'B2');
        expect(routeProvider.isPergi, isFalse);
        expect(settingsProvider.animMode, 'Blink');
        expect(settingsProvider.speed, 70.0);
        expect(settingsProvider.brightness, 60.0);
        expect(presetProvider.hasLoadedPreset, isTrue);
        expect(presetProvider.loadedPresetName, 'Preset Sore');
        expect(
          find.text('Preset "Preset Sore" berhasil diterapkan.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('menampilkan pesan kosong ketika belum ada preset tersimpan', (
      tester,
    ) async {
      fakePresetRepo.presetsToReturn = [];

      await pumpCard(tester);

      await tester.tap(find.text('Muat Preset'));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada preset tersimpan.'), findsOneWidget);
    });
  });

  group('QuickActionCard - menimpa preset yang sedang dimuat', () {
    testWidgets(
      'tombol timpa hanya muncul setelah preset dimuat, dan mengirim id yang benar setelah konfirmasi',
      (tester) async {
        fakePresetRepo.presetsToReturn = [
          {
            'id': 'p1',
            'name': 'Preset Sore',
            'payload': {
              'route': routeProvider.routes[1].fullDisplayName,
              'direction': 'Pulang',
              'animation': 'Blink',
              'speed': 70,
              'brightness': 60,
              'fontSize': 20,
            },
          },
        ];
        fakePresetRepo.updateResult = OperationResult.success(
          null,
          'Preset berhasil ditimpa!',
        );

        await pumpCard(tester);

        expect(find.textContaining('Timpa Preset'), findsNothing);

        await tester.tap(find.text('Muat Preset'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Pilih'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 5));

        final overwriteButtonLabel = 'Timpa Preset "Preset Sore"';
        expect(find.text(overwriteButtonLabel), findsOneWidget);

        await tester.tap(find.text(overwriteButtonLabel));
        await tester.pumpAndSettle();
        expect(find.text('Timpa Preset'), findsOneWidget);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Timpa'));
        await tester.pumpAndSettle();

        expect(fakePresetRepo.lastUpdatedId, 'p1');
        expect(fakePresetRepo.lastUpdatedName, 'Preset Sore');
        expect(find.text('Preset berhasil ditimpa!'), findsOneWidget);
      },
    );
  });

  group('QuickActionCard - reset ke default', () {
    testWidgets(
      'mengembalikan rute, pengaturan tampilan, dan melepas preset yang dimuat',
      (tester) async {
        await pumpCard(tester);

        routeProvider.setRoute(routeProvider.routes[1]);
        settingsProvider.setAnimMode('Blink');
        presetProvider.markLoadedPreset(presetId: 'x', presetName: 'Y');
        await tester.pump();

        await tester.tap(find.text('Reset ke Default'));
        await tester.pumpAndSettle();

        expect(
          routeProvider.selectedRoute.code,
          routeProvider.routes.first.code,
        );
        expect(routeProvider.isPergi, isTrue);
        expect(settingsProvider.animMode, 'Scroll Left');
        expect(settingsProvider.speed, 50.0);
        expect(presetProvider.hasLoadedPreset, isFalse);
        expect(
          find.text('Pengaturan berhasil direset ke default.'),
          findsOneWidget,
        );
      },
    );
  });
}
