import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/shared/ui/animacion_overlay_entrada.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Cartel de reglas con la misma animación de entrada que ajustes/cuenta/menú.
Future<void> mostrarCartelReglas(BuildContext context, String texto) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Reglas',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: Duration.zero,
    pageBuilder: (ctx, _, __) {
      return AnimacionOverlayEntrada(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
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
              content: SingleChildScrollView(
                child: Text(
                  texto,
                  style: const TextStyle(
                    color: AppColors.texto,
                    height: 1.35,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
