import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/config/racha_config.dart';
import 'package:app_juegos_mesa/shared/formato/numero_formato.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

const _fuego = Color(0xFFFF7043);

/// Cartel que explica la racha de login diario.
Future<void> mostrarCartelComoFuncionaRacha(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const _CartelComoFuncionaRacha(),
  );
}

class _CartelComoFuncionaRacha extends StatelessWidget {
  const _CartelComoFuncionaRacha();

  @override
  Widget build(BuildContext context) {
    final diaria = formatoMonedasGanadas(RachaConfig.diaria);
    final semana = formatoMonedasGanadas(RachaConfig.bonusSemana);
    final mes = formatoMonedasGanadas(RachaConfig.bonusMes);

    return AlertDialog(
      backgroundColor: AppColors.carta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            color: _fuego,
            size: 28,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '¿Cómo funciona la racha?',
              style: TextStyle(
                color: _fuego,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _bloque(
              icono: Icons.login_rounded,
              titulo: 'Entrá todos los días',
              texto:
                  'Iniciá sesión cada día con tu cuenta para mantener la racha. '
                  'Si un día no entrás, la racha vuelve a cero.',
            ),
            const SizedBox(height: 12),
            _bloque(
              icono: Icons.monetization_on_outlined,
              titulo: 'Recompensa diaria',
              texto:
                  'Por cada día consecutivo que entres ganás $diaria monedas.',
            ),
            const SizedBox(height: 12),
            _bloque(
              icono: Icons.calendar_view_week_rounded,
              titulo: '${RachaConfig.diasSemana} días seguidos',
              texto:
                  'Al completar ${RachaConfig.diasSemana} días seguidos, ese día '
                  'recibís $semana monedas extra (además de las diarias).',
            ),
            const SizedBox(height: 12),
            _bloque(
              icono: Icons.calendar_month_rounded,
              titulo: '${RachaConfig.diasMes} días seguidos',
              texto:
                  'Si entrás ${RachaConfig.diasMes} días seguidos, ese día '
                  'recibís $mes monedas extra. Luego el ciclo se reinicia '
                  'y volvés a empezar desde el día 1.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Entendido',
            style: TextStyle(
              color: AppColors.acento,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _bloque({
    required IconData icono,
    required String titulo,
    required String texto,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.fondoSuave.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.cartaBorde.withValues(alpha: 0.9),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: _fuego, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  texto,
                  style: TextStyle(
                    color: AppColors.textoSuave.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
