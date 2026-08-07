import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/chanchoVa/motor_chancho_va.dart';
import 'package:app_juegos_mesa/chanchoVa/textos.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Overlay de fin: quién completó CHANCHO VA.
class VictoriaChanchoOverlay extends StatelessWidget {
  const VictoriaChanchoOverlay({
    super.key,
    required this.partida,
    required this.onVolverAJugar,
    required this.onVolver,
  });

  final PartidaChancho partida;
  final VoidCallback onVolverAJugar;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    final perdedor = partida.perdedor ?? 'Alguien';
    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF3B1D6E),
                      Color(0xFF1A0A33),
                      Color(0xFF2A1050),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.acento, width: 2),
                  boxShadow: neonGlow(AppColors.acento, blur: 18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '¡CHANCHO VA!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.acento,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$perdedor completó el tablero y pierde.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onVolverAJugar,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.mint,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          TextosChancho.reiniciar,
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onVolver,
                        child: const Text(TextosChancho.volverMenu),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
