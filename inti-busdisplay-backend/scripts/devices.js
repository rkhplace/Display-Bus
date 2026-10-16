// Mengelola device yang sudah dipasangkan.
// Pemakaian:
//   npm run devices:list
//   npm run devices:revoke -- <deviceId>
const config = require('../src/config');
const { openDatabase } = require('../src/db');

const [command, deviceId] = process.argv.slice(2);
const db = openDatabase(config.dbPath);

function formatTime(millis) {
  return millis ? new Date(millis).toLocaleString('id-ID') : '-';
}

if (command === 'list') {
  const devices = db.prepare('SELECT * FROM devices ORDER BY paired_at DESC').all();
  if (devices.length === 0) {
    console.log('Belum ada device yang dipasangkan.');
  }
  for (const d of devices) {
    console.log(
      [
        d.id,
        `  nama       : ${d.name ?? '-'}`,
        `  dipasangkan: ${formatTime(d.paired_at)}`,
        `  terakhir   : ${formatTime(d.last_seen_at)}`,
        `  status     : ${d.revoked_at ? `DICABUT (${formatTime(d.revoked_at)})` : 'aktif'}`,
      ].join('\n'),
    );
  }
} else if (command === 'revoke' && deviceId) {
  const { changes } = db
    .prepare('UPDATE devices SET revoked_at = ? WHERE id = ? AND revoked_at IS NULL')
    .run(Date.now(), deviceId);
  console.log(
    changes > 0
      ? `Device ${deviceId} dicabut. Request berikutnya dari device itu akan ditolak (401).`
      : `Device ${deviceId} tidak ditemukan atau sudah dicabut.`,
  );
} else {
  console.log('Pemakaian: npm run devices:list | npm run devices:revoke -- <deviceId>');
  process.exitCode = 1;
}

db.close();
