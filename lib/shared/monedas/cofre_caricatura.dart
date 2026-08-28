import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';

enum CofreCaricaturaTipo { madera, oro }

/// Cofre caricaturesco con estilo arcade/neón de la app (sin imágenes externas).
class CofreCaricatura extends StatelessWidget {
  const CofreCaricatura({
    super.key,
    required this.tipo,
    this.abierto = false,
    this.size = 48,
  });

  final CofreCaricaturaTipo tipo;
  final bool abierto;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.92,
      child: CustomPaint(
        painter: _CofreCaricaturaPainter(
          tipo: tipo,
          abierto: abierto,
        ),
      ),
    );
  }
}

class _CofreCaricaturaPainter extends CustomPainter {
  _CofreCaricaturaPainter({
    required this.tipo,
    required this.abierto,
  });

  final CofreCaricaturaTipo tipo;
  final bool abierto;

  static const _outline = Color(0xFF1A0A2E);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final cx = w / 2;
    final esOro = tipo == CofreCaricaturaTipo.oro;

    if (abierto) {
      _dibujarTapaAbierta(canvas, size, esOro);
      _dibujarCuerpo(canvas, size, esOro, conMonedas: true);
      _dibujarMonedas(canvas, size, esOro);
      _dibujarBrillos(canvas, size, esOro);
    } else {
      _dibujarCuerpo(canvas, size, esOro, conMonedas: false);
      _dibujarTapaCerrada(canvas, size, esOro);
      _dibujarCerradura(canvas, size, esOro);
      if (esOro) _dibujarBrillos(canvas, size, true);
    }

    _dibujarOjos(canvas, size, cx);
  }

  void _dibujarCuerpo(
    Canvas canvas,
    Size size,
    bool esOro, {
    required bool conMonedas,
  }) {
    final w = size.width;
    final h = size.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.38, w * 0.76, h * 0.5),
      const Radius.circular(8),
    );

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: esOro
            ? [const Color(0xFFFFE082), const Color(0xFFFFB300)]
            : [const Color(0xFFBC8A5A), const Color(0xFF8B5E3C)],
      ).createShader(body.outerRect);

    canvas.drawRRect(body, fill);
    canvas.drawRRect(
      body,
      Paint()
        ..color = _outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05,
    );

    final bandColor = esOro ? AppColors.violeta : AppColors.acentoSuave;
    for (final y in [0.48, 0.62, 0.76]) {
      final bandY = h * y;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.1, bandY, w * 0.8, h * 0.07),
          const Radius.circular(3),
        ),
        Paint()..color = bandColor,
      );
      for (final rx in [0.22, 0.5, 0.78]) {
        canvas.drawCircle(
          Offset(w * rx, bandY + h * 0.035),
          w * 0.028,
          Paint()..color = esOro ? AppColors.acento : const Color(0xFF5D3A1A),
        );
      }
    }

    if (conMonedas) {
      final interior = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.16, h * 0.42, w * 0.68, h * 0.2),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        interior,
        Paint()..color = const Color(0xFF3E2723).withValues(alpha: 0.55),
      );
    }
  }

  void _dibujarTapaCerrada(Canvas canvas, Size size, bool esOro) {
    final w = size.width;
    final h = size.height;
    final lid = Path()
      ..moveTo(w * 0.1, h * 0.42)
      ..quadraticBezierTo(w * 0.5, h * 0.08, w * 0.9, h * 0.42)
      ..lineTo(w * 0.88, h * 0.48)
      ..quadraticBezierTo(w * 0.5, h * 0.16, w * 0.12, h * 0.48)
      ..close();

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: esOro
            ? [const Color(0xFFFFF59D), const Color(0xFFFFCA28)]
            : [const Color(0xFFD4A574), const Color(0xFFA67C52)],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.5));

    canvas.drawPath(lid, fill);
    canvas.drawPath(
      lid,
      Paint()
        ..color = _outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _dibujarTapaAbierta(Canvas canvas, Size size, bool esOro) {
    final w = size.width;
    final h = size.height;
    canvas.save();
    canvas.translate(w * 0.18, h * 0.34);
    canvas.rotate(-0.55);

    final lid = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w * 0.64, h * 0.22),
      const Radius.circular(10),
    );
    final fill = Paint()
      ..shader = LinearGradient(
        colors: esOro
            ? [const Color(0xFFFFF59D), const Color(0xFFFFCA28)]
            : [const Color(0xFFD4A574), const Color(0xFFA67C52)],
      ).createShader(lid.outerRect);

    canvas.drawRRect(lid, fill);
    canvas.drawRRect(
      lid,
      Paint()
        ..color = _outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045,
    );
    canvas.restore();
  }

  void _dibujarCerradura(Canvas canvas, Size size, bool esOro) {
    final w = size.width;
    final h = size.height;
    final lock = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.58),
        width: w * 0.22,
        height: h * 0.16,
      ),
      const Radius.circular(5),
    );

    canvas.drawRRect(
      lock,
      Paint()..color = esOro ? AppColors.violeta : AppColors.acento,
    );
    canvas.drawRRect(
      lock,
      Paint()
        ..color = _outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035,
    );

    final keyhole = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.555),
        width: w * 0.06,
        height: w * 0.07,
      ))
      ..moveTo(w * 0.5, h * 0.59)
      ..lineTo(w * 0.5, h * 0.64)
      ..lineTo(w * 0.46, h * 0.64);

    canvas.drawPath(
      keyhole,
      Paint()
        ..color = _outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.03
        ..strokeCap = StrokeCap.round,
    );
  }

  void _dibujarMonedas(Canvas canvas, Size size, bool esOro) {
    final w = size.width;
    final h = size.height;
    final rng = math.Random(esOro ? 7 : 3);
    final baseY = h * 0.56;

    for (var i = 0; i < (esOro ? 7 : 5); i++) {
      final x = w * (0.22 + rng.nextDouble() * 0.56);
      final y = baseY + rng.nextDouble() * h * 0.12;
      final r = w * (0.055 + rng.nextDouble() * 0.025);

      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFFFFF8E1), AppColors.acento],
          ).createShader(Rect.fromCircle(center: Offset(x, y), radius: r)),
      );
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = _outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.02,
      );
    }
  }

  void _dibujarBrillos(Canvas canvas, Size size, bool esOro) {
    final w = size.width;
    final h = size.height;
    final color = esOro ? AppColors.acento : AppColors.azul;

    void estrella(Offset c, double s) {
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final a = i * math.pi / 2;
        path.moveTo(c.dx, c.dy);
        path.lineTo(c.dx + math.cos(a) * s, c.dy + math.sin(a) * s);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.04
          ..strokeCap = StrokeCap.round,
      );
    }

    estrella(Offset(w * 0.82, h * 0.14), w * 0.07);
    estrella(Offset(w * 0.18, h * 0.2), w * 0.05);
    if (esOro) estrella(Offset(w * 0.5, h * 0.06), w * 0.06);
  }

  void _dibujarOjos(Canvas canvas, Size size, double cx) {
    final w = size.width;
    final h = size.height;
    final eyeY = h * (abierto ? 0.5 : 0.52);

    for (final dx in [-0.1, 0.1]) {
      final center = Offset(cx + w * dx, eyeY);
      canvas.drawCircle(center, w * 0.045, Paint()..color = Colors.white);
      canvas.drawCircle(
        center + Offset(w * 0.012, 0),
        w * 0.02,
        Paint()..color = _outline,
      );
      canvas.drawCircle(
        center,
        w * 0.048,
        Paint()
          ..color = _outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.02,
      );
    }

    final smile = Path()
      ..moveTo(cx - w * 0.1, h * (abierto ? 0.62 : 0.6))
      ..quadraticBezierTo(
        cx,
        h * (abierto ? 0.68 : 0.66),
        cx + w * 0.1,
        h * (abierto ? 0.62 : 0.6),
      );
    canvas.drawPath(
      smile,
      Paint()
        ..color = _outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.028
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CofreCaricaturaPainter oldDelegate) {
    return oldDelegate.tipo != tipo || oldDelegate.abierto != abierto;
  }
}
