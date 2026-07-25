import 'package:flutter/material.dart';

/// Dado tradicional con puntos (1–6), estilo mockup.
class DadoFace extends StatelessWidget {
  const DadoFace({
    super.key,
    required this.valor,
    this.suma = false,
    this.tamano = 58,
    this.vacio = false,
  });

  final int valor;
  final bool suma;
  final double tamano;
  final bool vacio;

  static const _dorado = Color(0xFFF5C518);
  static const _blanco = Color(0xFFF4F1EA);
  static const _punto = Color(0xFF141414);

  @override
  Widget build(BuildContext context) {
    final fondo = vacio
        ? const Color(0xFF244A3A)
        : (suma ? _dorado : _blanco);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(tamano * 0.22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          if (suma)
            BoxShadow(
              color: _dorado.withValues(alpha: 0.45),
              blurRadius: 12,
              spreadRadius: 1,
            ),
        ],
      ),
      child: vacio
          ? null
          : CustomPaint(
              painter: _PuntosDadoPainter(
                valor: valor.clamp(1, 6),
                color: _punto,
              ),
            ),
    );
  }
}

class _PuntosDadoPainter extends CustomPainter {
  _PuntosDadoPainter({required this.valor, required this.color});

  final int valor;
  final Color color;

  static const _layouts = <int, List<(int, int)>>{
    1: [(1, 1)],
    2: [(0, 0), (2, 2)],
    3: [(0, 0), (1, 1), (2, 2)],
    4: [(0, 0), (0, 2), (2, 0), (2, 2)],
    5: [(0, 0), (0, 2), (1, 1), (2, 0), (2, 2)],
    6: [(0, 0), (1, 0), (2, 0), (0, 2), (1, 2), (2, 2)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final radio = size.shortestSide * 0.105;
    final step = size.shortestSide / 4;
    final origen = Offset(size.width / 2 - step, size.height / 2 - step);

    for (final (fila, col) in _layouts[valor]!) {
      canvas.drawCircle(
        Offset(origen.dx + col * step, origen.dy + fila * step),
        radio,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PuntosDadoPainter oldDelegate) =>
      oldDelegate.valor != valor || oldDelegate.color != color;
}

List<bool> marcarDadosQueSuman(List<int> dados, List<ComboUsados> combos) {
  final necesitados = <int, int>{};
  for (final c in combos) {
    for (final v in c.valores) {
      necesitados[v] = (necesitados[v] ?? 0) + 1;
    }
  }

  final usados = <int, int>{};
  final marcas = <bool>[];
  for (final v in dados) {
    final ya = usados[v] ?? 0;
    final max = necesitados[v] ?? 0;
    if (ya < max) {
      usados[v] = ya + 1;
      marcas.add(true);
    } else {
      marcas.add(false);
    }
  }
  return marcas;
}

class ComboUsados {
  const ComboUsados(this.valores);
  final List<int> valores;
}
