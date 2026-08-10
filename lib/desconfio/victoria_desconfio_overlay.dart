import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/desconfio/motor_desconfio.dart';
import 'package:app_juegos_mesa/shared/cartas/carta_espanola_skin.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/theme/victoria_celebration.dart';

/// Fin de Desconfío: victoria (confeti + fuegos) o derrota.
class VictoriaDesconfioOverlay extends StatefulWidget {
  const VictoriaDesconfioOverlay({
    super.key,
    required this.partida,
    required this.gane,
    required this.onVolverAJugar,
    required this.onVolver,
    this.animaciones = true,
  });

  final PartidaDesconfio partida;
  /// True si el jugador local ganó (en local hot-seat suele ser true).
  final bool gane;
  final VoidCallback onVolverAJugar;
  final VoidCallback onVolver;
  final bool animaciones;

  @override
  State<VictoriaDesconfioOverlay> createState() =>
      _VictoriaDesconfioOverlayState();
}

class _VictoriaDesconfioOverlayState extends State<VictoriaDesconfioOverlay>
    with TickerProviderStateMixin {
  static const int _cicloConfetiSegundos = 3600;

  late final AnimationController _entrada;
  late final AnimationController _pulso;
  late final AnimationController _confeti;
  late final Animation<double> _escala;
  late final Animation<double> _opacidad;

  bool _mostrarHistorial = false;
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

  Widget _construirContenido() {
    if (_mostrarHistorial) {
      return _PanelHistorialDesconfio(
        partida: widget.partida,
        onCerrar: () => setState(() => _mostrarHistorial = false),
        onVolver: widget.onVolver,
      );
    }

    return _FinCardDesconfio(
      gane: widget.gane,
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
                              child: _construirContenido(),
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

class _FinCardDesconfio extends StatelessWidget {
  const _FinCardDesconfio({
    required this.gane,
    required this.ganador,
    required this.subtitulo,
    required this.pulso,
    required this.onHistorial,
    required this.onVolverAJugar,
    required this.onVolver,
    this.animaciones = true,
  });

  final bool gane;
  final String ganador;
  final String subtitulo;
  final AnimationController pulso;
  final VoidCallback onHistorial;
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

class _PanelHistorialDesconfio extends StatelessWidget {
  const _PanelHistorialDesconfio({
    required this.partida,
    required this.onCerrar,
    required this.onVolver,
  });

  final PartidaDesconfio partida;
  final VoidCallback onCerrar;
  final VoidCallback onVolver;

  PaloEspanolVisual _paloVisual(PaloDesconfio p) => switch (p) {
        PaloDesconfio.oro => PaloEspanolVisual.oro,
        PaloDesconfio.copa => PaloEspanolVisual.copa,
        PaloDesconfio.espada => PaloEspanolVisual.espada,
        PaloDesconfio.basto => PaloEspanolVisual.basto,
      };

  @override
  Widget build(BuildContext context) {
    final historial = partida.historial;
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
                      'No hubo tiradas en esta partida.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textoSuave),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: historial.length,
                    itemBuilder: (context, i) {
                      final e = historial[i];
                      final n = i + 1;
                      final mentira = e.huboDesconfio && e.eraDelPalo == false;
                      final verdad = e.huboDesconfio && e.eraDelPalo == true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: mentira
                                ? AppColors.peligro.withValues(alpha: 0.5)
                                : verdad
                                    ? AppColors.mint.withValues(alpha: 0.5)
                                    : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CartaEspanolaSkin(
                              numero: e.carta.numero,
                              etiqueta: e.carta.etiqueta,
                              palo: _paloVisual(e.carta.palo),
                              width: 44,
                              height: 66,
                              compacta: true,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tirada $n · ${e.jugador}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    e.carta.etiqueta,
                                    style: const TextStyle(
                                      color: AppColors.acento,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Declarado: ${nombrePaloDesconfio(e.paloDeclarado)}',
                                    style: const TextStyle(
                                      color: AppColors.textoSuave,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (e.huboDesconfio) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      mentira
                                          ? '¡Desconfío (${e.desconfiador})! Mentira → '
                                              '${e.quienSeLleva} se lleva ${e.cartasLlevadas}'
                                          : '¡Desconfío (${e.desconfiador})! Era verdad → '
                                              '${e.quienSeLleva} se lleva ${e.cartasLlevadas}',
                                      style: TextStyle(
                                        color: mentira
                                            ? AppColors.peligro
                                            : AppColors.mint,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
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

