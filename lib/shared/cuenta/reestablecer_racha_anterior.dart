import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/config/racha_config.dart';
import 'package:app_juegos_mesa/services/usuario_mongo_service.dart';
import 'package:app_juegos_mesa/shared/formato/numero_formato.dart';
import 'package:app_juegos_mesa/shared/monedas/monedas_store.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Si se puede pagar para recuperar la racha anterior.
bool puedeReestablecerRacha({
  required int rachaAnterior,
  required int rachaActual,
}) {
  return rachaAnterior > 1 || rachaAnterior > rachaActual;
}

String motivoNoReestablecerRacha({
  required int rachaAnterior,
  required int rachaActual,
}) {
  if (puedeReestablecerRacha(
    rachaAnterior: rachaAnterior,
    rachaActual: rachaActual,
  )) {
    return '';
  }
  if (rachaAnterior <= 0) {
    return 'No tenés una racha anterior guardada para reestablecer.';
  }
  if (rachaAnterior <= 1 && rachaActual >= rachaAnterior) {
    return 'Solo podés reestablecer si tu racha anterior es mayor a 1 día '
        'o mayor que tu racha actual.';
  }
  return 'Tu racha anterior no supera los requisitos para reestablecerla.';
}

/// Enlace para reestablecer la última racha (1500 monedas).
class OpcionReestablecerRacha extends StatelessWidget {
  const OpcionReestablecerRacha({
    super.key,
    required this.rachaAnterior,
    required this.rachaActual,
    this.onRestablecida,
    this.textAlign = TextAlign.start,
  });

  final int rachaAnterior;
  final int rachaActual;
  final VoidCallback? onRestablecida;
  final TextAlign textAlign;

  static const costo = RachaConfig.costoReestablecerRacha;

  @override
  Widget build(BuildContext context) {
    const estiloLink = TextStyle(
      color: AppColors.textoSuave,
      fontSize: 12,
      fontStyle: FontStyle.italic,
    );

    return TextButton(
      onPressed: () => _alTocar(context),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: AppColors.textoSuave.withValues(alpha: 0.85),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Reestablecer última racha - ',
              style: estiloLink.copyWith(
                color: AppColors.textoSuave.withValues(alpha: 0.85),
              ),
            ),
            TextSpan(
              text: '${formatoNumero(costo)} monedas',
              style: const TextStyle(
                color: AppColors.acento,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        textAlign: textAlign,
      ),
    );
  }

  Future<void> _alTocar(BuildContext context) async {
    if (!puedeReestablecerRacha(
      rachaAnterior: rachaAnterior,
      rachaActual: rachaActual,
    )) {
      await _mostrarCartelNoDisponible(context);
      return;
    }

    final confirmado = await _mostrarCartelConfirmacion(context);
    if (confirmado != true || !context.mounted) return;

    try {
      await UsuarioMongoService.instance.reestablecerRachaAnterior();
      MonedasStore.instance.notificar();
      onRestablecida?.call();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Racha reestablecida a $rachaAnterior '
            '${rachaAnterior == 1 ? 'día' : 'días'}.',
          ),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.carta,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'No se pudo reestablecer',
            style: TextStyle(
              color: AppColors.peligro,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            e.toString().replaceFirst('Bad state: ', ''),
            style: const TextStyle(color: AppColors.texto),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _mostrarCartelNoDisponible(BuildContext context) {
    final motivo = motivoNoReestablecerRacha(
      rachaAnterior: rachaAnterior,
      rachaActual: rachaActual,
    );
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.carta,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Reestablecer racha',
          style: TextStyle(
            color: AppColors.acento,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          motivo,
          style: const TextStyle(
            color: AppColors.texto,
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Entendido',
              style: TextStyle(
                color: AppColors.acento,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _mostrarCartelConfirmacion(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.carta,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '¿Reestablecer racha?',
          style: TextStyle(
            color: AppColors.acento,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          'Vas a recuperar tu racha de $rachaAnterior '
          '${rachaAnterior == 1 ? 'día' : 'días'} por '
          '${formatoNumero(costo)} monedas.',
          style: const TextStyle(
            color: AppColors.texto,
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Confirmar · ${formatoNumero(costo)}',
              style: const TextStyle(
                color: AppColors.acento,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
