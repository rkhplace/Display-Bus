# Smart Bus Display — Firmware Panel P5

Firmware ESP32 untuk panel LED HUB75 **P5 64x32**. Firmware ini:

- Menjadi BLE server yang menerima konfigurasi dari aplikasi Flutter (`../inti-busdisplay-main`).
- Membuka paket AES-256-GCM dari aplikasi dengan kunci khusus panel ini, dan menolak paket yang diubah, diputar ulang, atau dari kredensial kedaluwarsa. Detailnya di [SECURITY.md](../SECURITY.md).
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
| G1 | 26 | G2 | 32 |
| B1 | 27 | B2 | 13 |
| A | 23 | B | 19 |
| C | 5 | D | 17 |
| E | – (tidak dipakai di 64x32) | CLK | 16 |
| LAT | 4 | OE | 15 |
| GND | GND | | |

- **GND power supply panel dan GND ESP32 wajib disatukan.**
- G2 memakai GPIO 32, bukan GPIO 12 (default library). GPIO 12 adalah pin strapping: kalau tertarik HIGH oleh panel saat boot, ESP32 gagal menyala. Jangan pindahkan pin apa pun ke GPIO 12.
- Kebanyakan panel menerima sinyal 3,3V dari ESP32. Kalau tampilan acak atau berkedip, pasang level shifter 74HCT245.

## Langkah pertama

1. **Daftarkan panel di backend** dan tulis kuncinya langsung ke folder ini:

   ```bash
   cd ../inti-busdisplay-backend
   npm run panels:add -- P5-BUS-01 --out ../inti-busdisplay-firmware/include/secrets.h
   ```

   `secrets.h` berisi `PANEL_NAME` (nama BLE panel) dan `PANEL_KEY`. Setiap panel punya nama dan kunci sendiri, jadi ulangi langkah ini dengan nama lain untuk panel berikutnya (mis. `P5-BUS-02`). File ini tidak ikut ke git. Untuk mencetak ulang kunci panel yang sudah terdaftar, pakai `npm run panels:secrets -- P5-BUS-01 --out ...`.
2. Upload lalu buka serial monitor:

   ```bash
   pio run -t upload
   pio device monitor
   ```

3. Di serial monitor harus muncul:

   ```
   Panel: P5-BUS-01
   [SELFTEST] buka paket contoh dari aplikasi: LULUS
   [SELFTEST] tolak paket yang diubah: LULUS
   [BLE] advertising sebagai "P5-BUS-01"
   ```

   Panel menampilkan `P5-BUS-01` / `SIAP`.

4. Di aplikasi, lakukan pairing ke backend, lalu ketuk chip status panel di kanan atas dan pilih `P5-BUS-01`. App mengambil kredensial panel dari server lalu mengirim salam. Di serial muncul `[BLE] salam dari aplikasi diterima`. Setelah itu tekan **Kirim ke Display**.

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
| `src/main.cpp` | Setup, cek kedaluwarsa & anti-replay, antrean BLE → loop, simpan/muat NVS |
| `src/ble_link.cpp` | BLE server, putus klien tanpa salam, advertising ulang setelah terputus |
| `src/display_config.cpp` | Turunan kunci HMAC + dekripsi AES-256-GCM (mbedtls) + parse JSON |
| `src/renderer.cpp` | Tata letak teks dan animasi di panel 64x32 |
| `src/self_test.cpp` | Vektor uji lintas komponen + uji paket yang diubah, dicek tiap boot |
| `include/config.h` | UUID, batas waktu salam, driver & pin panel, warna |
| `include/secrets.h` | Nama dan kunci panel (dibuat backend, tidak ikut git) |

### Format paket BLE

`[0x02][deviceId 16B][expiresAt u32 BE][nonce 12B][ciphertext][tag 16B]`, AES-256-GCM dengan kunci yang diturunkan dari `PANEL_KEY`. Isinya setelah dibuka:

```json
{"ts":1792028342419,"payload":{"route":"B1 • Bandung - Garut","direction":"Pergi","animation":"Scroll Left","speed":50,"brightness":80,"fontSize":16}}
```

atau `{"ts":...,"hello":true}` untuk salam. Penjelasan lengkap kunci, aturan, dan pencabutan akses ada di [SECURITY.md](../SECURITY.md).

### Tampilan

- Teksnya sama dengan preview di aplikasi: `B1 | BANDUNG → GARUT`. Kalau arahnya `Pulang`, kotanya dibalik.
- **Running / Scroll Left / Scroll Right**: satu baris berjalan.
- **Static / Blink / Scroll Up / Scroll Down**: teks harus muat selebar 64 px. Ukuran huruf dikecilkan dulu. Kalau masih tidak muat, teks dipecah jadi 3 baris (kode, kota asal, `→`kota tujuan), masing-masing maksimal 10 karakter.
- **fontSize**: 0–23 → ukuran 1 (tinggi 8 px), 24–47 → 2, 48–71 → 3, 72–100 → 4 (32 px).
- **brightness**: 0–100 dipetakan ke 5–100% kecerahan panel.
- Huruf non-ASCII (selain pemisah `•`) diganti `?`, karena font panel hanya punya karakter CP437.

### Karakteristik status

UUID `beb5483e-36e1-4688-b7f5-ea07361b26a9` bisa di-read dan di-notify. Setiap kali aplikasi menulis, nilainya diisi `OK`, `ERR_PACKET` (bukan dari device sah atau paket diubah), `ERR_EXPIRED` (kredensial kedaluwarsa), `ERR_REPLAY`, atau `ERR_JSON`. Aplikasi menunggu balasan ini (maks. 3 detik) sebelum menampilkan sukses dan menyinkronkan ke server. Kalau balasannya `ERR_PACKET`/`ERR_EXPIRED`, aplikasi meminta kredensial baru ke server lalu mencoba sekali lagi.

## Troubleshooting

| Gejala | Penyebab | Solusi |
| --- | --- | --- |
| Compile error `secrets.h belum ada` | Langkah 1 belum dilakukan | Jalankan `panels:add` (atau `panels:secrets`) dengan `--out` |
| App: "Panel ... belum terdaftar di server" | Nama BLE panel tidak ada di database backend | `npm run panels:list`; daftarkan dengan `panels:add` dan flash ulang |
| Serial: `bukan dari device sah atau sudah diubah` | Kunci di panel beda dengan di server (mis. flash `secrets.h` panel lain, atau panel didaftarkan ulang) | `npm run panels:secrets -- <nama> --out ...` lalu upload ulang |
| Serial: `kredensial device sudah kedaluwarsa` | HP lama tidak terhubung ke server | Sambungkan HP ke server; app memperbarui kredensial otomatis |
| Serial: `timestamp tidak lebih baru` | Paket rekaman lama diputar ulang, atau device lain sudah mengirim dengan waktu lebih baru | Kirim ulang. Lihat SECURITY.md bagian "Sisa risiko" bila terus terjadi |
| Serial: `klien tidak mengirim paket sah, koneksi diputus` | Perangkat asing terhubung tanpa kredensial, atau app versi lama | Normal untuk perangkat asing; perbarui app kalau itu HP operator |
| Panel tidak muncul di scan aplikasi | Perangkat lain sedang terhubung, atau izin Bluetooth di HP mati | Tunggu maks. 10 detik (klien tanpa salam diputus); cek izin |
| Teks pecah atau warna salah | Wiring, atau chip driver panel lain | Cek kabel; ubah `PANEL_DRIVER` di `config.h` (mis. `HUB75_I2S_CFG::FM6124`) |
| ESP32 restart terus saat panel menyala | Daya kurang | Pakai PSU 5V terpisah ≥3A, GND disatukan |

## Batasan (catatan pengembangan)

- **iOS:** MTU iOS sekitar 185 byte. Aplikasi mengirim paket yang lebih panjang dengan *long write* (prepare/execute write), dan library BLE ESP32 menggabungkannya sebelum `onWrite`. Ini belum diuji di iPhone.
- **Flash ESP32 belum dienkripsi.** Orang yang membawa panel pergi bisa membaca kunci panel itu (panel lain tetap aman). Untuk produksi, aktifkan *flash encryption* dan *secure boot*.
- Belum ada OTA. Update firmware dan ganti kunci panel masih lewat kabel USB.
