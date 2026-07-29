import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Duración mínima visible de la pantalla de carga entre menús / partidas.
const Duration duracionCargaMinima = Duration(milliseconds: 1500);

/// Navega mostrando [PantallaCarga] encima (overlay) mientras se construye
/// el destino. Evita el “tranco” al tocar un juego o iniciar partida.
///
/// - [replace]: usa [Navigator.pushReplacement] (p. ej. lobby → partida).
/// - Devuelve el mismo future que el `push` (se completa al volver atrás).
Future<T?> navegarConCarga<T extends Object?>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool replace = false,
  Duration minimo = duracionCargaMinima,
  String mensaje = 'Cargando',
  Color? acento,
}) async {
  final overlayState = Overlay.maybeOf(context, rootOverlay: true);
  if (overlayState == null) {
    final route = MaterialPageRoute<T>(builder: builder);
    return replace
        ? Navigator.of(context).pushReplacement(route)
        : Navigator.of(context).push(route);
  }

  final entry = OverlayEntry(
    builder: (_) => AbsorbPointer(
      child: PantallaCarga(
        mensaje: mensaje,
        acento: acento,
        duracion: minimo,
      ),
    ),
  );
  overlayState.insert(entry);

  final reloj = Stopwatch()..start();
  // Un frame para pintar la carga antes del build pesado del destino.
  await Future<void>.delayed(Duration.zero);
  await WidgetsBinding.instance.endOfFrame;

  if (!context.mounted) {
    entry.remove();
    return null;
  }

  try {
    final nav = Navigator.of(context);
    final Future<T?> viaje = replace
        ? nav.pushReplacement(MaterialPageRoute<T>(builder: builder))
        : nav.push(MaterialPageRoute<T>(builder: builder));

    // La ruta nueva se monta encima del overlay: lo volvemos a poner arriba.
    if (entry.mounted) entry.remove();
    overlayState.insert(entry);

    final resto = minimo - reloj.elapsed;
    if (resto > Duration.zero) {
      await Future<void>.delayed(resto);
    }

    if (entry.mounted) entry.remove();
    return viaje;
  } catch (_) {
    if (entry.mounted) entry.remove();
    rethrow;
  }
}

/// Cartel de carga a pantalla completa: fondo neon + barra animada.
class PantallaCarga extends StatefulWidget {
  const PantallaCarga({
    super.key,
    this.mensaje = 'Cargando',
    this.acento,
    this.duracion = duracionCargaMinima,
  });

  final String mensaje;
  final Color? acento;
  final Duration duracion;

  @override
  State<PantallaCarga> createState() => _PantallaCargaState();
}

class _PantallaCargaState extends State<PantallaCarga>
    with TickerProviderStateMixin {
  late final AnimationController _barra;
  late final AnimationController _pulso;
  late final AnimationController _orbit;

  @override
  void initState() {
    super.initState();
    _barra = AnimationController(vsync: this, duration: widget.duracion)
      ..forward();
    _pulso = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _barra.dispose();
    _pulso.dispose();
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final acento = widget.acento ?? AppColors.acento;
    final size = MediaQuery.sizeOf(context);
    final anchoBarra = (size.width * 0.72).clamp(200.0, 420.0);

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.15,
                colors: [
                  Color(0xFF2E1760),
                  AppColors.fondo,
                  Color(0xFF05020C),
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _orbit,
            builder: (context, _) {
              final t = _orbit.value * math.pi * 2;
              return Stack(
                children: [
                  Positioned(
                    left: size.width * 0.5 + math.cos(t) * size.width * 0.28 - 40,
                    top: size.height * 0.32 + math.sin(t) * 36 - 40,
                    child: _Halo(color: acento, tamano: 80),
                  ),
                  Positioned(
                    left: size.width * 0.5 +
                        math.cos(t + 2.1) * size.width * 0.22 -
                        28,
                    top: size.height * 0.58 + math.sin(t + 2.1) * 48 - 28,
                    child: const _Halo(color: AppColors.azul, tamano: 56),
                  ),
                  Positioned(
                    left: size.width * 0.5 +
                        math.cos(t + 4.2) * size.width * 0.18 -
                        22,
                    top: size.height * 0.42 + math.sin(t + 4.2) * 60 - 22,
                    child: const _Halo(color: AppColors.violeta, tamano: 44),
                  ),
                ],
              );
            },
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pulso,
                        builder: (context, child) {
                          final s = 0.94 + (_pulso.value * 0.06);
                          return Transform.scale(scale: s, child: child);
                        },
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                acento,
                                AppColors.violeta,
                                AppColors.azul,
                              ],
                            ),
                            boxShadow: neonGlow(acento, blur: 22),
                          ),
                          child: const Icon(
                            Icons.casino_rounded,
                            size: 42,
                            color: Color(0xFF1A0A00),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [Colors.white, acento, AppColors.azul],
                        ).createShader(bounds),
                        child: Text(
                          widget.mensaje.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Preparando la mesa…',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textoSuave,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: anchoBarra,
                        child: AnimatedBuilder(
                          animation: _barra,
                          builder: (context, _) {
                            final v = Curves.easeInOutCubic.transform(
                              _barra.value.clamp(0.0, 1.0),
                            );
                            return _BarraCarga(progreso: v, acento: acento);
                          },
                        ),
                      ),
                    ],
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

class _Halo extends StatelessWidget {
  const _Halo({required this.color, required this.tamano});

  final Color color;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.35),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarraCarga extends StatelessWidget {
  const _BarraCarga({required this.progreso, required this.acento});

  final double progreso;
  final Color acento;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: AppColors.carta,
            border: Border.all(color: AppColors.cartaBorde),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth * progreso;
              return Stack(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: w,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            acento,
                            AppColors.rosa,
                            AppColors.azul,
                          ],
                        ),
                        boxShadow: neonGlow(acento, blur: 10),
                      ),
                    ),
                  ),
                  if (progreso > 0.05)
                    Positioned(
                      left: (w - 28).clamp(0.0, constraints.maxWidth),
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: 0.55),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${(progreso * 100).round()}%',
          style: TextStyle(
            color: acento,
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}
