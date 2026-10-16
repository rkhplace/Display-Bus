import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/animation_mode.dart';
import '../../../core/providers/route_provider.dart';
import '../../../core/providers/display_settings_provider.dart';
import '../../../core/theme/app_colors.dart';

const double kP5PanelAspectRatio = 3.6;

class PreviewCard extends StatefulWidget {
  const PreviewCard({super.key});

  @override
  State<PreviewCard> createState() => _PreviewCardState();
}

class _PreviewCardState extends State<PreviewCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  String? _lastModeLabel;
  double? _lastSpeed;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation(AnimationMode mode, double speed) {
    if (mode.label == _lastModeLabel && speed == _lastSpeed) return;
    _lastModeLabel = mode.label;
    _lastSpeed = speed;

    if (mode.isStatic) {
      _controller
        ..stop()
        ..value = 0;
      return;
    }

    _controller
      ..stop()
      ..value = 0
      ..repeat(period: mode.periodFor(speed));
  }

  @override
  Widget build(BuildContext context) {
    final routeProvider = context.watch<RouteProvider>();
    final settingsProvider = context.watch<DisplaySettingsProvider>();
    final mode = AnimationMode.fromLabel(settingsProvider.animMode);
    _syncAnimation(mode, settingsProvider.speed);

    final route = routeProvider.selectedRoute;
    final label = routeProvider.isPergi
        ? '${route.code} | ${route.origin.toUpperCase()} \u2192 ${route.destination.toUpperCase()}'
        : '${route.code} | ${route.destination.toUpperCase()} \u2192 ${route.origin.toUpperCase()}';

    return AspectRatio(
      aspectRatio: kP5PanelAspectRatio,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.ledBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final panelW = constraints.maxWidth;
            final panelH = constraints.maxHeight;
            final horizontalInset = 20.0;

            final double fontScale = (settingsProvider.fontSize / 16.0).clamp(
              0.2,
              5.0,
            );
            double fontSize = panelH * 0.34 * fontScale;

            final double brightnessAlpha = (settingsProvider.brightness / 100.0)
                .clamp(0.05, 1.0);
            final Color dynamicLedColor = AppColors.ledText.withValues(
              alpha: brightnessAlpha,
            );

            TextStyle buildStyle(double size) => TextStyle(
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: dynamicLedColor,
              fontSize: size,
              shadows: [
                Shadow(color: dynamicLedColor, blurRadius: 12),
                Shadow(color: dynamicLedColor, blurRadius: 24),
              ],
            );

            TextPainter measure(double size) => TextPainter(
              text: TextSpan(text: label, style: buildStyle(size)),
              maxLines: 1,
              textDirection: TextDirection.ltr,
            )..layout();

            var tp = measure(fontSize);

            if (!mode.travelsHorizontally &&
                tp.width > panelW - horizontalInset * 2) {
              final scale = (panelW - horizontalInset * 2) / tp.width;
              fontSize = (fontSize * scale).clamp(10.0, fontSize);
              tp = measure(fontSize);
            }
            final textStyle = buildStyle(fontSize);

            return Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final offset = mode.offsetFor(
                      panelWidth: panelW,
                      panelHeight: panelH,
                      textWidth: tp.width,
                      textHeight: tp.height,
                      t: _controller.value,
                    );

                    final blinkOpacity = mode.blinkOpacityFor(
                      _controller.value,
                    );

                    return Positioned(
                      left: offset.dx,
                      top: offset.dy,
                      child: Opacity(
                        opacity: blinkOpacity,
                        child: Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          style: textStyle,
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  top: 8,
                  child: Row(
                    children: [
                      Icon(
                        Icons.monitor_rounded,
                        color: dynamicLedColor.withValues(
                          alpha: brightnessAlpha * 0.7,
                        ),
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'P5 PANEL • PRATINJAU LIVE',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        mode.icon,
                        color: Colors.white.withValues(alpha: 0.45),
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        mode.label,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  static const double _pitch = 7.0;
  static const double _dotRadius = 1.1;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    for (double y = _pitch / 2; y < size.height; y += _pitch) {
      for (double x = _pitch / 2; x < size.width; x += _pitch) {
        canvas.drawCircle(Offset(x, y), _dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) => false;
}
