const path = require('node:path');

const rootDir = path.resolve(__dirname, '..');

function resolveDbPath(raw) {
  if (!raw) return path.join(rootDir, 'data', 'busdisplay.db');
  if (raw === ':memory:') return raw;
  return path.resolve(rootDir, raw);
}

module.exports = {
  port: Number(process.env.PORT) || 3000,
  host: process.env.HOST || '0.0.0.0',
  dbPath: resolveDbPath(process.env.DB_PATH),
  bleKey: process.env.BLE_KEY?.trim() || null,
  pairingCodeTtlMinutes: Number(process.env.PAIRING_CODE_TTL_MINUTES) || 15,
  // Isi saat server berada di belakang reverse proxy (Nginx/Caddy) supaya
  // req.ip berisi IP asli HP, bukan IP proxy (dipakai pembatas pairing).
  // Contoh: "loopback" bila proxy di mesin yang sama, atau "1" (1 hop).
  trustProxy: process.env.TRUST_PROXY?.trim() || null,
};
