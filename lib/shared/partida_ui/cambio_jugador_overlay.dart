import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Cartel a pantalla completa para pasar el dispositivo al siguiente jugador.
class CambioJugadorOverlay extends StatelessWidget {
  const CambioJugadorOverlay({
    super.key,
    required this.nombreJugador,
    required this.onAceptar,
    this.titulo = 'Cambio de jugador',
    this.botonLabel = 'Aceptar',
  });

  final String nombreJugador;
  final VoidCallback onAceptar;
  final String titulo;
  final String botonLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.92),
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
                    const Icon(
                      Icons.swap_horiz_rounded,
                      color: AppColors.acento,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.acento,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Pasá el dispositivo a $nombreJugador.\n'
                      'Tocá Aceptar solo cuando $nombreJugador esté mirando.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textoSuave,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onAceptar,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.acento,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          botonLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.4,
                          ),
                        ),
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
