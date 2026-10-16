import 'package:flutter/material.dart';

enum AnimationMode {
  running('Running', Icons.sync_alt_rounded),
  still('Static', Icons.crop_square_rounded),
  blink('Blink', Icons.flash_on_rounded),
  scrollLeft('Scroll Left', Icons.arrow_back_rounded),
  scrollRight('Scroll Right', Icons.arrow_forward_rounded),
  scrollUp('Scroll Up', Icons.arrow_upward_rounded),
  scrollDown('Scroll Down', Icons.arrow_downward_rounded);

  final String label;
  final IconData icon;

  const AnimationMode(this.label, this.icon);

  static AnimationMode fromLabel(String? label) {
    return AnimationMode.values.firstWhere(
      (mode) => mode.label == label,
      orElse: () => AnimationMode.still,
    );
  }

  static List<String> get allLabels =>
      AnimationMode.values.map((m) => m.label).toList(growable: false);

  bool get travelsHorizontally =>
      this == scrollLeft || this == scrollRight || this == running;

  bool get isBlink => this == blink;
  bool get isStatic => this == still;

  Duration periodFor(double speed) {
    final t = speed.clamp(0, 100) / 100;
    if (isBlink) {
      return Duration(milliseconds: _lerp(1600, 260, t).round());
    }
    return Duration(milliseconds: _lerp(7000, 900, t).round());
  }

  Offset offsetFor({
    required double panelWidth,
    required double panelHeight,
    required double textWidth,
    required double textHeight,
    required double t,
  }) {
    final centerX = (panelWidth - textWidth) / 2;
    final centerY = (panelHeight - textHeight) / 2;

    switch (this) {
      case scrollLeft:
      case running:
        return Offset(_lerp(panelWidth, -textWidth, t), centerY);
      case scrollRight:
        return Offset(_lerp(-textWidth, panelWidth, t), centerY);
      case scrollUp:
        return Offset(centerX, _lerp(panelHeight, -textHeight, t));
      case scrollDown:
        return Offset(centerX, _lerp(-textHeight, panelHeight, t));
      case blink:
      case still:
        return Offset(centerX, centerY);
    }
  }

  double blinkOpacityFor(double t) {
    if (!isBlink) return 1.0;
    return t < 0.5 ? 1.0 : 0.12;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
