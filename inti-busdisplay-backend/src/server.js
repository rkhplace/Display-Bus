const os = require('node:os');
const config = require('./config');
const { openDatabase } = require('./db');
const { createApp } = require('./app');

const db = openDatabase(config.dbPath);
const app = createApp({ db, config });

const { count: panelCount } = db.prepare('SELECT COUNT(*) AS count FROM panels').get();
if (panelCount === 0) {
  console.warn(
    '[PERINGATAN] Belum ada panel terdaftar, jadi aplikasi belum bisa mengontrol panel mana pun.\n' +
      '  Daftarkan dengan: npm run panels:add -- P5-BUS-01',
  );
}

function lanAddresses() {
  return Object.values(os.networkInterfaces())
    .flat()
    .filter((iface) => iface && iface.family === 'IPv4' && !iface.internal)
    .map((iface) => iface.address);
}

// Express 5 meneruskan error listen (mis. port terpakai) ke callback ini,
// bukan melemparnya, jadi wajib diperiksa.
const server = app.listen(config.port, config.host, (err) => {
  if (err) {
    console.error(
      err.code === 'EADDRINUSE'
        ? `[ERROR] Port ${config.port} sudah dipakai. Backend mungkin sudah jalan di terminal lain.`
        : `[ERROR] Server gagal jalan: ${err.message}`,
    );
    db.close();
    process.exit(1);
  }
  console.log(`Smart Bus Display backend jalan di port ${config.port}`);
  for (const ip of lanAddresses()) {
    console.log(`  BACKEND_IP=${ip}  BACKEND_PORT=${config.port}  BACKEND_SCHEME=http`);
  }
});

function shutdown() {
  server.close(() => {
    db.close();
    process.exit(0);
  });
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
