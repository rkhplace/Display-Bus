import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:runningtext_app/core/services/ble_payload_cipher.dart';
import '../../fakes/test_credentials.dart';
import 'cipher_test_support.dart';

/// Byte persis paket vektor uji. Nilai yang sama dikunci di
/// inti-busdisplay-backend/test/api.test.js dan firmware src/self_test.cpp.
const expectedVectorHex =
    '023f2b1c4e000040008000000000000001f4865700a0a1a2a3a4a5a6a7a8a9aaab'
    '9ddc50cd83d1ac8a2fc3794c6a4893ef8f6023bb7494834fad27fdb93d944c421d'
    'fd23f64997c0374f77f62519c27571d520a08f31bc3ef44eaaacffd790f4aa3fa2'
    'b869b2c02a7dc828b62d223248d60d41f0add51c0a6b54747df9bdecd535ff45a2'
    'b10c778c379571b339b367b21ff3940ed608bcaa55f0fd09fb56e872dadb751cd5'
    '30cd5c27f4f7b6ead271306752354bda7fa627fc53a8c03643859055c2693cb7f1'
    '90b27c';

void main() {
  const deviceId = vectorDeviceId;

  group('BlePayloadCipher v2 (AES-256-GCM)', () {
    test('vektor uji: byte paket sama persis dengan firmware & backend', () {
      expect(toHex(buildVectorPacket()), expectedVectorHex);
    });

    test('susunan header: versi, deviceId, masa berlaku, nonce', () {
      final cred = testCredential();
      final packet = BlePayloadCipher.encrypt(
        message: const {'hello': true},
        credential: cred,
        deviceId: deviceId,
      );

      expect(packet[0], 0x02);
      expect(packet.sublist(1, 17), BlePayloadCipher.deviceIdBytes(deviceId));
      expect(
        ByteData.sublistView(packet, 17, 21).getUint32(0),
        cred.expiresAt,
      );
      // header + nonce + plaintext + tag 16 byte
      expect(packet.length, greaterThan(21 + 12 + 16));
    });

    test('bisa dibuka dengan kunci yang benar; ts memakai jam server', () {
      final cred = testCredential(clockOffsetMs: 60000);
      final now = DateTime.utc(2026, 10, 21, 10);
      final packet = BlePayloadCipher.encrypt(
        message: const {'payload': {'route': 'X'}},
        credential: cred,
        deviceId: deviceId,
        now: now,
      );

      final opened = openPacket(packet, cred.key);
      expect(opened['ts'], now.millisecondsSinceEpoch + 60000);
      expect(opened['payload'], {'route': 'X'});
    });

    test('mengubah satu bit di bagian mana pun membuat paket ditolak', () {
      final cred = testCredential();
      final packet = BlePayloadCipher.encrypt(
        message: const {'payload': {'route': 'X'}},
        credential: cred,
        deviceId: deviceId,
      );

      // header (timestamp kedaluwarsa), nonce, ciphertext, dan tag
      for (final index in [0, 5, 18, 25, 40, packet.length - 1]) {
        final tampered = Uint8List.fromList(packet)..[index] ^= 0x01;
        expect(
          () => openPacket(tampered, cred.key),
          throwsA(anything),
          reason: 'byte $index diubah tapi tetap diterima',
        );
      }
    });

    test('kredensial device lain tidak bisa membuka paket', () {
      final mine = testCredential(keySeed: 1);
      final other = testCredential(keySeed: 2);
      final packet = BlePayloadCipher.encrypt(
        message: const {'hello': true},
        credential: mine,
        deviceId: deviceId,
      );

      expect(() => openPacket(packet, other.key), throwsA(anything));
    });

    test('nonce acak: dua paket sama isinya tetap berbeda', () {
      final cred = testCredential();
      final now = DateTime.utc(2026);
      Uint8List make() => BlePayloadCipher.encrypt(
        message: const {'hello': true},
        credential: cred,
        deviceId: deviceId,
        now: now,
      );

      expect(make(), isNot(equals(make())));
    });

    test('deviceId bukan UUID ditolak', () {
      expect(
        () => BlePayloadCipher.encrypt(
          message: const {'hello': true},
          credential: testCredential(),
          deviceId: 'bukan-uuid',
        ),
        throwsArgumentError,
      );
    });
  });
}
