import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class BlePayloadCipher {
  const BlePayloadCipher._();

  static Uint8List _deriveKeyFromToken(String token) {
    final digest = sha256.convert(utf8.encode(token));
    return Uint8List.fromList(digest.bytes);
  }

  static List<int> encryptPayload({
    required Map<String, dynamic> payload,
    required String keySource,
    bool keySourceIsRawKey = false,
  }) {
    final keyBytes = keySourceIsRawKey
        ? Uint8List.fromList(base64.decode(keySource))
        : _deriveKeyFromToken(keySource);

    final key = enc.Key(keyBytes);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final envelope = {
      'ts': DateTime.now().toUtc().millisecondsSinceEpoch,
      'payload': payload,
    };
    final plaintext = jsonEncode(envelope);

    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    return [...iv.bytes, ...encrypted.bytes];
  }
}
