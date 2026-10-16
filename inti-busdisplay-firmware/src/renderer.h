#pragma once
#include "display_config.h"

bool rendererBegin();

// Menampilkan rute sesuai konfigurasi dari aplikasi (dengan animasinya).
void rendererApply(const DisplayConfig& cfg);

// Teks statis 2 baris, dipakai saat boot sebelum ada konfigurasi.
void rendererShowMessage(const char* line1, const char* line2);

// Dipanggil terus dari loop(); menggambar frame berikutnya bila sudah waktunya.
void rendererTick();
