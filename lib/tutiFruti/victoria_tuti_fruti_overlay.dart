import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/theme/victoria_celebration.dart';
import 'package:app_juegos_mesa/tutiFruti/motor_tuti_fruti.dart';

/// Cartel de victoria de Tutti Frutti (confeti + fuegos artificiales).
class VictoriaTutiFrutiOverlay extends StatefulWidget {
  const VictoriaTutiFrutiOverlay({
    super.key,
    required this.partida,
    required this.onVolver,
    this.animaciones = true,
  });

  final PartidaTuti partida;
  final VoidCallback onVolver;
  final bool animaciones;

  @override
  State<VictoriaTutiFrutiOverlay> createState() =>
      _VictoriaTutiFrutiOverlayState();
}

class _VictoriaTutiFrutiOverlayState extends State<VictoriaTutiFrutiOverlay>
    with TickerProviderStateMixin {
  static const int _cicloConfetiSegundos = 3600;

  late final AnimationController _entrada;
  late final AnimationController _pulso;
  late final AnimationController _confeti;
  late final Animation<double> _escala;
  late final Animation<double> _opacidad;

  bool _mostrarRanking = false;
  bool _cartelVisible = true;

  List<MapEntry<String, int>> get _ranking => rankingTuti(widget.partida);

  List<String> get _ganadores {
    final r = _ranking;
    if (r.isEmpty) return const [];
    final top = r.first.value;
    return r.where((e) => e.value == top).map((e) => e.key).toList();
  }

  bool get _empate => _ganadores.length > 1;

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
    if (_mostrarRanking) {
      return _RankingPanel(
        ranking: _ranking,
        ganadores: _ganadores.toSet(),
        onCerrar: () => setState(() => _mostrarRanking = false),
      );
    }

    final pts = _ranking.isEmpty ? 0 : _ranking.first.value;
    final nombres = _ganadores.isEmpty
        ? '—'
        : _ganadores.map((n) => n.toUpperCase()).join('\n');

    return _WinnerCardTuti(
      titulo: _empate ? '¡EMPATE!' : '¡GANADOR!',
      nombres: nombres,
      pulso: _pulso,
      animaciones: widget.animaciones,
      subtitulo: _empate
          ? '$pts PTS · ¡Quedaron a la par!'
          : '$pts PTS · ¡Más puntos y se lleva la partida!',
      onRanking: () => setState(() => _mostrarRanking = true),
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
                if (widget.animaciones) ...[
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
                onTap: () => setState(
                  () => _cartelVisible = !_cartelVisible,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WinnerCardTuti extends StatelessWidget {
  const _WinnerCardTuti({
    required this.titulo,
    required this.nombres,
    required this.pulso,
    required this.subtitulo,
    required this.onRanking,
    required this.onVolver,
    this.animaciones = true,
  });

  final String titulo;
  final String nombres;
  final AnimationController pulso;
  final String subtitulo;
  final VoidCallback onRanking;
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
              child: Text(
                titulo,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              nombres,
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
              label: 'RANKING',
              icon: Icons.emoji_events_rounded,
              color: AppColors.azul,
              onPressed: onRanking,
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

class _RankingPanel extends StatelessWidget {
  const _RankingPanel({
    required this.ranking,
    required this.ganadores,
    required this.onCerrar,
  });

  final List<MapEntry<String, int>> ranking;
  final Set<String> ganadores;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
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
                  'RANKING',
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
          const SizedBox(height: 8),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: ranking.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final e = ranking[i];
                final esGanador = ganadores.contains(e.key);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.carta.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: esGanador
                          ? AppColors.acento
                          : AppColors.cartaBorde,
                      width: esGanador ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '#${i + 1}',
                        style: TextStyle(
                          color: esGanador ? AppColors.acento : AppColors.rosa,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          e.key,
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (esGanador)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Text('🏆', style: TextStyle(fontSize: 18)),
                        ),
                      Text(
                        '${e.value}',
                        style: const TextStyle(
                          color: AppColors.acento,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ],
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
