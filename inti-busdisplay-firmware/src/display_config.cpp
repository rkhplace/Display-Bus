#include "display_config.h"

#include <ArduinoJson.h>
#include <mbedtls/gcm.h>
#include <mbedtls/md.h>
#include <string.h>

namespace {

constexpr uint8_t kPacketVersion = 0x02;
constexpr size_t kHeaderLen = 1 + 16 + 4;  // versi + deviceId + expiresAt (= AAD)
constexpr size_t kNonceLen = 12;
constexpr size_t kTagLen = 16;
// Payload normal ~150 byte, maksimal ~400; batas ini juga mencegah paket asing
// yang besar memakan RAM.
constexpr size_t kMaxPlainLen = 512;
constexpr char kKeyContext[] = "busdisplay-v2";

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

// Kunci khusus device: HMAC-SHA256(panelKey, "busdisplay-v2" || deviceId || expiresAt).
// deviceId (16 byte) dan expiresAt (4 byte BE) diambil langsung dari header paket,
// jadi kunci ini sekaligus mengikat paket ke device dan masa berlakunya.
bool deriveDeviceKey(const uint8_t panelKey[32], const uint8_t* header, uint8_t out[32]) {
  uint8_t input[sizeof(kKeyContext) - 1 + 16 + 4];
  memcpy(input, kKeyContext, sizeof(kKeyContext) - 1);
  memcpy(input + sizeof(kKeyContext) - 1, header + 1, 16 + 4);
  return mbedtls_md_hmac(mbedtls_md_info_from_type(MBEDTLS_MD_SHA256), panelKey, 32, input,
                         sizeof(input), out) == 0;
}

bool decryptGcm(const uint8_t* data, size_t len, const uint8_t panelKey[32], uint8_t* plain,
                size_t& plainLen) {
  if (len < kHeaderLen + kNonceLen + kTagLen + 2) return false;
  if (data[0] != kPacketVersion) return false;

  const size_t cipherLen = len - kHeaderLen - kNonceLen - kTagLen;
  if (cipherLen > kMaxPlainLen) return false;

  uint8_t key[32];
  if (!deriveDeviceKey(panelKey, data, key)) return false;

  const uint8_t* nonce = data + kHeaderLen;
  const uint8_t* cipherText = nonce + kNonceLen;
  const uint8_t* tag = cipherText + cipherLen;

  mbedtls_gcm_context ctx;
  mbedtls_gcm_init(&ctx);
  int rc = mbedtls_gcm_setkey(&ctx, MBEDTLS_CIPHER_ID_AES, key, 256);
  if (rc == 0) {
    // Gagal (MBEDTLS_ERR_GCM_AUTH_FAILED) bila satu bit pun di header, nonce,
    // ciphertext, atau tag diubah, atau kredensial bukan untuk panel ini.
    rc = mbedtls_gcm_auth_decrypt(&ctx, cipherLen, nonce, kNonceLen, data, kHeaderLen, tag,
                                  kTagLen, cipherText, plain);
  }
  mbedtls_gcm_free(&ctx);
  memset(key, 0, sizeof(key));
  if (rc != 0) return false;

  plainLen = cipherLen;
  return true;
}

uint32_t readU32BE(const uint8_t* p) {
  return (uint32_t(p[0]) << 24) | (uint32_t(p[1]) << 16) | (uint32_t(p[2]) << 8) | uint32_t(p[3]);
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

PacketError decodePacket(const uint8_t* data, size_t len, const uint8_t panelKey[32],
                         DecodedPacket& out) {
  static uint8_t plain[kMaxPlainLen];
  size_t plainLen = 0;
  if (!decryptGcm(data, len, panelKey, plain, plainLen)) return PacketError::BadPacket;

  JsonDocument doc;
  if (deserializeJson(doc, reinterpret_cast<const char*>(plain), plainLen)) {
    return PacketError::BadJson;
  }

  JsonVariantConst ts = doc["ts"];
  if (!ts.is<uint64_t>()) return PacketError::BadJson;

  DecodedPacket decoded;
  decoded.timestamp = ts.as<uint64_t>();
  decoded.expiresAt = readU32BE(data + 17);

  if (doc["hello"] == true) {
    decoded.hello = true;
    out = decoded;
    return PacketError::None;
  }

  JsonObjectConst payload = doc["payload"];
  if (payload.isNull()) return PacketError::BadJson;

  DisplayConfig& cfg = decoded.config;
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

  out = decoded;
  return PacketError::None;
}
