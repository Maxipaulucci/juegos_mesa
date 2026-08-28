import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/shared/cuenta/cartel_como_funciona_racha.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Muestra racha actual (fuego + días) y racha máxima del usuario.
class RachaPerfil extends StatelessWidget {
  const RachaPerfil({
    super.key,
    required this.rachaDias,
    required this.rachaMaxima,
    this.compacto = false,
  });

  final int rachaDias;
  final int rachaMaxima;
  final bool compacto;

  static const _fuego = Color(0xFFFF7043);

  @override
  Widget build(BuildContext context) {
    final tamIcono = compacto ? 22.0 : 26.0;
    final tamRacha = compacto ? 18.0 : 20.0;
    final maximaVisible =
        rachaMaxima >= rachaDias ? rachaMaxima : rachaDias;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => mostrarCartelComoFuncionaRacha(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: compacto ? 12 : 14,
            vertical: compacto ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: AppColors.carta.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _fuego.withValues(alpha: 0.55),
              width: 1.4,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: _fuego,
                    size: tamIcono,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$rachaDias ${rachaDias == 1 ? 'día' : 'días'}',
                    style: TextStyle(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w900,
                      fontSize: tamRacha,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Racha máxima: $maximaVisible ${maximaVisible == 1 ? 'día' : 'días'}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textoSuave.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w700,
                  fontSize: compacto ? 12 : 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
