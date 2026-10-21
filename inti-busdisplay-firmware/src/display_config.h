#pragma once
#include <stddef.h>
#include <stdint.h>

// Sama urutan dan labelnya dengan enum AnimationMode di aplikasi.
enum class Animation : uint8_t {
  Running,
  Static,
  Blink,
  ScrollLeft,
  ScrollRight,
  ScrollUp,
  ScrollDown,
};

struct DisplayConfig {
  // Naikkan setiap kali isi struct berubah: data NVS versi lama diabaikan.
  static constexpr uint8_t kVersion = 2;

  uint8_t version = kVersion;
  // RouteModel.fullDisplayName, mis. "B1 • Bandung - Garut". Backend membatasi
  // kode 10 + kota 2x40 karakter (~98 karakter); 256 byte memberi ruang untuk
  // huruf non-ASCII yang di UTF-8 bisa 2-3 byte per karakter.
  char route[256] = "";
  bool pergi = true;
  Animation animation = Animation::ScrollLeft;
  uint8_t speed = 50;       // 0-100
  uint8_t brightness = 80;  // 0-100
  uint8_t fontSize = 16;    // 0-100
};

enum class PacketError : uint8_t {
  None,
  BadPacket,  // format salah, atau tag GCM tidak cocok (kunci salah / paket diubah)
  BadJson,    // paket sah tapi isinya bukan payload yang valid
};

// Isi paket yang sudah terbukti asli (tag GCM cocok).
struct DecodedPacket {
  uint64_t timestamp = 0;  // ms, jam server (ditambah selisih oleh app)
  uint32_t expiresAt = 0;  // detik, batas berlaku kredensial device
  bool hello = false;      // salam setelah konek: tidak mengubah tampilan
  DisplayConfig config;    // hanya diisi bila hello == false
};

// Membuka paket versi 2 dari aplikasi:
//   [0x02][deviceId 16B][expiresAt u32 BE][nonce 12B][ciphertext][tag 16B]
// Kunci GCM = HMAC-SHA256(panelKey, "busdisplay-v2" || deviceId || expiresAt).
// Format ini harus identik dengan app (ble_payload_cipher.dart) dan backend
// (src/lib/panel-crypto.js).
PacketError decodePacket(const uint8_t* data, size_t len, const uint8_t panelKey[32],
                         DecodedPacket& out);
