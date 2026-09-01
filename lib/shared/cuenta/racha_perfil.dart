import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/shared/cuenta/cartel_calendario_racha.dart';
import 'package:app_juegos_mesa/shared/cuenta/cartel_como_funciona_racha.dart';
import 'package:app_juegos_mesa/shared/cuenta/reestablecer_racha_anterior.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Muestra racha actual, racha máxima y racha anterior del usuario.
class RachaPerfil extends StatelessWidget {
  const RachaPerfil({
    super.key,
    required this.rachaDias,
    required this.rachaMaxima,
    required this.rachaAnterior,
    this.compacto = false,
    this.onRachaRestablecida,
  });

  final int rachaDias;
  final int rachaMaxima;
  final int rachaAnterior;
  final bool compacto;
  final VoidCallback? onRachaRestablecida;

  static const _fuego = Color(0xFFFF7043);

  @override
  Widget build(BuildContext context) {
    final tamIcono = compacto ? 22.0 : 26.0;
    final tamRacha = compacto ? 18.0 : 20.0;
    final tamAyuda = compacto ? 15.0 : 16.0;
    final tamCalendario = compacto ? 17.0 : 18.0;
    final tamBotonCalendario = compacto ? 30.0 : 32.0;
    final maximaVisible =
        rachaMaxima >= rachaDias ? rachaMaxima : rachaDias;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            compacto ? 12 : 14,
            compacto ? 12 : 14,
            compacto ? 10 : 12,
            compacto ? 12 : 14,
          ),
          decoration: BoxDecoration(
            color: AppColors.carta.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _fuego.withValues(alpha: 0.55),
              width: 1.4,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Racha actual',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textoSuave.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w800,
                        fontSize: compacto ? 11 : 12,
                      ),
                    ),
                    SizedBox(height: compacto ? 8 : 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                        const SizedBox(width: 12),
                        Material(
                          color: _fuego.withValues(alpha: 0.18),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () =>
                                mostrarCartelCalendarioRacha(context),
                            customBorder: const CircleBorder(),
                            child: SizedBox(
                              width: tamBotonCalendario,
                              height: tamBotonCalendario,
                              child: Center(
                                child: Icon(
                                  Icons.calendar_month_rounded,
                                  size: tamCalendario,
                                  color: _fuego,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => mostrarCartelComoFuncionaRacha(context),
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.help,
                        size: tamAyuda,
                        color: AppColors.textoSuave,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _CartelRachaExtra(
                  titulo: 'Racha máxima',
                  dias: maximaVisible,
                  compacto: compacto,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CartelRachaExtra(
                  titulo: 'Racha anterior',
                  dias: rachaAnterior,
                  compacto: compacto,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Expanded(child: SizedBox()),
            const SizedBox(width: 10),
            Expanded(
              child: OpcionReestablecerRacha(
                rachaAnterior: rachaAnterior,
                rachaActual: rachaDias,
                onRestablecida: onRachaRestablecida,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CartelRachaExtra extends StatelessWidget {
  const _CartelRachaExtra({
    required this.titulo,
    required this.dias,
    required this.compacto,
  });

  final String titulo;
  final int dias;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final tamIcono = compacto ? 18.0 : 20.0;
    final tamNumero = compacto ? 16.0 : 18.0;

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 10 : 12,
        vertical: compacto ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.carta.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: RachaPerfil._fuego.withValues(alpha: 0.55),
          width: 1.4,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textoSuave.withValues(alpha: 0.95),
              fontWeight: FontWeight.w800,
              fontSize: compacto ? 11 : 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: RachaPerfil._fuego,
                size: tamIcono,
              ),
              const SizedBox(width: 6),
              Text(
                '$dias ${dias == 1 ? 'día' : 'días'}',
                style: TextStyle(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w900,
                  fontSize: tamNumero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
