import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Duración mínima visible de la pantalla de carga entre menús / partidas.
const Duration duracionCargaMinima = Duration(milliseconds: 2500);

/// Pausa con la barra al 100% antes de quitar el overlay.
const Duration pausaTrasCienPorCiento = Duration(milliseconds: 200);

/// Navega mostrando [PantallaCarga] encima mientras, en segundo plano,
/// se construye / prepara el destino. Solo quita la carga cuando la barra
/// llegó al 100% **y** la preparación terminó.
///
/// - [replace]: usa [Navigator.pushReplacement] (p. ej. lobby → partida).
/// - [preparar]: trabajo extra en paralelo (assets, red, etc.).
/// - Devuelve el mismo future que el `push` (se completa al volver atrás).
Future<T?> navegarConCarga<T extends Object?>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool replace = false,
  Duration minimo = duracionCargaMinima,
  String mensaje = 'Cargando',
  Color? acento,
  Future<void> Function()? preparar,
}) async {
  final overlayState = Overlay.maybeOf(context, rootOverlay: true);
  if (overlayState == null) {
    if (preparar != null) await preparar();
    if (!context.mounted) return null;
    final route = MaterialPageRoute<T>(builder: builder);
    return replace
        ? Navigator.of(context).pushReplacement(route)
        : Navigator.of(context).push(route);
  }

  final barraListo = Completer<void>();
  final entry = OverlayEntry(
    builder: (_) => AbsorbPointer(
      child: PantallaCarga(
        mensaje: mensaje,
        acento: acento,
        duracion: minimo,
        onBarraCompleta: () {
          if (!barraListo.isCompleted) barraListo.complete();
        },
      ),
    ),
  );
  overlayState.insert(entry);

  // Un frame para pintar la carga antes del trabajo pesado.
  await Future<void>.delayed(Duration.zero);
  await WidgetsBinding.instance.endOfFrame;

  if (!context.mounted) {
    entry.remove();
    return null;
  }

  Future<T?>? viaje;

  try {
    // Segundo plano: preparar + montar el destino (initState, layout, etc.).
    final prep = () async {
      if (preparar != null) await preparar();
      if (!context.mounted) return;

      final nav = Navigator.of(context);
      viaje = replace
          ? nav.pushReplacement(MaterialPageRoute<T>(builder: builder))
          : nav.push(MaterialPageRoute<T>(builder: builder));

      // La ruta nueva queda debajo: el overlay vuelve arriba.
      if (entry.mounted) entry.remove();
      overlayState.insert(entry);

      // Dejar que el juego termine de construir / inicializar.
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(Duration.zero);
      await WidgetsBinding.instance.endOfFrame;
    }();

    await Future.wait<void>([barraListo.future, prep]);

    // El jugador ve el 100% un instante antes de pasar.
    await Future<void>.delayed(pausaTrasCienPorCiento);

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
    this.onBarraCompleta,
  });

  final String mensaje;
  final Color? acento;
  final Duration duracion;
  /// Se llama cuando la barra llega al 100%.
  final VoidCallback? onBarraCompleta;

  @override
  State<PantallaCarga> createState() => _PantallaCargaState();
}

class _PantallaCargaState extends State<PantallaCarga>
    with TickerProviderStateMixin {
  late final AnimationController _barra;
  late final AnimationController _pulso;
  late final AnimationController _orbit;
  /// Un solo pase: dado → cartas → tablero a lo largo de la carga.
  late final AnimationController _cicloIconos;
  int _faseIcono = 0;
  bool _avisoCompleto = false;

  void _avisarCompleto() {
    if (_avisoCompleto) return;
    _avisoCompleto = true;
    widget.onBarraCompleta?.call();
  }

  int _faseDe(double v) {
    // [0,1/3) dado · [1/3,2/3) cartas · [2/3,1] tablero
    if (v >= 1.0) return 2;
    return (v * 3).floor().clamp(0, 2);
  }

  @override
  void initState() {
    super.initState();
    _barra = AnimationController(vsync: this, duration: widget.duracion);
    _barra.addStatusListener((status) {
      if (status == AnimationStatus.completed) _avisarCompleto();
    });
    _barra.forward();
    _pulso = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    // Misma duración que la barra: cada ícono una sola vez (~1/3 c/u).
    _cicloIconos = AnimationController(
      vsync: this,
      duration: widget.duracion,
    )..forward();
    _cicloIconos.addListener(() {
      final nueva = _faseDe(_cicloIconos.value);
      if (nueva != _faseIcono && mounted) {
        setState(() => _faseIcono = nueva);
      }
    });
  }

  @override
  void dispose() {
    _barra.dispose();
    _pulso.dispose();
    _orbit.dispose();
    _cicloIconos.dispose();
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
                        child: _CirculoMesa(
                          acento: acento,
                          fase: _faseIcono,
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

/// Círculo único que alterna: dado → cartas → tablero.
class _CirculoMesa extends StatelessWidget {
  const _CirculoMesa({required this.acento, required this.fase});

  final Color acento;
  /// 0 = dado, 1 = cartas, 2 = tablero.
  final int fase;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(anim),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(fase),
          child: Center(
            child: switch (fase) {
              1 => const _CartasEnCirculo(),
              2 => const _TableroEnCirculo(),
              _ => const Icon(
                  Icons.casino_rounded,
                  size: 42,
                  color: Color(0xFF1A0A00),
                ),
            },
          ),
        ),
      ),
    );
  }
}

class _CartasEnCirculo extends StatelessWidget {
  const _CartasEnCirculo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -0.28,
            child: const _CartaMini(
              pip: 'A',
              suitColor: Color(0xFF1A0A00),
            ),
          ),
          Transform.translate(
            offset: const Offset(8, -2),
            child: Transform.rotate(
              angle: 0.24,
              child: const _CartaMini(
                pip: '7',
                suitColor: Color(0xFF1A0A00),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaMini extends StatelessWidget {
  const _CartaMini({
    required this.pip,
    required this.suitColor,
  });

  final String pip;
  final Color suitColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: const Color(0xFF1A0A00).withValues(alpha: 0.55),
        border: Border.all(
          color: const Color(0xFF1A0A00),
          width: 1.4,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            pip,
            style: TextStyle(
              color: suitColor,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              height: 1,
            ),
          ),
          Icon(
            Icons.style_rounded,
            size: 11,
            color: suitColor.withValues(alpha: 0.9),
          ),
        ],
      ),
    );
  }
}

class _TableroEnCirculo extends StatelessWidget {
  const _TableroEnCirculo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: CustomPaint(
        painter: _TableroPainter(),
      ),
    );
  }
}

class _TableroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const color = Color(0xFF1A0A00);
    final borde = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final relleno = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final linea = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      const Radius.circular(5),
    );
    canvas.drawRRect(rect, relleno);
    canvas.drawRRect(rect, borde);

    // Cuadrícula 4×4 en el centro.
    const celdas = 4;
    final pad = size.width * 0.14;
    final area = Rect.fromLTRB(pad, pad, size.width - pad, size.height - pad);
    final pasoX = area.width / celdas;
    final pasoY = area.height / celdas;

    for (var i = 0; i <= celdas; i++) {
      final x = area.left + pasoX * i;
      final y = area.top + pasoY * i;
      canvas.drawLine(Offset(x, area.top), Offset(x, area.bottom), linea);
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), linea);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
