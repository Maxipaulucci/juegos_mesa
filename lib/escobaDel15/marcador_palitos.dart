import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Palitos de anotación estilo truco / escoba (grupos de 5).
/// 1=|, 2=┌, 3=⊓ abiertos, 4=□, 5=□ con diagonal.
class MarcadorPalitosEscoba extends StatelessWidget {
  const MarcadorPalitosEscoba({
    super.key,
    required this.puntos,
    this.color = AppColors.acento,
    this.tamanoGrupo = 28,
  });

  final int puntos;
  final Color color;
  final double tamanoGrupo;

  @override
  Widget build(BuildContext context) {
    final n = puntos.clamp(0, 99);
    if (n == 0) {
      return Text(
        '0',
        style: TextStyle(
          color: color.withValues(alpha: 0.7),
          fontWeight: FontWeight.w800,
          fontSize: tamanoGrupo * 0.55,
        ),
      );
    }
    final completos = n ~/ 5;
    final resto = n % 5;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < completos; i++)
          _GrupoPalitos(valor: 5, color: color, size: tamanoGrupo),
        if (resto > 0)
          _GrupoPalitos(valor: resto, color: color, size: tamanoGrupo),
      ],
    );
  }
}

class _GrupoPalitos extends StatelessWidget {
  const _GrupoPalitos({
    required this.valor,
    required this.color,
    required this.size,
  });

  final int valor;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PalitosPainter(valor: valor, color: color),
      ),
    );
  }
}

class _PalitosPainter extends CustomPainter {
  _PalitosPainter({required this.valor, required this.color});

  final int valor;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = mathMax(2.0, size.shortestSide * 0.1)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final pad = size.shortestSide * 0.18;
    final left = pad;
    final right = size.width - pad;
    final top = pad;
    final bottom = size.height - pad;

    // 1: lado izquierdo
    if (valor >= 1) {
      canvas.drawLine(Offset(left, top), Offset(left, bottom), paint);
    }
    // 2: lado superior
    if (valor >= 2) {
      canvas.drawLine(Offset(left, top), Offset(right, top), paint);
    }
    // 3: lado derecho
    if (valor >= 3) {
      canvas.drawLine(Offset(right, top), Offset(right, bottom), paint);
    }
    // 4: lado inferior → cuadrado
    if (valor >= 4) {
      canvas.drawLine(Offset(left, bottom), Offset(right, bottom), paint);
    }
    // 5: diagonal
    if (valor >= 5) {
      canvas.drawLine(Offset(left, top), Offset(right, bottom), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PalitosPainter oldDelegate) =>
      oldDelegate.valor != valor || oldDelegate.color != color;
}

double mathMax(double a, double b) => a > b ? a : b;
