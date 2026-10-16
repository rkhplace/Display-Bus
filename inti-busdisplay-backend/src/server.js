const os = require('node:os');
const config = require('./config');
const { openDatabase } = require('./db');
const { createApp } = require('./app');

const db = openDatabase(config.dbPath);
const app = createApp({ db, config });

if (!config.bleKey) {
  console.warn(
    '[PERINGATAN] BLE_KEY belum diset. Device yang pairing tidak akan menerima bleKey,\n' +
      '  sehingga aplikasi memakai SHA-256(deviceToken) sebagai kunci dan panel tidak bisa\n' +
      '  mendekripsi payload. Jalankan "npm run ble:keygen" lalu isi BLE_KEY di .env.',
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
