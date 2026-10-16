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

## API

Semua path diawali `/api`. Respons sukses berbentuk `{ "data": ... }`, respons gagal berbentuk `{ "error": "pesan" }` (pesan berbahasa Indonesia dan aman ditampilkan ke operator).

Endpoint bertanda **Auth** wajib membawa header `x-device-id` dan `x-device-token` dari hasil pairing. Token salah, device tidak dikenal, atau device dicabut dibalas `401`.

| Method | Path | Auth | Keterangan |
| --- | --- | --- | --- |
| GET | `/display/status` | – | Cek server hidup, plus tampilan terakhir yang dikirim |
| POST | `/devices/pair` | – | `{code, deviceId, deviceName?}` → `201 {data:{deviceId, deviceToken, bleKey}}` |
| GET | `/routes` | – | Daftar rute `{id, code, origin, destination}` |
| POST | `/routes` | ✓ | Tambah rute → `201`; `409` jika kode sama atau pasangan kota sama (searah/kebalikan) |
| DELETE | `/routes/:id` | ✓ | Hapus rute; `404` jika tidak ada, `409` jika tinggal 1 rute |
| POST | `/display/send` | ✓ | Simpan payload yang baru dikirim ke panel ke riwayat |
| GET | `/display/logs?limit=20` | – | Riwayat tampilan terbaru (maks 200) |
| GET | `/display/presets` | – | Daftar preset `{id, name, payload, createdAt, updatedAt}` |
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

## Catatan keamanan (untuk tahap demo)

Yang sudah ada:
- Token device disimpan sebagai hash SHA-256.
- Kode pairing sekali pakai dan kedaluwarsa.
- Percobaan pairing gagal dibatasi 10 kali per 15 menit per IP.
- Payload divalidasi.

Yang belum (catatan untuk pengembangan berikutnya):
- **GET tidak butuh auth** karena aplikasi memang tidak mengirim header untuk GET. Siapa pun di jaringan yang sama bisa membaca rute, preset, dan riwayat.
- **Semua panel memakai satu `BLE_KEY`.** Idealnya satu kunci per panel.
- **AES-CBC tanpa MAC.** Lebih aman memakai AES-GCM atau menambahkan HMAC, dan ini perlu diubah di aplikasi dan firmware sekaligus.
- **HTTP tanpa TLS** di LAN. Untuk deploy sungguhan, pasang di belakang reverse proxy HTTPS.
