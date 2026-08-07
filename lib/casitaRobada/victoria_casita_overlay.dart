import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/casitaRobada/motor_casita.dart';
import 'package:app_juegos_mesa/casitaRobada/textos.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/theme/victoria_celebration.dart';

class VictoriaCasitaOverlay extends StatefulWidget {
  const VictoriaCasitaOverlay({
    super.key,
    required this.partida,
    required this.gane,
    required this.onOtraVez,
    required this.onVolver,
  });

  final PartidaCasita partida;
  final bool gane;
  final VoidCallback onOtraVez;
  final VoidCallback onVolver;

  @override
  State<VictoriaCasitaOverlay> createState() => _VictoriaCasitaOverlayState();
}

class _VictoriaCasitaOverlayState extends State<VictoriaCasitaOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confeti;

  @override
  void initState() {
    super.initState();
    _confeti = AnimationController.unbounded(vsync: this)
      ..repeat(
        min: 0,
        max: 3600,
        period: const Duration(seconds: 3600),
      );
  }

  @override
  void dispose() {
    _confeti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final empate = widget.partida.ganador == null;
    final titulo = empate
        ? 'Empate'
        : (widget.gane
            ? '¡${widget.partida.ganador} gana!'
            : 'Perdiste');
    final color = empate
        ? AppColors.acento
        : (widget.gane ? AppColors.mint : AppColors.peligro);

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: Stack(
        children: [
          if (widget.gane && !empate) ...[
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
                      widget.partida.mensajeFin ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.texto,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final j in widget.partida.jugadores)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${j.nombre}: ${j.cartasPozo} cartas',
                          style: const TextStyle(
                            color: AppColors.textoSuave,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.onOtraVez,
                        child: const Text(TextosCasita.reiniciar),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: widget.onVolver,
                        child: const Text(TextosCasita.volverMenu),
                      ),
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
