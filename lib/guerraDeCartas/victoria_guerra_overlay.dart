import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/guerraDeCartas/motor_guerra.dart';
import 'package:app_juegos_mesa/guerraDeCartas/textos.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/theme/victoria_celebration.dart';

class VictoriaGuerraOverlay extends StatefulWidget {
  const VictoriaGuerraOverlay({
    super.key,
    required this.partida,
    required this.gane,
    required this.onOtraVez,
    required this.onVolver,
  });

  final PartidaGuerra partida;
  final bool gane;
  final VoidCallback onOtraVez;
  final VoidCallback onVolver;

  @override
  State<VictoriaGuerraOverlay> createState() => _VictoriaGuerraOverlayState();
}

class _VictoriaGuerraOverlayState extends State<VictoriaGuerraOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confeti;

  @override
  void initState() {
    super.initState();
    _confeti = AnimationController.unbounded(vsync: this)
      ..repeat(min: 0, max: 3600, period: const Duration(seconds: 3600));
  }

  @override
  void dispose() {
    _confeti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.gane ? '¡GANASTE!' : 'FIN';
    final sub = widget.partida.mensajeFin ??
        (widget.partida.ganador != null
            ? 'Ganó ${widget.partida.ganador}'
            : 'Partida terminada');

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: Stack(
        children: [
          if (widget.gane)
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
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
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
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: widget.gane ? AppColors.mint : AppColors.acento,
                        width: 2,
                      ),
                      boxShadow: neonGlow(
                        widget.gane ? AppColors.mint : AppColors.acento,
                        blur: 18,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          TextosGuerra.titulo,
                          style: TextStyle(
                            color: AppColors.textoSuave.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          titulo,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                widget.gane ? AppColors.mint : AppColors.acento,
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          sub,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: widget.onOtraVez,
                            child: const Text(TextosGuerra.reiniciar),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: widget.onVolver,
                            child: const Text(TextosGuerra.volverMenu),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
