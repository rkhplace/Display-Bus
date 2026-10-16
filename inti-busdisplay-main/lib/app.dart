import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/services/auth_session_notifier.dart';
import 'features/splash/splash_screen.dart';
import 'features/pairing/pairing_screen.dart';

class SmartBusDisplayApp extends StatefulWidget {
  const SmartBusDisplayApp({super.key});

  @override
  State<SmartBusDisplayApp> createState() => _SmartBusDisplayAppState();
}

class _SmartBusDisplayAppState extends State<SmartBusDisplayApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    AuthSessionNotifier.instance.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (AuthSessionNotifier.instance.value) return;

    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PairingScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    AuthSessionNotifier.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'PT INTI Bus Display',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
