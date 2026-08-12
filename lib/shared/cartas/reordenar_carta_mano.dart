import 'package:flutter/material.dart';

/// Desplazamiento horizontal de una carta al abrir hueco mientras se
/// reordena otra en la misma fila.
///
/// Si se arrastra desde [from] hacia [to]:
/// - a la derecha: las cartas `(from, to]` corren a la izquierda (−[paso]);
/// - a la izquierda: las cartas `[to, from)` corren a la derecha (+[paso]).
double shiftXReordenMano({
  required int index,
  required int? from,
  required int? to,
  required double paso,
}) {
  if (from == null || to == null || from == to) return 0;
  if (from < to) {
    if (index > from && index <= to) return -paso;
  } else {
    if (index >= to && index < from) return paso;
  }
  return 0;
}

/// Índice de inserción según la X local del **borde izquierdo** de la carta
/// que se arrastra (no del dedo), cruzando la mitad de cada slot.
///
/// [origen] es el padding izquierdo cuando la fila está centrada:
/// `max(0, (anchoFila - contenido) / 2)`.
int indiceInsercionReordenMano({
  required double localX,
  required int cantidad,
  required double anchoCarta,
  required double gap,
  required double origen,
}) {
  if (cantidad <= 0) return 0;
  final paso = anchoCarta + gap;
  var idx = 0;
  for (var i = 0; i < cantidad; i++) {
    final mid = origen + i * paso + anchoCarta / 2;
    if (localX < mid) {
      idx = i;
      break;
    }
    idx = i;
  }
  return idx.clamp(0, cantidad - 1);
}

/// Origen X de una fila centrada dentro de [anchoFila].
double origenFilaCentradaReorden({
  required int cantidad,
  required double anchoCarta,
  required double gap,
  required double anchoFila,
}) {
  if (cantidad <= 0) return 0;
  final contenido = cantidad * anchoCarta + (cantidad - 1) * gap;
  final origen = (anchoFila - contenido) / 2;
  return origen < 0 ? 0.0 : origen;
}

/// Estado de arrastre para reordenar una carta en una mano horizontal.
///
/// Uso típico dentro de un [State]:
/// ```dart
/// final _reorden = ReordenarCartaManoDrag();
/// // en onPanStart: _reorden.iniciar(...)
/// // en build: shift = _reorden.shiftX(i, paso)
/// ```
class ReordenarCartaManoDrag {
  ReordenarCartaManoDrag({this.maxDragDy = 16});

  /// Tope de desplazamiento vertical mientras se arrastra (hacia abajo).
  final double maxDragDy;

  int? dragIndex;
  int? insertIndex;
  double dragDx = 0;
  double dragDy = 0;

  /// Offset X local donde se agarró la carta (evita saltos si tocás el borde).
  double grabLocalX = 0;

  bool get arrastrando => dragIndex != null;

  double shiftX(int index, double paso) => shiftXReordenMano(
        index: index,
        from: dragIndex,
        to: insertIndex,
        paso: paso,
      );

  void iniciar({
    required int index,
    required Offset localPosition,
    required double anchoCarta,
  }) {
    dragIndex = index;
    insertIndex = index;
    dragDx = 0;
    dragDy = 0;
    grabLocalX = localPosition.dx.clamp(0.0, anchoCarta);
  }

  /// Actualiza offsets y, si cambió, el índice de inserción.
  /// Devuelve `true` si hubo cambio de estado relevante.
  bool actualizar({
    required DragUpdateDetails details,
    required int Function(double globalX) indiceInsercionDesdeGlobal,
  }) {
    if (dragIndex == null) return false;
    final nuevo = indiceInsercionDesdeGlobal(details.globalPosition.dx);
    dragDx += details.delta.dx;
    dragDy = (dragDy + details.delta.dy).clamp(0.0, maxDragDy);
    final cambioHueco = nuevo != insertIndex;
    if (cambioHueco) insertIndex = nuevo;
    return true;
  }

  /// Resultado al soltar: índices desde/hacia, o null si no hay reorder.
  ({int desde, int hacia})? soltar() {
    final from = dragIndex;
    final to = insertIndex;
    limpiar();
    if (from != null && to != null && from != to) {
      return (desde: from, hacia: to);
    }
    return null;
  }

  void cancelar() => limpiar();

  void limpiar() {
    dragIndex = null;
    insertIndex = null;
    dragDx = 0;
    dragDy = 0;
    grabLocalX = 0;
  }
}

/// Duración del deslizamiento al abrir/cerrar el hueco.
const Duration kDuracionHuecoReordenMano = Duration(milliseconds: 200);

/// Curva del deslizamiento (suave y fluido).
const Curve kCurvaHuecoReordenMano = Curves.easeOutCubic;

/// Aplica el deslizamiento animado a las cartas que abren el hueco.
///
/// No afecta a la carta que se está arrastrando ([esLaQueArrastro]).
class CartaConHuecoReorden extends StatelessWidget {
  const CartaConHuecoReorden({
    super.key,
    required this.arrastrandoMano,
    required this.esLaQueArrastro,
    required this.shiftX,
    required this.child,
    this.duration = kDuracionHuecoReordenMano,
    this.curve = kCurvaHuecoReordenMano,
  });

  final bool arrastrandoMano;
  final bool esLaQueArrastro;
  final double shiftX;
  final Widget child;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    if (!arrastrandoMano || esLaQueArrastro) return child;
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      transform: Matrix4.translationValues(shiftX, 0, 0),
      child: child,
    );
  }
}

/// Elevación + seguimiento del dedo para la carta que se arrastra.
class CartaArrastreVisualReorden extends StatelessWidget {
  const CartaArrastreVisualReorden({
    super.key,
    required this.esLaQueArrastro,
    required this.dragDx,
    required this.dragDy,
    required this.child,
    this.borderRadius,
  });

  final bool esLaQueArrastro;
  final double dragDx;
  final double dragDy;
  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(
        esLaQueArrastro ? dragDx : 0,
        esLaQueArrastro ? dragDy : 0,
      ),
      child: Material(
        color: Colors.transparent,
        elevation: esLaQueArrastro ? 10 : 0,
        shadowColor: Colors.black54,
        borderRadius: borderRadius,
        child: child,
      ),
    );
  }
}

/// Detector de pan para iniciar/actualizar/soltar el reorden.
class DetectorArrastreReorden extends StatelessWidget {
  const DetectorArrastreReorden({
    super.key,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onPanCancel,
    required this.child,
  });

  final void Function(DragStartDetails details) onPanStart;
  final void Function(DragUpdateDetails details) onPanUpdate;
  final VoidCallback onPanEnd;
  final VoidCallback onPanCancel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      onPanEnd: (_) => onPanEnd(),
      onPanCancel: onPanCancel,
      child: child,
    );
  }
}

/// Auto-scroll horizontal cerca de los bordes mientras se arrastra.
void autoScrollDuranteDragReorden({
  required ScrollController scroll,
  required BuildContext context,
  required double globalX,
  double margen = 40,
  double paso = 10,
}) {
  if (!scroll.hasClients) return;
  final box = context.findRenderObject() as RenderBox?;
  if (box == null) return;
  final local = box.globalToLocal(Offset(globalX, 0)).dx;
  final ancho = box.size.width;
  double delta = 0;
  if (local < margen) {
    delta = -paso;
  } else if (local > ancho - margen) {
    delta = paso;
  }
  if (delta == 0) return;
  final destino =
      (scroll.offset + delta).clamp(0.0, scroll.position.maxScrollExtent);
  scroll.jumpTo(destino);
}

/// Índice de inserción a partir de la X global del puntero y el [drag] activo.
int indiceInsercionDesdeGlobalReorden({
  required GlobalKey rowKey,
  required ReordenarCartaManoDrag drag,
  required double globalX,
  required int cantidad,
  required double anchoCarta,
  required double gap,
}) {
  final box = rowKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return drag.dragIndex ?? 0;
  // Referencia = borde izquierdo de la carta, no el dedo/cursor.
  final localX = box.globalToLocal(Offset(globalX - drag.grabLocalX, 0)).dx;
  final contenido =
      cantidad <= 0 ? 0.0 : cantidad * anchoCarta + (cantidad - 1) * gap;
  final origen = (box.size.width - contenido) / 2;
  final origenClamped = origen < 0 ? 0.0 : origen;
  return indiceInsercionReordenMano(
    localX: localX,
    cantidad: cantidad,
    anchoCarta: anchoCarta,
    gap: gap,
    origen: origenClamped,
  );
}
