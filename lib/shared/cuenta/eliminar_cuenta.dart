import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_juegos_mesa/services/usuario_mongo_service.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Diálogo para confirmar la eliminación escribiendo el nombre de usuario.
Future<bool> mostrarDialogoEliminarCuenta(BuildContext context) async {
  final api = UsuarioMongoService.instance;
  final nombreActual = api.nombreParaPartida ?? '';
  final ctrl = TextEditingController();
  String? error;
  var cargando = false;

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: !cargando,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final coincide = nombreActual.isNotEmpty &&
              formatoNombreUsuario(ctrl.text).toLowerCase() ==
                  nombreActual.toLowerCase();

          Future<void> confirmar() async {
            if (!coincide) {
              setDialogState(() {
                error = 'El nombre de usuario no coincide.';
              });
              return;
            }

            setDialogState(() {
              cargando = true;
              error = null;
            });
            try {
              await api.eliminarCuenta(ctrl.text);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
            } catch (e) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                cargando = false;
                error = e.toString().replaceFirst('Bad state: ', '');
              });
            }
          }

          return AlertDialog(
            backgroundColor: AppColors.carta,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Eliminar cuenta',
              style: TextStyle(
                color: AppColors.peligro,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Esta acción es permanente. Se borrarán tus puntos, '
                  'monedas y racha.',
                  style: TextStyle(
                    color: AppColors.texto,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Escribí tu nombre de usuario ($nombreActual) para confirmar:',
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  enabled: !cargando,
                  maxLength: 20,
                  autofocus: true,
                  textCapitalization: TextCapitalization.none,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[A-Za-z0-9_]'),
                    ),
                  ],
                  style: const TextStyle(color: AppColors.texto),
                  decoration: const InputDecoration(
                    labelText: 'Nombre de usuario',
                    counterStyle: TextStyle(color: AppColors.textoSuave),
                  ),
                  onChanged: (_) {
                    if (error != null) {
                      setDialogState(() => error = null);
                    } else {
                      setDialogState(() {});
                    }
                  },
                  onSubmitted: (_) {
                    if (!cargando && coincide) confirmar();
                  },
                ),
                if (error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    error!,
                    style: const TextStyle(
                      color: AppColors.peligro,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (cargando) ...[
                  const SizedBox(height: 12),
                  const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.peligro,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: cargando
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: cargando || !coincide ? null : confirmar,
                child: const Text(
                  'Eliminar',
                  style: TextStyle(
                    color: AppColors.peligro,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );

  ctrl.dispose();
  return ok == true;
}
