import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Palos del mazo inglés (visual).
enum PaloInglesVisual { corazones, diamantes, treboles, picas }

Color colorPaloIngles(PaloInglesVisual palo) => switch (palo) {
      PaloInglesVisual.corazones || PaloInglesVisual.diamantes =>
        const Color(0xFFE53935),
      PaloInglesVisual.treboles || PaloInglesVisual.picas =>
        const Color(0xFF1A1A1A),
    };

String simboloPaloIngles(PaloInglesVisual palo) => switch (palo) {
      PaloInglesVisual.corazones => '♥',
      PaloInglesVisual.diamantes => '♦',
      PaloInglesVisual.treboles => '♣',
      PaloInglesVisual.picas => '♠',
    };

/// Skin simple de carta inglesa (frente / dorso).
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
    final radio = 12.0;
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
    final sim = simboloPaloIngles(palo);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(
          color: seleccionada
              ? AppColors.acento
              : const Color(0xFF2A1450).withValues(alpha: 0.35),
          width: seleccionada ? 2.2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              etiquetaValor,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: width * 0.26,
                height: 1,
              ),
            ),
            Text(
              sim,
              style: TextStyle(
                color: color,
                fontSize: width * 0.22,
                height: 1,
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  sim,
                  style: TextStyle(
                    color: color,
                    fontSize: width * 0.42,
                    height: 1,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Transform.rotate(
                angle: 3.14159,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      etiquetaValor,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: width * 0.2,
                        height: 1,
                      ),
                    ),
                    Text(
                      sim,
                      style: TextStyle(
                        color: color,
                        fontSize: width * 0.18,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
