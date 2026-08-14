import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Botón circular para ciclar el orden de la mano (cartas + flechas).
///
/// Pensado para ir **fuera** del contenedor de la mano (p. ej. arriba a la
/// derecha). La lógica de ordenamiento está en [ordenar_mano_cartas.dart].
class BotonOrdenarMano extends StatelessWidget {
  const BotonOrdenarMano({
    super.key,
    required this.onPressed,
    this.size = 40,
    this.tooltip = 'Ordenar mano',
    this.color,
  });

  final VoidCallback? onPressed;
  final double size;
  final String tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.rosa;
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: CustomPaint(
              size: Size.square(size),
              painter: _IconoOrdenarManoPainter(color: c),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dibuja el icono: círculo, dos cartas y flechas curvas de ciclo.
class _IconoOrdenarManoPainter extends CustomPainter {
  _IconoOrdenarManoPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, s * 0.055)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glow = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke.strokeWidth + 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final c = Offset(size.width / 2, size.height / 2);
    final r = s * 0.46;

    // Círculo exterior.
    canvas.drawCircle(c, r, glow);
    canvas.drawCircle(c, r, stroke);

    // Dos cartas inclinadas al centro.
    _dibujarCarta(
      canvas,
      center: c + Offset(-s * 0.07, s * 0.02),
      width: s * 0.22,
      height: s * 0.32,
      angle: -0.28,
      paint: stroke,
    );
    _dibujarCarta(
      canvas,
      center: c + Offset(s * 0.08, -s * 0.01),
      width: s * 0.22,
      height: s * 0.32,
      angle: 0.28,
      paint: stroke,
    );

    // Flecha izquierda (curva hacia abajo).
    _dibujarFlechaCurva(
      canvas,
      paint: stroke,
      center: c,
      radio: s * 0.34,
      startAngle: math.pi * 0.55,
      sweep: math.pi * 0.55,
      puntaAlFinal: true,
    );
    // Flecha derecha (curva hacia arriba).
    _dibujarFlechaCurva(
      canvas,
      paint: stroke,
      center: c,
      radio: s * 0.34,
      startAngle: -math.pi * 0.45,
      sweep: math.pi * 0.55,
      puntaAlFinal: true,
    );
  }

  void _dibujarCarta(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
    required double angle,
    required Paint paint,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: width, height: height),
      Radius.circular(width * 0.14),
    );
    canvas.drawRRect(rect, paint);
    // Línea interior (detalle de carta).
    final inner = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: width * 0.55,
        height: height * 0.55,
      ),
      Radius.circular(width * 0.08),
    );
    canvas.drawRRect(inner, paint);
    canvas.restore();
  }

  void _dibujarFlechaCurva(
    Canvas canvas, {
    required Paint paint,
    required Offset center,
    required double radio,
    required double startAngle,
    required double sweep,
    required bool puntaAlFinal,
  }) {
    final path = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: radio),
        startAngle,
        sweep,
      );
    canvas.drawPath(path, paint);

    final angPunta = puntaAlFinal ? startAngle + sweep : startAngle;
    final tip = Offset(
      center.dx + radio * math.cos(angPunta),
      center.dy + radio * math.sin(angPunta),
    );
    // Tangente al arco: perpendicular al radio.
    final tangente = angPunta + (sweep >= 0 ? math.pi / 2 : -math.pi / 2);
    final dir = Offset(math.cos(tangente), math.sin(tangente));
    final normal = Offset(-dir.dy, dir.dx);
    final len = radio * 0.22;
    final p1 = tip - dir * len + normal * (len * 0.55);
    final p2 = tip - dir * len - normal * (len * 0.55);
    final flecha = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(p2.dx, p2.dy);
    canvas.drawPath(flecha, paint);
  }

  @override
  bool shouldRepaint(covariant _IconoOrdenarManoPainter oldDelegate) =>
      oldDelegate.color != color;
}
