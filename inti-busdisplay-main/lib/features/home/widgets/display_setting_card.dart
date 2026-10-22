import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/animation_mode.dart';
import '../../../core/providers/display_settings_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/modern_slider.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/selection_sheet.dart';

/// Mode animasi + kecepatan, kecerahan, dan ukuran font dalam satu kartu.
class DisplaySettingCard extends StatelessWidget {
  const DisplaySettingCard({super.key});

  Future<void> _pickMode(
    BuildContext context,
    DisplaySettingsProvider provider,
  ) async {
    final picked = await showSelectionSheet<String>(
      context: context,
      title: 'Mode Animasi',
      selected: provider.animMode,
      options: AnimationMode.values
          .map(
            (m) => SelectionOption(
              value: m.label,
              title: m.label,
              subtitle: m.description,
              icon: m.icon,
            ),
          )
          .toList(),
    );
    if (picked != null) provider.setAnimMode(picked);
  }

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
          SelectField(
            icon: mode.icon,
            label: mode.label,
            subtitle: mode.description,
            onTap: () => _pickMode(context, settingsProvider),
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
