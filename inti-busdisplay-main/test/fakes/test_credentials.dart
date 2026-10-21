import 'dart:typed_data';
import 'package:runningtext_app/core/models/panel_credential.dart';

/// Kredensial uji dengan kunci 0x00..0x1f.
PanelCredential testCredential({
  String panel = 'P5-BUS-01',
  Duration validFor = const Duration(days: 7),
  int clockOffsetMs = 0,
  int keySeed = 0,
}) {
  return PanelCredential(
    panel: panel,
    key: Uint8List.fromList(List.generate(32, (i) => (i + keySeed) & 0xff)),
    expiresAt:
        DateTime.now().add(validFor).millisecondsSinceEpoch ~/ 1000,
    clockOffsetMs: clockOffsetMs,
  );
}
