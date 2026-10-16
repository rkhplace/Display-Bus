#include "display_config.h"

#include <ArduinoJson.h>
#include <mbedtls/aes.h>
#include <string.h>

namespace {

constexpr size_t kBlock = 16;
// Payload normal ~150 byte; batas ini juga mencegah alokasi besar dari paket asing.
constexpr size_t kMaxCipherLen = 512;

struct AnimationLabel {
  const char* label;
  Animation value;
};

constexpr AnimationLabel kAnimationLabels[] = {
    {"Running", Animation::Running},         {"Static", Animation::Static},
    {"Blink", Animation::Blink},             {"Scroll Left", Animation::ScrollLeft},
    {"Scroll Right", Animation::ScrollRight}, {"Scroll Up", Animation::ScrollUp},
    {"Scroll Down", Animation::ScrollDown},
};

bool decryptCbc(const uint8_t* data, size_t len, const uint8_t key[32], uint8_t* plain,
                size_t& plainLen) {
  if (len < kBlock * 2 || (len - kBlock) % kBlock != 0 || len - kBlock > kMaxCipherLen) {
    return false;
  }

  uint8_t iv[kBlock];
  memcpy(iv, data, kBlock);
  const size_t cipherLen = len - kBlock;

  mbedtls_aes_context ctx;
  mbedtls_aes_init(&ctx);
  int rc = mbedtls_aes_setkey_dec(&ctx, key, 256);
  if (rc == 0) {
    rc = mbedtls_aes_crypt_cbc(&ctx, MBEDTLS_AES_DECRYPT, cipherLen, iv, data + kBlock, plain);
  }
  mbedtls_aes_free(&ctx);
  if (rc != 0) return false;

  // PKCS7: n byte terakhir semuanya bernilai n (1..16). Kunci yang salah hampir
  // selalu gagal di sini.
  const uint8_t pad = plain[cipherLen - 1];
  if (pad == 0 || pad > kBlock) return false;
  for (size_t i = cipherLen - pad; i < cipherLen; i++) {
    if (plain[i] != pad) return false;
  }
  plainLen = cipherLen - pad;
  return true;
}

bool readPercent(JsonVariantConst value, uint8_t& out) {
  if (!value.is<int>()) return false;
  const int v = value.as<int>();
  if (v < 0 || v > 100) return false;
  out = static_cast<uint8_t>(v);
  return true;
}

bool parseAnimation(const char* label, Animation& out) {
  if (!label) return false;
  for (const auto& entry : kAnimationLabels) {
    if (strcmp(entry.label, label) == 0) {
      out = entry.value;
      return true;
    }
  }
  return false;
}

}  // namespace

PacketError decodePacket(const uint8_t* data, size_t len, const uint8_t key[32],
                         DisplayConfig& out, uint64_t& outTimestamp) {
  static uint8_t plain[kMaxCipherLen];
  size_t plainLen = 0;
  if (!decryptCbc(data, len, key, plain, plainLen)) return PacketError::BadPacket;

  JsonDocument doc;
  if (deserializeJson(doc, reinterpret_cast<const char*>(plain), plainLen)) {
    return PacketError::BadJson;
  }

  JsonVariantConst ts = doc["ts"];
  JsonObjectConst payload = doc["payload"];
  if (!ts.is<uint64_t>() || payload.isNull()) return PacketError::BadJson;

  DisplayConfig cfg;
  const char* route = payload["route"];
  const char* direction = payload["direction"];
  if (!route || strlen(route) >= sizeof(cfg.route) || !direction) return PacketError::BadJson;
  if (!parseAnimation(payload["animation"], cfg.animation)) return PacketError::BadJson;
  if (!readPercent(payload["speed"], cfg.speed) ||
      !readPercent(payload["brightness"], cfg.brightness) ||
      !readPercent(payload["fontSize"], cfg.fontSize)) {
    return PacketError::BadJson;
  }

  strcpy(cfg.route, route);
  cfg.pergi = strcmp(direction, "Pulang") != 0;

  out = cfg;
  outTimestamp = ts.as<uint64_t>();
  return PacketError::None;
}
