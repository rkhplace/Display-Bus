# Smart Bus Display

Sistem pengendali panel LED *running text* (P5 64x32) di bus, terdiri dari tiga bagian:

| Folder | Isi | Teknologi |
| --- | --- | --- |
| [`inti-busdisplay-main/`](inti-busdisplay-main) | Aplikasi operator di HP/tablet: pilih rute, atur animasi, kirim ke panel | Flutter, flutter_blue_plus, Provider |
| [`inti-busdisplay-backend/`](inti-busdisplay-backend) | Pairing device, data rute & preset, riwayat tampilan | Node.js, Express 5, SQLite (`node:sqlite`) |
| [`inti-busdisplay-firmware/`](inti-busdisplay-firmware) | Firmware panel: BLE server, dekripsi AES-GCM, render teks & animasi | ESP32, PlatformIO, HUB75 DMA |

```
[App Flutter] ──BLE (AES-256-GCM)──> [ESP32 + panel P5 64x32]
      │                                  │
      │ <──────── status OK / ERR ───────┘
      │
      └──HTTP /api──> [Backend] ──> SQLite
```

- App mengirim konfigurasi ke panel lewat BLE terenkripsi, lalu menunggu balasan `OK` dari panel.
- Setelah panel membalas, app mencatat konfigurasi itu ke backend.
- Setiap panel punya kunci sendiri yang hanya ada di backend dan di panel itu. App menerima kredensial turunan per panel yang berumur pendek. Lihat [SECURITY.md](SECURITY.md).

## Mulai cepat

1. **Backend**: `cd inti-busdisplay-backend && npm install && cp .env.example .env`, lalu daftarkan panel: `npm run panels:add -- P5-BUS-01 --out ../inti-busdisplay-firmware/include/secrets.h`. Jalankan `npm start`.
2. **Firmware**: `secrets.h` sudah ditulis oleh langkah 1, jadi tinggal `pio run -t upload`.
3. **App**: `cd inti-busdisplay-main && flutter pub get && cp .env.example .env`, isi `BACKEND_IP` dengan IP laptop yang menjalankan backend, lalu `flutter run`.
4. Buat kode pairing dengan `npm run pair:generate` di folder backend, lalu masukkan kodenya di aplikasi.

Detail setiap bagian ada di README masing-masing folder.

## File yang tidak ikut repo

File berikut berisi rahasia atau konfigurasi lokal, jadi tidak dicatat di git. Buat sendiri dari contohnya:

- `inti-busdisplay-backend/.env`, dari `.env.example`
- `inti-busdisplay-firmware/include/secrets.h`, dibuat oleh `npm run panels:add` / `panels:secrets`
- `inti-busdisplay-backend/data/`, database berisi kunci semua panel
- `inti-busdisplay-main/.env`, dari `.env.example`
