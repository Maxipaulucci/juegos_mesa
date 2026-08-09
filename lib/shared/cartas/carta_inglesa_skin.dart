import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Palos del mazo inglés (visual).
enum PaloInglesVisual { corazones, diamantes, treboles, picas }

Color colorPaloIngles(PaloInglesVisual palo) => switch (palo) {
      PaloInglesVisual.corazones || PaloInglesVisual.diamantes =>
        const Color(0xFFE53935),
      PaloInglesVisual.treboles || PaloInglesVisual.picas =>
        const Color(0xFF111111),
    };

String simboloPaloIngles(PaloInglesVisual palo) => switch (palo) {
      PaloInglesVisual.corazones => '♥',
      PaloInglesVisual.diamantes => '♦',
      PaloInglesVisual.treboles => '♣',
      PaloInglesVisual.picas => '♠',
    };

int? rangoDesdeEtiquetaInglesa(String etiqueta) => switch (etiqueta) {
      'A' || 'a' => 1,
      'J' || 'j' => 11,
      'Q' || 'q' => 12,
      'K' || 'k' => 13,
      _ => int.tryParse(etiqueta),
    };

/// Skin de carta inglesa al estilo mazo estándar (índices + pips).
class CartaInglesaSkin extends StatelessWidget {
  const CartaInglesaSkin({
    super.key,
    required this.etiquetaValor,
    required this.palo,
    this.bocaArriba = true,
    this.width = 68,
    this.height = 102,
    this.seleccionada = false,
  });

  final String etiquetaValor;
  final PaloInglesVisual palo;
  final bool bocaArriba;
  final double width;
  final double height;
  final bool seleccionada;

  @override
  Widget build(BuildContext context) {
    final radio = math.min(width, height) * 0.12;
    if (!bocaArriba) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radio),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3B1D6E),
              Color(0xFF1A0A33),
              Color(0xFF5C2DB2),
            ],
          ),
          border: Border.all(
            color: AppColors.violeta.withValues(alpha: 0.9),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.style_outlined,
            color: AppColors.acento.withValues(alpha: 0.85),
            size: width * 0.42,
          ),
        ),
      );
    }

    final color = colorPaloIngles(palo);
    final rango = rangoDesdeEtiquetaInglesa(etiquetaValor) ?? 1;
    final esFigura = rango >= 11;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(
          color: seleccionada
              ? AppColors.acento
              : const Color(0xFF9E9E9E),
          width: seleccionada ? 2.2 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radio - 0.5),
        child: Stack(
          children: [
            // Índice superior izquierdo (estilo mazo estándar).
            Positioned(
              left: width * 0.045,
              top: height * 0.028,
              child: _IndiceEsquina(
                etiqueta: etiquetaValor,
                palo: palo,
                color: color,
                width: width,
              ),
            ),
            // Índice inferior derecho, invertido.
            Positioned(
              right: width * 0.045,
              bottom: height * 0.028,
              child: Transform.rotate(
                angle: math.pi,
                child: _IndiceEsquina(
                  etiqueta: etiquetaValor,
                  palo: palo,
                  color: color,
                  width: width,
                ),
              ),
            ),
            // Zona central de pips / figura.
            Positioned(
              left: width * 0.18,
              right: width * 0.18,
              top: height * 0.12,
              bottom: height * 0.12,
              child: esFigura
                  ? _CartaFigura(
                      etiqueta: etiquetaValor,
                      palo: palo,
                      color: color,
                    )
                  : _ZonaPips(
                      rango: rango,
                      palo: palo,
                      color: color,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IndiceEsquina extends StatelessWidget {
  const _IndiceEsquina({
    required this.etiqueta,
    required this.palo,
    required this.color,
    required this.width,
  });

  final String etiqueta;
  final PaloInglesVisual palo;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    final fontSize = width * (etiqueta.length > 1 ? 0.20 : 0.24);
    final pipSize = width * 0.16;
    return SizedBox(
      width: width * 0.22,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            etiqueta,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              height: 1,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: width * 0.01),
          SizedBox(
            width: pipSize,
            height: pipSize,
            child: CustomPaint(
              painter: _PaloPainter(palo: palo, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _PipPos {
  const _PipPos(this.x, this.y, {this.invertido = false, this.grande = false});

  /// Coordenadas 0–1 dentro de la zona de pips.
  final double x;
  final double y;
  final bool invertido;
  final bool grande;
}

/// Posiciones exactas del mazo inglés estándar.
List<_PipPos> _pipsDeRango(int rango) {
  const l = 0.22;
  const c = 0.50;
  const r = 0.78;
  // Filas de 3 (2, 3, 4, 5, 6, 7, 8)
  const t3 = 0.10;
  const m3 = 0.50;
  const b3 = 0.90;
  // Extra 7 / 8
  const u78 = 0.30;
  const d78 = 0.70;
  // Filas de 4 (9, 10)
  const t4 = 0.08;
  const tm4 = 0.34;
  const bm4 = 0.66;
  const b4 = 0.92;
  // Extra 10
  const u10 = 0.21;
  const d10 = 0.79;

  switch (rango) {
    case 1:
      return const [_PipPos(c, 0.50, grande: true)];
    case 2:
      return const [
        _PipPos(c, t3),
        _PipPos(c, b3, invertido: true),
      ];
    case 3:
      return const [
        _PipPos(c, t3),
        _PipPos(c, m3),
        _PipPos(c, b3, invertido: true),
      ];
    case 4:
      return const [
        _PipPos(l, t3),
        _PipPos(r, t3),
        _PipPos(l, b3, invertido: true),
        _PipPos(r, b3, invertido: true),
      ];
    case 5:
      return const [
        _PipPos(l, t3),
        _PipPos(r, t3),
        _PipPos(c, m3),
        _PipPos(l, b3, invertido: true),
        _PipPos(r, b3, invertido: true),
      ];
    case 6:
      return const [
        _PipPos(l, t3),
        _PipPos(r, t3),
        _PipPos(l, m3),
        _PipPos(r, m3),
        _PipPos(l, b3, invertido: true),
        _PipPos(r, b3, invertido: true),
      ];
    case 7:
      return const [
        _PipPos(l, t3),
        _PipPos(r, t3),
        _PipPos(c, u78),
        _PipPos(l, m3),
        _PipPos(r, m3),
        _PipPos(l, b3, invertido: true),
        _PipPos(r, b3, invertido: true),
      ];
    case 8:
      return const [
        _PipPos(l, t3),
        _PipPos(r, t3),
        _PipPos(c, u78),
        _PipPos(l, m3),
        _PipPos(r, m3),
        _PipPos(c, d78, invertido: true),
        _PipPos(l, b3, invertido: true),
        _PipPos(r, b3, invertido: true),
      ];
    case 9:
      return const [
        _PipPos(l, t4),
        _PipPos(r, t4),
        _PipPos(l, tm4),
        _PipPos(r, tm4),
        _PipPos(c, 0.50),
        _PipPos(l, bm4, invertido: true),
        _PipPos(r, bm4, invertido: true),
        _PipPos(l, b4, invertido: true),
        _PipPos(r, b4, invertido: true),
      ];
    case 10:
      return const [
        _PipPos(l, t4),
        _PipPos(r, t4),
        _PipPos(c, u10),
        _PipPos(l, tm4),
        _PipPos(r, tm4),
        _PipPos(l, bm4, invertido: true),
        _PipPos(r, bm4, invertido: true),
        _PipPos(c, d10, invertido: true),
        _PipPos(l, b4, invertido: true),
        _PipPos(r, b4, invertido: true),
      ];
    default:
      return const [_PipPos(c, 0.50, grande: true)];
  }
}

class _ZonaPips extends StatelessWidget {
  const _ZonaPips({
    required this.rango,
    required this.palo,
    required this.color,
  });

  final int rango;
  final PaloInglesVisual palo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pips = _pipsDeRango(rango);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final pipBase = math.min(w, h) * (rango == 1 ? 0.55 : 0.28);
        return Stack(
          children: [
            for (final p in pips)
              Positioned(
                left: p.x * w - pipBase * (p.grande ? 1.15 : 1) / 2,
                top: p.y * h - pipBase * (p.grande ? 1.15 : 1) / 2,
                width: pipBase * (p.grande ? 1.15 : 1),
                height: pipBase * (p.grande ? 1.15 : 1),
                child: Transform.rotate(
                  angle: p.invertido ? math.pi : 0,
                  child: CustomPaint(
                    painter: _PaloPainter(palo: palo, color: color),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Figura estilizada (doble cabeza) cuando no hay arte de corte.
class _CartaFigura extends StatelessWidget {
  const _CartaFigura({
    required this.etiqueta,
    required this.palo,
    required this.color,
  });

  final String etiqueta;
  final PaloInglesVisual palo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF5C4033), width: 1.2),
        borderRadius: BorderRadius.circular(3),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF4E0),
            Color(0xFFE8D4B0),
            Color(0xFFFFF4E0),
          ],
        ),
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              heightFactor: 0.5,
              widthFactor: 1,
              child: _MitadFigura(
                etiqueta: etiqueta,
                palo: palo,
                color: color,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.5,
              widthFactor: 1,
              child: Transform.rotate(
                angle: math.pi,
                child: _MitadFigura(
                  etiqueta: etiqueta,
                  palo: palo,
                  color: color,
                ),
              ),
            ),
          ),
          const Center(
            child: Divider(
              color: Color(0xFF5C4033),
              thickness: 0.8,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MitadFigura extends StatelessWidget {
  const _MitadFigura({
    required this.etiqueta,
    required this.palo,
    required this.color,
  });

  final String etiqueta;
  final PaloInglesVisual palo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final s = math.min(c.maxWidth, c.maxHeight);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              etiqueta,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: s * 0.42,
                height: 1,
              ),
            ),
            SizedBox(height: s * 0.04),
            SizedBox(
              width: s * 0.36,
              height: s * 0.36,
              child: CustomPaint(
                painter: _PaloPainter(palo: palo, color: color),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PaloPainter extends CustomPainter {
  const _PaloPainter({required this.palo, required this.color});

  final PaloInglesVisual palo;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = math.min(size.width, size.height);

    switch (palo) {
      case PaloInglesVisual.corazones:
        _heart(canvas, paint, cx, cy, s);
      case PaloInglesVisual.diamantes:
        _diamond(canvas, paint, cx, cy, s);
      case PaloInglesVisual.treboles:
        _club(canvas, paint, cx, cy, s);
      case PaloInglesVisual.picas:
        _spade(canvas, paint, cx, cy, s);
    }
  }

  void _heart(Canvas canvas, Paint paint, double cx, double cy, double s) {
    final path = Path();
    final w = s * 0.92;
    final h = s * 0.88;
    final top = cy - h * 0.42;
    path.moveTo(cx, top + h * 0.28);
    path.cubicTo(
      cx - w * 0.08,
      top,
      cx - w * 0.52,
      top,
      cx - w * 0.52,
      top + h * 0.32,
    );
    path.cubicTo(
      cx - w * 0.52,
      top + h * 0.55,
      cx,
      top + h * 0.78,
      cx,
      top + h,
    );
    path.cubicTo(
      cx,
      top + h * 0.78,
      cx + w * 0.52,
      top + h * 0.55,
      cx + w * 0.52,
      top + h * 0.32,
    );
    path.cubicTo(
      cx + w * 0.52,
      top,
      cx + w * 0.08,
      top,
      cx,
      top + h * 0.28,
    );
    path.close();
    canvas.drawPath(path, paint);
  }

  void _diamond(Canvas canvas, Paint paint, double cx, double cy, double s) {
    final path = Path()
      ..moveTo(cx, cy - s * 0.46)
      ..lineTo(cx + s * 0.34, cy)
      ..lineTo(cx, cy + s * 0.46)
      ..lineTo(cx - s * 0.34, cy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _spade(Canvas canvas, Paint paint, double cx, double cy, double s) {
    final path = Path();
    final tipY = cy - s * 0.46;
    path.moveTo(cx, tipY);
    path.cubicTo(
      cx + s * 0.05,
      tipY + s * 0.18,
      cx + s * 0.48,
      tipY + s * 0.38,
      cx + s * 0.48,
      tipY + s * 0.58,
    );
    path.cubicTo(
      cx + s * 0.48,
      tipY + s * 0.78,
      cx + s * 0.18,
      tipY + s * 0.82,
      cx,
      tipY + s * 0.68,
    );
    path.cubicTo(
      cx - s * 0.18,
      tipY + s * 0.82,
      cx - s * 0.48,
      tipY + s * 0.78,
      cx - s * 0.48,
      tipY + s * 0.58,
    );
    path.cubicTo(
      cx - s * 0.48,
      tipY + s * 0.38,
      cx - s * 0.05,
      tipY + s * 0.18,
      cx,
      tipY,
    );
    path.close();
    canvas.drawPath(path, paint);
    // Tallo
    final stem = Path()
      ..moveTo(cx - s * 0.07, cy + s * 0.12)
      ..lineTo(cx + s * 0.07, cy + s * 0.12)
      ..lineTo(cx + s * 0.12, cy + s * 0.46)
      ..lineTo(cx - s * 0.12, cy + s * 0.46)
      ..close();
    canvas.drawPath(stem, paint);
  }

  void _club(Canvas canvas, Paint paint, double cx, double cy, double s) {
    final r = s * 0.22;
    canvas.drawCircle(Offset(cx, cy - s * 0.22), r, paint);
    canvas.drawCircle(Offset(cx - s * 0.22, cy + s * 0.02), r, paint);
    canvas.drawCircle(Offset(cx + s * 0.22, cy + s * 0.02), r, paint);
    // Centro de unión
    canvas.drawCircle(Offset(cx, cy - s * 0.02), r * 0.55, paint);
    final stem = Path()
      ..moveTo(cx - s * 0.07, cy + s * 0.08)
      ..lineTo(cx + s * 0.07, cy + s * 0.08)
      ..lineTo(cx + s * 0.12, cy + s * 0.46)
      ..lineTo(cx - s * 0.12, cy + s * 0.46)
      ..close();
    canvas.drawPath(stem, paint);
  }

  @override
  bool shouldRepaint(covariant _PaloPainter oldDelegate) =>
      oldDelegate.palo != palo || oldDelegate.color != color;
}
