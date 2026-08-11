import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/jodete/motor_jodete.dart';
import 'package:app_juegos_mesa/jodete/textos.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/theme/victoria_celebration.dart';

class VictoriaJodeteOverlay extends StatefulWidget {
  const VictoriaJodeteOverlay({
    super.key,
    required this.partida,
    required this.gane,
    required this.onOtraVez,
    required this.onVolver,
    this.animaciones = true,
  });

  final PartidaJodete partida;
  final bool gane;
  final VoidCallback onOtraVez;
  final VoidCallback onVolver;
  final bool animaciones;

  @override
  State<VictoriaJodeteOverlay> createState() => _VictoriaJodeteOverlayState();
}

class _VictoriaJodeteOverlayState extends State<VictoriaJodeteOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confeti;

  @override
  void initState() {
    super.initState();
    _confeti = AnimationController.unbounded(vsync: this);
    if (widget.animaciones && widget.gane) {
      _confeti.repeat(
        min: 0,
        max: 3600,
        period: const Duration(seconds: 3600),
      );
    }
  }

  @override
  void dispose() {
    _confeti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.gane
        ? '¡${widget.partida.ganador ?? 'Ganaste'}!'
        : 'Perdiste';
    final color = widget.gane ? AppColors.mint : AppColors.peligro;
    final sub = widget.partida.mensajeFin ??
        (widget.gane
            ? '¡Te quedaste sin cartas!'
            : 'Ganó ${widget.partida.ganador ?? '—'}');

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: Stack(
        children: [
          if (widget.gane && widget.animaciones) ...[
            const Positioned.fill(
              child: IgnorePointer(child: FuegosArtificialesCapa()),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confeti,
                  builder: (_, __) => CustomPaint(
                    painter: ConfetiPainter(tiempo: _confeti.value),
                  ),
                ),
              ),
            ),
          ],
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A0A33),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: color, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      sub,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textoSuave,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: widget.onOtraVez,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.mint,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text(TextosJodete.reiniciar),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: widget.onVolver,
                      child: const Text(TextosJodete.volverMenu),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
