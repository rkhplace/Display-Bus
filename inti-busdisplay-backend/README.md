# Smart Bus Display — Backend

Backend untuk aplikasi Flutter **Smart Bus Display** (folder `../inti-busdisplay-main`). Tugasnya:

- Pairing device (HP/tablet operator) dengan kode sekali pakai, lalu memberi `deviceToken` dan `bleKey`.
- Menyimpan daftar rute dan preset tampilan.
- Mencatat riwayat setiap payload yang dikirim aplikasi ke panel P5.

Stack: Node.js + Express 5 + SQLite bawaan Node (`node:sqlite`). Tidak ada dependency native, jadi `npm install` tidak butuh compiler.

## Arsitektur singkat

```
[App Flutter] --BLE (AES-256-CBC, bleKey)--> [ESP32 + panel P5 64x32]
      |
      +--HTTP /api--> [Backend ini] --> SQLite (data/busdisplay.db)
```

Panel tidak pernah berbicara dengan backend. Backend hanya membagikan `bleKey` ke aplikasi saat pairing. Kunci yang sama di-flash ke firmware ESP32.

## Persiapan

Butuh **Node.js 22.13+** (sudah diuji di Node 24).

```bash
npm install
cp .env.example .env
npm run ble:keygen
```

Salin baris `BLE_KEY=...` dari output `ble:keygen` ke `.env`. Array byte `BLE_KEY[32]` di output yang sama dipakai di firmware ESP32. Simpan output ini; kalau kunci diganti, semua device harus pairing ulang dan firmware di-flash ulang.

## Menjalankan

```bash
npm start        # mode biasa
npm run dev      # restart otomatis saat file berubah
npm test         # test API (database in-memory)
```

Saat start, server mencetak nilai `BACKEND_IP`/`BACKEND_PORT`/`BACKEND_SCHEME` untuk diisi di `.env` aplikasi Flutter. HP dan laptop harus satu jaringan WiFi. Untuk demo di LAN pakai `BACKEND_SCHEME=http`.

> Jika Windows Firewall bertanya saat pertama kali start, izinkan untuk jaringan **Private**, kalau tidak HP tidak bisa mengakses server.

## Perintah admin

| Perintah | Fungsi |
| --- | --- |
| `npm run pair:generate` | Membuat kode pairing 8 karakter, berlaku 15 menit (atur di `PAIRING_CODE_TTL_MINUTES`), sekali pakai |
| `npm run devices:list` | Daftar device yang sudah dipasangkan beserta waktu terakhir aktif |
| `npm run devices:revoke -- <deviceId>` | Mencabut device; request berikutnya dibalas 401 dan aplikasi kembali ke layar Pairing |
| `npm run ble:keygen` | Membuat kunci BLE baru (base64 untuk `.env`, array byte untuk ESP32) |
| `npm run db:backup` | Menyalin database ke `backups/busdisplay-<waktu>.db`, aman walaupun server sedang jalan |

## API

Semua path diawali `/api`. Respons sukses berbentuk `{ "data": ... }`, respons gagal berbentuk `{ "error": "pesan" }` (pesan berbahasa Indonesia dan aman ditampilkan ke operator).

Semua endpoint kecuali `status` dan `pair` wajib membawa header `x-device-id` dan `x-device-token` dari hasil pairing (kolom **Auth**). Token salah, device tidak dikenal, atau device dicabut dibalas `401`, dan aplikasi lalu kembali ke layar Pairing.

| Method | Path | Auth | Keterangan |
| --- | --- | --- | --- |
| GET | `/display/status` | – | Cek server hidup. Tidak memuat data apa pun |
| POST | `/devices/pair` | – | `{code, deviceId, deviceName?}` → `201 {data:{deviceId, deviceToken, bleKey}}` |
| GET | `/routes` | ✓ | Daftar rute `{id, code, origin, destination}` |
| POST | `/routes` | ✓ | Tambah rute → `201`; `409` jika kode sama atau pasangan kota sama (searah/kebalikan) |
| DELETE | `/routes/:id` | ✓ | Hapus rute; `404` jika tidak ada, `409` jika tinggal 1 rute |
| POST | `/display/send` | ✓ | Simpan payload yang baru dikirim ke panel ke riwayat |
| GET | `/display/logs?limit=20` | ✓ | Riwayat tampilan terbaru (maks 200) |
| GET | `/display/presets` | ✓ | Daftar preset `{id, name, payload, createdAt, updatedAt}` |
| POST | `/display/presets` | ✓ | `{name, payload}` → `201`; `409` jika nama sudah dipakai |
| PUT | `/display/presets/:id` | ✓ | Timpa preset; `404`/`409` |
| DELETE | `/display/presets/:id` | ✓ | Hapus preset (belum dipakai aplikasi) |

### Bentuk payload tampilan

Sama dengan `DisplayPayloadBuilder.build()` di aplikasi, dan divalidasi server:

```json
{
  "route": "B1 • Bandung - Garut",
  "direction": "Pergi",
  "animation": "Scroll Left",
  "speed": 50,
  "brightness": 80,
  "fontSize": 16
}
```

- `direction`: `Pergi` atau `Pulang`.
- `animation`: `Running`, `Static`, `Blink`, `Scroll Left`, `Scroll Right`, `Scroll Up`, `Scroll Down`. Kalau menambah mode di `AnimationMode` aplikasi, tambahkan juga di `src/lib/validation.js`.
- `speed`, `brightness`, `fontSize`: bilangan bulat 0–100.

### Format paket BLE (untuk firmware ESP32)

Aplikasi menulis ke karakteristik BLE: `IV (16 byte) || ciphertext AES-256-CBC (PKCS7)`. Hasil dekripsinya adalah JSON:

```json
{ "ts": 1760500000000, "payload": { ...payload tampilan di atas... } }
```

`ts` adalah waktu kirim (ms epoch UTC) dari HP.

## Struktur folder

```
src/
├── server.js              # entry point: buka DB, jalankan HTTP server
├── app.js                 # rakit Express + error handler { error }
├── config.js              # baca variabel environment
├── db.js                  # skema SQLite + seed rute default (B1, B2)
├── lib/                   # token & kode pairing, validasi, HttpError
├── middleware/            # auth device, pembatas percobaan pairing
└── routes/                # devices, routes, display (+ presets & logs)
scripts/                   # CLI admin (pair:generate, devices, ble:keygen)
test/api.test.js           # test seluruh endpoint
```

## Deploy ke server

Untuk pemakaian di luar demo, backend dijalankan di server tetap (server kantor atau VPS), bukan di laptop.

1. **Pasang Node.js 22.13+**, salin folder ini, lalu jalankan `npm ci --omit=dev`. Buat `.env` dengan `BLE_KEY` yang sama dengan firmware.
2. **Jalankan sebagai service** supaya otomatis hidup lagi setelah crash atau reboot, misalnya dengan [pm2](https://pm2.keymetrics.io/):
   ```bash
   pm2 start npm --name busdisplay -- start
   pm2 save && pm2 startup
   ```
   Atau pakai unit systemd yang menjalankan `npm start` di folder ini.
3. **Pasang HTTPS di depan backend** dengan reverse proxy. Contoh Caddy (sertifikat dibuat otomatis):
   ```
   busdisplay.contoh.co.id {
       reverse_proxy 127.0.0.1:3000
   }
   ```
   Setelah itu set `HOST=127.0.0.1` dan `TRUST_PROXY=loopback` di `.env`, supaya backend hanya bisa diakses lewat proxy dan pembatas pairing membaca IP asli HP.
4. **Arahkan aplikasi ke server.** Di `.env` aplikasi: `BACKEND_IP=busdisplay.contoh.co.id`, `BACKEND_PORT=443`, `BACKEND_SCHEME=https`, lalu build ulang.
5. **Backup terjadwal.** Jalankan `npm run db:backup` setiap hari (cron atau Task Scheduler) dan salin folder `backups/` ke luar server.

## Catatan keamanan

Yang sudah ada:
- Token device disimpan sebagai hash SHA-256.
- Semua data (rute, preset, riwayat) hanya bisa dibaca device yang sudah dipasangkan.
- Kode pairing sekali pakai dan kedaluwarsa.
- Percobaan pairing gagal dibatasi 10 kali per 15 menit per IP.
- Payload divalidasi.

Yang belum (catatan untuk pengembangan berikutnya):
- **Semua panel memakai satu `BLE_KEY`.** Idealnya satu kunci per panel.
- **AES-CBC tanpa MAC.** Lebih aman memakai AES-GCM. Ini perlu diubah di aplikasi dan firmware sekaligus, sebaiknya setelah uji hardware dengan format sekarang lolos.
- **HTTPS bergantung pada reverse proxy.** Tanpa langkah Deploy no. 3, lalu lintas berjalan tanpa enkripsi.
