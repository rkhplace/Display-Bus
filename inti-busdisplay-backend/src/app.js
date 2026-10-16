const express = require('express');
const { HttpError } = require('./lib/http-error');
const { deviceAuth } = require('./middleware/device-auth');
const { devicesRouter } = require('./routes/devices');
const { routesRouter } = require('./routes/routes');
const { displayRouter } = require('./routes/display');

function createApp({ db, config }) {
  const app = express();
  const auth = deviceAuth(db);

  app.disable('x-powered-by');

  // CORS untuk aplikasi versi web (flutter run -d chrome). Aman memakai "*"
  // karena auth lewat header x-device-*, bukan cookie, jadi situs lain tidak
  // bisa menumpang sesi browser.
  app.use((req, res, next) => {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, x-device-id, x-device-token');
    res.set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    if (req.method === 'OPTIONS') return res.sendStatus(204);
    next();
  });

  app.use(express.json({ limit: '16kb' }));

  app.use('/api/devices', devicesRouter({ db, config }));
  app.use('/api/routes', routesRouter({ db, auth }));
  app.use('/api/display', displayRouter({ db, auth }));

  app.use((_req, _res, next) => next(new HttpError(404, 'Endpoint tidak ditemukan.')));

  // Semua error dibalas { error } karena itu yang dibaca ApiService._extractErrorMessage().
  app.use((err, req, res, _next) => {
    if (err instanceof HttpError) {
      return res.status(err.status).json({ error: err.message });
    }
    if (err.type === 'entity.parse.failed') {
      return res.status(400).json({ error: 'Body JSON tidak valid.' });
    }
    if (err.type === 'entity.too.large') {
      return res.status(413).json({ error: 'Data terlalu besar.' });
    }

    console.error(`[${req.method} ${req.originalUrl}]`, err);
    res.status(500).json({ error: 'Terjadi kesalahan pada server.' });
  });

  return app;
}

module.exports = { createApp };
