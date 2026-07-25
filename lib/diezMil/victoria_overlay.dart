import 'dart:math' as math;

import 'package:flutter/material.dart';

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
    this.subtitulo,
  });

  final String ganador;
  final EstadisticasPartida estadisticas;
  final VoidCallback onVolver;
  /// Si viene de una rendición: p.ej. "Jugador 1 se ha rendido".
  final String? subtitulo;

  @override
  State<VictoriaOverlay> createState() => _VictoriaOverlayState();
}

class _VictoriaOverlayState extends State<VictoriaOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _entrada;
  late final AnimationController _pulso;
  late final AnimationController _confeti;
  late final Animation<double> _escala;
  late final Animation<double> _opacidad;
  bool _mostrarStats = false;
  String? _statsJugador;

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
    _confeti = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
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

  Widget _construirContenido() {
    if (!_mostrarStats) {
      return _WinnerCard(
        ganador: widget.ganador,
        pulso: _pulso,
        subtitulo: widget.subtitulo,
        onEstadisticas: () => setState(() {
          _mostrarStats = true;
          _statsJugador = null;
        }),
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
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _confeti,
              builder: (_, __) => CustomPaint(
                painter: _ConfetiPainter(progreso: _confeti.value),
              ),
            ),
          ),
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
    );
  }
}

class _WinnerCard extends StatelessWidget {
  const _WinnerCard({
    required this.ganador,
    required this.pulso,
    required this.onEstadisticas,
    required this.onVolver,
    this.subtitulo,
  });

  final String ganador;
  final AnimationController pulso;
  final VoidCallback onEstadisticas;
  final VoidCallback onVolver;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulso,
      builder: (context, child) {
        final glow = 14 + pulso.value * 18;
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
          child: child,
        );
      },
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
            subtitulo ?? 'llegó a 10.000 y se lleva la partida',
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

class _ConfetiPiece {
  _ConfetiPiece(math.Random rng, Size size)
      : x = rng.nextDouble() * size.width,
        y0 = -20 - rng.nextDouble() * size.height,
        w = 6 + rng.nextDouble() * 8,
        h = 8 + rng.nextDouble() * 12,
        speed = 0.35 + rng.nextDouble() * 0.9,
        spin = rng.nextDouble() * math.pi * 2,
        spinSpeed = (rng.nextDouble() - 0.5) * 8,
        color = [
          AppColors.acento,
          AppColors.azul,
          AppColors.rosa,
          AppColors.mint,
          AppColors.violeta,
          Colors.white,
        ][rng.nextInt(6)];

  final double x;
  final double y0;
  final double w;
  final double h;
  final double speed;
  final double spin;
  final double spinSpeed;
  final Color color;
}

class _ConfetiPainter extends CustomPainter {
  _ConfetiPainter({required this.progreso});

  final double progreso;
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
    for (final p in _pieces!) {
      final y = (p.y0 + progreso * size.height * (1.4 + p.speed)) %
          (size.height + 40);
      final angulo = p.spin + progreso * p.spinSpeed;
      canvas.save();
      canvas.translate(p.x, y);
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
      oldDelegate.progreso != progreso;
}
