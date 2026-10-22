import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:runningtext_app/core/models/operation_result.dart';
import 'package:runningtext_app/core/providers/connection_provider.dart';
import 'package:runningtext_app/core/providers/display_settings_provider.dart';
import 'package:runningtext_app/core/providers/preset_provider.dart';
import 'package:runningtext_app/core/providers/route_provider.dart';
import 'package:runningtext_app/core/services/bluetooth_service.dart';
import 'package:runningtext_app/core/theme/app_colors.dart';
import 'package:runningtext_app/core/widgets/app_toast.dart';
import 'package:runningtext_app/features/home/widgets/send_button.dart';
import '../../../fakes/fake_api_service_for_connection.dart';
import '../../../fakes/fake_ble_service.dart';
import '../../../fakes/fake_device_identity_service.dart';
import '../../../fakes/fake_preset_repository.dart';
import '../../../fakes/fake_route_repository.dart';

void main() {
  late FakeBleService fakeBle;
  late FakeApiServiceForConnection fakeApi;
  late ConnectionProvider connectionProvider;

  setUp(() {
    fakeBle = FakeBleService();
    fakeApi = FakeApiServiceForConnection();
    connectionProvider = ConnectionProvider(
      apiService: fakeApi,
      bleService: fakeBle,
      deviceIdentity: FakeDeviceIdentityService(),
      debugInitiallyConnected: true,
    );
  });

  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectionProvider>.value(
            value: connectionProvider,
          ),
          ChangeNotifierProvider(
            create: (_) =>
                RouteProvider(routeRepository: FakeRouteRepository()),
          ),
          ChangeNotifierProvider(create: (_) => DisplaySettingsProvider()),
          ChangeNotifierProvider(
            create: (_) =>
                PresetProvider(presetRepository: FakePresetRepository()),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Center(child: SendToDisplayButton())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Color toastColor(WidgetTester tester) =>
      tester.widget<AppToastCard>(find.byType(AppToastCard)).color;

  testWidgets('BLE sukses tapi server gagal: notifikasi kuning', (
    tester,
  ) async {
    fakeApi.sendDisplayConfigResult = OperationResult.failure('down');
    await pumpCard(tester);

    await tester.tap(find.text('Kirim ke Display'));
    await tester.pumpAndSettle();

    expect(toastColor(tester), AppColors.warning);
  });

  testWidgets(
    'gagal di BLE setelah sinkron sebelumnya gagal: notifikasi merah, bukan kuning',
    (tester) async {
      fakeApi.sendDisplayConfigResult = OperationResult.failure('down');
      await connectionProvider.sendPayload({'route': 'x'});
      expect(connectionProvider.lastApiSyncFailed, isTrue);

      fakeBle.sendPayloadResult = BleSendResult.rejectedReplay;
      await pumpCard(tester);

      await tester.tap(find.text('Kirim ke Display'));
      await tester.pumpAndSettle();

      expect(toastColor(tester), AppColors.danger);
      expect(find.textContaining('Coba kirim ulang'), findsOneWidget);
    },
  );
}
