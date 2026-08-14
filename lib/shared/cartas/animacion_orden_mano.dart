import 'package:flutter/material.dart';

/// Duración del deslizamiento al ordenar la mano (similar al hueco de reorden).
const Duration kDuracionAnimacionOrdenMano = Duration(milliseconds: 380);

/// Curva suave, alineada al reorden manual.
const Curve kCurvaAnimacionOrdenMano = Curves.easeOutCubic;

/// Desplazamiento X inicial de cada carta para animar desde el orden [antes]
/// hacia el orden [despues] (pintando ya en el orden nuevo).
///
/// Cada id empieza en `(índiceViejo - índiceNuevo) * paso` y debe animarse a 0.
///
/// Importante: [antes] debe ser una **copia** del orden previo. Si se ordena
/// la lista in-place, no uses la misma referencia como [antes] y [despues].
Map<Object, double> deltasInicioOrdenMano({
  required List<Object> antes,
  required List<Object> despues,
  required double paso,
}) {
  if (antes.length != despues.length || paso == 0) return const {};
  final mapa = <Object, double>{};
  for (var nuevo = 0; nuevo < despues.length; nuevo++) {
    final id = despues[nuevo];
    final viejo = antes.indexOf(id);
    if (viejo < 0 || viejo == nuevo) continue;
    mapa[id] = (viejo - nuevo) * paso;
  }
  return mapa;
}

/// Desliza [child] desde [dxInicial] hasta 0 (animación de reacomodo).
///
/// Misma técnica que el hueco del reorden manual ([AnimatedContainer] +
/// transform). Poné un [Key] distinto por carta y generación en el padre
/// para reiniciar el deslizamiento en cada ordenado.
class CartaDeslizOrdenMano extends StatefulWidget {
  const CartaDeslizOrdenMano({
    super.key,
    required this.dxInicial,
    required this.child,
    this.animaciones = true,
    this.duration = kDuracionAnimacionOrdenMano,
    this.curve = kCurvaAnimacionOrdenMano,
  });

  final double dxInicial;
  final Widget child;
  final bool animaciones;
  final Duration duration;
  final Curve curve;

  @override
  State<CartaDeslizOrdenMano> createState() => _CartaDeslizOrdenManoState();
}

class _CartaDeslizOrdenManoState extends State<CartaDeslizOrdenMano> {
  late double _dx;
  bool _activo = false;

  @override
  void initState() {
    super.initState();
    _iniciarSiCorresponde();
  }

  void _iniciarSiCorresponde() {
    if (!widget.animaciones || widget.dxInicial == 0) {
      _dx = 0;
      _activo = false;
      return;
    }
    _dx = widget.dxInicial;
    _activo = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_activo) return;
      setState(() => _dx = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_activo) return widget.child;
    return AnimatedContainer(
      duration: widget.duration,
      curve: widget.curve,
      transform: Matrix4.translationValues(_dx, 0, 0),
      onEnd: () {
        if (!mounted) return;
        setState(() => _activo = false);
      },
      child: widget.child,
    );
  }
}
