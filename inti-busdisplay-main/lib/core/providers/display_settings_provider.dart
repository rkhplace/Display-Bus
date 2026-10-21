import 'package:flutter/foundation.dart';
import '../models/animation_mode.dart';

class DisplaySettingsProvider extends ChangeNotifier {
  String _animMode = 'Scroll Left';
  double _speed = 50;
  double _brightness = 80;
  double _fontSize = 16;

  String get animMode => _animMode;
  double get speed => _speed;
  double get brightness => _brightness;
  double get fontSize => _fontSize;

  void setAnimMode(String mode) {
    _animMode = mode;
    notifyListeners();
  }

  void setSpeed(double value) {
    _speed = value;
    notifyListeners();
  }

  void setBrightness(double value) {
    _brightness = value;
    notifyListeners();
  }

  void setFontSize(double value) {
    _fontSize = value;
    notifyListeners();
  }

  void resetToDefault() {
    _animMode = 'Scroll Left';
    _speed = 50;
    _brightness = 80;
    _fontSize = 16;
    notifyListeners();
  }

  /// Data preset berasal dari server, jadi dinormalisasi dulu: label animasi
  /// yang tidak dikenal menjadi Static dan angka dijepit ke 0-100. Tanpa ini,
  /// dropdown dan slider akan error (assert) saat menerima nilai di luar daftar
  /// atau rentang.
  void applyFromPayload(Map<String, dynamic> payload) {
    final animation = payload['animation'];
    _animMode = AnimationMode.fromLabel(
      animation is String ? animation : null,
    ).label;
    _speed = _percentOr(payload['speed'], 50);
    _brightness = _percentOr(payload['brightness'], 80);
    _fontSize = _percentOr(payload['fontSize'], 16);
    notifyListeners();
  }

  static double _percentOr(Object? value, double fallback) {
    if (value is! num || value.isNaN) return fallback;
    return value.toDouble().clamp(0, 100);
  }
}
