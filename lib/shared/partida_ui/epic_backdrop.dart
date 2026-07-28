import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Fondo épico: rayos láser diagonales + destellos + resplandor central.
class EpicBackdrop extends StatelessWidget {
  const EpicBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.25),
          radius: 1.25,
          colors: [
            Color(0xFF321A5E),
            Color(0xFF1B0D38),
            Color(0xFF0A0418),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: LasersPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class LasersPainter extends CustomPainter {
  static const _colores = [
    AppColors.acento,
    AppColors.azul,
    AppColors.rosa,
    AppColors.violeta,
    AppColors.mint,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height * 0.30);
    final rng = math.Random(11);

    // Rayos láser que salen del centro hacia afuera (siempre más allá del borde).
    final largoMin = size.longestSide * 1.15;
    for (var i = 0; i < 22; i++) {
      final angulo = rng.nextDouble() * math.pi * 2;
      final largo = largoMin + rng.nextDouble() * size.longestSide * 0.35;
      final color = _colores[i % _colores.length];
      final ancho = 1.2 + rng.nextDouble() * 2.6;

      final fin = Offset(
        centro.dx + math.cos(angulo) * largo,
        centro.dy + math.sin(angulo) * largo,
      );
      final inicio = Offset(
        centro.dx + math.cos(angulo) * 30,
        centro.dy + math.sin(angulo) * 30,
      );

      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: 0.5),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromPoints(inicio, fin))
        ..strokeWidth = ancho
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(inicio, fin, paint);
    }

    // Destellos / partículas brillantes
    for (var i = 0; i < 70; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 0.6 + rng.nextDouble() * 2.2;
      final color = _colores[i % _colores.length];
      final paint = Paint()
        ..color = color.withValues(alpha: 0.25 + rng.nextDouble() * 0.45);
      canvas.drawCircle(Offset(x, y), r, paint);

      if (i % 6 == 0) {
        final linea = Paint()
          ..color = color.withValues(alpha: 0.5)
          ..strokeWidth = 0.8;
        canvas.drawLine(Offset(x - r * 3, y), Offset(x + r * 3, y), linea);
        canvas.drawLine(Offset(x, y - r * 3), Offset(x, y + r * 3), linea);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
