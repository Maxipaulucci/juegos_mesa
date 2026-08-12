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

/// Opacidad de una carta durante el reorden / selección.
///
/// La carta que se arrastra ([esLaQueArrastro]) **siempre** queda opaca.
double opacidadReordenMano({
  required bool esLaQueArrastro,
  bool atenuar = false,
  double opacidadAtenuada = 0.34,
}) {
  if (esLaQueArrastro) return 1;
  return atenuar ? opacidadAtenuada : 1;
}

/// Envuelve con atenuación solo cuando corresponde.
///
/// Importante: la carta arrastrada **no** se envuelve en [Opacity] /
/// [AnimatedOpacity] aunque sea 1.0 — ese layer al solaparse con cartas
/// atenuadas hace que se vea translúcida.
class CartaOpacidadReorden extends StatelessWidget {
  const CartaOpacidadReorden({
    super.key,
    required this.esLaQueArrastro,
    required this.atenuar,
    required this.child,
    this.duration = const Duration(milliseconds: 180),
    this.opacidadAtenuada = 0.34,
  });

  final bool esLaQueArrastro;
  final bool atenuar;
  final Widget child;
  final Duration duration;
  final double opacidadAtenuada;

  @override
  Widget build(BuildContext context) {
    // Sin Opacity en la carta que se mueve: estilo intacto y totalmente opaca.
    if (esLaQueArrastro) return child;
    if (!atenuar) return child;
    return AnimatedOpacity(
      duration: duration,
      opacity: opacidadAtenuada,
      child: child,
    );
  }
}

/// Duración de la subida al seleccionar una carta (mismo valor en todos los juegos).
const Duration kDuracionSubidaSeleccionCarta = Duration(milliseconds: 380);

/// Curva de la subida al seleccionar (suave y fluido).
const Curve kCurvaSubidaSeleccionCarta = Curves.easeOutCubic;

/// Espacio extra del slot para que la carta suba sin achicar el layout.
const double kDeslizamientoSeleccionCarta = 14;

/// Slot con [AnimatedAlign]: la carta sube/baja en [kDuracionSubidaSeleccionCarta].
///
/// Mantener este widget en un árbol estable (mismos padres al seleccionar);
/// si el padre cambia, la animación se reinicia y la carta “teletransporta”.
class CartaSlotSeleccion extends StatelessWidget {
  const CartaSlotSeleccion({
    super.key,
    required this.seleccionada,
    required this.width,
    required this.height,
    required this.child,
    this.animaciones = true,
    this.deslizamiento = kDeslizamientoSeleccionCarta,
    this.duration = kDuracionSubidaSeleccionCarta,
    this.curve = kCurvaSubidaSeleccionCarta,
  });

  final bool seleccionada;
  final bool animaciones;
  final double width;
  final double height;
  final double deslizamiento;
  final Duration duration;
  final Curve curve;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height + deslizamiento,
      child: AnimatedAlign(
        duration: animaciones ? duration : Duration.zero,
        curve: curve,
        alignment:
            seleccionada ? Alignment.topCenter : Alignment.bottomCenter,
        child: child,
      ),
    );
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
///
/// No usa [Material] transparente (lavaba la carta). La sombra es solo
/// decorativa; el contenido de [child] debe ser opaco.
class CartaArrastreVisualReorden extends StatelessWidget {
  const CartaArrastreVisualReorden({
    super.key,
    required this.esLaQueArrastro,
    required this.dragDx,
    required this.dragDy,
    required this.child,
    this.borderRadius,
    this.ocultarEnSlot = false,
  });

  final bool esLaQueArrastro;
  final double dragDx;
  final double dragDy;
  final Widget child;
  final BorderRadius? borderRadius;

  /// Si true y [esLaQueArrastro], el slot queda invisible (la carta se pinta
  /// arriba con [CartaFlotanteReorden]) pero conserva tamaño y gestos.
  final bool ocultarEnSlot;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(14);
    Widget body = child;
    if (ocultarEnSlot && esLaQueArrastro) {
      body = Visibility(
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: body,
      );
    }
    return Transform.translate(
      offset: Offset(
        esLaQueArrastro && !ocultarEnSlot ? dragDx : 0,
        esLaQueArrastro && !ocultarEnSlot ? dragDy : 0,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: esLaQueArrastro && !ocultarEnSlot
              ? const [
                  BoxShadow(
                    color: Color(0x8A000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: body,
      ),
    );
  }
}

/// Posición X del borde izquierdo del slot [index] en una fila centrada.
double offsetXSlotReordenMano({
  required int index,
  required int cantidad,
  required double anchoCarta,
  required double gap,
  required double anchoFila,
}) {
  if (cantidad <= 0) return 0;
  final contenido = cantidad * anchoCarta + (cantidad - 1) * gap;
  final origen = (anchoFila - contenido) / 2;
  final origenClamped = origen < 0 ? 0.0 : origen;
  return origenClamped + index * (anchoCarta + gap);
}

/// Carta arrastrada pintada **encima** de la fila (evita que cartas vecinas
/// con opacidad baja se dibujen encima y la hagan ver translúcida).
class CartaFlotanteReorden extends StatelessWidget {
  const CartaFlotanteReorden({
    super.key,
    required this.rowKey,
    required this.index,
    required this.cantidad,
    required this.anchoCarta,
    required this.gap,
    required this.dragDx,
    required this.dragDy,
    required this.child,
    this.borderRadius,
  });

  final GlobalKey rowKey;
  final int index;
  final int cantidad;
  final double anchoCarta;
  final double gap;
  final double dragDx;
  final double dragDy;
  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final box = rowKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return const SizedBox.shrink();
    final left = offsetXSlotReordenMano(
          index: index,
          cantidad: cantidad,
          anchoCarta: anchoCarta,
          gap: gap,
          anchoFila: box.size.width,
        ) +
        dragDx;
    final radius = borderRadius ?? BorderRadius.circular(14);
    return Positioned(
      left: left,
      top: dragDy,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: const [
              BoxShadow(
                color: Color(0x8A000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
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
    this.onTap,
  });

  final void Function(DragStartDetails details) onPanStart;
  final void Function(DragUpdateDetails details) onPanUpdate;
  final VoidCallback onPanEnd;
  final VoidCallback onPanCancel;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
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
