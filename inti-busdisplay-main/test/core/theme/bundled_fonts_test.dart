import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

// main.dart mematikan unduhan font (allowRuntimeFetching = false), jadi setiap
// bobot Poppins yang dipakai di kode HARUS ada di assets/google_fonts/.
// Kalau menambah bobot baru (mis. w800), tambahkan juga file .ttf-nya.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() => GoogleFonts.config.allowRuntimeFetching = true);

  for (final weight in [
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
  ]) {
    test('Poppins $weight tersedia di asset tanpa internet', () async {
      GoogleFonts.poppins(fontWeight: weight);
      await expectLater(GoogleFonts.pendingFonts(), completes);
    });
  }

  test('tema teks Poppins memuat tanpa internet', () async {
    GoogleFonts.poppinsTextTheme();
    await expectLater(GoogleFonts.pendingFonts(), completes);
  });
}
