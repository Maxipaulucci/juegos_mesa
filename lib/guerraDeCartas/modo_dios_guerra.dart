import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/guerraDeCartas/motor_guerra.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Orden de salida del mazo: índice 0 = próxima a tirar.
List<CartaGuerra> ordenSalidaMazoGuerra(JugadorGuerra j) =>
    j.mazo.reversed.toList();

/// [ordenDesdeProxima]: índice 0 = próxima a tirar.
void forzarMazoGuerra(JugadorGuerra j, List<CartaGuerra> ordenDesdeProxima) {
  j.mazo
    ..clear()
    ..addAll(ordenDesdeProxima.reversed);
}

CartaGuerra? proximaCartaMazoGuerra(JugadorGuerra j) =>
    j.mazo.isEmpty ? null : j.mazo.last;

/// Diálogo Modo Dios: ver y reordenar las cartas del mazo del jugador.
Future<List<CartaGuerra>?> mostrarEditarMazoGuerra({
  required BuildContext context,
  required List<CartaGuerra> ordenDesdeProxima,
  String titulo = 'Modo Dios · tu mazo',
}) {
  return showDialog<List<CartaGuerra>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _DialogoEditarMazoGuerra(
      ordenInicial: ordenDesdeProxima,
      titulo: titulo,
    ),
  );
}

class _DialogoEditarMazoGuerra extends StatefulWidget {
  const _DialogoEditarMazoGuerra({
    required this.ordenInicial,
    required this.titulo,
  });

  final List<CartaGuerra> ordenInicial;
  final String titulo;

  @override
  State<_DialogoEditarMazoGuerra> createState() =>
      _DialogoEditarMazoGuerraState();
}

class _DialogoEditarMazoGuerraState extends State<_DialogoEditarMazoGuerra> {
  late List<CartaGuerra> _orden;

  @override
  void initState() {
    super.initState();
    _orden = List.of(widget.ordenInicial);
  }

  Color _colorCarta(CartaGuerra c) =>
      c.esRoja ? const Color(0xFFE53935) : AppColors.texto;

  void _ponerProxima(int index) {
    if (index <= 0 || index >= _orden.length) return;
    setState(() {
      final c = _orden.removeAt(index);
      _orden.insert(0, c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.85;
    return Dialog(
      backgroundColor: AppColors.carta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.bug_report, color: AppColors.acento),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.titulo,
                      style: const TextStyle(
                        color: AppColors.acento,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Arriba = próxima carta. Arrastrá para reordenar '
                'o tocá ↑ para ponerla primera.',
                style: TextStyle(
                  color: AppColors.textoSuave,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _orden.isEmpty
                    ? const Center(
                        child: Text(
                          'No quedan cartas',
                          style: TextStyle(color: AppColors.textoSuave),
                        ),
                      )
                    : ReorderableListView.builder(
                        itemCount: _orden.length,
                        buildDefaultDragHandles: false,
                        onReorderItem: (oldIndex, newIndex) {
                          setState(() {
                            final c = _orden.removeAt(oldIndex);
                            _orden.insert(newIndex, c);
                          });
                        },
                        itemBuilder: (context, index) {
                          final c = _orden[index];
                          final color = _colorCarta(c);
                          final esProxima = index == 0;
                          return Material(
                            key: ObjectKey(c),
                            color: Colors.transparent,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: esProxima
                                      ? AppColors.acento
                                      : color.withValues(alpha: 0.55),
                                  width: esProxima ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Icon(
                                      Icons.drag_handle_rounded,
                                      color: AppColors.textoSuave,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${index + 1}.',
                                    style: TextStyle(
                                      color: esProxima
                                          ? AppColors.acento
                                          : AppColors.textoSuave,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      c.etiqueta,
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (esProxima)
                                    Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.acento
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        'PRÓXIMA',
                                        style: TextStyle(
                                          color: AppColors.acento,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  if (!esProxima)
                                    IconButton(
                                      tooltip: 'Poner como próxima',
                                      onPressed: () => _ponerProxima(index),
                                      icon: Icon(
                                        Icons.vertical_align_top_rounded,
                                        color: color,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(List.of(_orden)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.peligro,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
