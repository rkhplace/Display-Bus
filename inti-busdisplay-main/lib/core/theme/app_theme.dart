import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.card,
        error: AppColors.danger,
      ),
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      // Material 3 mewarnai dialog/sheet dengan primary; dimatikan supaya
      // tetap putih bersih.
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.cardBorder,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
    );
  }

  static const double cardRadius = 10;

  // Kartu datar dengan garis tipis, tanpa bayangan: ringkas dan tetap
  // terbaca di layar landscape yang pendek.
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(cardRadius),
    border: Border.all(color: AppColors.cardBorder),
  );

  /// Label judul bagian: huruf kapital kecil, tebal, sedikit renggang.
  static TextStyle get sectionLabel => GoogleFonts.poppins(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    color: AppColors.textPrimary,
  );

  static BoxDecoration coloredCardDecoration(
    Color color, {
    double radius = 28,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.25),
          blurRadius: 28,
          spreadRadius: -4,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  static BoxDecoration gradientCardDecoration(
    List<Color> colors, {
    double radius = 28,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: colors.last.withValues(alpha: 0.25),
          blurRadius: 28,
          spreadRadius: -4,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }
}
