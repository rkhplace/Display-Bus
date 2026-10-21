const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { openDatabase } = require('../src/db');
const { createApp } = require('../src/app');
const { deriveDeviceKey } = require('../src/lib/panel-crypto');

const PANEL_KEY = Buffer.alloc(32, 7);
const CREDENTIAL_TTL_DAYS = 7;
const DEVICE_ID = '3f2b1c4e-0000-4000-8000-000000000001';

const validPayload = {
  route: 'B1 • Bandung - Garut',
  direction: 'Pergi',
  animation: 'Scroll Left',
  speed: 50,
  brightness: 80,
  fontSize: 16,
};

let db;
let server;
let baseUrl;
let auth;

function createPairingCode(code, expiresInMs = 60_000) {
  const now = Date.now();
  db.prepare('INSERT INTO pairing_codes (code, created_at, expires_at) VALUES (?, ?, ?)').run(
    code,
    now,
    now + expiresInMs,
  );
}

async function request(method, path, { body, headers } = {}) {
  const res = await fetch(`${baseUrl}${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: res.status, body: await res.json() };
}

before(async () => {
  db = openDatabase(':memory:');
  const app = createApp({ db, config: { credentialTtlDays: CREDENTIAL_TTL_DAYS } });
  db.prepare('INSERT INTO panels (name, key, created_at) VALUES (?, ?, ?)').run(
    'P5-BUS-01',
    PANEL_KEY.toString('base64'),
    Date.now(),
  );
  await new Promise((resolve) => {
    server = app.listen(0, '127.0.0.1', resolve);
  });
  baseUrl = `http://127.0.0.1:${server.address().port}/api`;
});

after(() => {
  server.close();
  db.close();
});

test('GET /display/status membalas 200', async () => {
  const res = await request('GET', '/display/status');
  assert.equal(res.status, 200);
  assert.equal(res.body.data.status, 'ok');
  assert.equal(res.body.data.lastDisplay, undefined, 'status publik tidak boleh memuat data');
});

test('GET data (rute, preset, riwayat) tanpa token ditolak 401', async () => {
  for (const path of ['/routes', '/display/presets', '/display/logs']) {
    const res = await request('GET', path);
    assert.equal(res.status, 401, path);
  }
});

test('pairing dengan kode salah ditolak', async () => {
  const res = await request('POST', '/devices/pair', {
    body: { code: 'SALAH123', deviceId: DEVICE_ID },
  });
  assert.equal(res.status, 400);
  assert.match(res.body.error, /tidak valid/);
});

test('pairing dengan kode kedaluwarsa ditolak', async () => {
  createPairingCode('EXPIRED2', -1);
  const res = await request('POST', '/devices/pair', {
    body: { code: 'EXPIRED2', deviceId: DEVICE_ID },
  });
  assert.equal(res.status, 400);
});

test('pairing sukses mengembalikan deviceToken tanpa kunci BLE, kode tidak bisa dipakai ulang', async () => {
  createPairingCode('ABCD2345');
  // Huruf kecil dan spasi tetap diterima.
  const res = await request('POST', '/devices/pair', {
    body: { code: ' abcd2345 ', deviceId: DEVICE_ID, deviceName: 'Tablet Bus 01' },
  });
  assert.equal(res.status, 201);
  assert.equal(typeof res.body.data.deviceToken, 'string');
  assert.equal(res.body.data.bleKey, undefined, 'kunci BLE tidak boleh dibagikan saat pairing');

  auth = { 'x-device-id': DEVICE_ID, 'x-device-token': res.body.data.deviceToken };

  const reuse = await request('POST', '/devices/pair', {
    body: { code: 'ABCD2345', deviceId: '3f2b1c4e-0000-4000-8000-000000000002' },
  });
  assert.equal(reuse.status, 400);
});

test('GET /routes dengan token berisi rute default', async () => {
  const res = await request('GET', '/routes', { headers: auth });
  assert.equal(res.status, 200);
  assert.deepEqual(
    res.body.data.map((r) => r.code),
    ['B1', 'B2'],
  );
  assert.equal(typeof res.body.data[0].id, 'string');
});

test('pairing menolak deviceId yang bukan UUID', async () => {
  createPairingCode('UUIDTEST');
  const res = await request('POST', '/devices/pair', {
    body: { code: 'UUIDTEST', deviceId: 'bukan-uuid-12345' },
  });
  assert.equal(res.status, 400);
});

test('kredensial panel: butuh token, panel harus terdaftar, kunci = HMAC(kunci panel, device, exp)', async () => {
  const noAuth = await request('POST', '/panels/P5-BUS-01/credential');
  assert.equal(noAuth.status, 401);

  const unknown = await request('POST', '/panels/P5-BUS-99/credential', { headers: auth });
  assert.equal(unknown.status, 404);
  assert.match(unknown.body.error, /belum terdaftar/);

  const before = Date.now();
  const res = await request('POST', '/panels/p5-bus-01/credential', { headers: auth });
  assert.equal(res.status, 200);
  const { panel, expiresAt, key, serverTime } = res.body.data;
  assert.equal(panel, 'P5-BUS-01');
  assert.ok(serverTime >= before && serverTime <= Date.now());

  const ttl = expiresAt - Math.floor(serverTime / 1000);
  assert.equal(ttl, CREDENTIAL_TTL_DAYS * 24 * 60 * 60);
  assert.equal(key, deriveDeviceKey(PANEL_KEY, DEVICE_ID, expiresAt).toString('base64'));
  assert.notEqual(key, PANEL_KEY.toString('base64'), 'kunci panel tidak boleh keluar');
});

test('endpoint mutasi menolak request tanpa token / token salah dengan 401', async () => {
  const noAuth = await request('POST', '/routes', {
    body: { code: 'X1', origin: 'A', destination: 'B' },
  });
  assert.equal(noAuth.status, 401);

  const wrong = await request('POST', '/display/send', {
    body: validPayload,
    headers: { 'x-device-id': DEVICE_ID, 'x-device-token': 'salah' },
  });
  assert.equal(wrong.status, 401);
});

test('tambah rute, tolak duplikat kode dan duplikat arah sebaliknya', async () => {
  const created = await request('POST', '/routes', {
    headers: auth,
    body: { code: 'B3', origin: 'Bandung', destination: 'Tasikmalaya' },
  });
  assert.equal(created.status, 201);
  assert.equal(created.body.data.code, 'B3');

  const dupCode = await request('POST', '/routes', {
    headers: auth,
    body: { code: 'b3', origin: 'Cimahi', destination: 'Sumedang' },
  });
  assert.equal(dupCode.status, 409);

  const dupReverse = await request('POST', '/routes', {
    headers: auth,
    body: { code: 'B9', origin: 'garut', destination: 'BANDUNG' },
  });
  assert.equal(dupReverse.status, 409);

  const deleted = await request('DELETE', `/routes/${created.body.data.id}`, { headers: auth });
  assert.equal(deleted.status, 200);

  const missing = await request('DELETE', `/routes/${created.body.data.id}`, { headers: auth });
  assert.equal(missing.status, 404);
});

test('rute terakhir tidak bisa dihapus', async () => {
  const { body } = await request('GET', '/routes', { headers: auth });
  const [first, ...rest] = body.data;
  for (const route of rest) {
    assert.equal((await request('DELETE', `/routes/${route.id}`, { headers: auth })).status, 200);
  }
  const last = await request('DELETE', `/routes/${first.id}`, { headers: auth });
  assert.equal(last.status, 409);
});

test('display/send menyimpan riwayat dan memvalidasi payload', async () => {
  const sent = await request('POST', '/display/send', { headers: auth, body: validPayload });
  assert.equal(sent.status, 200);

  const logs = await request('GET', '/display/logs?limit=1', { headers: auth });
  assert.deepEqual(logs.body.data[0].payload, validPayload);
  assert.equal(logs.body.data[0].deviceName, 'Tablet Bus 01');

  const invalid = await request('POST', '/display/send', {
    headers: auth,
    body: { ...validPayload, animation: 'Zigzag', speed: 150 },
  });
  assert.equal(invalid.status, 400);
});

test('preset: simpan, tolak nama duplikat, timpa, dan muat', async () => {
  const saved = await request('POST', '/display/presets', {
    headers: auth,
    body: { name: 'Preset Pagi', payload: validPayload },
  });
  assert.equal(saved.status, 201);
  const id = saved.body.data.id;

  const dup = await request('POST', '/display/presets', {
    headers: auth,
    body: { name: 'preset pagi', payload: validPayload },
  });
  assert.equal(dup.status, 409);

  const updated = await request('PUT', `/display/presets/${id}`, {
    headers: auth,
    body: { name: 'Preset Pagi', payload: { ...validPayload, animation: 'Blink' } },
  });
  assert.equal(updated.status, 200);

  const list = await request('GET', '/display/presets', { headers: auth });
  assert.equal(list.body.data.length, 1);
  assert.equal(list.body.data[0].id, id);
  assert.equal(list.body.data[0].name, 'Preset Pagi');
  assert.equal(list.body.data[0].payload.animation, 'Blink');
});

test('device yang dicabut mendapat 401', async () => {
  db.prepare('UPDATE devices SET revoked_at = ? WHERE id = ?').run(Date.now(), DEVICE_ID);
  const res = await request('POST', '/display/send', { headers: auth, body: validPayload });
  assert.equal(res.status, 401);

  // Device yang dicabut tidak bisa memperbarui kredensial panel.
  const cred = await request('POST', '/panels/P5-BUS-01/credential', { headers: auth });
  assert.equal(cred.status, 401);
});

test('body JSON rusak dibalas 400 dengan field error', async () => {
  const res = await fetch(`${baseUrl}/routes`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: '{rusak',
  });
  assert.equal(res.status, 400);
  assert.equal(typeof (await res.json()).error, 'string');
});

test('preflight CORS untuk aplikasi web diizinkan', async () => {
  const res = await fetch(`${baseUrl}/routes`, {
    method: 'OPTIONS',
    headers: {
      Origin: 'http://localhost:8080',
      'Access-Control-Request-Method': 'POST',
      'Access-Control-Request-Headers': 'content-type, x-device-id, x-device-token',
    },
  });
  assert.equal(res.status, 204);
  assert.equal(res.headers.get('access-control-allow-origin'), '*');
  assert.match(res.headers.get('access-control-allow-headers'), /x-device-token/);
});

// Vektor uji lintas komponen: paket ini dibuat oleh BlePayloadCipher (app Dart)
// dan juga didekripsi oleh self-test firmware. Lihat
// inti-busdisplay-main/test/core/services/ble_payload_cipher_test.dart.
test('paket buatan app terbuka dengan aturan backend/firmware; paket diubah ditolak', () => {
  const { decryptPacket } = require('../src/lib/panel-crypto');
  const panelKey = Buffer.from([...Array(32).keys()]);
  const packet = Buffer.from(
    '023f2b1c4e000040008000000000000001f4865700a0a1a2a3a4a5a6a7a8a9aaab' +
      '9ddc50cd83d1ac8a2fc3794c6a4893ef8f6023bb7494834fad27fdb93d944c421d' +
      'fd23f64997c0374f77f62519c27571d520a08f31bc3ef44eaaacffd790f4aa3fa2' +
      'b869b2c02a7dc828b62d223248d60d41f0add51c0a6b54747df9bdecd535ff45a2' +
      'b10c778c379571b339b367b21ff3940ed608bcaa55f0fd09fb56e872dadb751cd5' +
      '30cd5c27f4f7b6ead271306752354bda7fa627fc53a8c03643859055c2693cb7f1' +
      '90b27c',
    'hex',
  );

  const opened = decryptPacket(panelKey, packet);
  assert.equal(opened.deviceId, '3f2b1c4e-0000-4000-8000-000000000001');
  assert.equal(opened.expiresAt, 4102444800);
  assert.equal(opened.message.ts, 1792028342419);
  assert.deepEqual(opened.message.payload, { ...validPayload });

  for (const index of [0, 10, 18, 25, 40, packet.length - 1]) {
    const tampered = Buffer.from(packet);
    tampered[index] ^= 0x01;
    assert.throws(() => decryptPacket(panelKey, tampered), undefined, `byte ${index}`);
  }
});
