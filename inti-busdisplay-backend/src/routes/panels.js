const express = require('express');
const { HttpError } = require('../lib/http-error');
const { deriveDeviceKey } = require('../lib/panel-crypto');

function panelsRouter({ db, auth, config }) {
  const router = express.Router();

  const findPanel = db.prepare('SELECT * FROM panels WHERE name = ? COLLATE NOCASE');

  // Kredensial berumur pendek untuk satu device + satu panel. Device yang
  // dicabut tidak bisa meminta yang baru, jadi aksesnya ke panel habis paling
  // lambat saat kredensial terakhirnya kedaluwarsa (CREDENTIAL_TTL_DAYS).
  router.post('/:name/credential', auth, (req, res) => {
    const panel = findPanel.get(req.params.name);
    if (!panel) {
      throw new HttpError(404, `Panel "${req.params.name}" belum terdaftar di server.`);
    }

    const now = Date.now();
    const expiresAt = Math.floor(now / 1000) + config.credentialTtlDays * 24 * 60 * 60;
    const key = deriveDeviceKey(Buffer.from(panel.key, 'base64'), req.device.id, expiresAt);

    res.json({
      data: {
        panel: panel.name,
        expiresAt,
        key: key.toString('base64'),
        // App memakai ini untuk menyelaraskan timestamp paket dengan jam
        // server, supaya jam HP yang salah tidak memicu penolakan replay.
        serverTime: now,
      },
    });
  });

  return router;
}

module.exports = { panelsRouter };
