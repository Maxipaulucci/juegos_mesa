import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/shared/formato/numero_formato.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Cartel previo a unirse: muestra la config del anfitrión y la apuesta.
Future<bool> mostrarCartelConfigSalaOnline({
  required BuildContext context,
  required List<String> resumen,
  int apuestaMonedas = 0,
}) async {
  final maxAltura = MediaQuery.sizeOf(context).height * 0.7;
  final lineas = <String>[
    if (apuestaMonedas > 0)
      'Apuesta: ${formatoNumero(apuestaMonedas)} monedas por jugador '
          '(el ganador se lleva el pozo y suma esa cantidad al ranking).'
    else
      'Sin apuesta de monedas.',
    ...resumen.isEmpty
        ? const <String>['El anfitrión usa la configuración por defecto.']
        : resumen,
  ];

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppColors.carta,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Configuración de la partida',
          style: TextStyle(
            color: AppColors.mint,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        content: SizedBox(
          width: 340,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxAltura),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Así configuró la partida el anfitrión '
                  '(Modificar partida):',
                  style: TextStyle(
                    color: AppColors.textoSuave.withValues(alpha: 0.95),
                    height: 1.35,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxAltura > 180 ? maxAltura - 180 : maxAltura,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final linea in lineas) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.fondo.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.cartaBorde),
                            ),
                            child: Text(
                              linea,
                              style: const TextStyle(
                                color: AppColors.texto,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(
                      apuestaMonedas > 0
                          ? 'Unirse · apostar ${formatoNumero(apuestaMonedas)}'
                          : 'Unirse',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result == true;
}
