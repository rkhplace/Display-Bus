// Membuat kode pairing sekali pakai untuk aplikasi Smart Bus Display.
// Pemakaian: npm run pair:generate
const config = require('../src/config');
const { openDatabase } = require('../src/db');
const { generatePairingCode } = require('../src/lib/tokens');

const db = openDatabase(config.dbPath);
const now = Date.now();
const expiresAt = now + config.pairingCodeTtlMinutes * 60 * 1000;

// Kode lama yang sudah kedaluwarsa dan belum terpakai tidak berguna lagi.
db.prepare('DELETE FROM pairing_codes WHERE used_at IS NULL AND expires_at <= ?').run(now);

const insert = db.prepare(
  'INSERT OR IGNORE INTO pairing_codes (code, created_at, expires_at) VALUES (?, ?, ?)',
);
let code;
do {
  code = generatePairingCode();
} while (insert.run(code, now, expiresAt).changes === 0);

db.close();

console.log('');
console.log(`  Kode pairing : ${code}`);
console.log(`  Berlaku s/d  : ${new Date(expiresAt).toLocaleString('id-ID')}`);
console.log('');
console.log('  Masukkan kode ini di layar "Pasangkan Device" pada aplikasi.');
console.log('');
