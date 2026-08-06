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
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Hoja larga (~70% de la altura): punta arriba, base en la guarda.
    final hoja = Path()
      ..moveTo(w * 0.50, h * 0.02)
      ..lineTo(w * 0.58, h * 0.58)
      ..lineTo(w * 0.50, h * 0.66)
      ..lineTo(w * 0.42, h * 0.58)
      ..close();
    canvas.drawPath(hoja, stroke);

    // Filo / línea central.
    canvas.drawLine(
      Offset(w * 0.50, h * 0.08),
      Offset(w * 0.50, h * 0.64),
      stroke,
    );

    // Guarda (cruz) más abajo.
    canvas.drawLine(
      Offset(w * 0.18, h * 0.66),
      Offset(w * 0.82, h * 0.66),
      stroke,
    );
    canvas.drawLine(
      Offset(w * 0.18, h * 0.66),
      Offset(w * 0.14, h * 0.60),
      stroke,
    );
    canvas.drawLine(
      Offset(w * 0.82, h * 0.66),
      Offset(w * 0.86, h * 0.60),
      stroke,
    );

    // Empuñadura corta.
    canvas.drawLine(
      Offset(w * 0.50, h * 0.66),
      Offset(w * 0.50, h * 0.86),
      stroke,
    );

    // Pomo.
    canvas.drawCircle(Offset(w * 0.50, h * 0.92), w * 0.065, stroke);
  }

  @override
  bool shouldRepaint(covariant _EspadaOutlinedPainter oldDelegate) =>
      oldDelegate.color != color;
}
