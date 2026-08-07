import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/chanchoVa/motor_chancho_va.dart';
import 'package:app_juegos_mesa/chanchoVa/tablero_chancho_va.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Cartel de fin de ronda + acceso al tablero de letras.
class FinRondaChanchoOverlay extends StatefulWidget {
  const FinRondaChanchoOverlay({
    super.key,
    required this.partida,
    required this.onContinuar,
  });

  final PartidaChancho partida;
  final VoidCallback onContinuar;

  @override
  State<FinRondaChanchoOverlay> createState() => _FinRondaChanchoOverlayState();
}

class _FinRondaChanchoOverlayState extends State<FinRondaChanchoOverlay> {
  bool _mostrarTablero = false;

  @override
  Widget build(BuildContext context) {
    if (_mostrarTablero) {
      return TableroChanchoOverlay(
        partida: widget.partida,
        onCerrar: () => setState(() => _mostrarTablero = false),
      );
    }

    final resumen = widget.partida.ultimoResumenRonda;
    final chanchoDe = resumen?.chanchoDe ?? '—';
    final chancho = resumen?.chancho ?? '—';
    final etDe = resumen?.etiquetaChanchoDe ?? 'Chancho de';
    final etCh = resumen?.etiquetaChancho ?? 'Chancho';

    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF3B1D6E),
                      Color(0xFF1A0A33),
                      Color(0xFF2A1050),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.acento, width: 2.5),
                  boxShadow: [
                    ...neonGlow(AppColors.acento, blur: 22),
                    ...neonGlow(AppColors.rosa, blur: 12),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Fin de la ronda',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.acento,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _LineaResumen(
                      etiqueta: etDe,
                      valor: chanchoDe,
                    ),
                    const SizedBox(height: 10),
                    _LineaResumen(
                      etiqueta: etCh,
                      valor: chancho,
                    ),
                    const SizedBox(height: 24),
                    BotonVerTableroChancho(
                      onPressed: () => setState(() => _mostrarTablero = true),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: widget.onContinuar,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.mint,
                          foregroundColor: Colors.black,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'CONTINUAR',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LineaResumen extends StatelessWidget {
  const _LineaResumen({
    required this.etiqueta,
    required this.valor,
  });

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          color: AppColors.textoSuave,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        children: [
          TextSpan(text: '$etiqueta: '),
          TextSpan(
            text: valor,
            style: const TextStyle(
              color: AppColors.texto,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón cápsula violeta como en Generala / foto de referencia.
class BotonVerTableroChancho extends StatelessWidget {
  const BotonVerTableroChancho({
    super.key,
    required this.onPressed,
  });

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: enabled ? neonGlow(AppColors.rosa, blur: 14) : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Ink(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFCE93D8),
                    Color(0xFFAB47BC),
                    Color(0xFF6A1B9A),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white70, width: 1.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.grid_view_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'VER TABLERO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
