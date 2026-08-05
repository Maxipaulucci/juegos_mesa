import 'package:flutter/material.dart';

/// Espada outlined, mismo lenguaje visual que los íconos Material outlined.
class IconoEspadaOutlined extends StatelessWidget {
  const IconoEspadaOutlined({
    super.key,
    this.size = 24,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Colors.white;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _EspadaOutlinedPainter(color: c),
      ),
    );
  }
}

class _EspadaOutlinedPainter extends CustomPainter {
  _EspadaOutlinedPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Hoja (rombo alargado / punta arriba).
    final hoja = Path()
      ..moveTo(w * 0.50, h * 0.06)
      ..lineTo(w * 0.62, h * 0.42)
      ..lineTo(w * 0.50, h * 0.55)
      ..lineTo(w * 0.38, h * 0.42)
      ..close();
    canvas.drawPath(hoja, stroke);

    // Línea central de la hoja.
    canvas.drawLine(
      Offset(w * 0.50, h * 0.12),
      Offset(w * 0.50, h * 0.52),
      stroke,
    );

    // Guarda (cruz).
    canvas.drawLine(
      Offset(w * 0.22, h * 0.55),
      Offset(w * 0.78, h * 0.55),
      stroke,
    );
    canvas.drawLine(
      Offset(w * 0.22, h * 0.55),
      Offset(w * 0.18, h * 0.48),
      stroke,
    );
    canvas.drawLine(
      Offset(w * 0.78, h * 0.55),
      Offset(w * 0.82, h * 0.48),
      stroke,
    );

    // Empuñadura.
    canvas.drawLine(
      Offset(w * 0.50, h * 0.55),
      Offset(w * 0.50, h * 0.82),
      stroke,
    );

    // Pomo.
    canvas.drawCircle(Offset(w * 0.50, h * 0.88), w * 0.07, stroke);
  }

  @override
  bool shouldRepaint(covariant _EspadaOutlinedPainter oldDelegate) =>
      oldDelegate.color != color;
}
