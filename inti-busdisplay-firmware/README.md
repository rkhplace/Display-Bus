# Smart Bus Display — Firmware Panel P5

Firmware ESP32 untuk panel LED HUB75 **P5 64x32**. Firmware ini:

- Menjadi BLE server yang menerima konfigurasi dari aplikasi Flutter (`../inti-busdisplay-main`).
- Mendekripsi paket AES-256-CBC memakai `BLE_KEY` yang sama dengan backend (`../inti-busdisplay-backend`).
- Menampilkan rute dengan 7 mode animasi, dengan logika gerak dan kecepatan yang sama dengan preview di aplikasi.
- Menyimpan tampilan terakhir di flash, jadi panel langsung menampilkan rute lagi setelah mati listrik.

## Yang dibutuhkan

- ESP32 DevKit (ESP32-WROOM-32). ESP32-S3 dan C3 butuh pin dan board yang berbeda.
- Panel P5 64x32 HUB75 (scan 1/16).
- Power supply 5V minimal 3A untuk panel. Jangan ambil daya panel dari pin 5V ESP32.
- [PlatformIO](https://platformio.org/install/ide?install=vscode): extension VS Code atau `pip install platformio`.

## Wiring

Ini pin default library ESP32-HUB75-MatrixPanel-DMA. Bisa diubah di `include/config.h`.

| HUB75 | ESP32 GPIO | HUB75 | ESP32 GPIO |
| --- | --- | --- | --- |
| R1 | 25 | R2 | 14 |
| G1 | 26 | G2 | 12 |
| B1 | 27 | B2 | 13 |
| A | 23 | B | 19 |
| C | 5 | D | 17 |
| E | – (tidak dipakai di 64x32) | CLK | 16 |
| LAT | 4 | OE | 15 |
| GND | GND | | |

- **GND power supply panel dan GND ESP32 wajib disatukan.**
- GPIO 12 adalah pin strapping. Kalau ESP32 gagal boot saat kabel panel terpasang, cabut R2 sebentar saat upload atau pindahkan R2 ke pin lain di `config.h`.
- Kebanyakan panel menerima sinyal 3,3V dari ESP32. Kalau tampilan acak atau berkedip, pasang level shifter 74HCT245.

## Langkah pertama

1. Di folder backend, jalankan `npm run ble:keygen`. Isi `BLE_KEY=...` di `.env` backend.
2. Di folder ini, salin `include/secrets.h.example` menjadi `include/secrets.h`. Tempel array byte dari output `ble:keygen` ke situ. File ini tidak ikut ke git.
3. Kalau ada lebih dari satu panel, ganti `BLE_DEVICE_NAME` di `include/config.h`, mis. `P5-BUS-02`.
4. Upload lalu buka serial monitor:

   ```bash
   pio run -t upload
   pio device monitor
   ```

5. Di serial monitor harus muncul:

   ```
   [SELFTEST] dekripsi paket contoh dari aplikasi: LULUS
   [BLE] advertising sebagai "P5-BUS-01"
   ```

   Panel menampilkan `P5-BUS-01` / `SIAP`.

6. Di aplikasi, lakukan pairing ke backend. Hubungkan ke `P5-BUS-01` dari Status Card, lalu tekan **Kirim ke Display**.

## Cara kerja

```
App ──BLE write──> [karakteristik config] ──> dekripsi + validasi (task BLE)
                                                   │
                                     antrean 1 slot (paket terbaru menang)
                                                   │
                                                   v
                                     loop(): render + simpan ke NVS
```

| File | Isi |
| --- | --- |
| `src/main.cpp` | Setup, anti-replay, antrean BLE → loop, simpan/muat NVS |
| `src/ble_link.cpp` | BLE server, advertising ulang setelah aplikasi terputus |
| `src/display_config.cpp` | Dekripsi AES-256-CBC (mbedtls) + parse JSON (ArduinoJson) |
| `src/renderer.cpp` | Tata letak teks dan animasi di panel 64x32 |
| `src/self_test.cpp` | Paket uji yang dienkripsi kode Dart aplikasi, dicek tiap boot |
| `include/config.h` | Nama BLE, UUID, pin, warna |

### Format paket BLE

Aplikasi (`BlePayloadCipher`) menulis `IV (16 byte) || AES-256-CBC(PKCS7)`. Isinya setelah didekripsi:

```json
{"ts":1792028342419,"payload":{"route":"B1 • Bandung - Garut","direction":"Pergi","animation":"Scroll Left","speed":50,"brightness":80,"fontSize":16}}
```

### Tampilan

- Teksnya sama dengan preview di aplikasi: `B1 | BANDUNG → GARUT`. Kalau arahnya `Pulang`, kotanya dibalik.
- **Running / Scroll Left / Scroll Right**: satu baris berjalan.
- **Static / Blink / Scroll Up / Scroll Down**: teks harus muat selebar 64 px. Ukuran huruf dikecilkan dulu. Kalau masih tidak muat, teks dipecah jadi 3 baris (kode, kota asal, `→`kota tujuan), masing-masing maksimal 10 karakter.
- **fontSize**: 0–23 → ukuran 1 (tinggi 8 px), 24–47 → 2, 48–71 → 3, 72–100 → 4 (32 px).
- **brightness**: 0–100 dipetakan ke 5–100% kecerahan panel.
- Huruf non-ASCII (selain pemisah `•`) diganti `?`, karena font panel hanya punya karakter CP437.

### Karakteristik status

UUID `beb5483e-36e1-4688-b7f5-ea07361b26a9` bisa di-read dan di-notify. Setiap kali aplikasi menulis, nilainya diisi `OK`, `ERR_PACKET` (gagal dekripsi), `ERR_JSON`, atau `ERR_REPLAY`. Aplikasi menunggu balasan ini (maks. 3 detik) sebelum menampilkan sukses dan menyinkronkan ke server; kalau panel menolak, aplikasi menampilkan alasannya. Untuk debug manual, pakai nRF Connect.

## Troubleshooting

| Gejala | Penyebab | Solusi |
| --- | --- | --- |
| Compile error `secrets.h belum ada` | Langkah 2 belum dilakukan | Salin `secrets.h.example` → `secrets.h` |
| Serial: `paket ... gagal dekripsi` | `BLE_KEY` firmware beda dengan backend, atau device pairing saat backend belum punya `BLE_KEY` | Samakan kunci, lalu pairing ulang aplikasi |
| Serial: `timestamp tidak lebih baru` | Jam HP mundur dibanding paket terakhir, atau ganti HP yang jamnya tertinggal | Aktifkan jam otomatis di HP. Untuk reset, jalankan `pio run -t erase` lalu upload ulang |
| Panel tidak muncul di scan aplikasi | Aplikasi lain sedang terhubung, atau izin Bluetooth/lokasi di HP mati | Putuskan aplikasi lain; cek izin |
| Teks pecah atau warna salah | Wiring, atau panel memakai driver chip lain | Cek kabel; lihat opsi `mxconfig.driver` di dokumentasi library HUB75 |
| ESP32 restart terus saat panel menyala | Daya kurang | Pakai PSU 5V terpisah ≥3A, GND disatukan |

## Batasan (catatan pengembangan)

- **iOS:** MTU iOS sekitar 185 byte. Paket dengan nama rute panjang (>~190 byte) perlu *long write*, padahal aplikasi saat ini menulis satu kali. Di Android aman karena aplikasi meminta MTU 512.
- **Anti-replay memakai jam HP.** Panel tidak punya jam sendiri, jadi paket ditolak kalau `ts`-nya tidak lebih baru dari paket terakhir. Cara yang lebih kuat: challenge/nonce dari panel.
- **AES-CBC tanpa MAC**, dan semua panel memakai satu kunci. Untuk produksi, ganti ke AES-GCM dengan kunci per panel. Ini perlu diubah di aplikasi, backend, dan firmware sekaligus.
- Belum ada OTA. Update firmware masih lewat kabel USB.
