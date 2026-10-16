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
  BadPacket,  // panjang salah, kunci salah, atau padding rusak
  BadJson,    // dekripsi berhasil tapi isinya bukan payload yang valid
};

// Mendekripsi paket dari aplikasi: IV (16 byte) || AES-256-CBC(PKCS7) dari
// JSON {"ts": <ms epoch>, "payload": {...}} lalu mem-parse payload-nya.
PacketError decodePacket(const uint8_t* data, size_t len, const uint8_t key[32],
                         DisplayConfig& out, uint64_t& outTimestamp);
