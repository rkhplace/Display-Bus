import 'dart:convert';
import 'dart:typed_data';

/// Kunci akses BLE untuk satu panel, khusus device ini, dengan masa berlaku.
///
/// Diterbitkan server lewat `POST /api/panels/:name/credential`. Kunci panel
/// yang asli tidak pernah sampai ke HP: [key] adalah turunan
/// HMAC-SHA256(kunciPanel, deviceId, expiresAt), jadi tidak bisa dipakai device
/// lain dan tidak berlaku lagi setelah [expiresAt].
class PanelCredential {
  final String panel;
  final Uint8List key;

  /// Batas berlaku (detik Unix, jam server).
  final int expiresAt;

  /// Selisih jam server dikurangi jam HP saat kredensial diambil. Ditambahkan
  /// ke timestamp paket supaya jam HP yang salah tidak memicu penolakan replay.
  final int clockOffsetMs;

  /// Kredensial diperbarui bila sisa masa berlakunya kurang dari ini.
  static const Duration refreshBefore = Duration(days: 1);

  PanelCredential({
    required this.panel,
    required this.key,
    required this.expiresAt,
    required this.clockOffsetMs,
  }) {
    if (key.length != 32) {
      throw ArgumentError.value(key.length, 'key', 'harus 32 byte');
    }
  }

  factory PanelCredential.fromApi(
    Map<String, dynamic> data, {
    required DateTime receivedAt,
  }) {
    return PanelCredential(
      panel: data['panel'] as String,
      key: base64Decode(data['key'] as String),
      expiresAt: data['expiresAt'] as int,
      clockOffsetMs:
          (data['serverTime'] as int) - receivedAt.millisecondsSinceEpoch,
    );
  }

  factory PanelCredential.fromJson(Map<String, dynamic> json) {
    return PanelCredential(
      panel: json['panel'] as String,
      key: base64Decode(json['key'] as String),
      expiresAt: json['expiresAt'] as int,
      clockOffsetMs: json['clockOffsetMs'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'panel': panel,
    'key': base64Encode(key),
    'expiresAt': expiresAt,
    'clockOffsetMs': clockOffsetMs,
  };

  /// Waktu sekarang menurut server (ms), berdasarkan jam HP + selisih.
  int serverNowMs([DateTime? now]) =>
      (now ?? DateTime.now()).millisecondsSinceEpoch + clockOffsetMs;

  bool isExpired([DateTime? now]) => serverNowMs(now) ~/ 1000 >= expiresAt;

  bool needsRefresh([DateTime? now]) =>
      expiresAt - serverNowMs(now) ~/ 1000 < refreshBefore.inSeconds;
}
