import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/escobaDel15/marcador_palitos.dart';
import 'package:app_juegos_mesa/escobaDel15/motor_escoba.dart';
import 'package:app_juegos_mesa/escobaDel15/resumen_ronda_escoba_overlay.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/theme/victoria_celebration.dart';

/// Victoria de Escoba: confeti + fuegos + cartel estándar (como el resto de juegos).
class VictoriaEscobaOverlay extends StatefulWidget {
  const VictoriaEscobaOverlay({
    super.key,
    required this.partida,
    required this.onVolverAJugar,
    required this.onVolver,
    this.animaciones = true,
  });

  final PartidaEscoba partida;
  final VoidCallback onVolverAJugar;
  final VoidCallback onVolver;
  final bool animaciones;

  @override
  State<VictoriaEscobaOverlay> createState() => _VictoriaEscobaOverlayState();
}

class _VictoriaEscobaOverlayState extends State<VictoriaEscobaOverlay>
    with TickerProviderStateMixin {
  static const int _cicloConfetiSegundos = 3600;

  late final AnimationController _entrada;
  late final AnimationController _pulso;
  late final AnimationController _confeti;
  late final Animation<double> _escala;
  late final Animation<double> _opacidad;

  bool _mostrarStats = false;
  bool _mostrarResumenRonda = false;
  bool _cartelVisible = true;

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
      _confeti.repeat(
        min: 0,
        max: _cicloConfetiSegundos.toDouble(),
        period: const Duration(seconds: _cicloConfetiSegundos),
      );
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

  Widget _construirContenido() {
    if (_mostrarStats) {
      return _PanelMarcadorEscoba(
        partida: widget.partida,
        ganador: widget.partida.ganador ?? '',
        onVerUltimaRonda: widget.partida.ultimoResultado == null
            ? null
            : () => setState(() => _mostrarResumenRonda = true),
        onCerrar: () => setState(() => _mostrarStats = false),
        onVolver: widget.onVolver,
      );
    }

    return _WinnerCardEscoba(
      ganador: widget.partida.ganador ?? 'Alguien',
      subtitulo: widget.partida.mensajeFin ??
          'Llegó a ${widget.partida.objetivo} puntos',
      pulso: _pulso,
      animaciones: widget.animaciones,
      onEstadisticas: () => setState(() => _mostrarStats = true),
      onVolverAJugar: widget.onVolverAJugar,
      onVolver: widget.onVolver,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_mostrarResumenRonda && widget.partida.ultimoResultado != null) {
      return ResumenRondaEscobaOverlay(
        resultado: widget.partida.ultimoResultado!,
        labelContinuar: 'VOLVER',
        onContinuar: () => setState(() => _mostrarResumenRonda = false),
      );
    }

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
                if (widget.animaciones)
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
                              child: _construirContenido(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (widget.animaciones)
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

class _WinnerCardEscoba extends StatelessWidget {
  const _WinnerCardEscoba({
    required this.ganador,
    required this.subtitulo,
    required this.pulso,
    required this.onEstadisticas,
    required this.onVolverAJugar,
    required this.onVolver,
    this.animaciones = true,
  });

  final String ganador;
  final String subtitulo;
  final AnimationController pulso;
  final VoidCallback onEstadisticas;
  final VoidCallback onVolverAJugar;
  final VoidCallback onVolver;
  final bool animaciones;

  @override
  Widget build(BuildContext context) {
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
          border: Border.all(color: AppColors.acento, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.acento.withValues(alpha: 0.55),
              blurRadius: glow,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: AppColors.rosa.withValues(alpha: 0.35),
              blurRadius: glow * 1.2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 8),
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
                    color: AppColors.acento.withValues(alpha: 0.8),
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
              label: 'ESTADÍSTICAS',
              icon: Icons.bar_chart_rounded,
              color: AppColors.azul,
              onPressed: onEstadisticas,
            ),
            const SizedBox(height: 10),
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

class _PanelMarcadorEscoba extends StatelessWidget {
  const _PanelMarcadorEscoba({
    required this.partida,
    required this.ganador,
    required this.onCerrar,
    required this.onVolver,
    this.onVerUltimaRonda,
  });

  final PartidaEscoba partida;
  final String ganador;
  final VoidCallback onCerrar;
  final VoidCallback onVolver;
  final VoidCallback? onVerUltimaRonda;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B1D6E), Color(0xFF1A0A33)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.azul, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'ESTADÍSTICAS',
            style: TextStyle(
              color: AppColors.azul,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 14),
          for (final j in partida.jugadores) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: j.nombre == ganador
                      ? AppColors.acento
                      : AppColors.textoSuave.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      j.nombre == ganador ? '🏆 ${j.nombre}' : j.nombre,
                      style: TextStyle(
                        color: j.nombre == ganador
                            ? AppColors.acento
                            : AppColors.texto,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  MarcadorPalitosEscoba(
                    puntos: j.puntos,
                    color: j.nombre == ganador
                        ? AppColors.acento
                        : AppColors.azul,
                    tamanoGrupo: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${j.puntos} pts',
                    style: const TextStyle(
                      color: AppColors.textoSuave,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (onVerUltimaRonda != null) ...[
            const SizedBox(height: 6),
            GlowButtonVictoria(
              label: 'ÚLTIMA RONDA',
              icon: Icons.history_rounded,
              color: AppColors.rosa,
              onPressed: onVerUltimaRonda!,
            ),
          ],
          const SizedBox(height: 10),
          GlowButtonVictoria(
            label: 'VOLVER',
            icon: Icons.arrow_back_rounded,
            color: AppColors.mint,
            onPressed: onCerrar,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onVolver,
            child: const Text(
              'Ir al menú',
              style: TextStyle(
                color: AppColors.textoSuave,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
