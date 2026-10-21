import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app.dart';
import 'core/providers/connection_provider.dart';
import 'core/providers/display_settings_provider.dart';
import 'core/providers/preset_provider.dart';
import 'core/providers/route_provider.dart';
import 'core/services/api_service.dart';
import 'core/repositories/route_repository.dart';
import 'core/repositories/preset_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Font Poppins dibundel di assets/google_fonts/. Tanpa ini google_fonts akan
  // mengunduh font saat app jalan, yang gagal di bus tanpa sinyal.
  GoogleFonts.config.allowRuntimeFetching = false;

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint(
      'Peringatan: file .env tidak ditemukan atau gagal dimuat ($e). '
      'Menggunakan nilai default bawaan ApiService.',
    );
  }

  // Orientasi tidak dikunci: layar kontrol menyesuaikan diri (2 kolom saat
  // landscape, 1 kolom saat portrait).
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]).then((_) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    final apiService = ApiService.instance;

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => ConnectionProvider(apiService: apiService),
          ),
          ChangeNotifierProvider(
            create: (_) => RouteProvider(
              routeRepository: RouteRepository(apiService: apiService),
            ),
          ),
          ChangeNotifierProvider(create: (_) => DisplaySettingsProvider()),
          ChangeNotifierProvider(
            create: (_) => PresetProvider(
              presetRepository: PresetRepository(apiService: apiService),
            ),
          ),
        ],
        child: const SmartBusDisplayApp(),
      ),
    );
  });
}
