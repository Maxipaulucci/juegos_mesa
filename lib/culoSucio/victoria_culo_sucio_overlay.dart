import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/culoSucio/historial_culo_sucio.dart';
import 'package:app_juegos_mesa/culoSucio/motor_culo_sucio.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/theme/victoria_celebration.dart';

/// Victoria de Culo sucio: confeti + fuegos + cartel (mismo estilo que el resto).
class VictoriaCuloSucioOverlay extends StatefulWidget {
  const VictoriaCuloSucioOverlay({
    super.key,
    required this.partida,
    required this.onVolverAJugar,
    required this.onVolver,
    this.mostrarVolverAJugar = true,
  });

  final PartidaCuloSucio partida;
  final VoidCallback onVolverAJugar;
  final VoidCallback onVolver;
  final bool mostrarVolverAJugar;

  @override
  State<VictoriaCuloSucioOverlay> createState() =>
      _VictoriaCuloSucioOverlayState();
}

class _VictoriaCuloSucioOverlayState extends State<VictoriaCuloSucioOverlay>
    with TickerProviderStateMixin {
  static const int _cicloConfetiSegundos = 3600;

  late final AnimationController _entrada;
  late final AnimationController _pulso;
  late final AnimationController _confeti;
  late final Animation<double> _escala;
  late final Animation<double> _opacidad;

  bool _cartelVisible = true;

  @override
  void initState() {
    super.initState();
    _entrada = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _pulso = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _confeti = AnimationController.unbounded(vsync: this)
      ..repeat(
        min: 0,
        max: _cicloConfetiSegundos.toDouble(),
        period: const Duration(seconds: _cicloConfetiSegundos),
      );

    _escala = CurvedAnimation(parent: _entrada, curve: Curves.elasticOut);
    _opacidad = CurvedAnimation(parent: _entrada, curve: Curves.easeOut);
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
    final ganador = widget.partida.ganador ?? 'Alguien';
    final perdedor = widget.partida.perdedor;
    final subtitulo = perdedor != null && esNombrePc(perdedor)
        ? '$perdedor sacó el 1 de oro. ¡Es el culo sucio!'
        : (widget.partida.mensajeFin ??
            '¡${perdedor ?? "Alguien"} sacó el 1 de oro!');

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
                              child: AnimatedBuilder(
                                animation: _pulso,
                                builder: (context, _) {
                                  final glow = 14 + _pulso.value * 18;
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      28,
                                      22,
                                      20,
                                    ),
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
                                      border: Border.all(
                                        color: AppColors.acento,
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.acento
                                              .withValues(alpha: 0.55),
                                          blurRadius: glow,
                                          spreadRadius: 2,
                                        ),
                                        BoxShadow(
                                          color: AppColors.rosa
                                              .withValues(alpha: 0.35),
                                          blurRadius: glow * 1.2,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          '🏆',
                                          style: TextStyle(fontSize: 52),
                                        ),
                                        const SizedBox(height: 8),
                                        ShaderMask(
                                          shaderCallback: (b) =>
                                              const LinearGradient(
                                            colors: [
                                              Colors.white,
                                              AppColors.acento,
                                              AppColors.rosa,
                                            ],
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
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          ganador.toUpperCase(),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: AppColors.acento,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                            shadows: [
                                              Shadow(
                                                color: AppColors.acento
                                                    .withValues(alpha: 0.8),
                                                blurRadius: 16,
                                              ),
                                            ],
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
                                        if (widget.partida.cartasSacadas >
                                            0) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            'Cartas sacadas: ${widget.partida.cartasSacadas}',
                                            style: const TextStyle(
                                              color: AppColors.textoSuave,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 24),
                                        GlowButtonVictoria(
                                          label: 'HISTORIAL',
                                          icon: Icons.history_rounded,
                                          color: AppColors.azul,
                                          onPressed: () =>
                                              mostrarHistorialCuloSucio(
                                            context: context,
                                            partida: widget.partida,
                                          ),
                                        ),
                                        if (widget.mostrarVolverAJugar) ...[
                                          const SizedBox(height: 10),
                                          GlowButtonVictoria(
                                            label: 'VOLVER A JUGAR',
                                            icon: Icons.replay_rounded,
                                            color: AppColors.mint,
                                            onPressed: widget.onVolverAJugar,
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        GlowButtonVictoria(
                                          label: 'VOLVER AL MENÚ',
                                          icon: Icons.home_rounded,
                                          color: AppColors.violeta,
                                          onPressed: widget.onVolver,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
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
                onTap: () =>
                    setState(() => _cartelVisible = !_cartelVisible),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
