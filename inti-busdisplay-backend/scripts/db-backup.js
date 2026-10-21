// Membuat salinan database yang konsisten walaupun server sedang berjalan.
// Pemakaian: npm run db:backup            -> backups/busdisplay-<waktu>.db
// Jalankan terjadwal (cron / Task Scheduler) dan simpan salinannya di luar server.
const fs = require('node:fs');
const path = require('node:path');
const config = require('../src/config');
const { openDatabase } = require('../src/db');

if (config.dbPath === ':memory:') {
  console.error('DB_PATH=:memory: tidak bisa di-backup.');
  process.exit(1);
}

const backupDir = path.resolve(__dirname, '..', process.env.BACKUP_DIR || 'backups');
fs.mkdirSync(backupDir, { recursive: true });

const stamp = new Date().toISOString().replace(/[-:]/g, '').replace('T', '-').slice(0, 15);
const target = path.join(backupDir, `busdisplay-${stamp}.db`);

const db = openDatabase(config.dbPath);
// VACUUM INTO menulis snapshot utuh dalam satu transaksi baca, aman saat WAL aktif.
db.prepare('VACUUM INTO ?').run(target);
db.close();

const sizeKb = (fs.statSync(target).size / 1024).toFixed(1);
console.log(`Backup tersimpan: ${target} (${sizeKb} KB)`);
