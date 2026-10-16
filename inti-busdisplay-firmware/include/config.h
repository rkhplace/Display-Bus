#pragma once

// ---------------------------------------------------------------------------
// Identitas BLE. Nama ini yang muncul di daftar scan aplikasi.
// Ganti per panel kalau ada lebih dari satu bus (mis. "P5-BUS-02").
// ---------------------------------------------------------------------------
#define BLE_DEVICE_NAME "P5-BUS-01"

// Harus sama dengan BleService.serviceUuid / characteristicUuid di aplikasi
// (lib/core/services/bluetooth_service.dart).
#define BLE_SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define BLE_CONFIG_CHAR_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// Karakteristik status (read + notify): "OK", "ERR_PACKET", "ERR_JSON",
// "ERR_REPLAY". Belum dibaca aplikasi, tapi berguna untuk debug lewat nRF Connect.
#define BLE_STATUS_CHAR_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a9"

// ---------------------------------------------------------------------------
// Panel HUB75 P5 64x32 (scan 1/16, pin E tidak dipakai).
// Pin di bawah adalah pin default library ESP32-HUB75-MatrixPanel-DMA.
// ---------------------------------------------------------------------------
#define PANEL_WIDTH 64
#define PANEL_HEIGHT 32
#define PANEL_CHAIN 1

#define PIN_R1 25
#define PIN_G1 26
#define PIN_B1 27
#define PIN_R2 14
#define PIN_G2 12
#define PIN_B2 13
#define PIN_A 23
#define PIN_B 19
#define PIN_C 5
#define PIN_D 17
#define PIN_E -1
#define PIN_LAT 4
#define PIN_OE 15
#define PIN_CLK 16

// Warna teks, sama dengan AppColors.ledText (#FFB300) di aplikasi.
#define LED_COLOR_R 255
#define LED_COLOR_G 179
#define LED_COLOR_B 0

// Interval antar frame animasi (ms). 16 ms ~ 60 fps.
#define FRAME_INTERVAL_MS 16
