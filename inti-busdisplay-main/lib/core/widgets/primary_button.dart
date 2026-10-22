import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;

  /// null = tombol nonaktif (ditampilkan redup).
  final VoidCallback? onTap;
  final bool isOutline;
  final bool isLoading;
  final List<Color>? gradient;
  final Color? tintColor;
  final double minHeight;
  final double radius;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isOutline = false,
    this.isLoading = false,
    this.gradient,
    this.tintColor,
    this.minHeight = 44,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final bool useGradient = gradient != null;
    final Color base = tintColor ?? AppColors.primary;
    final Color foreground = (isOutline && !useGradient) ? base : Colors.white;
    final bool enabled = onTap != null && !isLoading;

    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: useGradient
            ? Colors.transparent
            : (isOutline ? AppColors.card : base),
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            constraints: BoxConstraints(minHeight: minHeight),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              gradient: useGradient
                  ? LinearGradient(
                      colors: gradient!,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              border: isOutline
                  ? Border.all(color: AppColors.inputBorder)
                  : null,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                else
                  Icon(icon, color: foreground, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
