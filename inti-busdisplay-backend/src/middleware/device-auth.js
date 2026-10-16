const { HttpError } = require('../lib/http-error');
const { tokenMatches } = require('../lib/tokens');

// Header dikirim oleh ApiService._authHeaders() di aplikasi.
// Status 401 membuat aplikasi menghapus pairing dan kembali ke layar Pairing,
// jadi hanya dipakai untuk token yang memang tidak valid.
function deviceAuth(db) {
  const findDevice = db.prepare('SELECT * FROM devices WHERE id = ?');
  const touch = db.prepare('UPDATE devices SET last_seen_at = ? WHERE id = ?');

  return (req, _res, next) => {
    const deviceId = req.get('x-device-id');
    const token = req.get('x-device-token');

    if (!deviceId || !token) {
      throw new HttpError(401, 'Device belum dipasangkan.');
    }

    const device = findDevice.get(deviceId);
    if (!device || !tokenMatches(token, device.token_hash)) {
      throw new HttpError(401, 'Sesi device tidak valid. Silakan pairing ulang.');
    }
    if (device.revoked_at) {
      throw new HttpError(401, 'Device sudah dicabut oleh admin. Silakan pairing ulang.');
    }

    touch.run(Date.now(), device.id);
    req.device = device;
    next();
  };
}

module.exports = { deviceAuth };
