const express = require('express');
const { HttpError } = require('../lib/http-error');
const { parseRouteInput } = require('../lib/validation');

function toRouteJson(row) {
  return {
    id: row.id,
    code: row.code,
    origin: row.origin,
    destination: row.destination,
  };
}

function routesRouter({ db, auth }) {
  const router = express.Router();

  const listRoutes = db.prepare('SELECT * FROM routes ORDER BY created_at, code');
  const findByCode = db.prepare('SELECT 1 FROM routes WHERE code = ? COLLATE NOCASE');
  // Rute searah maupun arah sebaliknya dianggap sama: arah ditangani toggle Pergi/Pulang.
  const findSamePair = db.prepare(`
    SELECT 1 FROM routes
    WHERE (origin = ?1 COLLATE NOCASE AND destination = ?2 COLLATE NOCASE)
       OR (origin = ?2 COLLATE NOCASE AND destination = ?1 COLLATE NOCASE)
  `);
  const insertRoute = db.prepare(
    'INSERT INTO routes (id, code, origin, destination, created_at) VALUES (?, ?, ?, ?, ?)',
  );
  const findById = db.prepare('SELECT * FROM routes WHERE id = ?');
  const countRoutes = db.prepare('SELECT COUNT(*) AS count FROM routes');
  const deleteById = db.prepare('DELETE FROM routes WHERE id = ?');

  router.get('/', auth, (_req, res) => {
    res.json({ data: listRoutes.all().map(toRouteJson) });
  });

  router.post('/', auth, (req, res) => {
    const input = parseRouteInput(req.body);

    if (findByCode.get(input.code)) {
      throw new HttpError(409, `Kode rute "${input.code}" sudah terdaftar.`);
    }
    if (findSamePair.get(input.origin, input.destination)) {
      throw new HttpError(409, `Rute "${input.origin} - ${input.destination}" sudah terdaftar.`);
    }

    const id = crypto.randomUUID();
    insertRoute.run(id, input.code, input.origin, input.destination, Date.now());
    res.status(201).json({ data: toRouteJson(findById.get(id)) });
  });

  router.delete('/:id', auth, (req, res) => {
    if (!findById.get(req.params.id)) {
      throw new HttpError(404, 'Rute tidak ditemukan.');
    }
    if (countRoutes.get().count <= 1) {
      throw new HttpError(409, 'Minimal harus ada 1 rute tersisa!');
    }

    deleteById.run(req.params.id);
    res.json({ data: { id: req.params.id } });
  });

  return router;
}

module.exports = { routesRouter };
