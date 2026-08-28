import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/shared/monedas/cartel_como_ganar_monedas.dart';
import 'package:app_juegos_mesa/shared/monedas/monedas_store.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Burbuja de monedas (esquina inferior derecha, encima de la nav).
class MonedasBubble extends StatelessWidget {
  const MonedasBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MonedasStore.instance,
      builder: (context, _) {
        if (!MonedasStore.instance.visible) {
          return const SizedBox.shrink();
        }
        final n = MonedasStore.instance.monedas;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => mostrarCartelComoGanarMonedas(context),
            borderRadius: BorderRadius.circular(999),
            child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.carta,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.acento.withValues(alpha: 0.9),
                width: 1.6,
              ),
              boxShadow: neonGlow(AppColors.acento, blur: 12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.monetization_on_rounded,
                  color: AppColors.acento,
                  size: 22,
                ),
                const SizedBox(width: 6),
                Text(
                  '$n',
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}
