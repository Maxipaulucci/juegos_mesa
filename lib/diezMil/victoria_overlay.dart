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
  });

  final String ganador;
  final EstadisticasPartida estadisticas;
  final VoidCallback onVolver;

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
                      child: _mostrarStats
                          ? _StatsPanel(
                              estadisticas: widget.estadisticas,
                              ganador: widget.ganador,
                              onCerrar: () =>
                                  setState(() => _mostrarStats = false),
                              onVolver: widget.onVolver,
                            )
                          : _WinnerCard(
                              ganador: widget.ganador,
                              pulso: _pulso,
                              onEstadisticas: () =>
                                  setState(() => _mostrarStats = true),
                              onVolver: widget.onVolver,
                            ),
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
  });

  final String ganador;
  final AnimationController pulso;
  final VoidCallback onEstadisticas;
  final VoidCallback onVolver;

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
          const Text(
            'llegó a 10.000 y se lleva la partida',
            textAlign: TextAlign.center,
            style: TextStyle(
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

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({
    required this.estadisticas,
    required this.ganador,
    required this.onCerrar,
    required this.onVolver,
  });

  final EstadisticasPartida estadisticas;
  final String ganador;
  final VoidCallback onCerrar;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    final jugadores = estadisticas.porJugador.values.toList();

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
          Text(
            'Ganó: $ganador',
            style: const TextStyle(
              color: AppColors.mint,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: jugadores.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final e = jugadores[i];
                final esGanador = e.nombre == ganador;
                final accent =
                    esGanador ? AppColors.acento : AppColors.azul;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.carta.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.8),
                      width: esGanador ? 2 : 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            esGanador
                                ? Icons.emoji_events
                                : Icons.person,
                            color: accent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.nombre.toUpperCase(),
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (esGanador)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.acento,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'GANADOR',
                                style: TextStyle(
                                  color: Color(0xFF1A0A00),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _StatPill(
                            label: 'TOTALES',
                            valor: '${e.tirosTotales}',
                            color: AppColors.texto,
                          ),
                          const SizedBox(width: 6),
                          _StatPill(
                            label: 'SUMÓ',
                            valor: '${e.tirosConPuntos}',
                            color: AppColors.mint,
                          ),
                          const SizedBox(width: 6),
                          _StatPill(
                            label: 'NO SUMÓ',
                            valor: '${e.tirosSinPuntos}',
                            color: AppColors.peligro,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tiradas:',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textoSuave,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (e.tiradas.isEmpty)
                        const Text(
                          'Sin tiradas registradas',
                          style: TextStyle(color: AppColors.textoSuave),
                        )
                      else
                        ...e.tiradas.map(
                          (t) => Padding(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
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
              boxShadow: neonGlow(color, blur: 12),
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
