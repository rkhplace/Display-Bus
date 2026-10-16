#pragma once
#include <stddef.h>
#include <stdint.h>

// Dipanggil dari task BLE setiap kali aplikasi menulis ke karakteristik config.
// Mengembalikan teks status yang dipancarkan lewat karakteristik status.
using BleWriteHandler = const char* (*)(const uint8_t* data, size_t len);

void bleBegin(BleWriteHandler onWrite);
bool bleIsConnected();
