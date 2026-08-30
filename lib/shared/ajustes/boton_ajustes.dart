import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Botón circular de ajustes (mismo look que el menú de juegos).
class BotonAjustes extends StatelessWidget {
  const BotonAjustes({
    super.key,
    required this.onPressed,
    this.tooltip = 'Ajustes',
  });

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.carta,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.rosa.withValues(alpha: 0.85),
                width: 1.6,
              ),
              boxShadow: neonGlow(AppColors.rosa, blur: 10),
            ),
            child: const Icon(
              Icons.settings,
              color: AppColors.texto,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
