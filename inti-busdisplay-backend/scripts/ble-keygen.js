// Membuat kunci AES-256 untuk payload BLE.
// Isi BLE_KEY di .env backend dengan nilai base64, dan flash nilai yang sama
// (format array byte di bawah) ke firmware ESP32.
const { randomBytes } = require('node:crypto');

const key = randomBytes(32);
const cArray = [...key].map((b) => `0x${b.toString(16).padStart(2, '0')}`);

console.log('');
console.log('BLE_KEY (untuk .env backend):');
console.log(`  BLE_KEY=${key.toString('base64')}`);
console.log('');
console.log('Untuk firmware ESP32:');
console.log('  static const uint8_t BLE_KEY[32] = {');
for (let i = 0; i < cArray.length; i += 8) {
  console.log(`    ${cArray.slice(i, i + 8).join(', ')},`);
}
console.log('  };');
console.log('');
