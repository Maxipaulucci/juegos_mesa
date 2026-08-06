import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/culoSucio/motor_culo_sucio.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Cartel con el historial de cartas sacadas por cada jugador.
Future<void> mostrarHistorialCuloSucio({
  required BuildContext context,
  required PartidaCuloSucio partida,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _CartelHistorialCuloSucio(partida: partida),
  );
}

class _CartelHistorialCuloSucio extends StatelessWidget {
  const _CartelHistorialCuloSucio({required this.partida});

  final PartidaCuloSucio partida;

  Color _colorPalo(PaloCuloSucio? palo) => switch (palo) {
        PaloCuloSucio.oro => const Color(0xFFFFC107),
        PaloCuloSucio.copa => const Color(0xFFFF5252),
        PaloCuloSucio.espada => const Color(0xFF40C4FF),
        PaloCuloSucio.basto => const Color(0xFF69F0AE),
        null => AppColors.violeta,
      };

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.78;
    final historial = partida.historial;

    return Dialog(
      backgroundColor: AppColors.carta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'HISTORIAL',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.azul,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${historial.length} carta${historial.length == 1 ? '' : 's'} sacada${historial.length == 1 ? '' : 's'}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: historial.isEmpty
                    ? const Center(
                        child: Text(
                          'Sin jugadas registradas.',
                          style: TextStyle(color: AppColors.textoSuave),
                        ),
                      )
                    : ListView.separated(
                        itemCount: historial.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final j = historial[index];
                          final color = j.carta.esCuloSucio
                              ? AppColors.peligro
                              : _colorPalo(j.carta.palo);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.28),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: j.carta.esCuloSucio
                                    ? AppColors.peligro
                                    : color.withValues(alpha: 0.55),
                                width: j.carta.esCuloSucio ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  child: Text(
                                    '#${j.turno}',
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        j.jugador,
                                        style: const TextStyle(
                                          color: AppColors.texto,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        j.carta.etiqueta,
                                        style: TextStyle(
                                          color: j.carta.esCuloSucio
                                              ? AppColors.peligro
                                              : AppColors.textoSuave,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (j.carta.esCuloSucio)
                                  const Text(
                                    'CULO SUCIO',
                                    style: TextStyle(
                                      color: AppColors.peligro,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.azul,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
