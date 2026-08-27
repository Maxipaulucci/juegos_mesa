import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/services/usuario_mongo_service.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Botón circular de perfil / cuenta (mismo estilo que en home).
class BotonPerfil extends StatelessWidget {
  const BotonPerfil({
    super.key,
    required this.onTap,
    this.tamano = 42,
  });

  final VoidCallback onTap;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final haySesion = UsuarioMongoService.instance.haySesion;
    final nick =
        UsuarioMongoService.instance.usuario?.nombreUsuario ?? '';

    return Tooltip(
      message: haySesion ? 'Perfil' : 'Cuenta',
      child: Material(
        color: AppColors.carta,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: tamano,
            height: tamano,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.azul.withValues(alpha: 0.85),
                width: 1.6,
              ),
              boxShadow: neonGlow(AppColors.azul, blur: 10),
            ),
            child: Center(
              child: haySesion
                  ? Text(
                      nick.isEmpty ? '?' : nick.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: AppColors.texto,
                        fontWeight: FontWeight.w900,
                        fontSize: tamano * 0.38,
                      ),
                    )
                  : Icon(
                      Icons.person_rounded,
                      color: AppColors.texto,
                      size: tamano * 0.52,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
