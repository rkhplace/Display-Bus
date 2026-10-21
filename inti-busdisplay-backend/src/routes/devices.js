const express = require('express');
const { transaction } = require('../db');
const { HttpError } = require('../lib/http-error');
const { failureLimiter } = require('../middleware/rate-limit');
const { generateDeviceToken, hashToken, normalizePairingCode } = require('../lib/tokens');
const { isUuid } = require('../lib/panel-crypto');

function devicesRouter({ db }) {
  const router = express.Router();

  const limiter = failureLimiter({
    maxFailures: 10,
    windowMs: 15 * 60 * 1000,
    message: 'Terlalu banyak percobaan pairing. Coba lagi dalam 15 menit.',
  });

  const findUsableCode = db.prepare(
    'SELECT * FROM pairing_codes WHERE code = ? AND used_at IS NULL AND expires_at > ?',
  );
  const markCodeUsed = db.prepare(
    'UPDATE pairing_codes SET used_at = ?, used_by = ? WHERE code = ?',
  );
  // Device yang pairing ulang (mis. sesi lokal 30 hari habis) memakai deviceId yang
  // sama, jadi barisnya diperbarui dan status revoke dihapus.
  const upsertDevice = db.prepare(`
    INSERT INTO devices (id, name, token_hash, paired_at)
    VALUES (?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
      name = excluded.name,
      token_hash = excluded.token_hash,
      paired_at = excluded.paired_at,
      revoked_at = NULL
  `);

  router.post('/pair', limiter.guard, (req, res) => {
    const code = normalizePairingCode(req.body?.code);
    const deviceId = req.body?.deviceId;
    const deviceName =
      typeof req.body?.deviceName === 'string' ? req.body.deviceName.trim().slice(0, 60) : null;

    if (!code) throw new HttpError(400, 'Kode pairing wajib diisi.');
    // deviceId ikut dalam penurunan kunci BLE (16 byte), jadi wajib UUID.
    if (!isUuid(deviceId)) {
      throw new HttpError(400, 'Device ID tidak valid.');
    }

    const deviceToken = generateDeviceToken();
    const now = Date.now();

    const paired = transaction(db, () => {
      if (!findUsableCode.get(code, now)) return false;
      markCodeUsed.run(now, deviceId, code);
      upsertDevice.run(deviceId, deviceName, hashToken(deviceToken), now);
      return true;
    });

    if (!paired) {
      limiter.recordFailure(req);
      throw new HttpError(400, 'Kode pairing tidak valid atau sudah kedaluwarsa.');
    }

    // Kunci BLE tidak lagi dibagikan saat pairing: app meminta kredensial per
    // panel lewat POST /api/panels/:name/credential.
    res.status(201).json({ data: { deviceId, deviceToken } });
  });

  return router;
}

module.exports = { devicesRouter };
