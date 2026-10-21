// Mengelola panel dan kunci per panel.
// Pemakaian:
//   npm run panels:add -- <nama> [--out <path secrets.h>]
//   npm run panels:secrets -- <nama> [--out <path secrets.h>]
//   npm run panels:list
//   npm run panels:remove -- <nama>
//
// <nama> = nama BLE panel, mis. P5-BUS-01. Firmware panel itu harus di-flash
// dengan secrets.h hasil perintah add/secrets.
const fs = require('node:fs');
const path = require('node:path');
const config = require('../src/config');
const { openDatabase } = require('../src/db');
const { PANEL_NAME_PATTERN, generatePanelKey } = require('../src/lib/panel-crypto');

const [command, name, ...rest] = process.argv.slice(2);
const outIndex = rest.indexOf('--out');
const outPath = outIndex >= 0 ? rest[outIndex + 1] : null;

const db = openDatabase(config.dbPath);
const findPanel = db.prepare('SELECT * FROM panels WHERE name = ? COLLATE NOCASE');

function secretsHeader(panel) {
  const bytes = [...Buffer.from(panel.key, 'base64')].map(
    (b) => `0x${b.toString(16).padStart(2, '0')}`,
  );
  const rows = [];
  for (let i = 0; i < bytes.length; i += 8) rows.push(`  ${bytes.slice(i, i + 8).join(', ')},`);
  return [
    '#pragma once',
    '#include <stdint.h>',
    '',
    `// Dibuat oleh "npm run panels:${command}" untuk panel ${panel.name}.`,
    '// RAHASIA: jangan di-commit, jangan dipakai untuk panel lain.',
    '',
    `#define PANEL_NAME "${panel.name}"`,
    '',
    'static const uint8_t PANEL_KEY[32] = {',
    ...rows,
    '};',
    '',
  ].join('\n');
}

function emitSecrets(panel) {
  const header = secretsHeader(panel);
  if (outPath) {
    const target = path.resolve(process.cwd(), outPath);
    fs.writeFileSync(target, header);
    console.log(`secrets.h untuk ${panel.name} ditulis ke ${target}`);
  } else {
    console.log('Simpan sebagai inti-busdisplay-firmware/include/secrets.h:\n');
    console.log(header);
  }
}

function requireName() {
  if (!name || !PANEL_NAME_PATTERN.test(name)) {
    console.error('Nama panel wajib: 1-20 karakter huruf, angka, "-" atau "_" (mis. P5-BUS-01).');
    process.exit(1);
  }
}

switch (command) {
  case 'add': {
    requireName();
    if (findPanel.get(name)) {
      console.error(`Panel ${name} sudah terdaftar. Pakai "panels:secrets" untuk mencetak ulang kuncinya.`);
      process.exit(1);
    }
    db.prepare('INSERT INTO panels (name, key, created_at) VALUES (?, ?, ?)').run(
      name,
      generatePanelKey().toString('base64'),
      Date.now(),
    );
    console.log(`Panel ${name} terdaftar.`);
    emitSecrets(findPanel.get(name));
    break;
  }
  case 'secrets': {
    requireName();
    const panel = findPanel.get(name);
    if (!panel) {
      console.error(`Panel ${name} belum terdaftar.`);
      process.exit(1);
    }
    emitSecrets(panel);
    break;
  }
  case 'list': {
    const panels = db.prepare('SELECT name, created_at FROM panels ORDER BY name').all();
    if (panels.length === 0) console.log('Belum ada panel terdaftar.');
    for (const p of panels) {
      console.log(`${p.name}  (didaftarkan ${new Date(p.created_at).toLocaleString('id-ID')})`);
    }
    break;
  }
  case 'remove': {
    requireName();
    const { changes } = db.prepare('DELETE FROM panels WHERE name = ? COLLATE NOCASE').run(name);
    console.log(
      changes > 0
        ? `Panel ${name} dihapus. Device tidak bisa lagi meminta kredensial untuk panel ini.`
        : `Panel ${name} tidak ditemukan.`,
    );
    break;
  }
  default:
    console.log('Pemakaian: panels:add|panels:secrets -- <nama> [--out path] | panels:list | panels:remove -- <nama>');
    process.exitCode = 1;
}

db.close();
