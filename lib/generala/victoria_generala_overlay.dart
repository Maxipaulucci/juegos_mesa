import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/generala/motor_generala.dart';
import 'package:app_juegos_mesa/generala/tablero_generala.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/theme/victoria_celebration.dart';

/// Cartel de victoria de Generala (mismo estilo que Diez Mil: confeti + fuegos).
class VictoriaGeneralaOverlay extends StatefulWidget {
  const VictoriaGeneralaOverlay({
    super.key,
    required this.partida,
    required this.ganador,
    required this.onVolverAJugar,
    required this.onVolver,
    this.subtitulo,
    this.animaciones = true,
  });

  final PartidaGenerala partida;
  final String ganador;
  final String? subtitulo;
  final VoidCallback onVolverAJugar;
  final VoidCallback onVolver;
  final bool animaciones;

  @override
  State<VictoriaGeneralaOverlay> createState() =>
      _VictoriaGeneralaOverlayState();
}

class _VictoriaGeneralaOverlayState extends State<VictoriaGeneralaOverlay>
    with TickerProviderStateMixin {
  static const int _cicloConfetiSegundos = 3600;

  late final AnimationController _entrada;
  late final AnimationController _pulso;
  late final AnimationController _confeti;
  late final Animation<double> _escala;
  late final Animation<double> _opacidad;

  bool _mostrarStats = false;
  bool _mostrarTablero = false;
  JugadorGenerala? _jugadorDetalle;
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
    if (_jugadorDetalle != null) {
      return _DetalleJugadorPanel(
        partida: widget.partida,
        jugador: _jugadorDetalle!,
        ganador: widget.ganador,
        onCerrar: () => setState(() => _jugadorDetalle = null),
      );
    }

    if (_mostrarStats) {
      return _StatsRankingPanel(
        partida: widget.partida,
        ganador: widget.ganador,
        onSeleccionar: (j) => setState(() => _jugadorDetalle = j),
        onVerTablero: () => setState(() => _mostrarTablero = true),
        onCerrar: () => setState(() => _mostrarStats = false),
        onVolver: widget.onVolver,
      );
    }

    final total = widget.partida.jugadores
        .firstWhere((j) => j.nombre == widget.ganador)
        .total;

    return _WinnerCardGenerala(
      ganador: widget.ganador,
      pulso: _pulso,
      animaciones: widget.animaciones,
      subtitulo: widget.subtitulo ??
          '$total PTS · ¡Más puntos y se lleva la partida!',
      onEstadisticas: () => setState(() {
        _mostrarStats = true;
        _jugadorDetalle = null;
      }),
      onVolverAJugar: widget.onVolverAJugar,
      onVolver: widget.onVolver,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cartelVisible
          ? Colors.black.withValues(alpha: 0.72)
          : Colors.transparent,
      child: Stack(
        children: [
          if (widget.animaciones) ...[
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _confeti,
                builder: (_, __) => CustomPaint(
                  painter: ConfetiPainter(tiempo: _confeti.value),
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(child: FuegosArtificialesCapa()),
            ),
          ],
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
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: BotonOjoVictoria(
                  cartelVisible: _cartelVisible,
                  onTap: () => setState(
                    () => _cartelVisible = !_cartelVisible,
                  ),
                ),
              ),
            ),
          ),
          if (_mostrarTablero)
            Positioned.fill(
              child: TableroGeneralaOverlay(
                partida: widget.partida,
                onCerrar: () => setState(() => _mostrarTablero = false),
              ),
            ),
        ],
      ),
    );
  }
}

class _WinnerCardGenerala extends StatelessWidget {
  const _WinnerCardGenerala({
    required this.ganador,
    required this.pulso,
    required this.onEstadisticas,
    required this.onVolverAJugar,
    required this.onVolver,
    required this.subtitulo,
    this.animaciones = true,
  });

  final String ganador;
  final AnimationController pulso;
  final VoidCallback onEstadisticas;
  final VoidCallback onVolverAJugar;
  final VoidCallback onVolver;
  final String subtitulo;
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

class _StatsRankingPanel extends StatelessWidget {
  const _StatsRankingPanel({
    required this.partida,
    required this.ganador,
    required this.onSeleccionar,
    required this.onVerTablero,
    required this.onCerrar,
    required this.onVolver,
  });

  final PartidaGenerala partida;
  final String ganador;
  final ValueChanged<JugadorGenerala> onSeleccionar;
  final VoidCallback onVerTablero;
  final VoidCallback onCerrar;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    final ranking = [...partida.jugadores]
      ..sort((a, b) => b.total.compareTo(a.total));

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1450), Color(0xFF12081F)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.azul, width: 2),
        boxShadow: neonGlow(AppColors.azul, blur: 18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onCerrar,
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back, color: AppColors.texto),
              ),
              const Expanded(
                child: Text(
                  'ESTADÍSTICAS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: AppColors.acento,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const Text(
            'Elegí un jugador',
            style: TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: ranking.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final j = ranking[i];
                final esGanador = j.nombre == ganador;
                return GlowButtonVictoria(
                  label: '${i + 1}°  ${j.nombre.toUpperCase()}  ·  ${j.total} PTS',
                  icon: esGanador ? Icons.emoji_events : Icons.person,
                  color: esGanador ? AppColors.acento : AppColors.azul,
                  onPressed: () => onSeleccionar(j),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          GlowButtonVictoria(
            label: 'VER TABLERO',
            icon: Icons.grid_view_rounded,
            color: AppColors.violeta,
            onPressed: onVerTablero,
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
}

class _DetalleJugadorPanel extends StatelessWidget {
  const _DetalleJugadorPanel({
    required this.partida,
    required this.jugador,
    required this.ganador,
    required this.onCerrar,
  });

  final PartidaGenerala partida;
  final JugadorGenerala jugador;
  final String ganador;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final color = colorJugadorTablero(partida.jugadores.indexOf(jugador));
    final esGanador = jugador.nombre == ganador;
    final historial = jugador.historial;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1450), Color(0xFF12081F)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color, width: 2),
        boxShadow: neonGlow(color, blur: 18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onCerrar,
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back, color: AppColors.texto),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      jugador.nombre.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (esGanador)
                      const Text(
                        'GANADOR',
                        style: TextStyle(
                          color: AppColors.mint,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          Text(
            '${jugador.total} PTS · ${historial.length} turnos',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: historial.isEmpty
                ? const Center(
                    child: Text(
                      'Sin turnos registrados',
                      style: TextStyle(color: AppColors.textoSuave),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(right: 6, bottom: 4),
                    itemCount: historial.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final r = historial[i];
                      final dadosTxt = r.dadosFinales.join(' · ');
                      final accion = r.puntos > 0
                          ? 'Anotó ${r.categoria.etiqueta} → ${r.puntos} pts'
                          : 'Tachó ${r.categoria.etiqueta} → 0 pts';
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: color.withValues(alpha: 0.45),
                          ),
                          color: color.withValues(alpha: 0.08),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TURNO ${r.numero}',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tiradas usadas: ${r.tiradasUsadas}/$maxTiradasGenerala',
                                style: const TextStyle(
                                  color: AppColors.textoSuave,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Dados finales: $dadosTxt',
                                softWrap: true,
                                style: const TextStyle(
                                  color: AppColors.texto,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                accion,
                                softWrap: true,
                                style: TextStyle(
                                  color: r.puntos > 0
                                      ? AppColors.mint
                                      : AppColors.peligro,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
