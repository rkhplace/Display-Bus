# Keamanan BLE Smart Bus Display

Dokumen ini menjelaskan cara aplikasi, backend, dan panel saling mempercayai. Format paket di bawah **harus identik** di tiga tempat:

| Komponen | File |
| --- | --- |
| App (Dart) | `inti-busdisplay-main/lib/core/services/ble_payload_cipher.dart` |
| Backend (Node) | `inti-busdisplay-backend/src/lib/panel-crypto.js` |
| Firmware (C++) | `inti-busdisplay-firmware/src/display_config.cpp` |

Ketiganya diuji dengan **vektor uji yang sama**: paket buatan app dengan input tetap dikunci byte demi byte di test app, dibuka oleh test backend, dan didekripsi oleh self-test firmware setiap kali panel boot.

## Kunci

```
Kunci panel (32 byte, acak)        ← dibuat "npm run panels:add", hanya ada di server + panel itu
        │
        │  HMAC-SHA256(kunciPanel, "busdisplay-v2" || deviceId || expiresAt)
        ▼
Kredensial device (32 byte)        ← diberikan ke HP lewat POST /api/panels/:nama/credential
                                     berlaku CREDENTIAL_TTL_DAYS (default 7 hari)
```

- **Setiap panel punya kunci sendiri.** Bocornya satu panel tidak membuka panel lain.
- **HP tidak pernah memegang kunci panel**, hanya kredensial turunan yang terikat ke `deviceId`-nya dan punya masa berlaku. Kredensial satu HP tidak bisa dipakai HP lain, karena `deviceId` ikut dalam penurunan kunci dan dalam header paket yang diautentikasi.
- Panel tidak perlu daftar device: panel menurunkan kunci yang sama dari header paket, lalu memverifikasinya dengan GCM.

## Format paket (versi 2)

```
[0x02][deviceId 16B][expiresAt u32 BE][nonce 12B][ciphertext][tag GCM 16B]
 └──────────── AAD (21 byte) ─────────┘
```

- AES-256-GCM dengan kunci kredensial dan nonce acak 12 byte.
- Header (versi, deviceId, expiresAt) tidak dienkripsi tetapi ikut diautentikasi, jadi tidak bisa diubah.
- Plaintext: `{"ts": <ms jam server>, "payload": {...}}`, atau `{"ts": .., "hello": true}` untuk salam.
- **Satu bit saja diubah di bagian mana pun, panel menolak paket** (`ERR_PACKET`). Ini menutup celah versi 1 (AES-CBC tanpa MAC), di mana timestamp anti-replay bisa dipalsukan untuk mengunci panel.

## Aturan di panel

Semua nilai berikut hanya dibaca setelah tag GCM terbukti cocok:

| Cek | Balasan bila gagal |
| --- | --- |
| Format dan tag GCM | `ERR_PACKET` |
| `ts / 1000 <= expiresAt` (kredensial masih berlaku saat paket dibuat) | `ERR_EXPIRED` |
| `ts > ts paket terakhir yang diterima` (anti-replay, disimpan di flash) | `ERR_REPLAY` |
| Isi payload valid | `ERR_JSON` |

- **Waktu:** `ts` memakai jam server. App menghitung selisih jam HP terhadap jam server setiap kali mengambil kredensial, jadi HP dengan jam yang salah tidak memicu penolakan replay dan tidak bisa "melompat" ke masa depan melewati masa berlaku kredensialnya.
- **Salam:** setelah konek, app langsung mengirim paket `hello`. Klien yang tidak mengirim satu pun paket sah dalam `HELLO_TIMEOUT_MS` (10 detik) diputus, jadi orang asing tidak bisa menduduki satu-satunya slot koneksi panel. Salam juga memastikan kredensial cocok sebelum operator menekan Kirim.

## Mencabut akses

| Langkah | Efek |
| --- | --- |
| `npm run devices:revoke -- <deviceId>` | Device langsung tidak bisa memakai API dan **tidak bisa memperbarui kredensial**. Kredensial yang sudah ada di HP masih berlaku paling lama `CREDENTIAL_TTL_DAYS`. Setelah device lain mengirim paket dengan waktu lewat masa berlaku itu, paket dari kredensial lama otomatis ditolak (`ERR_EXPIRED` / `ERR_REPLAY`). |
| Akses harus berhenti **saat itu juga** | Ganti kunci panel: `npm run panels:remove -- <nama>`, lalu `panels:add` lagi dan flash ulang panel. Semua kredensial lama untuk panel itu langsung tidak berlaku. |

Perkecil `CREDENTIAL_TTL_DAYS` kalau jeda pencabutan 7 hari terlalu lama. Konsekuensinya, HP harus lebih sering terhubung ke server.

## Sisa risiko yang diketahui

- **Device sah yang berniat jahat** (sebelum dicabut) bisa mengirim paket dengan `ts` sampai batas masa berlaku kredensialnya, sehingga device lain ditolak (`ERR_REPLAY`) sampai waktu itu lewat. Dampaknya terbatas pada `CREDENTIAL_TTL_DAYS`. Pemulihan cepatnya ganti kunci panel.
- **Flash ESP32 bisa dibaca** oleh orang yang membawa panel pergi, sehingga kunci panel itu bocor (panel lain aman). Untuk produksi, aktifkan *flash encryption* dan *secure boot* ESP32.
- **API HTTP tanpa TLS** bisa disadap di WiFi yang sama. Deploy backend di belakang HTTPS (lihat README backend, bagian "Deploy").
- Belum ada OTA. Update firmware dan ganti kunci panel masih lewat kabel USB.
