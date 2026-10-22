import 'package:flutter/material.dart';

/// Foto bus yang memudar ke warna latar di tepi-tepinya, sehingga menyatu
/// dengan latar tanpa garis potong. Dipakai di splash dan halaman pairing.
class FadedBusPhoto extends StatelessWidget {
  /// Sisi foto yang memudar (atas saat portrait, kiri saat landscape).
  final Alignment fadeFrom;

  /// Ikut memudarkan sisi seberang; tidak dipakai bila foto menempel ke tepi
  /// layar.
  final bool fadeOppositeEdge;

  /// Bagian foto yang diutamakan saat foto terpotong (BoxFit.cover).
  final Alignment alignment;

  const FadedBusPhoto({
    super.key,
    required this.fadeFrom,
    this.fadeOppositeEdge = true,
    this.alignment = const Alignment(-0.15, 0.1),
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: fadeFrom,
        end: -fadeFrom,
        colors: [
          Colors.transparent,
          Colors.black,
          Colors.black,
          fadeOppositeEdge ? Colors.transparent : Colors.black,
        ],
        stops: const [0.0, 0.2, 0.86, 1.0],
      ).createShader(rect),
      child: Image.asset(
        'assets/images/splash_bus.jpg',
        fit: BoxFit.cover,
        alignment: alignment,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }
}
