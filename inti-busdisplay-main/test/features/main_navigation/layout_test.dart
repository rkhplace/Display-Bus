import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:runningtext_app/core/providers/connection_provider.dart';
import 'package:runningtext_app/core/providers/display_settings_provider.dart';
import 'package:runningtext_app/core/providers/preset_provider.dart';
import 'package:runningtext_app/core/providers/route_provider.dart';
import 'package:runningtext_app/features/home/widgets/display_setting_card.dart';
import 'package:runningtext_app/features/home/widgets/route_card.dart';
import 'package:runningtext_app/features/home/widgets/send_button.dart';
import 'package:runningtext_app/features/main_navigation/main_navigation.dart';
import '../../fakes/fake_api_service_for_connection.dart';
import '../../fakes/fake_ble_service.dart';
import '../../fakes/fake_device_identity_service.dart';
import '../../fakes/fake_preset_repository.dart';
import '../../fakes/fake_route_repository.dart';

Future<void> _pumpAt(WidgetTester tester, Size logicalSize) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = logicalSize;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ConnectionProvider(
            apiService: FakeApiServiceForConnection(),
            bleService: FakeBleService(),
            deviceIdentity: FakeDeviceIdentityService(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => RouteProvider(routeRepository: FakeRouteRepository()),
        ),
        ChangeNotifierProvider(create: (_) => DisplaySettingsProvider()),
        ChangeNotifierProvider(
          create: (_) =>
              PresetProvider(presetRepository: FakePresetRepository()),
        ),
      ],
      child: const MaterialApp(home: MainNavigation()),
    ),
  );
  // Preview LED beranimasi terus, jadi tidak pernah "settle".
  await tester.pump(const Duration(milliseconds: 500));
}

void _expectSendButtonVisible(WidgetTester tester, Size screen) {
  final rect = tester.getRect(find.byType(SendToDisplayButton));
  expect(rect.bottom, lessThanOrEqualTo(screen.height));
  expect(rect.top, greaterThanOrEqualTo(0));
}

void main() {
  const phoneLandscape = Size(914, 411);
  const phonePortrait = Size(411, 914);
  const tabletLandscape = Size(1280, 800);

  testWidgets('HP landscape: 2 kolom, tanpa overflow, tombol Kirim terlihat', (
    tester,
  ) async {
    await _pumpAt(tester, phoneLandscape);

    expect(tester.takeException(), isNull);
    final route = tester.getRect(find.byType(RouteCard));
    final settings = tester.getRect(find.byType(DisplaySettingCard));
    expect(settings.left, greaterThan(route.right), reason: 'harus 2 kolom');
    _expectSendButtonVisible(tester, phoneLandscape);
  });

  testWidgets('HP portrait: 1 kolom, tanpa overflow, tombol Kirim terlihat', (
    tester,
  ) async {
    await _pumpAt(tester, phonePortrait);

    expect(tester.takeException(), isNull);
    final route = tester.getRect(find.byType(RouteCard));
    expect(route.width, greaterThan(phonePortrait.width - 40));
    _expectSendButtonVisible(tester, phonePortrait);
  });

  testWidgets('tablet landscape: tanpa overflow', (tester) async {
    await _pumpAt(tester, tabletLandscape);

    expect(tester.takeException(), isNull);
    _expectSendButtonVisible(tester, tabletLandscape);
  });
}
