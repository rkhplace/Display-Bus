import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/models/animation_mode.dart';
import '../../../core/providers/display_settings_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/modern_slider.dart';
import '../../../core/widgets/section_card.dart';

/// Mode animasi + kecepatan, kecerahan, dan ukuran font dalam satu kartu.
class DisplaySettingCard extends StatelessWidget {
  const DisplaySettingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<DisplaySettingsProvider>();
    final mode = AnimationMode.fromLabel(settingsProvider.animMode);

    return SectionCard(
      title: 'Tampilan Panel',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: settingsProvider.animMode,
                isExpanded: true,
                borderRadius: BorderRadius.circular(8),
                icon: const Icon(
                  Icons.unfold_more_rounded,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                  color: AppColors.textPrimary,
                ),
                items: AnimationMode.values
                    .map(
                      (m) => DropdownMenuItem(
                        value: m.label,
                        child: Row(
                          children: [
                            Icon(m.icon, size: 18, color: AppColors.textSecondary),
                            const SizedBox(width: 10),
                            Text(m.label),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) => settingsProvider.setAnimMode(val!),
              ),
            ),
          ),
          const SizedBox(height: 6),
          ModernSlider(
            label: 'Kecepatan',
            icon: Icons.speed_rounded,
            color: AppColors.primary,
            value: settingsProvider.speed,
            // Mode Static tidak bergerak, jadi kecepatan tidak berpengaruh.
            onChanged: mode.isStatic ? null : settingsProvider.setSpeed,
          ),
          ModernSlider(
            label: 'Kecerahan',
            icon: Icons.brightness_6_rounded,
            color: AppColors.primary,
            value: settingsProvider.brightness,
            onChanged: settingsProvider.setBrightness,
          ),
          ModernSlider(
            label: 'Ukuran',
            icon: Icons.format_size_rounded,
            color: AppColors.primary,
            value: settingsProvider.fontSize,
            onChanged: settingsProvider.setFontSize,
          ),
        ],
      ),
    );
  }
}
