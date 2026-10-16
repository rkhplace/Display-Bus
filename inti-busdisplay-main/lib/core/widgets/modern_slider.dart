import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Slider 0-100 dalam satu baris: ikon, label, slider, nilai.
class ModernSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double value;

  /// null = slider nonaktif (mis. kecepatan saat mode Static).
  final ValueChanged<double>? onChanged;

  const ModernSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon = Icons.tune_rounded,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final tint = enabled ? color : AppColors.textSecondary;

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          SizedBox(
            width: 76,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12.5,
                color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: tint,
                inactiveTrackColor: AppColors.subtleFill,
                disabledActiveTrackColor: AppColors.cardBorder,
                disabledInactiveTrackColor: AppColors.background,
                trackHeight: 3,
                overlayColor: tint.withValues(alpha: 0.15),
                thumbColor: tint,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7,
                  elevation: 0,
                  pressedElevation: 0,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: value,
                min: 0,
                max: 100,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              value.toInt().toString(),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
