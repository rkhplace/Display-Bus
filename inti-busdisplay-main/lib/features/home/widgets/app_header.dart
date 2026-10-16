import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import 'status_card.dart';

/// Baris atas layar kontrol: logo + judul di kiri, status panel di kanan.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Image.asset(
            'assets/images/logo.png',
            height: 26,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.directions_bus_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Smart Bus Display',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const StatusCard(),
        ],
      ),
    );
  }
}
