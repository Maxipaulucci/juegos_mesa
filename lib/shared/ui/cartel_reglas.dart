import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/shared/ui/animacion_overlay_entrada.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Cartel de reglas con la misma animación de entrada que ajustes/cuenta/menú.
/// Si el texto no entra, muestra scroll con barra visible.
Future<void> mostrarCartelReglas(BuildContext context, String texto) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Reglas',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: Duration.zero,
    pageBuilder: (ctx, _, __) {
      return AnimacionOverlayEntrada(
        child: _CartelReglasDialog(texto: texto),
      );
    },
  );
}

class _CartelReglasDialog extends StatefulWidget {
  const _CartelReglasDialog({required this.texto});

  final String texto;

  @override
  State<_CartelReglasDialog> createState() => _CartelReglasDialogState();
}

class _CartelReglasDialogState extends State<_CartelReglasDialog> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final altoPantalla = MediaQuery.sizeOf(context).height;
    final maxAltoDialogo = altoPantalla * 0.85;
    final maxAltoContenido = (altoPantalla * 0.55).clamp(160.0, 480.0);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: maxAltoDialogo,
        ),
        child: AlertDialog(
          backgroundColor: AppColors.carta,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Reglas',
            style: TextStyle(
              color: AppColors.mint,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxAltoContenido),
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                trackVisibility: true,
                interactive: true,
                radius: const Radius.circular(8),
                thickness: 6,
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    widget.texto,
                    style: const TextStyle(
                      color: AppColors.texto,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }
}
