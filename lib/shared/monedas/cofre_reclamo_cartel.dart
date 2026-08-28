import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/shared/formato/numero_formato.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Cartel con animación de cofre cayendo, abriéndose y monedas subiendo.
class CartelCofreReclamado extends StatefulWidget {
  const CartelCofreReclamado({
    super.key,
    required this.etiqueta,
    required this.assetCerrado,
    required this.assetAbierto,
    required this.monedas,
  });

  final String etiqueta;
  final String assetCerrado;
  final String assetAbierto;
  final int monedas;

  @override
  State<CartelCofreReclamado> createState() => _CartelCofreReclamadoState();
}

class _CartelCofreReclamadoState extends State<CartelCofreReclamado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _caida;
  late final Animation<double> _agitarX;
  late final Animation<double> _agitarRot;
  late final Animation<double> _aperturaEscala;
  late final Animation<double> _monedasOpacidad;
  late final Animation<Offset> _monedasDesplazamiento;
  late final Animation<int> _contador;
  late final Animation<double> _particulasProgreso;

  bool _listoParaCerrar = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _listoParaCerrar = true);
        }
      });

    _caida = Tween<double>(begin: -150, end: 0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.28, curve: Curves.bounceOut),
      ),
    );

    _agitarX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -7), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -7, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 5), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5, end: -3), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -3, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.28, 0.48, curve: Curves.easeInOut),
      ),
    );

    _agitarRot = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -0.06), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.06, end: 0.07), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.07, end: -0.05), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.04), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.04, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.28, 0.48, curve: Curves.easeInOut),
      ),
    );

    _aperturaEscala = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 65),
    ]).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.48, 0.62, curve: Curves.easeOut),
      ),
    );

    _monedasOpacidad = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.58, 0.72, curve: Curves.easeOut),
      ),
    );

    _monedasDesplazamiento = Tween<Offset>(
      begin: const Offset(0, 28),
      end: const Offset(0, -18),
    ).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.62, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _contador = IntTween(begin: 0, end: widget.monedas).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.62, 0.95, curve: Curves.easeOutCubic),
      ),
    );

    _particulasProgreso = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.carta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      content: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          final abierto = t >= 0.48;
          final enAgite = t >= 0.28 && t < 0.48;
          final escalaCofre = abierto ? _aperturaEscala.value : 1.0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '¡Cofre de ${widget.etiqueta}!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.acento,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                width: 200,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Transform.translate(
                      offset: Offset(
                        enAgite ? _agitarX.value : 0,
                        _caida.value,
                      ),
                      child: Transform.rotate(
                        angle: enAgite ? _agitarRot.value : 0,
                        child: Transform.scale(
                          scale: escalaCofre,
                          child: Image.asset(
                            abierto
                                ? widget.assetAbierto
                                : widget.assetCerrado,
                            width: 120,
                            height: 110,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                    ),
                    if (_monedasOpacidad.value > 0)
                      ..._particulasMonedas(_particulasProgreso.value),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Opacity(
                opacity: _monedasOpacidad.value,
                child: Transform.translate(
                  offset: _monedasDesplazamiento.value,
                  child: _ContadorMonedasSubiendo(
                    cantidad: _contador.value,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: _listoParaCerrar
              ? () => Navigator.of(context).pop()
              : null,
          child: Text(
            '¡Genial!',
            style: TextStyle(
              color: _listoParaCerrar
                  ? AppColors.acento
                  : AppColors.textoSuave.withValues(alpha: 0.5),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _particulasMonedas(double progreso) {
    const cantidad = 7;
    return List.generate(cantidad, (i) {
      final angulo = (i / cantidad) * math.pi * 2;
      final radio = 12 + progreso * 38;
      final subida = progreso * 58;
      final opacidad = (1 - progreso).clamp(0.0, 1.0);
      return Transform.translate(
        offset: Offset(
          math.cos(angulo) * radio,
          -subida + math.sin(angulo) * radio * 0.25,
        ),
        child: Opacity(
          opacity: opacidad,
          child: Icon(
            Icons.monetization_on_rounded,
            size: 14 + (i % 3) * 2,
            color: AppColors.acento,
          ),
        ),
      );
    });
  }
}

class _ContadorMonedasSubiendo extends StatelessWidget {
  const _ContadorMonedasSubiendo({
    required this.cantidad,
  });

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.fondoSuave.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.acento.withValues(alpha: 0.85),
          width: 1.4,
        ),
        boxShadow: neonGlow(AppColors.acento, blur: 10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.monetization_on_rounded,
            color: AppColors.acento,
            size: 28,
          ),
          const SizedBox(width: 8),
          Text(
            formatoMonedasGanadas(cantidad),
            style: const TextStyle(
              color: AppColors.acento,
              fontWeight: FontWeight.w900,
              fontSize: 28,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'monedas',
            style: TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> mostrarCartelCofreReclamado(
  BuildContext context, {
  required String etiqueta,
  required String assetCerrado,
  required String assetAbierto,
  required int monedas,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CartelCofreReclamado(
      etiqueta: etiqueta,
      assetCerrado: assetCerrado,
      assetAbierto: assetAbierto,
      monedas: monedas,
    ),
  );
}
