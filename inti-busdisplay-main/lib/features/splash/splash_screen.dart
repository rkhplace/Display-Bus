import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/faded_bus_photo.dart';
import '../main_navigation/main_navigation.dart';
import '../pairing/pairing_screen.dart';

/// Layar pembuka: logo INTI + judul di atas, foto bus di tengah, indikator
/// "Memuat..." di bawah. Saat landscape, logo di kiri dan foto di kanan.
class SplashScreen extends StatefulWidget {
  final ApiService? apiService;

  const SplashScreen({super.key, this.apiService});

  /// Lama minimum splash tampil sebelum pindah halaman.
  static const Duration minDisplay = Duration(milliseconds: 1600);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final ApiService _apiService;

  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _photoOpacity;
  late final Animation<Offset> _photoSlide;
  late final Animation<double> _loaderOpacity;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _apiService = widget.apiService ?? ApiService.instance;

    // Singkat dan tanpa efek memantul supaya terasa ringan.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
          ),
        );
    _photoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.85, curve: Curves.easeOut),
    );
    _photoSlide = Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 0.85, curve: Curves.easeOutCubic),
          ),
        );
    _loaderOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();

    _navigationTimer = Timer(SplashScreen.minDisplay, _navigateNext);
  }

  Future<void> _navigateNext() async {
    final paired = await _apiService.isPaired();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            paired ? const MainNavigation() : const PairingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _brand({required double logoHeight, required double titleSize}) {
    return SlideTransition(
      position: _logoSlide,
      child: FadeTransition(
        opacity: _logoOpacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: logoHeight,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.directions_bus_rounded,
                color: AppColors.primary,
                size: logoHeight * 0.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Smart Bus Display',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppColors.splashTitle,
                fontSize: titleSize,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photo({required Alignment fadeFrom, bool fadeOppositeEdge = true}) {
    return SlideTransition(
      position: _photoSlide,
      child: FadeTransition(
        opacity: _photoOpacity,
        child: FadedBusPhoto(
          fadeFrom: fadeFrom,
          fadeOppositeEdge: fadeOppositeEdge,
        ),
      ),
    );
  }

  Widget _loader() {
    return FadeTransition(
      opacity: _loaderOpacity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              strokeCap: StrokeCap.round,
              color: AppColors.brandSky,
              backgroundColor: AppColors.cardBorder,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Memuat...',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 14,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final landscape = constraints.maxWidth > constraints.maxHeight;
          return landscape
              ? _buildLandscape(constraints)
              : _buildPortrait(constraints);
        },
      ),
    );
  }

  Widget _buildPortrait(BoxConstraints constraints) {
    final h = constraints.maxHeight;
    return SafeArea(
      child: Column(
        children: [
          SizedBox(height: h * 0.09),
          _brand(
            logoHeight: (h * 0.17).clamp(90.0, 190.0),
            titleSize: (h * 0.026).clamp(18.0, 26.0),
          ),
          Expanded(child: _photo(fadeFrom: Alignment.topCenter)),
          _loader(),
          SizedBox(height: h * 0.07),
        ],
      ),
    );
  }

  Widget _buildLandscape(BoxConstraints constraints) {
    final h = constraints.maxHeight;
    return Row(
      children: [
        Expanded(
          flex: 9,
          child: SafeArea(
            right: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                _brand(
                  logoHeight: (h * 0.32).clamp(80.0, 200.0),
                  titleSize: (h * 0.05).clamp(16.0, 26.0),
                ),
                const Spacer(flex: 2),
                _loader(),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 11,
          child: _photo(
            fadeFrom: Alignment.centerLeft,
            fadeOppositeEdge: false,
          ),
        ),
      ],
    );
  }
}
