// Kriptografi paket BLE versi 2 — HARUS identik dengan:
// - app:      lib/core/services/ble_payload_cipher.dart
// - firmware: src/display_config.cpp
//
// Paket: [0x02][deviceId 16B][expiresAt u32 BE][nonce 12B][ciphertext][tag 16B]
//   AAD       = 21 byte pertama (versi + deviceId + expiresAt)
//   kunci     = HMAC-SHA256(kunciPanel, "busdisplay-v2" || deviceId || expiresAt)
//   plaintext = JSON {"ts": <ms epoch>, "payload": {...}} atau {"ts": .., "hello": true}
//
// Kunci panel hanya ada di server dan di panel itu sendiri. HP hanya menerima
// kunci turunan yang terikat ke deviceId-nya dan punya masa berlaku.
const { createDecipheriv, createHmac, randomBytes } = require('node:crypto');

const PACKET_VERSION = 0x02;
const HEADER_LENGTH = 1 + 16 + 4;
const NONCE_LENGTH = 12;
const TAG_LENGTH = 16;
const KEY_CONTEXT = Buffer.from('busdisplay-v2', 'utf8');

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Nama panel = nama BLE yang di-advertise firmware (mis. "P5-BUS-01").
const PANEL_NAME_PATTERN = /^[A-Za-z0-9_-]{1,20}$/;

function isUuid(value) {
  return typeof value === 'string' && UUID_PATTERN.test(value);
}

function deviceIdBytes(deviceId) {
  if (!isUuid(deviceId)) throw new Error('deviceId harus UUID');
  return Buffer.from(deviceId.replace(/-/g, ''), 'hex');
}

function generatePanelKey() {
  return randomBytes(32);
}

function deriveDeviceKey(panelKey, deviceId, expiresAt) {
  const exp = Buffer.alloc(4);
  exp.writeUInt32BE(expiresAt);
  return createHmac('sha256', panelKey)
    .update(KEY_CONTEXT)
    .update(deviceIdBytes(deviceId))
    .update(exp)
    .digest();
}

// Dipakai test lintas bahasa untuk memastikan paket buatan app bisa dibuka
// dengan aturan yang sama dengan firmware.
function decryptPacket(panelKey, packet) {
  if (packet.length < HEADER_LENGTH + NONCE_LENGTH + TAG_LENGTH + 2) {
    throw new Error('paket terlalu pendek');
  }
  if (packet[0] !== PACKET_VERSION) throw new Error('versi paket tidak dikenal');

  const header = packet.subarray(0, HEADER_LENGTH);
  const idHex = packet.subarray(1, 17).toString('hex');
  const deviceId = `${idHex.slice(0, 8)}-${idHex.slice(8, 12)}-${idHex.slice(12, 16)}-${idHex.slice(16, 20)}-${idHex.slice(20)}`;
  const expiresAt = packet.readUInt32BE(17);
  const nonce = packet.subarray(HEADER_LENGTH, HEADER_LENGTH + NONCE_LENGTH);
  const body = packet.subarray(HEADER_LENGTH + NONCE_LENGTH, packet.length - TAG_LENGTH);
  const tag = packet.subarray(packet.length - TAG_LENGTH);

  const decipher = createDecipheriv(
    'aes-256-gcm',
    deriveDeviceKey(panelKey, deviceId, expiresAt),
    nonce,
  );
  decipher.setAAD(header);
  decipher.setAuthTag(tag);
  const plaintext = Buffer.concat([decipher.update(body), decipher.final()]);
  return { deviceId, expiresAt, message: JSON.parse(plaintext.toString('utf8')) };
}

module.exports = {
  PANEL_NAME_PATTERN,
  isUuid,
  generatePanelKey,
  deriveDeviceKey,
  decryptPacket,
};
