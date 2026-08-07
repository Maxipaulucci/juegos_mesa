import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/chanchoVa/motor_chancho_va.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/theme/victoria_celebration.dart';

/// Victoria de Chancho va: confeti + fuegos + cartel estándar.
class VictoriaChanchoOverlay extends StatefulWidget {
  const VictoriaChanchoOverlay({
    super.key,
    required this.partida,
    required this.onVolverAJugar,
    required this.onVolver,
    this.animaciones = true,
  });

  final PartidaChancho partida;
  final VoidCallback onVolverAJugar;
  final VoidCallback onVolver;
  final bool animaciones;

  @override
  State<VictoriaChanchoOverlay> createState() => _VictoriaChanchoOverlayState();
}

class _VictoriaChanchoOverlayState extends State<VictoriaChanchoOverlay>
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
    if (g != null) return g;
    final perdedor = widget.partida.perdedor;
    final ganadores = widget.partida.jugadores
        .where((j) => !j.eliminado && j.nombre != perdedor)
        .map((j) => j.nombre)
        .toList();
    if (ganadores.isEmpty) {
      // Fin al primer perdedor: ganan todos los que no perdieron.
      return widget.partida.jugadores
          .where((j) => j.nombre != perdedor)
          .map((j) => j.nombre)
          .join(' · ');
    }
    if (ganadores.length == 1) return ganadores.first;
    return ganadores.join(' · ');
  }

  String get _subtitulo {
    return widget.partida.mensajeFin ??
        '${widget.partida.perdedor ?? 'Alguien'} completó ${widget.partida.palabraObjetivo} y pierde.';
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
      return _PanelHistorialChancho(
        partida: widget.partida,
        onCerrar: () => setState(() => _mostrarHistorial = false),
        onVolver: widget.onVolver,
      );
    }

    return _WinnerCardChancho(
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

class _WinnerCardChancho extends StatelessWidget {
  const _WinnerCardChancho({
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

class _PanelHistorialChancho extends StatelessWidget {
  const _PanelHistorialChancho({
    required this.partida,
    required this.onCerrar,
    required this.onVolver,
  });

  final PartidaChancho partida;
  final VoidCallback onCerrar;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    final historial = partida.historialLetras;
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
              const Expanded(
                child: Text(
                  'HISTORIAL',
                  style: TextStyle(
                    color: AppColors.acento,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1,
                  ),
                ),
              ),
              IconButton(
                onPressed: onCerrar,
                icon: const Icon(Icons.close, color: AppColors.texto),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            historial.isEmpty
                ? 'Sin letras anotadas.'
                : '${historial.length} letra${historial.length == 1 ? '' : 's'} anotada${historial.length == 1 ? '' : 's'}',
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: historial.isEmpty
                ? const SizedBox.shrink()
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: historial.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final e = historial[index];
                      final esPerdedor = e.jugador == partida.perdedor &&
                          index == historial.length - 1;
                      final acento = esPerdedor
                          ? AppColors.peligro
                          : AppColors.acento;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: esPerdedor
                                ? AppColors.peligro.withValues(alpha: 0.75)
                                : AppColors.cartaBorde,
                            width: esPerdedor ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${e.jugador}: ${e.letrasTras}',
                              style: TextStyle(
                                color: acento,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              e.motivoTexto,
                              style: const TextStyle(
                                color: AppColors.textoSuave,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
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
