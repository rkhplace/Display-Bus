import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import '../models/panel_credential.dart';

/// Paket BLE versi 2 — HARUS identik dengan firmware (src/display_config.cpp)
/// dan backend (src/lib/panel-crypto.js):
///
/// ```
/// [0x02][deviceId 16B][expiresAt u32 BE][nonce 12B][ciphertext][tag 16B]
/// ```
/// - Enkripsi AES-256-GCM dengan kunci kredensial panel.
/// - 21 byte pertama (versi, deviceId, expiresAt) menjadi AAD: tidak
///   dienkripsi tapi ikut diautentikasi, jadi tidak bisa diubah.
/// - Plaintext: JSON `{"ts": <ms jam server>, ...message}`.
///
/// Berbeda dengan versi 1 (AES-CBC tanpa MAC), mengubah satu bit pun di paket
/// membuat panel menolaknya, termasuk mengubah timestamp anti-replay.
class BlePayloadCipher {
  const BlePayloadCipher._();

  static const int version = 0x02;
  static const int headerLength = 1 + 16 + 4;
  static const int nonceLength = 12;
  static const int tagLength = 16;

  static final _random = Random.secure();

  static Uint8List deviceIdBytes(String deviceId) {
    final hex = deviceId.replaceAll('-', '');
    if (!RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(hex)) {
      throw ArgumentError.value(deviceId, 'deviceId', 'harus UUID');
    }
    return Uint8List.fromList([
      for (var i = 0; i < 32; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
    ]);
  }

  static Uint8List buildHeader({
    required String deviceId,
    required int expiresAt,
  }) {
    final header = ByteData(headerLength)..setUint8(0, version);
    final id = deviceIdBytes(deviceId);
    for (var i = 0; i < id.length; i++) {
      header.setUint8(1 + i, id[i]);
    }
    header.setUint32(17, expiresAt, Endian.big);
    return header.buffer.asUint8List();
  }

  /// Mengenkripsi [message] (mis. `{'payload': {...}}` atau `{'hello': true}`)
  /// untuk panel [credential]. [now] dan [nonce] hanya diisi oleh test.
  static Uint8List encrypt({
    required Map<String, dynamic> message,
    required PanelCredential credential,
    required String deviceId,
    DateTime? now,
    Uint8List? nonce,
  }) {
    final header = buildHeader(
      deviceId: deviceId,
      expiresAt: credential.expiresAt,
    );
    final iv =
        nonce ??
        Uint8List.fromList(List.generate(nonceLength, (_) => _random.nextInt(256)));
    if (iv.length != nonceLength) {
      throw ArgumentError.value(iv.length, 'nonce', 'harus $nonceLength byte');
    }

    final plaintext = utf8.encode(
      jsonEncode({'ts': credential.serverNowMs(now), ...message}),
    );

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(credential.key), tagLength * 8, iv, header),
      );
    final sealed = cipher.process(Uint8List.fromList(plaintext));

    return Uint8List.fromList([...header, ...iv, ...sealed]);
  }
}
