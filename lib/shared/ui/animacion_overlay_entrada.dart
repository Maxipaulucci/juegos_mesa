import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/shared/ajustes/ajustes_store.dart';

/// Progreso de entrada compartido por fondo, cartel e ítems internos.
class OverlayEntradaScope extends InheritedWidget {
  const OverlayEntradaScope({
    super.key,
    required this.progreso,
    required this.conAnimacion,
    required super.child,
  });

  final Animation<double> progreso;
  final bool conAnimacion;

  static OverlayEntradaScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<OverlayEntradaScope>();
  }

  @override
  bool updateShouldNotify(OverlayEntradaScope oldWidget) {
    return progreso != oldWidget.progreso ||
        conAnimacion != oldWidget.conAnimacion;
  }
}

/// Animación de entrada para overlays (cuenta, ajustes, menú de partida).
/// El cartel crece desde un cuadrado pequeño al centro; el fondo y los ítems
/// internos usan [OverlayFondoEntrada], [OverlayCartelEntrada] y
/// [OverlayColumnaEntrada] / [OverlayItemEntrada].
class AnimacionOverlayEntrada extends StatefulWidget {
  const AnimacionOverlayEntrada({
    super.key,
    required this.child,
    this.duracion = const Duration(milliseconds: 460),
  });

  final Widget child;
  final Duration duracion;

  @override
  State<AnimacionOverlayEntrada> createState() =>
      _AnimacionOverlayEntradaState();
}

class _AnimacionOverlayEntradaState extends State<AnimacionOverlayEntrada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _progreso;
  late final bool _conAnimacion;

  @override
  void initState() {
    super.initState();
    _conAnimacion = AjustesStore.instance.animaciones;
    _ctrl = AnimationController(
      vsync: this,
      duration: _conAnimacion ? widget.duracion : Duration.zero,
      value: _conAnimacion ? 0 : 1,
    );
    _progreso = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutCubic,
    );
    if (_conAnimacion) {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayEntradaScope(
      progreso: _progreso,
      conAnimacion: _conAnimacion,
      child: widget.child,
    );
  }
}

/// Fondo semitransparente que aparece con fade.
class OverlayFondoEntrada extends StatelessWidget {
  const OverlayFondoEntrada({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = OverlayEntradaScope.maybeOf(context);
    if (scope == null || !scope.conAnimacion) return child;

    return AnimatedBuilder(
      animation: scope.progreso,
      builder: (context, child) {
        final t = const Interval(0, 0.35, curve: Curves.easeOut)
            .transform(scope.progreso.value);
        return Opacity(opacity: t, child: child);
      },
      child: child,
    );
  }
}

/// Cartel central que crece desde un cuadrado pequeño en el centro de la pantalla.
class OverlayCartelEntrada extends StatelessWidget {
  const OverlayCartelEntrada({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = OverlayEntradaScope.maybeOf(context);
    if (scope == null || !scope.conAnimacion) return child;

    return AnimatedBuilder(
      animation: scope.progreso,
      builder: (context, child) {
        final t = const Interval(0, 0.62, curve: Curves.easeOutCubic)
            .transform(scope.progreso.value);
        final escala = lerpDouble(0.06, 1, t)!;
        return Transform.scale(
          scale: escala,
          alignment: Alignment.center,
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Aplica fade escalonado a cada hijo de una columna de menú.
class OverlayColumnaEntrada extends StatelessWidget {
  const OverlayColumnaEntrada({
    super.key,
    required this.children,
    this.mainAxisSize = MainAxisSize.min,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.start,
  });

  final List<Widget> children;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final total = children.length;
    return Column(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      children: [
        for (var i = 0; i < total; i++)
          OverlayItemEntrada(
            indice: i,
            total: total,
            child: children[i],
          ),
      ],
    );
  }
}

/// Un bloque dentro del cartel que aparece con fade progresivo.
class OverlayItemEntrada extends StatelessWidget {
  const OverlayItemEntrada({
    super.key,
    required this.indice,
    required this.total,
    required this.child,
  });

  final int indice;
  final int total;
  final Widget child;

  static List<Widget> lista(List<Widget> hijos) {
    final n = hijos.length;
    return List.generate(
      n,
      (i) => OverlayItemEntrada(indice: i, total: n, child: hijos[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = OverlayEntradaScope.maybeOf(context);
    if (scope == null || !scope.conAnimacion || total <= 0) return child;

    return AnimatedBuilder(
      animation: scope.progreso,
      builder: (context, child) {
        final opacidad = _opacidadItem(scope.progreso.value, indice, total);
        return Opacity(opacity: opacidad, child: child);
      },
      child: child,
    );
  }

  static double _opacidadItem(double progreso, int indice, int total) {
    const inicio = 0.28;
    const ventana = 0.72;
    final paso = ventana / total;
    final t0 = inicio + indice * paso;
    final t1 = t0 + paso * 0.92;
    if (progreso <= t0) return 0;
    if (progreso >= t1) return 1;
    return ((progreso - t0) / (t1 - t0)).clamp(0.0, 1.0);
  }
}
