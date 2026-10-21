#include "renderer.h"

#include <Arduino.h>
#include <ESP32-HUB75-MatrixPanel-I2S-DMA.h>
#include <ctype.h>
#include <string.h>

#include "config.h"

namespace {

// Font bawaan Adafruit GFX: 5x7 di sel 6x8 piksel per ukuran.
constexpr int kCharW = 6;
constexpr int kCharH = 8;
constexpr int kLineGap = 2;
constexpr int kMaxLines = 3;
constexpr int kLineCap = 64;
// Karakter CP437 0x1A = panah kanan, pengganti "→" di preview aplikasi.
constexpr char kArrow = 0x1A;

MatrixPanel_I2S_DMA* matrix = nullptr;
bool ready = false;

struct Layout {
  char lines[kMaxLines][kLineCap] = {};
  uint8_t lineCount = 0;
  uint8_t textSize = 1;
  int16_t width = 0;
  int16_t height = 0;
};

Layout layout;
Animation animation = Animation::Static;
uint8_t speed = 50;
uint32_t animStartMs = 0;
uint32_t lastFrameMs = 0;
uint16_t colorOn = 0;
uint16_t colorDim = 0;

int textWidth(const char* s, uint8_t size) { return static_cast<int>(strlen(s)) * kCharW * size; }

// Huruf besar ASCII; setiap karakter UTF-8 non-ASCII diganti "?" karena font
// panel hanya punya karakter CP437.
void toPanelText(const char* src, size_t len, char* dst, size_t cap) {
  size_t o = 0;
  for (size_t i = 0; i < len && src[i] && o + 1 < cap; i++) {
    const uint8_t c = static_cast<uint8_t>(src[i]);
    if (c < 0x80) {
      dst[o++] = static_cast<char>(toupper(c));
    } else if ((c & 0xC0) != 0x80) {
      dst[o++] = '?';
    }
  }
  dst[o] = '\0';
}

void trimInPlace(char* s) {
  size_t len = strlen(s);
  while (len > 0 && s[len - 1] == ' ') s[--len] = '\0';
  size_t start = 0;
  while (s[start] == ' ') start++;
  if (start > 0) memmove(s, s + start, len - start + 1);
}

// Memecah RouteModel.fullDisplayName "B1 • Bandung - Garut" menjadi kode dan dua kota.
void splitRoute(const char* route, char* code, char* origin, char* destination) {
  code[0] = origin[0] = destination[0] = '\0';

  const char* bullet = strstr(route, "\xE2\x80\xA2");
  const char* rest = route;
  if (bullet) {
    toPanelText(route, bullet - route, code, kLineCap);
    rest = bullet + 3;
  }

  const char* dash = strstr(rest, " - ");
  if (dash) {
    toPanelText(rest, dash - rest, origin, kLineCap);
    toPanelText(dash + 3, strlen(dash + 3), destination, kLineCap);
  } else {
    toPanelText(rest, strlen(rest), origin, kLineCap);
  }

  trimInPlace(code);
  trimInPlace(origin);
  trimInPlace(destination);
}

void finishLayout(Layout& l) {
  l.width = 0;
  for (uint8_t i = 0; i < l.lineCount; i++) {
    l.width = max<int16_t>(l.width, textWidth(l.lines[i], l.textSize));
  }
  l.height = l.lineCount * kCharH * l.textSize + (l.lineCount - 1) * kLineGap;
}

bool travelsHorizontally(Animation a) {
  return a == Animation::Running || a == Animation::ScrollLeft || a == Animation::ScrollRight;
}

// Sama dengan label di PreviewCard aplikasi: "B1 | BANDUNG → GARUT".
Layout buildLayout(const DisplayConfig& cfg) {
  char code[kLineCap], origin[kLineCap], destination[kLineCap];
  splitRoute(cfg.route, code, origin, destination);

  const char* from = cfg.pergi ? origin : destination;
  const char* to = cfg.pergi ? destination : origin;
  if (!to[0]) to = from == origin ? destination : origin;

  Layout l;
  char single[kLineCap];
  if (code[0] && to[0]) {
    snprintf(single, sizeof(single), "%s | %s %c %s", code, from, kArrow, to);
  } else if (to[0]) {
    snprintf(single, sizeof(single), "%s %c %s", from, kArrow, to);
  } else {
    snprintf(single, sizeof(single), "%s", from[0] ? from : code);
  }

  // fontSize 0-100 dari slider: 16 (default) = ukuran 1, 24 = 2, 48 = 3, 72+ = 4.
  const uint8_t requested = min(1 + cfg.fontSize / 24, PANEL_HEIGHT / kCharH);

  if (travelsHorizontally(cfg.animation)) {
    strcpy(l.lines[0], single);
    l.lineCount = 1;
    l.textSize = requested;
    finishLayout(l);
    return l;
  }

  // Mode diam/naik-turun: teks harus muat selebar panel. Kecilkan dulu, lalu
  // pecah jadi beberapa baris kalau ukuran 1 pun masih kepanjangan.
  for (uint8_t size = requested; size >= 1; size--) {
    if (textWidth(single, size) <= PANEL_WIDTH) {
      strcpy(l.lines[0], single);
      l.lineCount = 1;
      l.textSize = size;
      finishLayout(l);
      return l;
    }
  }

  const int maxChars = PANEL_WIDTH / kCharW;
  auto addLine = [&](const char* text, bool withArrow) {
    if (!text[0] || l.lineCount >= kMaxLines) return;
    char* dst = l.lines[l.lineCount++];
    if (withArrow) snprintf(dst, kLineCap, "%c%s", kArrow, text);
    else snprintf(dst, kLineCap, "%s", text);
    dst[maxChars] = '\0';
  };
  addLine(code, false);
  addLine(from, false);
  addLine(to, true);
  l.textSize = 1;
  finishLayout(l);
  return l;
}

float lerp(float a, float b, float t) { return a + (b - a) * t; }

// Sama dengan AnimationMode.periodFor() di aplikasi.
uint32_t periodMs() {
  const float t = speed / 100.0f;
  if (animation == Animation::Blink) return static_cast<uint32_t>(lerp(1600, 260, t));
  return static_cast<uint32_t>(lerp(7000, 900, t));
}

// Sama dengan AnimationMode.offsetFor() di aplikasi.
void offsetFor(float t, int16_t& x, int16_t& y) {
  const int16_t centerX = (PANEL_WIDTH - layout.width) / 2;
  const int16_t centerY = (PANEL_HEIGHT - layout.height) / 2;
  switch (animation) {
    case Animation::Running:
    case Animation::ScrollLeft:
      x = lerp(PANEL_WIDTH, -layout.width, t);
      y = centerY;
      break;
    case Animation::ScrollRight:
      x = lerp(-layout.width, PANEL_WIDTH, t);
      y = centerY;
      break;
    case Animation::ScrollUp:
      x = centerX;
      y = lerp(PANEL_HEIGHT, -layout.height, t);
      break;
    case Animation::ScrollDown:
      x = centerX;
      y = lerp(-layout.height, PANEL_HEIGHT, t);
      break;
    case Animation::Blink:
    case Animation::Static:
      x = centerX;
      y = centerY;
      break;
  }
}

void drawLayout(int16_t x, int16_t y, uint16_t color) {
  matrix->setTextSize(layout.textSize);
  matrix->setTextColor(color);
  const int16_t lineStep = kCharH * layout.textSize + kLineGap;
  for (uint8_t i = 0; i < layout.lineCount; i++) {
    const int16_t lineX = x + (layout.width - textWidth(layout.lines[i], layout.textSize)) / 2;
    matrix->setCursor(lineX, y + i * lineStep);
    matrix->print(layout.lines[i]);
  }
}

void restartAnimation() {
  animStartMs = millis();
  lastFrameMs = 0;
}

}  // namespace

bool rendererBegin() {
  HUB75_I2S_CFG::i2s_pins pins = {PIN_R1, PIN_G1, PIN_B1, PIN_R2, PIN_G2, PIN_B2, PIN_A,
                                  PIN_B,  PIN_C,  PIN_D,  PIN_E,  PIN_LAT, PIN_OE, PIN_CLK};
  HUB75_I2S_CFG mxconfig(PANEL_WIDTH, PANEL_HEIGHT, PANEL_CHAIN, pins);
  // Double buffer: frame digambar di buffer belakang lalu ditukar, jadi teks
  // berjalan tidak berkedip.
  mxconfig.double_buff = true;
  // Driver chip panel (lihat PANEL_DRIVER di config.h). Panel dengan FM6124 butuh
  // inisialisasi khusus; tanpa ini tampilan belang atau hanya sebagian baris menyala.
  mxconfig.driver = PANEL_DRIVER;
  // Opsional bila gambar tampak bergeser atau berhantu: coba mxconfig.clkphase = false;

  matrix = new MatrixPanel_I2S_DMA(mxconfig);
  ready = matrix->begin();
  if (!ready) return false;

  matrix->setTextWrap(false);
  matrix->cp437(true);
  colorOn = matrix->color565(LED_COLOR_R, LED_COLOR_G, LED_COLOR_B);
  // Fase "mati" Blink di aplikasi memakai opacity 0.12, bukan hilang total.
  colorDim = matrix->color565(LED_COLOR_R * 0.12f, LED_COLOR_G * 0.12f, LED_COLOR_B * 0.12f);
  matrix->setBrightness8(200);
  return true;
}

void rendererApply(const DisplayConfig& cfg) {
  animation = cfg.animation;
  speed = cfg.speed;
  layout = buildLayout(cfg);
  if (!ready) return;
  // Sama dengan preview: kecerahan minimum 5% supaya teks tidak hilang.
  matrix->setBrightness8(13 + cfg.brightness * 242 / 100);
  restartAnimation();
}

void rendererShowMessage(const char* line1, const char* line2) {
  animation = Animation::Static;
  layout = Layout();
  snprintf(layout.lines[0], kLineCap, "%s", line1);
  snprintf(layout.lines[1], kLineCap, "%s", line2);
  layout.lineCount = 2;
  layout.textSize = 1;
  finishLayout(layout);
  restartAnimation();
}

void rendererTick() {
  if (!ready) return;
  const uint32_t now = millis();
  if (lastFrameMs != 0 && now - lastFrameMs < FRAME_INTERVAL_MS) return;
  lastFrameMs = now;

  const uint32_t period = periodMs();
  const float t = static_cast<float>((now - animStartMs) % period) / period;

  int16_t x, y;
  offsetFor(t, x, y);

  const bool dimPhase = animation == Animation::Blink && t >= 0.5f;

  matrix->clearScreen();
  drawLayout(x, y, dimPhase ? colorDim : colorOn);
  matrix->flipDMABuffer();
}
