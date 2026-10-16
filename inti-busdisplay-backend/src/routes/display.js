const express = require('express');
const { HttpError } = require('../lib/http-error');
const { parseDisplayPayload, parsePresetInput } = require('../lib/validation');

function toPresetJson(row) {
  return {
    id: row.id,
    name: row.name,
    payload: JSON.parse(row.payload),
    createdAt: new Date(row.created_at).toISOString(),
    updatedAt: new Date(row.updated_at).toISOString(),
  };
}

function toLogJson(row) {
  return {
    id: row.id,
    deviceId: row.device_id,
    deviceName: row.device_name ?? null,
    payload: JSON.parse(row.payload),
    createdAt: new Date(row.created_at).toISOString(),
  };
}

function displayRouter({ db, auth }) {
  const router = express.Router();

  const insertLog = db.prepare(
    'INSERT INTO display_logs (device_id, payload, created_at) VALUES (?, ?, ?)',
  );
  const listLogs = db.prepare(`
    SELECT l.*, d.name AS device_name
    FROM display_logs l LEFT JOIN devices d ON d.id = l.device_id
    ORDER BY l.id DESC LIMIT ?
  `);

  const listPresets = db.prepare('SELECT * FROM presets ORDER BY name COLLATE NOCASE');
  const findPreset = db.prepare('SELECT * FROM presets WHERE id = ?');
  const findPresetByName = db.prepare('SELECT id FROM presets WHERE name = ? COLLATE NOCASE');
  const insertPreset = db.prepare(
    'INSERT INTO presets (id, name, payload, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
  );
  const updatePreset = db.prepare(
    'UPDATE presets SET name = ?, payload = ?, updated_at = ? WHERE id = ?',
  );
  const deletePreset = db.prepare('DELETE FROM presets WHERE id = ?');

  // Dipakai ApiService.checkConnection(): cukup balas 200.
  router.get('/status', (_req, res) => {
    const [last] = listLogs.all(1);
    res.json({
      data: {
        status: 'ok',
        serverTime: new Date().toISOString(),
        lastDisplay: last ? toLogJson(last) : null,
      },
    });
  });

  // Dipanggil setelah payload berhasil terkirim ke panel via BLE.
  router.post('/send', auth, (req, res) => {
    const payload = parseDisplayPayload(req.body);
    const createdAt = Date.now();
    const { lastInsertRowid } = insertLog.run(req.device.id, JSON.stringify(payload), createdAt);
    res.json({ data: { id: Number(lastInsertRowid), createdAt: new Date(createdAt).toISOString() } });
  });

  router.get('/logs', (req, res) => {
    const limit = Math.min(Math.max(Number.parseInt(req.query.limit, 10) || 20, 1), 200);
    res.json({ data: listLogs.all(limit).map(toLogJson) });
  });

  router.get('/presets', (_req, res) => {
    res.json({ data: listPresets.all().map(toPresetJson) });
  });

  router.post('/presets', auth, (req, res) => {
    const { name, payload } = parsePresetInput(req.body);
    if (findPresetByName.get(name)) {
      throw new HttpError(409, `Nama preset "${name}" sudah terdaftar.`);
    }

    const id = crypto.randomUUID();
    const now = Date.now();
    insertPreset.run(id, name, JSON.stringify(payload), now, now);
    res.status(201).json({ data: toPresetJson(findPreset.get(id)) });
  });

  router.put('/presets/:id', auth, (req, res) => {
    if (!findPreset.get(req.params.id)) {
      throw new HttpError(404, 'Preset tidak ditemukan.');
    }
    const { name, payload } = parsePresetInput(req.body);
    const sameName = findPresetByName.get(name);
    if (sameName && sameName.id !== req.params.id) {
      throw new HttpError(409, `Nama preset "${name}" sudah dipakai oleh preset lain.`);
    }

    updatePreset.run(name, JSON.stringify(payload), Date.now(), req.params.id);
    res.json({ data: toPresetJson(findPreset.get(req.params.id)) });
  });

  router.delete('/presets/:id', auth, (req, res) => {
    if (!findPreset.get(req.params.id)) {
      throw new HttpError(404, 'Preset tidak ditemukan.');
    }
    deletePreset.run(req.params.id);
    res.json({ data: { id: req.params.id } });
  });

  return router;
}

module.exports = { displayRouter };
