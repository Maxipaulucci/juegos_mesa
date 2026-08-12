import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/jodete/motor_jodete.dart';
import 'package:app_juegos_mesa/shared/cartas/carta_espanola_skin.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Cartel con el puesto de cada jugador en todas las rondas.
Future<void> mostrarHistorialJodete({
  required BuildContext context,
  required PartidaJodete partida,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _CartelHistorialJodete(partida: partida),
  );
}

/// Cartel con las cartas que se tiraron en la ronda actual (según el pozo/descarte).
Future<void> mostrarCartasTiradasJodete({
  required BuildContext context,
  required PartidaJodete partida,
}) {
  final descartadas = partida.descarte;
  // En el descarte, la primera carta suele ser el “inicio” (no es jugada durante
  // la ronda). Para que se parezca a “cartas tiradas”, la omitimos.
  final jugadas = descartadas.length <= 1 ? const <CartaJodete>[] : descartadas.sublist(1);

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _CartelCartasTiradasJodete(jugadas: jugadas),
  );
}

PaloEspanolVisual _paloVisual(PaloJodete p) => switch (p) {
      PaloJodete.oro => PaloEspanolVisual.oro,
      PaloJodete.copa => PaloEspanolVisual.copa,
      PaloJodete.espada => PaloEspanolVisual.espada,
      PaloJodete.basto => PaloEspanolVisual.basto,
    };

class _CartelCartasTiradasJodete extends StatelessWidget {
  const _CartelCartasTiradasJodete({required this.jugadas});

  final List<CartaJodete> jugadas;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.80;
    return Dialog(
      backgroundColor: AppColors.carta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'CARTAS TIRADAS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.azul,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                jugadas.isEmpty ? 'Todavía no se jugó ninguna carta en la ronda.' : '${jugadas.length} carta${jugadas.length == 1 ? '' : 's'}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: jugadas.isEmpty
                    ? const Center(
                        child: Text(
                          '—',
                          style: TextStyle(color: AppColors.textoSuave),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 12,
                          children: [
                            for (final c in jugadas)
                              _MiniCartaJodete(c: c),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 10),
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

class _MiniCartaJodete extends StatelessWidget {
  const _MiniCartaJodete({required this.c});

  final CartaJodete c;

  @override
  Widget build(BuildContext context) {
    const w = 48.0;
    const h = 72.0;

    if (c.esComodin) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6A1B9A), Color(0xFF1A0A33)],
          ),
          border: Border.all(color: AppColors.acento, width: 2),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_rounded, color: AppColors.acento, size: 22),
            SizedBox(height: 4),
            Text(
              'Comodín',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w900,
                fontSize: 8.5,
              ),
            ),
          ],
        ),
      );
    }

    return CartaEspanolaSkin(
      numero: c.numero!,
      etiqueta: c.etiqueta,
      palo: _paloVisual(c.palo!),
      seleccionada: false,
      compacta: true,
      width: w,
      height: h,
    );
  }
}

String _ordinal(int puesto) => switch (puesto) {
      1 => '1º',
      2 => '2º',
      3 => '3º',
      4 => '4º',
      _ => '$puestoº',
    };

Color _colorPuesto(int puesto) => switch (puesto) {
      1 => AppColors.acento,
      2 => AppColors.texto,
      3 => AppColors.azul,
      _ => AppColors.textoSuave,
    };

class _CartelHistorialJodete extends StatelessWidget {
  const _CartelHistorialJodete({required this.partida});

  final PartidaJodete partida;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.78;
    final historial = partida.historialRondas;

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
                historial.isEmpty
                    ? 'Sin rondas registradas'
                    : '${historial.length} ronda${historial.length == 1 ? '' : 's'}',
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
                          'No se jugó ninguna ronda.',
                          style: TextStyle(color: AppColors.textoSuave),
                        ),
                      )
                    : ListView.separated(
                        itemCount: historial.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final ronda = historial[index];
                          return Container(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.28),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.azul.withValues(alpha: 0.55),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'RONDA ${index + 1}',
                                  style: const TextStyle(
                                    color: AppColors.azul,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                for (final d in ronda.detalles) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 36,
                                          child: Text(
                                            _ordinal(d.puesto),
                                            style: TextStyle(
                                              color: _colorPuesto(d.puesto),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            d.nombre,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppColors.texto,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          d.puntosGanados > 0
                                              ? '+${d.puntosGanados}'
                                              : '0',
                                          style: TextStyle(
                                            color: d.puntosGanados > 0
                                                ? AppColors.mint
                                                : AppColors.textoSuave,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
