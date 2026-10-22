import 'package:flutter/material.dart';

/// Palet korporat: navy sebagai warna utama, abu-abu netral untuk struktur,
/// dan warna status yang diredam. Aksen terang hanya untuk LED di preview.
class AppColors {
  static const Color primary = Color(0xFF1D3A6E);
  static const Color primaryLight = Color(0xFF2A4F8F);
  static const Color secondary = Color(0xFF2A9D8F);

  static const Color amber = Color(0xFFFFA726);
  static const Color amberDeep = Color(0xFFB54708);
  static const Color sky = Color(0xFF00C2D1);
  static const Color dusk = Color(0xFF0B1220);

  static const Color background = Color(0xFFF5F6F8);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE4E7EC);
  static const Color inputBorder = Color(0xFFD0D5DD);
  static const Color subtleFill = Color(0xFFF2F4F7);

  static const Color textPrimary = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF667085);
  static const Color textOnDark = Color(0xFFEDEFF5);

  /// Biru muda logo INTI dan latar splash yang terang kebiruan.
  static const Color brandSky = Color(0xFF009FDB);
  static const Color splashBackground = Color(0xFFF7FAFE);
  static const Color splashTitle = Color(0xFF1B2A55);

  static const Color ledBackground = Color(0xFF0E1A2F);
  static const Color ledText = Color(0xFFFFB300);

  static const Color success = Color(0xFF079455);
  static const Color warning = Color(0xFFDC6803);
  static const Color danger = Color(0xFFD92D20);

  static const List<Color> headerGradient = [primary, primaryLight];
  static const List<Color> statusGradient = [primary, primaryLight];
  static const List<Color> amberGradient = [Color(0xFFFFC24B), amberDeep];

  /// Tombol utama: navy yang bergradasi ke biru.
  static const List<Color> heroButtonGradient = [primary, Color(0xFF3B78C2)];

  /// Latar halaman pairing: biru sangat muda ke putih.
  static const List<Color> softBackgroundGradient = [
    Color(0xFFEAF2FB),
    splashBackground,
  ];

  /// Isian teks: abu-abu kebiruan, sedikit lebih biru dari [subtleFill].
  static const Color inputFill = Color(0xFFF1F5FB);
}
