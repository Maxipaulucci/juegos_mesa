import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Cartel de confirmación antes de reiniciar una partida vs PC.
Future<bool> confirmarReiniciarPartidaPc(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.carta,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Text(
        'Reiniciar partida',
        style: TextStyle(
          color: AppColors.acento,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: const Text(
        '¿Querés reiniciar la partida contra la PC?\n'
        'Se aplicarán las configuraciones actuales de la partida.',
        style: TextStyle(color: AppColors.texto, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Reiniciar'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Ícono de reinicio (flecha circular), a la izquierda de ajustes.
class BotonReiniciarPartidaPc extends StatelessWidget {
  const BotonReiniciarPartidaPc({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Reiniciar partida',
      onPressed: onPressed,
      icon: const Icon(
        Icons.refresh_rounded,
        color: AppColors.textoSuave,
      ),
    );
  }
}
