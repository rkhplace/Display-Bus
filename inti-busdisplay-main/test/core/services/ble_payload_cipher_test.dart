import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:runningtext_app/core/services/ble_payload_cipher.dart';

void main() {
  group('BlePayloadCipher.encryptPayload', () {
    final payload = {'route': 'B1 • Bandung - Garut', 'speed': 50};

    test('dengan token (bukan raw key) menghasilkan bytes IV + ciphertext', () {
      final bytes = BlePayloadCipher.encryptPayload(
        payload: payload,
        keySource: 'some-device-token',
        keySourceIsRawKey: false,
      );

      expect(bytes.length, greaterThan(16));
      expect((bytes.length - 16) % 16, 0);
    });

    test(
      'dengan raw bleKey (base64 32-byte) juga menghasilkan bytes valid',
      () {
        final rawKey = base64Encode(List<int>.filled(32, 7));

        final bytes = BlePayloadCipher.encryptPayload(
          payload: payload,
          keySource: rawKey,
          keySourceIsRawKey: true,
        );

        expect(bytes.length, greaterThan(16));
        expect((bytes.length - 16) % 16, 0);
      },
    );

    test(
      'dua panggilan dengan payload & key sama menghasilkan ciphertext '
      'berbeda (IV acak per panggilan — bukan bug, ini properti keamanan)',
      () {
        final bytes1 = BlePayloadCipher.encryptPayload(
          payload: payload,
          keySource: 'same-token',
        );
        final bytes2 = BlePayloadCipher.encryptPayload(
          payload: payload,
          keySource: 'same-token',
        );

        expect(bytes1, isNot(equals(bytes2)));
      },
    );

    test('keySourceIsRawKey=true dengan base64 tidak valid melempar error', () {
      expect(
        () => BlePayloadCipher.encryptPayload(
          payload: payload,
          keySource: 'bukan-base64-valid-!!!',
          keySourceIsRawKey: true,
        ),
        throwsA(anything),
      );
    });
  });
}
