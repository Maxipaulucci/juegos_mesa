import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/shared/ajustes/ajustes_store.dart';

/// Animación de entrada para overlays (ajustes, cuenta, menú de partida).
/// Fade + ligero deslizamiento hacia arriba.
/// Si las animaciones están desactivadas en ajustes, muestra el contenido al instante.
class AnimacionOverlayEntrada extends StatefulWidget {
  const AnimacionOverlayEntrada({
    super.key,
    required this.child,
    this.duracion = const Duration(milliseconds: 240),
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
  late final Animation<double> _opacidad;
  late final Animation<Offset> _desliz;
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
    final curva = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _opacidad = curva;
    _desliz = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(curva);
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
    if (!_conAnimacion) return widget.child;
    return FadeTransition(
      opacity: _opacidad,
      child: SlideTransition(
        position: _desliz,
        child: widget.child,
      ),
    );
  }
}
