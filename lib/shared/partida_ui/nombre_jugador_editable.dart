import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Pastilla del nombre editable (fondo oscuro + borde violeta + lápiz).
/// Va *dentro* de la tarjeta del jugador; no pinta toda la tarjeta.
class NombreJugadorEditable extends StatelessWidget {
  const NombreJugadorEditable({
    super.key,
    required this.nombre,
    this.puedeRenombrar = false,
    this.onRenombrar,
    this.colorTexto,
    this.fontSize = 13,
    this.tachado = false,
    this.mayusculas = true,
  });

  final String nombre;
  final bool puedeRenombrar;
  final VoidCallback? onRenombrar;
  final Color? colorTexto;
  final double fontSize;
  final bool tachado;
  final bool mayusculas;

  @override
  Widget build(BuildContext context) {
    final texto = mayusculas ? nombre.toUpperCase() : nombre;
    final color = colorTexto ?? AppColors.texto;

    final label = Text(
      texto,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w900,
        fontSize: fontSize,
        letterSpacing: 0.5,
        decoration: tachado ? TextDecoration.lineThrough : null,
      ),
    );

    if (!puedeRenombrar) {
      return label;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onRenombrar,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0E061C),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.violeta.withValues(alpha: 0.7),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: label),
              const SizedBox(width: 6),
              Icon(
                Icons.edit_rounded,
                size: 14,
                color: AppColors.violeta.withValues(alpha: 0.95),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
