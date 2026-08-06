import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/shared/cartas/icono_espada.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Palos del mazo español (visual compartido entre juegos).
enum PaloEspanolVisual { oro, copa, espada, basto }

Color colorPaloEspanol(PaloEspanolVisual palo) => switch (palo) {
      PaloEspanolVisual.oro => const Color(0xFFFFC107),
      PaloEspanolVisual.copa => const Color(0xFFFF5252),
      PaloEspanolVisual.espada => const Color(0xFF40C4FF),
      PaloEspanolVisual.basto => const Color(0xFF69F0AE),
    };

/// Borde/glow al seleccionar (violeta, para no confundirse con basto).
const Color colorSeleccionCartaEspanola = Color(0xFFB388FF);

Widget iconoPaloEspanol(
  PaloEspanolVisual palo, {
  required double size,
  required Color color,
}) {
  if (palo == PaloEspanolVisual.espada) {
    return IconoEspadaOutlined(size: size, color: color);
  }
  final data = switch (palo) {
    PaloEspanolVisual.oro => Icons.monetization_on_outlined,
    PaloEspanolVisual.copa => Icons.wine_bar_outlined,
    PaloEspanolVisual.espada => Icons.bolt_outlined,
    PaloEspanolVisual.basto => Icons.park_outlined,
  };
  return Icon(data, size: size, color: color);
}

/// Skin de carta española (misma que Culo sucio).
class CartaEspanolaSkin extends StatelessWidget {
  const CartaEspanolaSkin({
    super.key,
    required this.numero,
    required this.etiqueta,
    required this.palo,
    this.seleccionada = false,
    this.compacta = false,
    this.bocaArriba = true,
    this.resaltarPeligro = false,
    this.subtitulo,
    this.width,
    this.height,
  });

  final int numero;
  final String etiqueta;
  final PaloEspanolVisual palo;
  final bool seleccionada;
  final bool compacta;
  final bool bocaArriba;
  final bool resaltarPeligro;
  final String? subtitulo;
  final double? width;
  final double? height;

  double get _w => width ?? (compacta ? 40.0 : 68.0);
  double get _h => height ?? (compacta ? 56.0 : (subtitulo != null ? 110.0 : 102.0));

  @override
  Widget build(BuildContext context) {
    final color = colorPaloEspanol(palo);
    final radio = compacta ? 10.0 : 14.0;

    if (!bocaArriba) {
      return Container(
        width: _w,
        height: _h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radio),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3B1D6E),
              Color(0xFF1A0A33),
              Color(0xFF2A1050),
            ],
          ),
          border: Border.all(
            color: seleccionada ? colorSeleccionCartaEspanola : AppColors.acento,
            width: seleccionada ? 2.4 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (seleccionada ? colorSeleccionCartaEspanola : AppColors.acento)
                  .withValues(alpha: 0.35),
              blurRadius: compacta ? 8 : 14,
              spreadRadius: 0.5,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(compacta ? 4 : 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radio - 4),
                    border: Border.all(
                      color: AppColors.violeta.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                '?',
                style: TextStyle(
                  color: AppColors.acento,
                  fontSize: compacta ? 18 : 36,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  shadows: const [
                    Shadow(color: Color(0xAAFFC107), blurRadius: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final borde = seleccionada
        ? colorSeleccionCartaEspanola
        : (resaltarPeligro ? AppColors.peligro : color);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: _w,
      height: _h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radio),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.carta,
            Color.lerp(AppColors.carta, color, 0.35)!,
          ],
        ),
        border: Border.all(
          color: borde,
          width: seleccionada || resaltarPeligro ? 2.4 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: borde.withValues(alpha: 0.45),
            blurRadius: compacta ? 8 : 14,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compacta ? 2 : 4,
          vertical: compacta ? 2 : 6,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconoPaloEspanol(
              palo,
              size: compacta ? 14 : 26,
              color: color,
            ),
            SizedBox(height: compacta ? 2 : 6),
            Text(
              compacta ? '$numero' : etiqueta,
              textAlign: TextAlign.center,
              maxLines: compacta ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: resaltarPeligro ? AppColors.peligro : AppColors.texto,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            if (subtitulo != null && !compacta) ...[
              const SizedBox(height: 3),
              Text(
                subtitulo!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ],
            if (resaltarPeligro && !compacta && subtitulo == null) ...[
              const SizedBox(height: 4),
              const Text(
                '¡CULO SUCIO!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.peligro,
                  fontWeight: FontWeight.w900,
                  fontSize: 7,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
