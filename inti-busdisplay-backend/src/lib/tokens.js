const { createHash, randomBytes, randomInt, timingSafeEqual } = require('node:crypto');

// Tanpa O/0 dan I/1 supaya kode tidak salah dibaca saat diketik operator.
const PAIRING_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const PAIRING_CODE_LENGTH = 8;

function generatePairingCode() {
  let code = '';
  for (let i = 0; i < PAIRING_CODE_LENGTH; i++) {
    code += PAIRING_ALPHABET[randomInt(PAIRING_ALPHABET.length)];
  }
  return code;
}

function normalizePairingCode(raw) {
  return String(raw ?? '').trim().toUpperCase();
}

function generateDeviceToken() {
  return randomBytes(32).toString('hex');
}

// Token disimpan sebagai hash: kalau file database bocor, token tidak bisa dipakai.
function hashToken(token) {
  return createHash('sha256').update(token).digest('hex');
}

function tokenMatches(token, expectedHash) {
  const actual = Buffer.from(hashToken(token), 'hex');
  const expected = Buffer.from(expectedHash, 'hex');
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

module.exports = {
  generatePairingCode,
  normalizePairingCode,
  generateDeviceToken,
  hashToken,
  tokenMatches,
};
