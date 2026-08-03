import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/theme/victoria_celebration.dart';
import 'package:app_juegos_mesa/unoSolo/motor_uno_solo.dart';

class VictoriaUnoSoloOverlay extends StatelessWidget {
  const VictoriaUnoSoloOverlay({
    super.key,
    required this.partida,
    required this.onVolverAJugar,
    required this.onVolver,
    this.mostrarVolverAJugar = true,
  });

  final PartidaUnoSolo partida;
  final VoidCallback onVolverAJugar;
  final VoidCallback onVolver;
  final bool mostrarVolverAJugar;

  @override
  Widget build(BuildContext context) {
    final perfecto = partida.fichaUnicaEnCentro ||
        (partida.fichasRestantes <= 1 && partida.fase == FaseUnoSolo.ganado);
    final gano = partida.fase == FaseUnoSolo.ganado &&
        (perfecto || partida.fichasRestantes <= 1);
    final titulo = partida.calificacion ??
        (gano ? '¡Perfecto!' : 'Fin');
    final color = (partida.fichasRestantes <= 2)
        ? AppColors.acento
        : (partida.fichasRestantes <= 5 ? AppColors.mint : AppColors.peligro);
    final nombre = partida.ganador;
    final sub = partida.mensajeFin ??
        (gano
            ? 'Quedó una sola ficha en el centro'
            : 'No quedan movimientos');

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A3A2A),
                    Color(0xFF0A1A14),
                    Color(0xFF142818),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: color, width: 2.5),
                boxShadow: neonGlow(color, blur: 18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titulo,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      letterSpacing: 1.0,
                    ),
                  ),
                  if (nombre != null &&
                      nombre.isNotEmpty &&
                      !partida.solo) ...[
                    const SizedBox(height: 10),
                    Text(
                      nombre,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    sub,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textoSuave,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Fichas restantes: ${partida.fichasRestantes}',
                    style: TextStyle(
                      color: color.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (mostrarVolverAJugar) ...[
                    GlowButtonVictoria(
                      label: 'VOLVER A JUGAR',
                      icon: Icons.replay_rounded,
                      color: AppColors.mint,
                      onPressed: onVolverAJugar,
                    ),
                    const SizedBox(height: 10),
                  ],
                  GlowButtonVictoria(
                    label: 'VOLVER AL MENÚ',
                    icon: Icons.home_rounded,
                    color: AppColors.violeta,
                    onPressed: onVolver,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
