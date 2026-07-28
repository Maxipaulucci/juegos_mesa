import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'app_theme.dart';

/// Botón con glow usado en carteles de victoria.
class GlowButtonVictoria extends StatelessWidget {
  const GlowButtonVictoria({
    super.key,
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

/// Ojo sutil para ocultar/mostrar el cartel y ver el fondo.
class BotonOjoVictoria extends StatelessWidget {
  const BotonOjoVictoria({
    super.key,
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

/// Explosiones Lottie en posiciones/escalas/retardos aleatorios.
class FuegosArtificialesCapa extends StatefulWidget {
  const FuegosArtificialesCapa({super.key});

  static const assets = [
    'assets/lottie/fireworks_a.json',
    'assets/lottie/fireworks_b.json',
    'assets/lottie/fireworks_c.json',
  ];

  @override
  State<FuegosArtificialesCapa> createState() =>
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

class _FuegosArtificialesCapaState extends State<FuegosArtificialesCapa> {
  final _rng = math.Random();
  late List<_FuegoBurst> _bursts;

  @override
  void initState() {
    super.initState();
    _bursts = List.generate(5, (_) => _nuevoBurst());
  }

  _FuegoBurst _nuevoBurst() {
    final zona = _rng.nextInt(4);
    late final double leftFrac;
    late final double topFrac;

    switch (zona) {
      case 0:
        leftFrac = -0.05 + _rng.nextDouble() * 0.85;
        topFrac = -0.08 + _rng.nextDouble() * 0.14;
      case 1:
        leftFrac = -0.05 + _rng.nextDouble() * 0.85;
        topFrac = 0.72 + _rng.nextDouble() * 0.18;
      case 2:
        leftFrac = -0.12 + _rng.nextDouble() * 0.18;
        topFrac = 0.08 + _rng.nextDouble() * 0.58;
      default:
        leftFrac = 0.72 + _rng.nextDouble() * 0.22;
        topFrac = 0.08 + _rng.nextDouble() * 0.58;
    }

    return _FuegoBurst(
      id: UniqueKey(),
      asset: FuegosArtificialesCapa
          .assets[_rng.nextInt(FuegosArtificialesCapa.assets.length)],
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
  final double velocidad;
  final double spin;
  final double spinSpeed;
  final double derivaAmplitud;
  final double derivaFrecuencia;
  final Color color;
}

/// Confeti cuadrado multicolor que cae de forma continua.
class ConfetiPainter extends CustomPainter {
  ConfetiPainter({required this.tiempo});

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
  bool shouldRepaint(covariant ConfetiPainter oldDelegate) =>
      oldDelegate.tiempo != tiempo;
}
