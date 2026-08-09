import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/guerraDeCartas/motor_guerra.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/theme/victoria_celebration.dart';

/// Victoria de Guerra de cartas: confeti + fuegos + cartel estándar.
class VictoriaGuerraOverlay extends StatefulWidget {
  const VictoriaGuerraOverlay({
    super.key,
    required this.partida,
    required this.onVolverAJugar,
    required this.onVolver,
    this.animaciones = true,
  });

  final PartidaGuerra partida;
  final VoidCallback onVolverAJugar;
  final VoidCallback onVolver;
  final bool animaciones;

  @override
  State<VictoriaGuerraOverlay> createState() => _VictoriaGuerraOverlayState();
}

class _VictoriaGuerraOverlayState extends State<VictoriaGuerraOverlay>
    with TickerProviderStateMixin {
  static const int _cicloConfetiSegundos = 3600;

  late final AnimationController _entrada;
  late final AnimationController _pulso;
  late final AnimationController _confeti;
  late final Animation<double> _escala;
  late final Animation<double> _opacidad;

  bool _mostrarHistorial = false;
  bool _cartelVisible = true;

  String get _ganadorTexto {
    final g = widget.partida.ganador;
    if (g != null && g.isNotEmpty) return g;
    return '—';
  }

  String get _subtitulo {
    return widget.partida.mensajeFin ??
        (widget.partida.ganador != null
            ? '¡${widget.partida.ganador} se quedó con todas las cartas!'
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
    if (_mostrarHistorial) {
      return _PanelHistorialGuerra(
        partida: widget.partida,
        onCerrar: () => setState(() => _mostrarHistorial = false),
        onVolver: widget.onVolver,
      );
    }

    return _WinnerCardGuerra(
      ganador: _ganadorTexto,
      subtitulo: _subtitulo,
      pulso: _pulso,
      animaciones: widget.animaciones,
      onHistorial: () => setState(() => _mostrarHistorial = true),
      onVolverAJugar: widget.onVolverAJugar,
      onVolver: widget.onVolver,
    );
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

class _WinnerCardGuerra extends StatelessWidget {
  const _WinnerCardGuerra({
    required this.ganador,
    required this.subtitulo,
    required this.pulso,
    required this.onHistorial,
    required this.onVolverAJugar,
    required this.onVolver,
    this.animaciones = true,
  });

  final String ganador;
  final String subtitulo;
  final AnimationController pulso;
  final VoidCallback onHistorial;
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
              label: 'HISTORIAL',
              icon: Icons.history_rounded,
              color: AppColors.azul,
              onPressed: onHistorial,
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

class _PanelHistorialGuerra extends StatelessWidget {
  const _PanelHistorialGuerra({
    required this.partida,
    required this.onCerrar,
    required this.onVolver,
  });

  final PartidaGuerra partida;
  final VoidCallback onCerrar;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    final historial = partida.historialRondas;
    final maxH = MediaQuery.sizeOf(context).height * 0.62;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
        border: Border.all(color: AppColors.azul, width: 2),
        boxShadow: neonGlow(AppColors.azul, blur: 16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onCerrar,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              const Expanded(
                child: Text(
                  'HISTORIAL',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          Text(
            historial.isEmpty
                ? 'Sin tiradas registradas'
                : '${historial.length} tirada${historial.length == 1 ? '' : 's'}',
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: historial.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No hubo rondas en esta partida.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textoSuave),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: historial.length,
                    itemBuilder: (context, i) {
                      final r = historial[i];
                      final n = i + 1;
                      final cartas = r.cartasJugadas.entries
                          .map((e) => '${e.key}: ${e.value.etiqueta}')
                          .join('  ·  ');
                      final titulo = r.huboGuerra
                          ? 'Tirada $n · ¡Guerra!'
                          : 'Tirada $n';
                      final detalle = r.mensaje ??
                          'Ganó ${r.ganadorNombre} (+${r.pozoMesa.length})';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: r.huboGuerra
                                ? AppColors.acento.withValues(alpha: 0.7)
                                : AppColors.cartaBorde,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    titulo,
                                    style: TextStyle(
                                      color: r.huboGuerra
                                          ? AppColors.acento
                                          : AppColors.texto,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Text(
                                  r.ganadorNombre,
                                  style: const TextStyle(
                                    color: AppColors.mint,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              cartas,
                              style: const TextStyle(
                                color: AppColors.textoSuave,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              detalle,
                              style: TextStyle(
                                color: AppColors.texto.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            if (r.mezclaronPozo.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Mezclaron pozo: ${r.mezclaronPozo.join(', ')}',
                                style: TextStyle(
                                  color: AppColors.textoSuave
                                      .withValues(alpha: 0.85),
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
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
}
