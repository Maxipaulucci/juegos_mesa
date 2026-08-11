import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/jodete/motor_jodete.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/theme/victoria_celebration.dart';

/// Fin de Jodete: mismo cartel de victoria que el resto de juegos.
class VictoriaJodeteOverlay extends StatefulWidget {
  const VictoriaJodeteOverlay({
    super.key,
    required this.partida,
    required this.gane,
    required this.onVolverAJugar,
    required this.onVolver,
    this.animaciones = true,
  });

  final PartidaJodete partida;
  /// True si el jugador local ganó (en local hot-seat suele ser true).
  final bool gane;
  final VoidCallback onVolverAJugar;
  final VoidCallback onVolver;
  final bool animaciones;

  @override
  State<VictoriaJodeteOverlay> createState() => _VictoriaJodeteOverlayState();
}

class _VictoriaJodeteOverlayState extends State<VictoriaJodeteOverlay>
    with TickerProviderStateMixin {
  static const int _cicloConfetiSegundos = 3600;

  late final AnimationController _entrada;
  late final AnimationController _pulso;
  late final AnimationController _confeti;
  late final Animation<double> _escala;
  late final Animation<double> _opacidad;

  bool _cartelVisible = true;

  bool get _celebrar => widget.gane && widget.partida.ganador != null;

  String get _ganadorTexto {
    final g = widget.partida.ganador;
    if (g != null && g.isNotEmpty) return g;
    return '—';
  }

  String get _subtitulo {
    if (!widget.gane && widget.partida.ganador != null) {
      return widget.partida.mensajeFin ??
          'Ganó $_ganadorTexto. ¡Mejor suerte la próxima!';
    }
    return widget.partida.mensajeFin ??
        (widget.partida.ganador != null
            ? '¡${widget.partida.ganador} se quedó sin cartas!'
            : 'Partida terminada');
  }

  @override
  void initState() {
    super.initState();
    final conAnim = widget.animaciones;

    _entrada = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: conAnim ? 700 : 0),
    );
    _pulso = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _confeti = AnimationController.unbounded(vsync: this);

    if (conAnim) {
      _entrada.forward();
      _pulso.repeat(reverse: true);
      if (_celebrar) {
        _confeti.repeat(
          min: 0,
          max: _cicloConfetiSegundos.toDouble(),
          period: const Duration(seconds: _cicloConfetiSegundos),
        );
      }
    } else {
      _entrada.value = 1;
    }

    _escala = CurvedAnimation(
      parent: _entrada,
      curve: conAnim ? Curves.elasticOut : Curves.linear,
    );
    _opacidad = CurvedAnimation(
      parent: _entrada,
      curve: conAnim ? Curves.easeOut : Curves.linear,
    );
  }

  @override
  void dispose() {
    _entrada.dispose();
    _pulso.dispose();
    _confeti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IgnorePointer(
          ignoring: !_cartelVisible,
          child: Material(
            color: _cartelVisible
                ? Colors.black.withValues(alpha: 0.72)
                : Colors.transparent,
            child: Stack(
              children: [
                if (widget.animaciones && _celebrar)
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
                if (_cartelVisible)
                  SafeArea(
                    child: Center(
                      child: FadeTransition(
                        opacity: _opacidad,
                        child: ScaleTransition(
                          scale: _escala,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: _FinCardJodete(
                                gane: widget.gane,
                                ganador: _ganadorTexto,
                                subtitulo: _subtitulo,
                                pulso: _pulso,
                                animaciones: widget.animaciones,
                                onVolverAJugar: widget.onVolverAJugar,
                                onVolver: widget.onVolver,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (widget.animaciones && _celebrar)
                  const Positioned.fill(
                    child: IgnorePointer(child: FuegosArtificialesCapa()),
                  ),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: BotonOjoVictoria(
                cartelVisible: _cartelVisible,
                onTap: () => setState(() => _cartelVisible = !_cartelVisible),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FinCardJodete extends StatelessWidget {
  const _FinCardJodete({
    required this.gane,
    required this.ganador,
    required this.subtitulo,
    required this.pulso,
    required this.onVolverAJugar,
    required this.onVolver,
    this.animaciones = true,
  });

  final bool gane;
  final String ganador;
  final String subtitulo;
  final AnimationController pulso;
  final VoidCallback onVolverAJugar;
  final VoidCallback onVolver;
  final bool animaciones;

  @override
  Widget build(BuildContext context) {
    final borde = gane ? AppColors.acento : AppColors.peligro;
    final glowA = gane ? AppColors.acento : AppColors.peligro;
    final glowB = gane ? AppColors.rosa : AppColors.peligro;

    Widget card(double glow) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
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
          border: Border.all(color: borde, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: glowA.withValues(alpha: 0.55),
              blurRadius: glow,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: glowB.withValues(alpha: 0.35),
              blurRadius: glow * 1.2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(gane ? '🏆' : '💀', style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 8),
            if (gane)
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Colors.white, AppColors.acento, AppColors.rosa],
                ).createShader(b),
                child: const Text(
                  '¡GANADOR!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              )
            else
              const Text(
                '¡PERDISTE!',
                style: TextStyle(
                  color: AppColors.peligro,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            const SizedBox(height: 10),
            Text(
              gane ? ganador.toUpperCase() : 'GANÓ ${ganador.toUpperCase()}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: gane ? AppColors.acento : AppColors.texto,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                shadows: gane
                    ? [
                        Shadow(
                          color: AppColors.acento.withValues(alpha: 0.8),
                          blurRadius: 16,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textoSuave,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            GlowButtonVictoria(
              label: 'VOLVER A JUGAR',
              icon: Icons.replay_rounded,
              color: AppColors.mint,
              onPressed: onVolverAJugar,
            ),
            const SizedBox(height: 10),
            GlowButtonVictoria(
              label: 'VOLVER AL MENÚ',
              icon: Icons.home_rounded,
              color: AppColors.violeta,
              onPressed: onVolver,
            ),
          ],
        ),
      );
    }

    if (!animaciones) return card(20);
    return AnimatedBuilder(
      animation: pulso,
      builder: (context, _) => card(14 + pulso.value * 18),
    );
  }
}
