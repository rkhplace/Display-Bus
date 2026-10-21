import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:runningtext_app/core/models/panel_credential.dart';
import 'package:runningtext_app/core/services/ble_payload_cipher.dart';

/// Input tetap untuk vektor uji lintas komponen. Byte hasilnya dikunci di
/// ble_payload_cipher_test.dart, test backend (api.test.js) dan self-test
/// firmware (self_test.cpp). Kalau format paket berubah, ketiganya ikut gagal.
final vectorPanelKey = Uint8List.fromList(List.generate(32, (i) => i));
const vectorDeviceId = '3f2b1c4e-0000-4000-8000-000000000001';
const vectorExpiresAt = 4102444800; // 2100-01-01 UTC
final vectorNow = DateTime.fromMillisecondsSinceEpoch(1792028342419, isUtc: true);
final vectorNonce = Uint8List.fromList(List.generate(12, (i) => 0xa0 + i));
const vectorMessage = {
  'payload': {
    'route': 'B1 • Bandung - Garut',
    'direction': 'Pergi',
    'animation': 'Scroll Left',
    'speed': 50,
    'brightness': 80,
    'fontSize': 16,
  },
};

/// Meniru penurunan kunci di server: HMAC-SHA256(kunciPanel,
/// "busdisplay-v2" || deviceId || expiresAt BE).
Uint8List deriveDeviceKey(Uint8List panelKey, String deviceId, int expiresAt) {
  final exp = ByteData(4)..setUint32(0, expiresAt, Endian.big);
  final hmac = HMac(SHA256Digest(), 64)..init(KeyParameter(panelKey));
  final input = Uint8List.fromList([
    ...utf8.encode('busdisplay-v2'),
    ...BlePayloadCipher.deviceIdBytes(deviceId),
    ...exp.buffer.asUint8List(),
  ]);
  return hmac.process(input);
}

PanelCredential vectorCredential() => PanelCredential(
  panel: 'P5-BUS-01',
  key: deriveDeviceKey(vectorPanelKey, vectorDeviceId, vectorExpiresAt),
  expiresAt: vectorExpiresAt,
  clockOffsetMs: 0,
);

Uint8List buildVectorPacket() => BlePayloadCipher.encrypt(
  message: vectorMessage,
  credential: vectorCredential(),
  deviceId: vectorDeviceId,
  now: vectorNow,
  nonce: vectorNonce,
);

/// Membuka paket seperti firmware. Melempar bila tag GCM tidak cocok.
Map<String, dynamic> openPacket(Uint8List packet, Uint8List key) {
  const h = BlePayloadCipher.headerLength;
  const n = BlePayloadCipher.nonceLength;
  final header = packet.sublist(0, h);
  final nonce = packet.sublist(h, h + n);
  final sealed = packet.sublist(h + n);
  final cipher = GCMBlockCipher(AESEngine())
    ..init(false, AEADParameters(KeyParameter(key), 128, nonce, header));
  final plain = cipher.process(sealed);
  return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
}

String toHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
