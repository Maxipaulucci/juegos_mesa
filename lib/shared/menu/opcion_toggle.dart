import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Etiqueta de sección + toggle (Decidir orden / Modo Dios).
class FilaOpcionToggle extends StatelessWidget {
  const FilaOpcionToggle({
    super.key,
    required this.etiqueta,
    required this.opcion,
    required this.activo,
    required this.onChanged,
    required this.onInfo,
  });

  final String etiqueta;
  final String opcion;
  final bool activo;
  final ValueChanged<bool> onChanged;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            etiqueta,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
          decoration: BoxDecoration(
            color: const Color(0xFF0E061C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.violeta.withValues(alpha: 0.7),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                opcion,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              SwitchNeon(activo: activo, onChanged: onChanged),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onInfo,
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.help,
                size: 18,
                color: AppColors.textoSuave,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Switch estilo neon (mismo look que Animaciones en ajustes).
class SwitchNeon extends StatelessWidget {
  const SwitchNeon({
    super.key,
    required this.activo,
    required this.onChanged,
  });

  final bool activo;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
          alignment: activo ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activo ? AppColors.azulSuave : AppColors.textoSuave,
              boxShadow: activo ? neonGlow(AppColors.azul, blur: 8) : null,
            ),
          ),
        ),
      ),
    );
  }
}
