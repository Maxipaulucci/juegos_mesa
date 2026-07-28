import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_theme.dart';
import 'estadisticas.dart';

String _pts(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Cartel de victoria con confeti + botón de estadísticas.
class VictoriaOverlay extends StatefulWidget {
  const VictoriaOverlay({
    super.key,
    required this.ganador,
    required this.estadisticas,
    required this.onVolver,
    required this.onVolverAJugar,
    this.subtitulo,
    this.animaciones = true,
  });

  final String ganador;
  final EstadisticasPartida estadisticas;
  final VoidCallback onVolver;
  final VoidCallback onVolverAJugar;
  /// Si viene de una rendición: p.ej. "Has ganado por abandono".
  final String? subtitulo;
  final bool animaciones;

  @override
  State<VictoriaOverlay> createState() => _VictoriaOverlayState();
}

class _VictoriaOverlayState extends State<VictoriaOverlay>
    with TickerProviderStateMixin {
  /// El reloj del confeti avanza en segundos reales durante una hora.
  static const int _cicloConfetiSegundos = 3600;

  late final AnimationController _entrada;
  late final AnimationController _pulso;
  late final AnimationController _confeti;
  late final Animation<double> _escala;
  late final Animation<double> _opacidad;
  bool _mostrarStats = false;
  String? _statsJugador;
  /// false = se ve el fondo de la partida; el cartel se oculta.
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
    // Reloj continuo en segundos: nunca vuelve a cero, así el confeti no
    // reaparece de golpe en las mismas posiciones.
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
    if (!_mostrarStats) {
      return _WinnerCard(
        ganador: widget.ganador,
        pulso: _pulso,
        animaciones: widget.animaciones,
        subtitulo: widget.subtitulo,
        onEstadisticas: () => setState(() {
          _mostrarStats = true;
          _statsJugador = null;
        }),
        onVolverAJugar: widget.onVolverAJugar,
        onVolver: widget.onVolver,
      );
    }

    if (_statsJugador == null) {
      return _StatsSelector(
        jugadores: widget.estadisticas.porJugador.keys.toList(),
        ganador: widget.ganador,
        onSeleccionar: (nombre) =>
            setState(() => _statsJugador = nombre),
        onCerrar: () => setState(() => _mostrarStats = false),
        onVolver: widget.onVolver,
      );
    }

    final jugador = widget.estadisticas.de(_statsJugador!);
    return _StatsPanel(
      jugador: jugador!,
      ganador: widget.ganador,
      onCerrar: () => setState(() => _statsJugador = null),
      onVolver: widget.onVolver,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Con el cartel oculto (ojo), los toques pasan al menú/ajustes de fondo.
        IgnorePointer(
          ignoring: !_cartelVisible,
          child: Material(
            color: _cartelVisible
                ? Colors.black.withValues(alpha: 0.72)
                : Colors.transparent,
            child: Stack(
              children: [
                // Confeti / fuegos siguen aunque el cartel se oculte.
                if (widget.animaciones) ...[
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _confeti,
                        builder: (_, __) => CustomPaint(
                          painter: _ConfetiPainter(tiempo: _confeti.value),
                        ),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: IgnorePointer(child: _FuegosArtificialesCapa()),
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
        // Fijo arriba-centro (sobre el título DIEZ MIL).
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _BotonOjoVictoria(
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

/// Ojo sutil (violeta) encima del cartel para ver el fondo.
class _BotonOjoVictoria extends StatelessWidget {
  const _BotonOjoVictoria({
    required this.cartelVisible,
    required this.onTap,
  });

  final bool cartelVisible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.violeta.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            cartelVisible
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            color: AppColors.violeta.withValues(alpha: 0.85),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _WinnerCard extends StatelessWidget {
  const _WinnerCard({
    required this.ganador,
    required this.pulso,
    required this.onEstadisticas,
    required this.onVolverAJugar,
    required this.onVolver,
    this.subtitulo,
    this.animaciones = true,
  });

  final String ganador;
  final AnimationController pulso;
  final VoidCallback onEstadisticas;
  final VoidCallback onVolverAJugar;
  final VoidCallback onVolver;
  final String? subtitulo;
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
              subtitulo ?? 'Llegó a 10.000 y se lleva la partida',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textoSuave,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            _GlowButton(
              label: 'ESTADÍSTICAS',
              icon: Icons.bar_chart_rounded,
              color: AppColors.azul,
              onPressed: onEstadisticas,
            ),
            const SizedBox(height: 10),
            _GlowButton(
              label: 'VOLVER A JUGAR',
              icon: Icons.replay_rounded,
              color: AppColors.mint,
              onPressed: onVolverAJugar,
            ),
            const SizedBox(height: 10),
            _GlowButton(
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

/// Paso 1: elegir de qué jugador ver las estadísticas.
class _StatsSelector extends StatelessWidget {
  const _StatsSelector({
    required this.jugadores,
    required this.ganador,
    required this.onSeleccionar,
    required this.onCerrar,
    required this.onVolver,
  });

  final List<String> jugadores;
  final String ganador;
  final ValueChanged<String> onSeleccionar;
  final VoidCallback onCerrar;
  final VoidCallback onVolver;

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
              const Expanded(
                child: Text(
                  'ESTADÍSTICAS',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: AppColors.acento,
                  ),
                ),
              ),
              IconButton(
                onPressed: onCerrar,
                icon: const Icon(Icons.close, color: AppColors.texto),
              ),
            ],
          ),
          const Text(
            'Elegí un jugador',
            style: TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < jugadores.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _GlowButton(
                      label: jugadores[i].toUpperCase(),
                      icon: jugadores[i] == ganador
                          ? Icons.emoji_events
                          : Icons.person,
                      color: jugadores[i] == ganador
                          ? AppColors.acento
                          : AppColors.azul,
                      onPressed: () => onSeleccionar(jugadores[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _GlowButton(
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

/// Paso 2: estadísticas de un jugador concreto.
class _StatsPanel extends StatelessWidget {
  const _StatsPanel({
    required this.jugador,
    required this.ganador,
    required this.onCerrar,
    required this.onVolver,
  });

  final EstadisticasJugador jugador;
  final String ganador;
  final VoidCallback onCerrar;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    final esGanador = jugador.nombre == ganador;
    final accent = esGanador ? AppColors.acento : AppColors.azul;

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
        border: Border.all(color: accent, width: 2),
        boxShadow: neonGlow(accent, blur: 18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onCerrar,
                icon: const Icon(Icons.arrow_back, color: AppColors.texto),
                tooltip: 'Elegir otro jugador',
              ),
              Expanded(
                child: Text(
                  jugador.nombre.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          if (esGanador)
            const Text(
              'GANADOR',
              style: TextStyle(
                color: AppColors.mint,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatPill(
                label: 'TOTALES',
                valor: '${jugador.tirosTotales}',
                color: AppColors.texto,
              ),
              const SizedBox(width: 6),
              _StatPill(
                label: 'SUMÓ',
                valor: '${jugador.tirosConPuntos}',
                color: AppColors.mint,
              ),
              const SizedBox(width: 6),
              _StatPill(
                label: 'NO SUMÓ',
                valor: '${jugador.tirosSinPuntos}',
                color: AppColors.peligro,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Tiradas:',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textoSuave,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: jugador.tiradas.isEmpty
                ? const Center(
                    child: Text(
                      'Sin tiradas registradas',
                      style: TextStyle(color: AppColors.textoSuave),
                    ),
                  )
                : ListView.builder(
                    itemCount: jugador.tiradas.length,
                    itemBuilder: (context, i) {
                      final t = jugador.tiradas[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 78,
                              child: Text(
                                'Tirada ${t.numero}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                t.sumo
                                    ? '+${_pts(t.puntos)} pts'
                                    : '0 pts (no sumó)',
                                style: TextStyle(
                                  color: t.sumo
                                      ? AppColors.mint
                                      : AppColors.peligro,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
          _GlowButton(
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

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.valor,
    required this.color,
  });

  final String label;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Column(
          children: [
            Text(
              valor,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.85),
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowButton extends StatelessWidget {
  const _GlowButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: neonGlow(color, blur: 12),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white24,
            highlightColor: Colors.white10,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.95),
                    color.withValues(alpha: 0.65),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Explosiones Lottie en posiciones/escalas/retardos aleatorios.
class _FuegosArtificialesCapa extends StatefulWidget {
  const _FuegosArtificialesCapa();

  static const _assets = [
    'assets/lottie/fireworks_a.json',
    'assets/lottie/fireworks_b.json',
    'assets/lottie/fireworks_c.json',
  ];

  @override
  State<_FuegosArtificialesCapa> createState() =>
      _FuegosArtificialesCapaState();
}

class _FuegoBurst {
  _FuegoBurst({
    required this.id,
    required this.asset,
    required this.leftFrac,
    required this.topFrac,
    required this.size,
    required this.delay,
  });

  final Key id;
  final String asset;
  final double leftFrac;
  final double topFrac;
  final double size;
  final Duration delay;
}

class _FuegosArtificialesCapaState extends State<_FuegosArtificialesCapa> {
  final _rng = math.Random();
  late List<_FuegoBurst> _bursts;

  @override
  void initState() {
    super.initState();
    _bursts = List.generate(5, (_) => _nuevoBurst());
  }

  _FuegoBurst _nuevoBurst() {
    // Zonas fuera del cartel central: arriba, abajo, izquierda o derecha.
    final zona = _rng.nextInt(4);
    late final double leftFrac;
    late final double topFrac;

    switch (zona) {
      case 0: // arriba
        leftFrac = -0.05 + _rng.nextDouble() * 0.85;
        topFrac = -0.08 + _rng.nextDouble() * 0.14;
      case 1: // abajo
        leftFrac = -0.05 + _rng.nextDouble() * 0.85;
        topFrac = 0.72 + _rng.nextDouble() * 0.18;
      case 2: // izquierda
        leftFrac = -0.12 + _rng.nextDouble() * 0.18;
        topFrac = 0.08 + _rng.nextDouble() * 0.58;
      default: // derecha
        leftFrac = 0.72 + _rng.nextDouble() * 0.22;
        topFrac = 0.08 + _rng.nextDouble() * 0.58;
    }

    return _FuegoBurst(
      id: UniqueKey(),
      asset: _FuegosArtificialesCapa
          ._assets[_rng.nextInt(_FuegosArtificialesCapa._assets.length)],
      leftFrac: leftFrac,
      topFrac: topFrac,
      size: 140 + _rng.nextDouble() * 130,
      delay: Duration(milliseconds: _rng.nextInt(700)),
    );
  }

  void _reemplazar(Key id) {
    if (!mounted) return;
    setState(() {
      final i = _bursts.indexWhere((b) => b.id == id);
      if (i >= 0) _bursts[i] = _nuevoBurst();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Stack(
      children: [
        for (final burst in _bursts)
          Positioned(
            left: burst.leftFrac * size.width,
            top: burst.topFrac * size.height,
            width: burst.size,
            height: burst.size,
            child: _FuegoLottie(
              key: burst.id,
              asset: burst.asset,
              delay: burst.delay,
              onFinished: () => _reemplazar(burst.id),
            ),
          ),
      ],
    );
  }
}

class _FuegoLottie extends StatefulWidget {
  const _FuegoLottie({
    super.key,
    required this.asset,
    required this.delay,
    required this.onFinished,
  });

  final String asset;
  final Duration delay;
  final VoidCallback onFinished;

  @override
  State<_FuegoLottie> createState() => _FuegoLottieState();
}

class _FuegoLottieState extends State<_FuegoLottie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _listo = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _reproducir(LottieComposition composition) async {
    if (_listo) return;
    _listo = true;
    _ctrl.duration = composition.duration;
    if (widget.delay > Duration.zero) {
      await Future<void>.delayed(widget.delay);
      if (!mounted) return;
    }
    try {
      await _ctrl.forward(from: 0);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    // Pausa corta entre explosiones del mismo slot.
    await Future<void>.delayed(
      Duration(milliseconds: 180 + math.Random().nextInt(420)),
    );
    if (mounted) widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      widget.asset,
      controller: _ctrl,
      fit: BoxFit.contain,
      onLoaded: _reproducir,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

class _ConfetiPiece {
  _ConfetiPiece(math.Random rng, Size size)
      : x = rng.nextDouble() * size.width,
        // Desfase inicial repartido a lo largo del recorrido completo para
        // que las piezas no reaparezcan todas juntas.
        desfase = rng.nextDouble(),
        w = 6 + rng.nextDouble() * 8,
        h = 8 + rng.nextDouble() * 12,
        velocidad = 90 + rng.nextDouble() * 220,
        spin = rng.nextDouble() * math.pi * 2,
        spinSpeed = (rng.nextDouble() - 0.5) * 4,
        derivaAmplitud = 6 + rng.nextDouble() * 26,
        derivaFrecuencia = 0.4 + rng.nextDouble() * 1.1,
        color = [
          AppColors.acento,
          AppColors.azul,
          AppColors.rosa,
          AppColors.mint,
          AppColors.violeta,
          Colors.white,
        ][rng.nextInt(6)];

  final double x;
  final double desfase;
  final double w;
  final double h;
  /// Píxeles por segundo.
  final double velocidad;
  final double spin;
  final double spinSpeed;
  final double derivaAmplitud;
  final double derivaFrecuencia;
  final Color color;
}

class _ConfetiPainter extends CustomPainter {
  _ConfetiPainter({required this.tiempo});

  /// Segundos transcurridos, siempre creciente (evita saltos al reiniciar).
  final double tiempo;
  static List<_ConfetiPiece>? _pieces;
  static Size? _lastSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (_pieces == null || _lastSize != size) {
      final rng = math.Random(42);
      _pieces = List.generate(70, (_) => _ConfetiPiece(rng, size));
      _lastSize = size;
    }

    final paint = Paint();
    final recorrido = size.height + 80;

    for (final p in _pieces!) {
      final avance = p.desfase * recorrido + tiempo * p.velocidad;
      final y = avance % recorrido - 40;
      final x =
          p.x + math.sin(tiempo * p.derivaFrecuencia + p.spin) * p.derivaAmplitud;
      final angulo = p.spin + tiempo * p.spinSpeed;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angulo);
      paint.color = p.color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.w, height: p.h),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfetiPainter oldDelegate) =>
      oldDelegate.tiempo != tiempo;
}
