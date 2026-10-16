#include <Arduino.h>
#include <Preferences.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>

#include "config.h"

#if __has_include("secrets.h")
#include "secrets.h"
#else
#error "include/secrets.h belum ada. Salin include/secrets.h.example menjadi secrets.h lalu isi BLE_KEY."
#endif

#include "ble_link.h"
#include "display_config.h"
#include "renderer.h"
#include "self_test.h"

namespace {

struct Update {
  DisplayConfig cfg;
  uint64_t timestamp;
};

// Antrean 1 slot dari task BLE ke loop(): kalau dua paket datang beruntun,
// yang terbaru menimpa yang lama.
QueueHandle_t updates = nullptr;
Preferences prefs;

// Hanya disentuh oleh task BLE setelah setup() selesai.
uint64_t lastAcceptedTs = 0;

bool keyIsPlaceholder() {
  for (uint8_t b : BLE_KEY) {
    if (b != 0) return false;
  }
  return true;
}

const char* onBleWrite(const uint8_t* data, size_t len) {
  Update update;
  switch (decodePacket(data, len, BLE_KEY, update.cfg, update.timestamp)) {
    case PacketError::BadPacket:
      Serial.printf("[BLE] paket %u byte ditolak: gagal dekripsi (kunci beda?)\n", len);
      return "ERR_PACKET";
    case PacketError::BadJson:
      Serial.println("[BLE] paket ditolak: isi payload tidak valid");
      return "ERR_JSON";
    case PacketError::None:
      break;
  }

  // Anti-replay: paket rekaman lama punya ts lebih kecil dari paket terakhir
  // yang diterima. ts berasal dari jam HP, jadi jam HP perlu otomatis (NTP).
  if (update.timestamp <= lastAcceptedTs) {
    Serial.println("[BLE] paket ditolak: timestamp tidak lebih baru (replay?)");
    return "ERR_REPLAY";
  }
  lastAcceptedTs = update.timestamp;

  xQueueOverwrite(updates, &update);
  return "OK";
}

}  // namespace

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("\n=== Smart Bus Display - Panel P5 ===");

  runCipherSelfTest();
  if (keyIsPlaceholder()) {
    Serial.println("[PERINGATAN] BLE_KEY masih nol semua. Isi include/secrets.h dengan kunci dari backend.");
  }

  if (!rendererBegin()) {
    Serial.println("[ERROR] Panel HUB75 gagal diinisialisasi. Cek wiring dan pin di config.h.");
  }

  prefs.begin("busdisplay", false);
  lastAcceptedTs = prefs.getULong64("last_ts", 0);

  // Setelah mati listrik, panel langsung menampilkan rute terakhir tanpa
  // menunggu operator mengirim ulang.
  DisplayConfig saved;
  if (prefs.getBytes("cfg", &saved, sizeof(saved)) == sizeof(saved) &&
      saved.version == DisplayConfig::kVersion) {
    Serial.printf("[NVS] memuat tampilan terakhir: %s\n", saved.route);
    rendererApply(saved);
  } else {
    rendererShowMessage(BLE_DEVICE_NAME, "SIAP");
  }

  updates = xQueueCreate(1, sizeof(Update));
  bleBegin(onBleWrite);
}

void loop() {
  Update update;
  if (xQueueReceive(updates, &update, 0) == pdTRUE) {
    Serial.printf("[DISPLAY] %s | %s | anim=%u speed=%u bright=%u font=%u\n", update.cfg.route,
                  update.cfg.pergi ? "Pergi" : "Pulang", static_cast<unsigned>(update.cfg.animation),
                  update.cfg.speed, update.cfg.brightness, update.cfg.fontSize);
    rendererApply(update.cfg);
    prefs.putBytes("cfg", &update.cfg, sizeof(update.cfg));
    prefs.putULong64("last_ts", update.timestamp);
  }

  rendererTick();
  delay(1);
}
