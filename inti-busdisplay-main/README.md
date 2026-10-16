<p align="center">
  <img src="assets/images/logo.png" alt="PT INTI Logo" width="140" />
</p>

<h1 align="center">Smart Bus Display</h1>
<p align="center">
  <b>Running Text Controller</b> - Aplikasi Flutter untuk mengendalikan panel LED (P5) pada bus, via Bluetooth Low Energy (BLE) terenkripsi dan sinkronisasi ke server.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" />
  <img src="https://img.shields.io/badge/State%20Management-Provider-blueviolet" />
  <img src="https://img.shields.io/badge/Auth-Device%20Pairing-success" />
  <img src="https://img.shields.io/badge/BLE-AES--256%20Encrypted-success" />
  <img src="https://img.shields.io/badge/API-HTTPS%20Default-success" />
</p>

---

## Daftar Isi

- [Tentang Aplikasi](#tentang-aplikasi)
- [Fitur Utama](#fitur-utama)
- [Struktur Folder](#struktur-folder)
- [Autentikasi & Keamanan](#autentikasi--keamanan)
- [Persiapan Lingkungan](#persiapan-lingkungan)
- [Instalasi](#instalasi)
- [Konfigurasi Environment](#konfigurasi-environment)
- [Menjalankan Aplikasi](#menjalankan-aplikasi)
- [Panduan Penggunaan Aplikasi](#panduan-penggunaan-aplikasi)
  - [1. Pairing Device (Pertama Kali)](#1-pairing-device-pertama-kali)
  - [2. Menghubungkan ke Panel via Bluetooth](#2-menghubungkan-ke-panel-via-bluetooth)
  - [3. Mengatur Rute](#3-mengatur-rute)
  - [4. Mengatur Tampilan Animasi](#4-mengatur-tampilan-animasi)
  - [5. Preset](#5-preset)
  - [6. Mengirim ke Display](#6-mengirim-ke-display)
- [Referensi Provider (State Management)](#referensi-provider-state-management)
- [Referensi Service & Repository](#referensi-service--repository)
- [Model Data](#model-data)
- [Penanganan Error & Feedback](#penanganan-error--feedback)
- [Pengujian (Testing)](#pengujian-testing)
- [Panduan Maintenance](#panduan-maintenance)
  - [Menambah Fitur Baru](#menambah-fitur-baru)
  - [Menambah Provider Baru](#menambah-provider-baru)
  - [Menambah Mode Animasi Baru](#menambah-mode-animasi-baru)
  - [Konvensi Kode](#konvensi-kode)
- [Troubleshooting](#troubleshooting)
- [Dependency Utama](#dependency-utama)
- [Lisensi Internal](#lisensi-internal)

---

## Tentang Aplikasi

**Smart Bus Display** adalah aplikasi kontrol untuk panel LED _running text_ (P5 Panel) yang dipasang di bus. Aplikasi ini memungkinkan operator untuk:

- Memilih rute bus dan arah perjalanan (Pergi/Pulang) yang akan ditampilkan di panel.
- Mengatur mode animasi teks (scroll, blink, static, dsb), kecepatan, kecerahan, dan ukuran font.
- Mengirim pengaturan tersebut langsung ke panel LED via **Bluetooth Low Energy (BLE) terenkripsi AES-256**.
- Menyimpan dan memuat kembali kombinasi pengaturan sebagai **preset** (misal: "Preset Pagi", "Preset Rute Jakarta").
- Menyinkronkan histori pengaturan ke **server backend (HTTPS)** agar dapat dipantau/di-manage terpusat.

Semua kontrol ada di **satu layar** yang menyesuaikan orientasi: 2 kolom saat landscape (mis. HP/tablet di holder dashboard), 1 kolom saat portrait. Tombol **Kirim ke Display** selalu terlihat.

---

## Fitur Utama

| Fitur               | Deskripsi                                                                                             |
| ------------------- | ----------------------------------------------------------------------------------------------------- |
| Device Pairing      | Autentikasi aman per-perangkat, sesi lokal otomatis kedaluwarsa                                       |
| Kontrol via BLE     | Kirim pengaturan ke panel P5 tanpa internet, payload terenkripsi AES-256                              |
| Manajemen Rute      | Tambah, pilih, hapus rute; toggle arah Pergi/Pulang; indikator loading                                |
| Mode Animasi        | 7 mode: Running, Static, Blink, Scroll (4 arah)                                                       |
| Pengaturan Tampilan | Kecepatan scroll, kecerahan, ukuran font (live preview)                                               |
| Preset              | Simpan, muat, dan timpa kombinasi pengaturan; peringatan jika rute preset sudah dihapus               |
| Live Preview        | Simulasi visual panel LED P5 secara real-time di layar                                                |
| Sinkronisasi Server | Rute & preset tersimpan terpusat di backend; deteksi & peringatan jika panel dan server tidak sinkron |
| Sesi Aman           | Auto logout & arahkan ke pairing ulang saat token ditolak server (401) atau kedaluwarsa lokal         |

---

### Struktur Folder

```
lib/
├── core/
│   ├── models/
│   │   ├── operation_result.dart      # Wrapper hasil operasi (success/failure)
│   │   ├── route_model.dart           # Model data rute
│   │   └── animation_mode.dart        # Enum mode animasi: label, ikon, offset, timing (single source of truth)
│   ├── providers/
│   │   ├── connection_provider.dart   # BLE (terenkripsi) + status sinkron API
│   │   ├── route_provider.dart        # Daftar rute, rute terpilih, arah, status loading
│   │   ├── display_settings_provider.dart  # Animasi, speed, brightness, fontSize
│   │   └── preset_provider.dart       # Simpan/muat/timpa preset
│   ├── repositories/
│   │   ├── route_repository.dart      # Abstraksi akses data rute
│   │   └── preset_repository.dart     # Abstraksi akses data preset
│   ├── services/
│   │   ├── api_service.dart           # HTTP client ke backend (HTTPS default, timeout, sanitasi error)
│   │   ├── bluetooth_service.dart     # Komunikasi BLE ke panel P5 (payload dienkripsi)
│   │   ├── ble_payload_cipher.dart    # Enkripsi AES-256-CBC untuk payload BLE
│   │   ├── device_identity_service.dart  # Secure storage device ID, token, bleKey, expiry sesi
│   │   └── auth_session_notifier.dart # Broadcast invalidasi sesi ke seluruh app
│   ├── theme/
│   │   ├── app_colors.dart
│   │   └── app_theme.dart
│   ├── utils/
│   │   ├── display_payload_builder.dart  # Pure function pembangun payload
│   │   └── feedback_extension.dart       # Extension SnackBar (context.showResult/showFeedback)
│   └── widgets/
│       ├── modern_slider.dart
│       └── primary_button.dart
├── features/
│   ├── splash/
│   │   └── splash_screen.dart         # Splash + cek status pairing
│   ├── pairing/
│   │   └── pairing_screen.dart        # Layar input kode pairing
│   ├── main_navigation/
│   │   └── main_navigation.dart       # Layar kontrol responsif (2 kolom / 1 kolom)
│   ├── home/
│   │   └── widgets/
│   │       ├── app_header.dart
│   │       ├── preview_card.dart      # Simulasi panel LED live (pakai AnimationMode)
│   │       ├── status_card.dart       # Chip status panel (BLE) + pemindai + banner gagal sinkron
│   │       ├── route_card.dart        # CRUD rute + indikator loading
│   │       ├── display_setting_card.dart
│   │       ├── quick_action_card.dart # Simpan/muat/timpa preset, reset
│   │       └── send_button.dart       # Tombol Kirim (menunggu balasan panel)
├── app.dart                            # MaterialApp root + listener AuthSessionNotifier
└── main.dart                           # Entry point + MultiProvider setup

test/
├── core/
│   ├── models/                        # Test OperationResult, RouteModel
│   ├── providers/                     # Test RouteProvider, PresetProvider, DisplaySettingsProvider, ConnectionProvider
│   ├── services/                      # Test BlePayloadCipher
│   └── utils/                         # Test DisplayPayloadBuilder
├── fakes/                             # Fake repository/service untuk test tanpa I/O nyata
└── widget_test.dart                   # Smoke test
```

---

## Persiapan Lingkungan

| Tool                   | Versi Minimum                                         |
| ---------------------- | ----------------------------------------------------- |
| Flutter SDK            | 3.38+                                                 |
| Dart SDK               | 3.10+ (lihat `environment.sdk` di `pubspec.yaml`)     |
| Android Studio / Xcode | Untuk build native                                    |
| Perangkat fisik        | **Wajib** — BLE tidak berfungsi di emulator/simulator |

Pastikan Bluetooth & Location permission diaktifkan di perangkat pengujian (Android memerlukan izin lokasi untuk BLE scan).

---

## Instalasi

```bash
# 1. Clone repository
git clone https://github.com/asepjamaludinn/inti-busdisplay
cd inti-busdisplay

# 2. Install dependencies
flutter pub get

# 3. Salin file environment
cp .env.example .env
```

---

## Konfigurasi Environment

Buat file `.env` di root project (sejajar dengan `pubspec.yaml`):

```env
BACKEND_IP=192.168.1.10
BACKEND_PORT=3000
BACKEND_SCHEME=https
```

| Variable         | Keterangan                                                                                                               |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `BACKEND_IP`     | Alamat IP server backend (gunakan IP lokal jaringan, bukan `localhost`, jika device fisik dan server berbeda mesin)      |
| `BACKEND_PORT`   | Port server backend (default `3000`)                                                                                     |
| `BACKEND_SCHEME` | Skema koneksi ke backend. **Default `https`** jika variabel ini tidak diset. Set `http` hanya untuk dev lokal tanpa TLS. |

> Jika `.env` tidak ditemukan saat aplikasi dijalankan, `main.dart` tidak akan crash — akan memakai nilai default bawaan (`127.0.0.1:3000`, skema `https`) dan mencatat peringatan di log.

Tambahkan `assets/images/logo.png` ke `pubspec.yaml`:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/logo.png
  fonts:
    # ... (jika ada font kustom)
```

---

## Menjalankan Aplikasi

```bash
# Jalankan di perangkat fisik yang terhubung
flutter run

# Jalankan seluruh test
flutter test

# Build APK release
flutter build apk --release

# Build App Bundle (untuk Play Store)
flutter build appbundle --release

# Build iOS (memerlukan macOS + Xcode)
flutter build ios --release
```

Orientasi yang diizinkan (portrait dan landscape) disetel di `main.dart`. Batas lebar untuk tata letak 2 kolom ada di `MainNavigation.twoColumnMinWidth`.

---

## Panduan Penggunaan Aplikasi

### 1. Pairing Device (Pertama Kali)

Saat aplikasi dibuka pertama kali (atau setelah data aplikasi dihapus, atau sesi kedaluwarsa/dicabut), pengguna akan diarahkan ke layar **Pairing**:

1. Hubungi admin untuk menjalankan perintah pairing di server:
   ```bash
   npm run pair:generate
   ```
2. Admin akan mendapatkan kode 8 karakter (misal: `A7XK2P9Q`), berlaku 15 menit.
3. Masukkan kode tersebut di layar Pairing aplikasi, lalu tekan **Pasangkan**.
4. Jika berhasil, aplikasi otomatis masuk ke halaman utama (`MainNavigation`); device token (dan `bleKey` jika disediakan server) tersimpan permanen di secure storage.

> Proses ini **dilakukan ulang otomatis** jika: sesi lokal melewati 30 hari, server menolak token dengan status 401 (mis. device di-revoke admin), atau data aplikasi dihapus. Selama sesi masih valid, splash screen akan langsung mengarahkan ke `MainNavigation`.

### 2. Menghubungkan ke Panel via Bluetooth

1. Di kanan atas layar, lihat chip status panel. Jika tertulis "Panel terputus", tekan chip tersebut.
2. Aplikasi akan memindai perangkat BLE di sekitar (4 detik).
3. Pilih panel P5 dari daftar (nama perangkat sesuai firmware panel), tekan **Hubungkan**.
4. Status akan berubah menjadi "Terhubung" dengan indikator hijau.

### 3. Mengatur Rute

- **Memilih rute:** gunakan dropdown di **Route Card**, pilih dari daftar rute yang tersinkron dari server. Indikator kecil muncul di header kartu selama daftar rute masih dimuat dari server.
- **Menambah rute baru:** tekan ikon `+`, isi 3 field terpisah (Kode, Kota Asal, Kota Tujuan), tekan **Simpan**. Sistem otomatis menolak kode atau kombinasi rute yang sudah ada (baik searah maupun arah sebaliknya).
- **Menghapus rute:** tekan ikon tempat sampah pada rute yang sedang aktif. Minimal harus tersisa 1 rute.
- **Toggle arah:** gunakan tab "Pergi Ke Tujuan" / "Kembali/Pulang" untuk membalik urutan asal-tujuan yang ditampilkan di panel.

### 4. Mengatur Tampilan Animasi

Di kartu **Tampilan Panel**:

- **Mode Animasi:** pilih dari 7 mode (Running, Static, Blink, Scroll Left/Right/Up/Down) — preview langsung terlihat di kartu preview.
- **Kecepatan Scroll:** slider 0–100, memengaruhi kecepatan animasi teks berjalan.
- **Kecerahan:** slider 0–100, memengaruhi opacity/brightness warna LED pada preview & panel fisik.
- **Ukuran Font:** slider yang menentukan ukuran teks pada panel.

### 5. Preset

- **Simpan Preset:** di kartu **Preset**, tekan **Simpan Preset**, beri nama (misal "Pagi - Rute Garut"), tekan Simpan. Kombinasi rute + arah + animasi + speed + brightness + fontSize saat ini akan tersimpan ke server.
- **Muat Preset:** tekan **Muat Preset**, pilih dari daftar preset tersimpan — semua pengaturan (rute, arah, animasi, dst) akan diterapkan otomatis. Jika rute yang tersimpan di preset sudah dihapus, aplikasi memberi tahu secara eksplisit (warna kuning) bahwa rute pertama dipakai sebagai gantinya, bukan diam-diam mengganti.
- **Timpa Preset:** setelah memuat preset dan mengubah sebagian pengaturan, tombol **Timpa Preset "..."** akan muncul untuk menyimpan perubahan ke preset yang sama.
- **Reset ke Default:** mengembalikan semua pengaturan (rute pertama, animasi Scroll Left, speed 50, brightness 80, fontSize 16) dan melepaskan preset yang sedang dimuat.

### 6. Mengirim ke Display

Tekan tombol **Kirim ke Display** (tombol navy yang selalu terlihat). Pengaturan saat ini akan:

1. Dienkripsi dan dikirim ke panel LED via Bluetooth (butuh koneksi BLE aktif dan kunci enkripsi tersedia).
2. **Hanya jika pengiriman BLE berhasil**, disinkronkan ke server backend.

Kemungkinan hasil:

| Kondisi                                 | Perilaku                                                                                                                                                         |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| BLE belum terhubung                     | Ditolak, muncul peringatan; tidak ada apa pun yang dikirim.                                                                                                      |
| BLE gagal terkirim                      | Ditolak, muncul peringatan; server **tidak** ikut disinkronkan (mencegah data server dan panel tidak sesuai).                                                    |
| BLE sukses, sinkron ke server sukses    | SnackBar hijau: berhasil sepenuhnya.                                                                                                                             |
| BLE sukses, sinkron ke server **gagal** | SnackBar kuning (bukan hijau) + banner peringatan persisten di atas kartu Rute sampai di-dismiss, karena panel sudah berubah tapi data di server belum tentu sesuai. |

---

## Referensi Provider (State Management)

| Provider                  | Getter Utama                                                       | Method Aksi Utama                                                                                                                                                                |
| ------------------------- | ------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ConnectionProvider`      | `isBleConnected`, `scanResults`, `isScanning`, `lastApiSyncFailed` | `startBleScan()`, `connectToDevice()`, `disconnectBle()`, `sendPayload()`, `acknowledgeApiSyncFailure()`                                                                         |
| `RouteProvider`           | `routes`, `selectedRoute`, `isPergi`, `isLoadingRoutes`            | `setRoute()`, `setDirection()`, `addRoute()`, `deleteRoute()`, `applyRouteFromPayload()` _(mengembalikan `bool` — `false` jika rute preset tidak ditemukan)_, `resetSelection()` |
| `DisplaySettingsProvider` | `animMode`, `speed`, `brightness`, `fontSize`                      | `setAnimMode()`, `setSpeed()`, `setBrightness()`, `setFontSize()`, `applyFromPayload()`, `resetToDefault()`                                                                      |
| `PresetProvider`          | `loadedPresetId`, `loadedPresetName`, `hasLoadedPreset`            | `saveCurrentPreset()`, `overwritePreset()`, `overwriteLoadedPreset()`, `markLoadedPreset()`, `clearLoadedPreset()`                                                               |

Semua provider didaftarkan di `main.dart` lewat `MultiProvider`, dapat diakses di widget manapun via:

```dart
final routeProvider = context.watch<RouteProvider>(); // rebuild saat state berubah
final routeProvider = context.read<RouteProvider>();   // baca sekali, untuk aksi (tap handler)
```

---

## Referensi Service & Repository

| Class                   | Tanggung Jawab                                                                                                                                                                                                                                                     |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `ApiService`            | Seluruh komunikasi HTTP ke backend (singleton via `ApiService.instance`, HTTPS default, timeout, sanitasi error). Helper internal: `_safeGet<T>()` (GET tanpa auth) dan `_authorizedRequest<T>()` (mutasi dengan device-token auth, auto-invalidate sesi saat 401) |
| `BleService`            | Scan, connect, disconnect, dan tulis data terenkripsi ke karakteristik BLE panel P5; menolak kirim jika tidak ada kunci enkripsi                                                                                                                                   |
| `BlePayloadCipher`      | Enkripsi AES-256-CBC payload BLE, dengan pembungkus timestamp untuk mitigasi replay                                                                                                                                                                                |
| `DeviceIdentityService` | Generate & simpan `deviceId`/`deviceToken`/`bleKey` di secure storage; mengelola kedaluwarsa sesi lokal (30 hari)                                                                                                                                                  |
| `AuthSessionNotifier`   | Singleton `ValueNotifier<bool>` yang di-broadcast ke seluruh app saat sesi device tidak valid lagi, didengarkan oleh `app.dart` untuk auto-redirect ke Pairing                                                                                                     |
| `RouteRepository`       | Abstraksi CRUD rute — dipanggil `RouteProvider`, meneruskan ke `ApiService`                                                                                                                                                                                        |
| `PresetRepository`      | Abstraksi CRUD preset — dipanggil `PresetProvider`, meneruskan ke `ApiService`                                                                                                                                                                                     |

---

## Model Data

### `RouteModel`

```dart
RouteModel({
  String? id,          // null jika belum tersimpan di server
  required String code,        // Kode rute, mis. "B1"
  required String origin,      // Kota asal
  required String destination, // Kota tujuan
})
```

- `fullDisplayName` → `"B1 • Bandung - Garut"` (untuk dropdown & konfirmasi)
- `apiRouteName` → `"Bandung - Garut"` (untuk label ringkas)

### `AnimationMode` (enum)

Single source of truth untuk seluruh logika mode animasi — label, ikon, arah gerak, dan timing:

```dart
enum AnimationMode {
  running, still, blink, scrollLeft, scrollRight, scrollUp, scrollDown;

  String get label;                 // "Running", "Static", dst — dipakai di payload & dropdown
  IconData get icon;
  bool get isStatic;
  bool get isBlink;
  bool get travelsHorizontally;

  Duration periodFor(double speed);
  Offset offsetFor({ required double panelWidth, ... required double t });
  double blinkOpacityFor(double t);

  static AnimationMode fromLabel(String? label); // fallback ke `still` jika tidak dikenali
}
```

Dipakai oleh `DisplaySettingCard` (pemilih mode) dan `PreviewCard` (simulasi panel) — **jangan** menduplikasi logika ikon/offset/timing di widget lain; tambahkan ke enum ini.

### `OperationResult<T>`

Wrapper hasil operasi asinkron (pengganti pola try/catch berulang):

```dart
OperationResult.success(data, message);
OperationResult.failure(message);
```

Digunakan oleh seluruh provider agar UI layer bisa menampilkan feedback secara konsisten lewat `context.showResult(result)`.

> **Catatan:** `result.success == true` tidak selalu berarti "semuanya sempurna" — untuk `ConnectionProvider.sendPayload()`, `success` bernilai `true` selama BLE berhasil terkirim, walau sinkron ke server gagal. Cek `ConnectionProvider.lastApiSyncFailed` secara terpisah untuk kasus ini (lihat [Penanganan Error & Feedback](#penanganan-error--feedback)).

---

## Penanganan Error & Feedback

Semua feedback ke pengguna (SnackBar) terpusat di `lib/core/utils/feedback_extension.dart`:

```dart
context.showFeedback(message: '...', color: AppColors.success);
context.showResult(result, fallbackSuccessMessage: '...');
```

**Aturan penting untuk maintenance:**

- Provider **tidak pernah** memanggil `ScaffoldMessenger` secara langsung. Jika menambah method baru di provider yang butuh feedback ke user, method tersebut harus mengembalikan `OperationResult`, bukan menampilkan SnackBar sendiri.
- `context.showResult(result)` memilih warna berdasarkan `result.success` — untuk kasus **sukses sebagian** (mis. BLE sukses tapi sinkron server gagal), **jangan** pakai `showResult` mentah, karena akan menampilkan snackbar hijau yang menyesatkan. Cek flag terkait (contoh: `ConnectionProvider.lastApiSyncFailed`) dan panggil `showFeedback` langsung dengan `AppColors.warning`. Lihat implementasi `SendToDisplayButton._send()` sebagai referensi pola ini.
- Pesan error dari `ApiService` sudah melalui sanitasi (lihat [Autentikasi & Keamanan](#5-sanitasi-pesan-error)) — jangan menampilkan `response.body` mentah di widget mana pun.

---

## Pengujian (Testing)

```bash
flutter test
```

| Area                      | File Test                                                 | Cakupan                                                                                                                         |
| ------------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Model                     | `test/core/models/*`                                      | `OperationResult`, `RouteModel` (equality, JSON)                                                                                |
| `RouteProvider`           | `test/core/providers/route_provider_test.dart`            | Validasi tambah rute, hapus rute, apply preset (termasuk rute yang tidak ditemukan)                                             |
| `PresetProvider`          | `test/core/providers/preset_provider_test.dart`           | Simpan/timpa/muat preset                                                                                                        |
| `DisplaySettingsProvider` | `test/core/providers/display_settings_provider_test.dart` | Setter, reset, apply dari payload                                                                                               |
| `ConnectionProvider`      | `test/core/providers/connection_provider_test.dart`       | BLE belum konek, BLE gagal (tidak sync ke API), BLE+API sukses, BLE sukses/API gagal (state drift), `acknowledgeApiSyncFailure` |
| `BlePayloadCipher`        | `test/core/services/ble_payload_cipher_test.dart`         | Bentuk output (IV + ciphertext), IV acak per panggilan, penanganan raw key tidak valid                                          |
| `DisplayPayloadBuilder`   | `test/core/utils/display_payload_builder_test.dart`       | Struktur payload untuk BLE/API                                                                                                  |
| Smoke test                | `test/widget_test.dart`                                   | App bisa di-build tanpa error                                                                                                   |

Fake yang tersedia di `test/fakes/` (`FakeBleService`, `FakeApiServiceForConnection`, `FakeDeviceIdentityService`, `FakeRouteRepository`, `FakePresetRepository`) dipakai untuk mengisolasi provider dari I/O nyata (network, BLE, secure storage) — gunakan pola yang sama saat menambah test provider baru.

---

## Panduan Maintenance

### Menambah Fitur Baru

1. Tentukan domain state-nya - apakah cocok masuk provider yang sudah ada, atau perlu provider baru?
2. Jika perlu data dari server, buat/gunakan repository yang sesuai - jangan panggil `ApiService` langsung dari provider.
3. Tambahkan UI di `features/`, hubungkan lewat `context.watch/read<ProviderX>()`.
4. Jangan panggil `BuildContext` dari dalam provider — kembalikan `OperationResult` dan biarkan widget yang menampilkan feedback.
5. Jika fitur melibatkan request ke `ApiService`, pastikan lewat `_authorizedRequest`/`_safeGet` yang sudah ada (bukan `http` langsung) agar timeout, sanitasi error, dan auto-invalidate 401 tetap berlaku otomatis.

### Menambah Provider Baru

```dart
// 1. Buat file baru di lib/core/providers/
class ExampleProvider extends ChangeNotifier {
  final ExampleRepository _repository;
  ExampleProvider({ExampleRepository? repository})
      : _repository = repository ?? ExampleRepository();
  // ... state & method
}

// 2. Daftarkan di main.dart
MultiProvider(
  providers: [
    // ...provider lain
    ChangeNotifierProvider(create: (_) => ExampleProvider()),
  ],
  child: const SmartBusDisplayApp(),
)
```

### Menambah Mode Animasi Baru

Jangan menambah string mode secara langsung di widget. Tambahkan varian baru ke `lib/core/models/animation_mode.dart`:

```dart
enum AnimationMode {
  // ...varian lain
  fadeInOut('Fade In-Out', Icons.blur_on_rounded);
  // lengkapi offsetFor()/periodFor()/blinkOpacityFor() jika perilakunya khusus
}
```

`DisplaySettingCard` dan `PreviewCard` akan otomatis mengikuti tanpa perubahan lain, karena keduanya membaca daftar mode dari `AnimationMode.allLabels`/`AnimationMode.values`.

### Konvensi Kode

- **Bahasa UI & pesan error:** Bahasa Indonesia (konsisten dengan seluruh aplikasi).
- **Bahasa kode & commit message:** Inggris, mengikuti [Conventional Commits](https://www.conventionalcommits.org/).
- **Penamaan file:** `snake_case.dart`.
- **Warna:** selalu gunakan konstanta dari `AppColors`, jangan hardcode hex color di widget.
- **Dekorasi kartu:** gunakan `AppTheme.cardDecoration` / `coloredCardDecoration` / `gradientCardDecoration`, jangan buat `BoxDecoration` manual berulang.
- **Provider tidak boleh punya dependency ke `BuildContext`, `Navigator`, atau `ScaffoldMessenger`.**
- **Mode animasi** selalu ditambahkan lewat `AnimationMode`, jangan duplikasi switch-case di widget.
- **Jangan bypass** `_authorizedRequest`/`_safeGet` di `ApiService` untuk memanggil `http` langsung — akan kehilangan timeout, sanitasi error, dan penanganan 401 otomatis.

---

## Troubleshooting

| Gejala                                                      | Kemungkinan Penyebab                                                                                       | Solusi                                                                                                                                            |
| ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Layar Pairing terus muncul walau sudah pairing              | Token di secure storage terhapus/reset (uninstall app)                                                     | Lakukan pairing ulang dengan kode baru dari admin                                                                                                 |
| Tiba-tiba diarahkan ke Pairing saat sedang memakai aplikasi | Server membalas 401 (device di-revoke admin) **atau** sesi lokal sudah lewat 30 hari                       | Lakukan pairing ulang; jika ini tidak diharapkan, cek status device di server                                                                     |
| BLE scan tidak menemukan perangkat                          | Izin lokasi/Bluetooth belum diaktifkan (Android)                                                           | Aktifkan izin di pengaturan aplikasi                                                                                                              |
| "Tidak dapat terhubung ke server"                           | `BACKEND_IP`/`BACKEND_PORT`/`BACKEND_SCHEME` salah, atau device tidak satu jaringan dengan server          | Cek `.env`, pastikan device & server satu WiFi/LAN; jika backend belum punya TLS, set `BACKEND_SCHEME=http`                                       |
| Kode rute/preset "sudah terdaftar"                          | Duplikat terdeteksi baik di client maupun server (unique constraint DB)                                    | Gunakan kode/nama lain, atau gunakan toggle Pergi/Pulang untuk rute searah terbalik                                                               |
| Kirim ke Display tidak ada efek di panel                    | BLE belum terhubung, `characteristicUuid` tidak cocok dengan firmware panel, atau tidak ada kunci enkripsi | Cek chip status panel di kanan atas; verifikasi UUID di `bluetooth_service.dart`; pastikan device sudah dipasangkan (ada `bleKey`/device token) |
| Panel berubah tapi ada banner kuning di atas kartu Rute     | Data berhasil sampai ke panel via BLE, tapi sinkron ke server gagal (server down/timeout)                  | Tekan **Kirim ke Display** lagi untuk mencoba sinkron ulang; banner bisa di-dismiss manual                                                        |
| Muncul preset warning "rute aslinya sudah tidak tersedia"   | Rute yang tersimpan di preset sudah dihapus setelah preset dibuat                                          | Simpan ulang preset dengan rute yang masih ada, atau abaikan jika rute pertama sudah sesuai kebutuhan                                             |

---

## Dependency Utama

| Package                  | Kegunaan                                              |
| ------------------------ | ----------------------------------------------------- |
| `provider`               | State management                                      |
| `http`                   | HTTP client ke backend                                |
| `flutter_blue_plus`      | Komunikasi Bluetooth Low Energy                       |
| `flutter_secure_storage` | Penyimpanan aman device ID, token pairing, dan bleKey |
| `uuid`                   | Generate device ID unik                               |
| `flutter_dotenv`         | Membaca konfigurasi `.env`                            |
| `encrypt`                | Enkripsi AES-256-CBC untuk payload BLE                |
| `crypto`                 | Turunan kunci (SHA-256) fallback untuk enkripsi BLE   |
| `google_fonts`           | Font Poppins                                          |

---

## Lisensi Internal

Aplikasi internal milik **PT INTI** — tidak untuk didistribusikan ke luar tanpa izin.
