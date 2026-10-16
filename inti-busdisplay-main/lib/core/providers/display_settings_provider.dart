import 'package:flutter/foundation.dart';

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

  void applyFromPayload(Map<String, dynamic> payload) {
    _animMode = payload['animation'] ?? 'Static';
    _speed = (payload['speed'] as num?)?.toDouble() ?? 50.0;
    _brightness = (payload['brightness'] as num?)?.toDouble() ?? 80.0;
    _fontSize = (payload['fontSize'] as num?)?.toDouble() ?? 16.0;
    notifyListeners();
  }
}
