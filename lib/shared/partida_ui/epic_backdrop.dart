import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Fondo épico: rayos láser diagonales + destellos + resplandor central.
class EpicBackdrop extends StatelessWidget {
  const EpicBackdrop({
    super.key,
    /// Fracción vertical del origen de los rayos (0 = arriba, 1 = abajo).
    this.centerY = 0.30,
    /// Si true, los rayos se desvanecen hacia el centro (más limpio para jugabilidad).
    this.fadeRayosAlCentro = false,
  });

  final double centerY;
  final bool fadeRayosAlCentro;

  @override
  Widget build(BuildContext context) {
    // Alignment.y: -1 arriba, 1 abajo → misma posición que [centerY].
    final alignmentY = (centerY * 2) - 1;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, alignmentY),
          radius: 1.25,
          colors: const [
            Color(0xFF321A5E),
            Color(0xFF1B0D38),
            Color(0xFF0A0418),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: LasersPainter(
          centerY: centerY,
          fadeAlCentro: fadeRayosAlCentro,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class LasersPainter extends CustomPainter {
  LasersPainter({
    this.centerY = 0.30,
    this.fadeAlCentro = false,
  });

  final double centerY;
  final bool fadeAlCentro;

  static const _colores = [
    AppColors.acento,
    AppColors.azul,
    AppColors.rosa,
    AppColors.violeta,
    AppColors.mint,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height * centerY);
    final rng = math.Random(11);

    // Rayos láser en línea recta a través del centro.
    final largoMin = size.longestSide * 1.15;
    final nRayos = fadeAlCentro ? 18 : 22;
    for (var i = 0; i < nRayos; i++) {
      final angulo = rng.nextDouble() * math.pi * 2;
      final largo = largoMin + rng.nextDouble() * size.longestSide * 0.35;
      final color = _colores[i % _colores.length];
      final ancho = fadeAlCentro
          ? (1.0 + rng.nextDouble() * 2.0)
          : (1.2 + rng.nextDouble() * 2.6);

      final fin = Offset(
        centro.dx + math.cos(angulo) * largo,
        centro.dy + math.sin(angulo) * largo,
      );
      final inicio = Offset(
        centro.dx - math.cos(angulo) * largo,
        centro.dy - math.sin(angulo) * largo,
      );

      final paint = Paint()
        ..shader = LinearGradient(
          colors: fadeAlCentro
              ? [
                  // Borde de pantalla: brillo normal.
                  color.withValues(alpha: 0.42),
                  color.withValues(alpha: 0.28),
                  // Se apaga al acercarse al centro.
                  color.withValues(alpha: 0.06),
                  color.withValues(alpha: 0.0),
                  color.withValues(alpha: 0.06),
                  color.withValues(alpha: 0.28),
                  // Otro borde: vuelve a brillo normal.
                  color.withValues(alpha: 0.42),
                ]
              : [
                  color.withValues(alpha: 0.0),
                  color.withValues(alpha: 0.45),
                  color.withValues(alpha: 0.0),
                ],
          stops: fadeAlCentro
              ? const [0.0, 0.16, 0.34, 0.5, 0.66, 0.84, 1.0]
              : const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromPoints(inicio, fin))
        ..strokeWidth = ancho
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(inicio, fin, paint);
    }

    // Destellos / partículas brillantes
    final nParticulas = fadeAlCentro ? 40 : 70;
    for (var i = 0; i < nParticulas; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      // En modo fade, menos brillo cerca del centro de juego.
      if (fadeAlCentro) {
        final dx = (x - centro.dx) / size.width;
        final dy = (y - centro.dy) / size.height;
        if (dx * dx + dy * dy < 0.045) continue;
      }
      final r = 0.6 + rng.nextDouble() * 2.2;
      final color = _colores[i % _colores.length];
      final alphaBase = fadeAlCentro ? 0.12 : 0.25;
      final alphaExtra = fadeAlCentro ? 0.22 : 0.45;
      final paint = Paint()
        ..color = color.withValues(alpha: alphaBase + rng.nextDouble() * alphaExtra);
      canvas.drawCircle(Offset(x, y), r, paint);

      if (i % 6 == 0) {
        final linea = Paint()
          ..color = color.withValues(alpha: fadeAlCentro ? 0.28 : 0.5)
          ..strokeWidth = 0.8;
        canvas.drawLine(Offset(x - r * 3, y), Offset(x + r * 3, y), linea);
        canvas.drawLine(Offset(x, y - r * 3), Offset(x, y + r * 3), linea);
      }
    }
  }

  @override
  bool shouldRepaint(covariant LasersPainter oldDelegate) =>
      oldDelegate.centerY != centerY ||
      oldDelegate.fadeAlCentro != fadeAlCentro;
}
