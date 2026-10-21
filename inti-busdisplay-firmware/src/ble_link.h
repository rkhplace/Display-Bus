#pragma once
#include <stddef.h>
#include <stdint.h>

// Dipanggil dari task BLE setiap kali aplikasi menulis ke karakteristik config.
// Mengembalikan teks status yang dipancarkan lewat karakteristik status;
// "OK" juga menandai koneksi ini sebagai sah (lihat HELLO_TIMEOUT_MS).
using BleWriteHandler = const char* (*)(const uint8_t* data, size_t len);

void bleBegin(const char* deviceName, BleWriteHandler onWrite);

// Dipanggil terus dari loop(): memutus klien yang belum mengirim paket sah.
void bleTick();

bool bleIsConnected();
