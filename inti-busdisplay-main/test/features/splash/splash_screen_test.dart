import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runningtext_app/core/services/api_service.dart';
import 'package:runningtext_app/features/pairing/pairing_screen.dart';
import 'package:runningtext_app/features/splash/splash_screen.dart';
import '../../fakes/fake_device_identity_service.dart';

class _ThrowingIdentity extends FakeDeviceIdentityService {
  @override
  Future<bool> isPaired() async =>
      throw PlatformException(code: 'read', message: 'BadPaddingException');
}

class _HangingIdentity extends FakeDeviceIdentityService {
  @override
  Future<bool> isPaired() => Completer<bool>().future;
}

Future<void> _pumpSplash(WidgetTester tester, FakeDeviceIdentityService id) {
  return tester.pumpWidget(
    MaterialApp(
      home: SplashScreen(apiService: ApiService(deviceIdentity: id)),
    ),
  );
}

void main() {
  testWidgets('status pairing error: tetap lanjut ke halaman pairing', (
    tester,
  ) async {
    await _pumpSplash(tester, _ThrowingIdentity());
    await tester.pump(SplashScreen.minDisplay);
    await tester.pumpAndSettle();

    expect(find.byType(PairingScreen), findsOneWidget);
  });

  testWidgets('status pairing tidak pernah selesai: lanjut setelah timeout', (
    tester,
  ) async {
    await _pumpSplash(tester, _HangingIdentity());
    await tester.pump(SplashScreen.minDisplay);
    await tester.pump(SplashScreen.pairingCheckTimeout);
    await tester.pumpAndSettle();

    expect(find.byType(PairingScreen), findsOneWidget);
  });
}
