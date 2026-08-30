import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_juegos_mesa/services/usuario_mongo_service.dart';
import 'package:app_juegos_mesa/shared/formato/numero_formato.dart';
import 'package:app_juegos_mesa/shared/monedas/monedas_store.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Botón / fila para abrir el diálogo de cambio de nombre (500 monedas).
class OpcionCambiarNombreUsuario extends StatelessWidget {
  const OpcionCambiarNombreUsuario({
    super.key,
    this.onCambiado,
    this.compacto = false,
  });

  final VoidCallback? onCambiado;
  final bool compacto;

  static const costo = UsuarioMongoService.costoCambiarNombreUsuario;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      color: AppColors.azul,
      fontWeight: FontWeight.w800,
      fontSize: compacto ? 13 : 14,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.azul.withValues(alpha: 0.7),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => mostrarDialogoCambiarNombreUsuario(
          context,
          onCambiado: onCambiado,
        ),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: compacto ? 4 : 6,
            horizontal: 4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cambiar nombre de usuario',
                textAlign: TextAlign.center,
                style: estilo,
              ),
              const SizedBox(height: 2),
              Text(
                '${formatoNumero(costo)} monedas',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.acento,
                  fontWeight: FontWeight.w700,
                  fontSize: compacto ? 11 : 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> mostrarDialogoCambiarNombreUsuario(
  BuildContext context, {
  VoidCallback? onCambiado,
}) async {
  final api = UsuarioMongoService.instance;
  final actual = api.nombreParaPartida ?? '';
  final ctrl = TextEditingController(text: actual);
  String? error;
  var cargando = false;

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: !cargando,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> confirmar() async {
            final raw = ctrl.text.trim();
            if (!usuarioNombreValido(raw)) {
              setDialogState(() {
                error =
                    '3 a 20 caracteres: letras, números o _.';
              });
              return;
            }
            final formateado = formatoNombreUsuario(raw);
            if (formateado.toLowerCase() == actual.toLowerCase()) {
              setDialogState(() {
                error = 'Ese ya es tu nombre de usuario.';
              });
              return;
            }
            if (api.usuario != null &&
                api.usuario!.monedas < OpcionCambiarNombreUsuario.costo) {
              setDialogState(() {
                error =
                    'Necesitás ${formatoNumero(OpcionCambiarNombreUsuario.costo)} monedas.';
              });
              return;
            }

            setDialogState(() {
              cargando = true;
              error = null;
            });
            try {
              await api.cambiarNombreUsuario(formateado);
              MonedasStore.instance.notificar();
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
              'Cambiar nombre de usuario',
              style: TextStyle(
                color: AppColors.acento,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Cuesta ${formatoNumero(OpcionCambiarNombreUsuario.costo)} monedas.',
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
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
                    labelText: 'Nuevo nombre',
                    counterStyle: TextStyle(color: AppColors.textoSuave),
                  ),
                  onChanged: (_) {
                    if (error != null) {
                      setDialogState(() => error = null);
                    }
                  },
                  onSubmitted: (_) {
                    if (!cargando) confirmar();
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
                        color: AppColors.acento,
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
                onPressed: cargando ? null : confirmar,
                child: Text(
                  'Confirmar · ${formatoNumero(OpcionCambiarNombreUsuario.costo)}',
                  style: const TextStyle(
                    color: AppColors.acento,
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
  if (ok == true) {
    onCambiado?.call();
    return true;
  }
  return false;
}
