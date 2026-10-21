# Smart Bus Display — Backend

Backend untuk aplikasi Flutter **Smart Bus Display** (folder `../inti-busdisplay-main`). Tugasnya:

- Pairing device (HP/tablet operator) dengan kode sekali pakai, lalu memberi `deviceToken`.
- Menyimpan kunci setiap panel dan menerbitkan kredensial BLE per device yang berumur pendek.
- Menyimpan daftar rute dan preset tampilan.
- Mencatat riwayat setiap payload yang dikirim aplikasi ke panel P5.

Stack: Node.js + Express 5 + SQLite bawaan Node (`node:sqlite`). Tidak ada dependency native, jadi `npm install` tidak butuh compiler.

## Arsitektur singkat

```
[App Flutter] --BLE (AES-256-GCM, kredensial per device)--> [ESP32 + panel P5 64x32]
      |
      +--HTTP /api--> [Backend ini] --> SQLite (data/busdisplay.db)
```

Panel tidak pernah berbicara dengan backend. Kunci panel hanya ada di database backend dan di `secrets.h` panel itu. App meminta **kredensial turunan** per panel (`POST /panels/:nama/credential`) yang terikat ke device-nya dan berlaku `CREDENTIAL_TTL_DAYS`. Model lengkapnya ada di [SECURITY.md](../SECURITY.md).

## Persiapan

Butuh **Node.js 22.13+** (sudah diuji di Node 24).

```bash
npm install
cp .env.example .env
npm run panels:add -- P5-BUS-01 --out ../inti-busdisplay-firmware/include/secrets.h
```

Perintah terakhir mendaftarkan panel `P5-BUS-01` dan menulis `secrets.h` (nama + kunci panel) untuk firmware-nya. Ulangi untuk setiap panel dengan nama berbeda.

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
| `npm run devices:revoke -- <deviceId>` | Mencabut device: API dibalas 401 dan kredensial panel tidak bisa diperbarui. Kredensial yang sudah ada habis paling lama `CREDENTIAL_TTL_DAYS` (lihat SECURITY.md) |
| `npm run panels:add -- <nama> [--out path]` | Mendaftarkan panel baru dengan kunci acak, lalu mencetak/menulis `secrets.h` untuk firmware-nya |
| `npm run panels:secrets -- <nama> [--out path]` | Mencetak ulang `secrets.h` panel yang sudah terdaftar (mis. untuk flash ulang) |
| `npm run panels:list` | Daftar panel terdaftar |
| `npm run panels:remove -- <nama>` | Menghapus panel; semua kredensial untuk panel itu langsung tidak bisa diperbarui |
| `npm run db:backup` | Menyalin database ke `backups/busdisplay-<waktu>.db`, aman walaupun server sedang jalan |

## API

Semua path diawali `/api`. Respons sukses berbentuk `{ "data": ... }`, respons gagal berbentuk `{ "error": "pesan" }` (pesan berbahasa Indonesia dan aman ditampilkan ke operator).

Semua endpoint kecuali `status` dan `pair` wajib membawa header `x-device-id` dan `x-device-token` dari hasil pairing (kolom **Auth**). Token salah, device tidak dikenal, atau device dicabut dibalas `401`, dan aplikasi lalu kembali ke layar Pairing.

| Method | Path | Auth | Keterangan |
| --- | --- | --- | --- |
| GET | `/display/status` | – | Cek server hidup. Tidak memuat data apa pun |
| POST | `/devices/pair` | – | `{code, deviceId (UUID), deviceName?}` → `201 {data:{deviceId, deviceToken}}` |
| POST | `/panels/:nama/credential` | ✓ | Kredensial BLE untuk panel itu → `{data:{panel, key, expiresAt, serverTime}}`; `404` bila panel belum terdaftar |
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

### Paket BLE

Backend tidak menerima paket BLE, tapi `src/lib/panel-crypto.js` berisi implementasi acuan formatnya (penurunan kunci dan dekripsi), dan test-nya membuka paket vektor uji buatan app. Format lengkapnya ada di [SECURITY.md](../SECURITY.md).

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
scripts/                   # CLI admin (pair:generate, devices, panels, db:backup)
test/api.test.js           # test seluruh endpoint
```

## Deploy ke server

Untuk pemakaian di luar demo, backend dijalankan di server tetap (server kantor atau VPS), bukan di laptop.

1. **Pasang Node.js 22.13+**, salin folder ini **beserta `data/busdisplay.db`** (berisi kunci panel), lalu jalankan `npm ci --omit=dev` dan buat `.env`.
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
- Kunci panel tidak pernah keluar dari server; device hanya menerima kredensial turunan berumur pendek.
- Semua data (rute, preset, riwayat) hanya bisa dibaca device yang sudah dipasangkan.
- Kode pairing sekali pakai dan kedaluwarsa.
- Percobaan pairing gagal dibatasi 10 kali per 15 menit per IP.
- Payload divalidasi.

Yang belum (catatan untuk pengembangan berikutnya):
- **Database berisi kunci semua panel.** Lindungi file `data/` dan hasil `db:backup` seperti kata sandi.
- Sisa risiko BLE (flash ESP32 belum dienkripsi, device sah yang berniat jahat) dijelaskan di [SECURITY.md](../SECURITY.md).
- **HTTPS bergantung pada reverse proxy.** Tanpa langkah Deploy no. 3, lalu lintas berjalan tanpa enkripsi.
