import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Preferencias de la partida (aún sin audio/animaciones reales).
class AjustesEstado {
  const AjustesEstado({
    this.volumenMusica = 0.8,
    this.volumenSonidos = 0.8,
    this.animaciones = true,
  });

  final double volumenMusica;
  final double volumenSonidos;
  final bool animaciones;

  AjustesEstado copyWith({
    double? volumenMusica,
    double? volumenSonidos,
    bool? animaciones,
  }) {
    return AjustesEstado(
      volumenMusica: volumenMusica ?? this.volumenMusica,
      volumenSonidos: volumenSonidos ?? this.volumenSonidos,
      animaciones: animaciones ?? this.animaciones,
    );
  }
}

/// Panel centrado de ajustes: música, sonidos y animaciones.
class AjustesOverlay extends StatelessWidget {
  const AjustesOverlay({
    super.key,
    required this.ajustes,
    required this.onChanged,
    required this.onCerrar,
  });

  final AjustesEstado ajustes;
  final ValueChanged<AjustesEstado> onChanged;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Fondo: tocar afuera cierra el menú
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCerrar,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.72),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: GestureDetector(
                    onTap: () {}, // absorbe el toque para no cerrar
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                        border: Border.all(color: AppColors.azul, width: 2),
                        boxShadow: neonGlow(AppColors.azul, blur: 18),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'AJUSTES',
                                  style: TextStyle(
                                    color: AppColors.acento,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: onCerrar,
                                icon: const Icon(
                                  Icons.close,
                                  color: AppColors.texto,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const _SeccionTitulo(
                            icon: Icons.music_note_rounded,
                            label: 'Música',
                          ),
                          const SizedBox(height: 8),
                          _VolumenSlider(
                            valor: ajustes.volumenMusica,
                            onChanged: (v) => onChanged(
                              ajustes.copyWith(volumenMusica: v),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const _SeccionTitulo(
                            icon: Icons.graphic_eq_rounded,
                            label: 'Sonidos',
                          ),
                          const SizedBox(height: 8),
                          _VolumenSlider(
                            valor: ajustes.volumenSonidos,
                            onChanged: (v) => onChanged(
                              ajustes.copyWith(volumenSonidos: v),
                            ),
                          ),
                          const SizedBox(height: 22),
                          _ToggleAnimaciones(
                            activo: ajustes.animaciones,
                            onChanged: (v) => onChanged(
                              ajustes.copyWith(animaciones: v),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeccionTitulo extends StatelessWidget {
  const _SeccionTitulo({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.azul, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.texto,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Slider estilo foto: icono bajo ← pista → icono alto.
class _VolumenSlider extends StatelessWidget {
  const _VolumenSlider({
    required this.valor,
    required this.onChanged,
  });

  final double valor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.volume_mute_rounded,
          color: AppColors.textoSuave.withValues(alpha: 0.85),
          size: 22,
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: AppColors.azul,
              inactiveTrackColor: AppColors.azul.withValues(alpha: 0.25),
              thumbColor: AppColors.azul,
              overlayColor: AppColors.azul.withValues(alpha: 0.18),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 9,
                elevation: 2,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: valor.clamp(0.0, 1.0),
              onChanged: onChanged,
            ),
          ),
        ),
        Icon(
          Icons.volume_up_rounded,
          color: AppColors.textoSuave.withValues(alpha: 0.85),
          size: 26,
        ),
      ],
    );
  }
}

class _ToggleAnimaciones extends StatelessWidget {
  const _ToggleAnimaciones({
    required this.activo,
    required this.onChanged,
  });

  final bool activo;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.azul.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Animaciones',
              style: TextStyle(
                color: AppColors.texto,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!activo),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 30,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: activo
                    ? AppColors.azul.withValues(alpha: 0.45)
                    : AppColors.textoSuave.withValues(alpha: 0.28),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment:
                    activo ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: activo
                        ? AppColors.azulSuave
                        : AppColors.textoSuave,
                    boxShadow:
                        activo ? neonGlow(AppColors.azul, blur: 8) : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
