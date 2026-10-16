import 'package:flutter/foundation.dart';

class AuthSessionNotifier extends ValueNotifier<bool> {
  AuthSessionNotifier._() : super(true);

  static final AuthSessionNotifier instance = AuthSessionNotifier._();

  void markAuthenticated() => value = true;

  void invalidate() => value = false;
}
