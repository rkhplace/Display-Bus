const fs = require('node:fs');
const path = require('node:path');
const { DatabaseSync } = require('node:sqlite');

const SCHEMA = `
  CREATE TABLE IF NOT EXISTS devices (
    id            TEXT PRIMARY KEY,
    name          TEXT,
    token_hash    TEXT NOT NULL,
    paired_at     INTEGER NOT NULL,
    last_seen_at  INTEGER,
    revoked_at    INTEGER
  );

  CREATE TABLE IF NOT EXISTS pairing_codes (
    code        TEXT PRIMARY KEY,
    created_at  INTEGER NOT NULL,
    expires_at  INTEGER NOT NULL,
    used_at     INTEGER,
    used_by     TEXT
  );

  CREATE TABLE IF NOT EXISTS routes (
    id           TEXT PRIMARY KEY,
    code         TEXT NOT NULL UNIQUE COLLATE NOCASE,
    origin       TEXT NOT NULL,
    destination  TEXT NOT NULL,
    created_at   INTEGER NOT NULL
  );

  CREATE TABLE IF NOT EXISTS presets (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE COLLATE NOCASE,
    payload     TEXT NOT NULL,
    created_at  INTEGER NOT NULL,
    updated_at  INTEGER NOT NULL
  );

  CREATE TABLE IF NOT EXISTS display_logs (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id   TEXT NOT NULL,
    payload     TEXT NOT NULL,
    created_at  INTEGER NOT NULL
  );
`;

// Sama dengan rute default di RouteProvider aplikasi Flutter.
const DEFAULT_ROUTES = [
  { code: 'B1', origin: 'Bandung', destination: 'Garut' },
  { code: 'B2', origin: 'Bandung', destination: 'Jakarta' },
];

function openDatabase(dbPath) {
  if (dbPath !== ':memory:') {
    fs.mkdirSync(path.dirname(dbPath), { recursive: true });
  }

  const db = new DatabaseSync(dbPath);
  db.exec('PRAGMA journal_mode = WAL;');
  db.exec(SCHEMA);
  seedRoutes(db);
  return db;
}

function seedRoutes(db) {
  const { count } = db.prepare('SELECT COUNT(*) AS count FROM routes').get();
  if (count > 0) return;

  const insert = db.prepare(
    'INSERT INTO routes (id, code, origin, destination, created_at) VALUES (?, ?, ?, ?, ?)',
  );
  const now = Date.now();
  for (const route of DEFAULT_ROUTES) {
    insert.run(crypto.randomUUID(), route.code, route.origin, route.destination, now);
  }
}

function transaction(db, fn) {
  db.exec('BEGIN IMMEDIATE');
  try {
    const result = fn();
    db.exec('COMMIT');
    return result;
  } catch (err) {
    db.exec('ROLLBACK');
    throw err;
  }
}

module.exports = { openDatabase, transaction };
