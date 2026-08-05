import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/culoSucioV2/motor_culo_sucio_v2.dart';
import 'package:app_juegos_mesa/culoSucioV2/textos.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/theme/victoria_celebration.dart';

/// Victoria de Culo sucio v2: confeti + fuegos.
class VictoriaCuloSucioV2Overlay extends StatefulWidget {
  const VictoriaCuloSucioV2Overlay({
    super.key,
    required this.partida,
    required this.onVolverAJugar,
    required this.onVolver,
  });

  final PartidaCuloSucioV2 partida;
  final VoidCallback onVolverAJugar;
  final VoidCallback onVolver;

  @override
  State<VictoriaCuloSucioV2Overlay> createState() =>
      _VictoriaCuloSucioV2OverlayState();
}

class _VictoriaCuloSucioV2OverlayState extends State<VictoriaCuloSucioV2Overlay>
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
    final subtitulo = widget.partida.mensajeFin ??
        'El rival se quedó con el 1 de oro.';

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
                                        const SizedBox(height: 24),
                                        GlowButtonVictoria(
                                          label: 'VOLVER A JUGAR',
                                          icon: Icons.replay_rounded,
                                          color: AppColors.mint,
                                          onPressed: widget.onVolverAJugar,
                                        ),
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

/// Cartel de derrota (sin confeti).
class DerrotaCuloSucioV2Overlay extends StatefulWidget {
  const DerrotaCuloSucioV2Overlay({
    super.key,
    required this.partida,
    required this.onOtraVez,
    required this.onVolver,
  });

  final PartidaCuloSucioV2 partida;
  final VoidCallback onOtraVez;
  final VoidCallback onVolver;

  @override
  State<DerrotaCuloSucioV2Overlay> createState() =>
      _DerrotaCuloSucioV2OverlayState();
}

class _DerrotaCuloSucioV2OverlayState extends State<DerrotaCuloSucioV2Overlay> {
  bool _cartelVisible = true;

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
            child: _cartelVisible
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Material(
                        color: AppColors.carta,
                        borderRadius: BorderRadius.circular(22),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.sentiment_very_dissatisfied_rounded,
                                size: 52,
                                color: AppColors.peligro,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                TextosCuloSucioV2.culoSucio,
                                style: TextStyle(
                                  color: AppColors.peligro,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.partida.mensajeFin ??
                                    'Te quedaste con el 1 de oro.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.texto,
                                  fontSize: 15,
                                  height: 1.35,
                                ),
                              ),
                              if (widget.partida.ganador != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Gana ${widget.partida.ganador}',
                                  style: const TextStyle(
                                    color: AppColors.mint,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 22),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: widget.onOtraVez,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.peligro,
                                    foregroundColor: Colors.white,
                                  ),
                                  child:
                                      const Text(TextosCuloSucioV2.reiniciar),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: widget.onVolver,
                                  child: const Text(
                                    TextosCuloSucioV2.volverMenu,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.expand(),
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
