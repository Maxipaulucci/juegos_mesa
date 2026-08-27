import 'package:flutter/material.dart';

import '../menu/menu_juego_screen.dart';
import '../../theme/app_theme.dart';
import '../../tutiFruti/menu_tuti_fruti_screen.dart';

class JuegoPortadaMeta {
  const JuegoPortadaMeta({
    required this.portadaAsset,
    required this.accent,
    this.destacadoFuego = false,
  });

  final String portadaAsset;
  final Color accent;
  final bool destacadoFuego;
}

const _portadaProximamente = 'assets/img/portadas/portadaProximamente.png';

JuegoPortadaMeta portadaMetaDeJuego(String juegoId) {
  return switch (juegoId) {
    MenuJuegoScreen.juegoIdDiezMil => const JuegoPortadaMeta(
        portadaAsset: 'assets/img/portadas/portadaDiezMil.png',
        accent: AppColors.acento,
      ),
    MenuJuegoScreen.juegoIdGenerala => const JuegoPortadaMeta(
        portadaAsset: 'assets/img/portadas/portadaGenerala.png',
        accent: AppColors.violeta,
      ),
    MenuJuegoScreen.juegoIdLaPapa => const JuegoPortadaMeta(
        portadaAsset: 'assets/img/portadas/portadaLaPapa.jpeg',
        accent: AppColors.mint,
      ),
    MenuJuegoScreen.juegoIdEscobaDel15 => const JuegoPortadaMeta(
        portadaAsset: 'assets/img/portadas/portadaEscoba.png',
        accent: AppColors.azul,
      ),
    MenuJuegoScreen.juegoIdUnoSolo => const JuegoPortadaMeta(
        portadaAsset: 'assets/img/portadas/portadaUnoSolo.png',
        accent: AppColors.mint,
      ),
    MenuJuegoScreen.juegoIdCuloSucioV1 => const JuegoPortadaMeta(
        portadaAsset: 'assets/img/portadas/portadaCuloSucioV1.png',
        accent: AppColors.peligro,
      ),
    MenuJuegoScreen.juegoIdCuloSucioV2 => const JuegoPortadaMeta(
        portadaAsset: 'assets/img/portadas/portadaCuloSucioV2.png',
        accent: AppColors.acentoSuave,
        destacadoFuego: true,
      ),
    MenuJuegoScreen.juegoIdCasitaRobada => const JuegoPortadaMeta(
        portadaAsset: 'assets/img/portadas/portadaCasitaRobada.png',
        accent: AppColors.mint,
      ),
    MenuJuegoScreen.juegoIdChanchoVa => const JuegoPortadaMeta(
        portadaAsset: 'assets/img/portadas/portadaChanchoVa.png',
        accent: AppColors.acentoSuave,
      ),
    MenuJuegoScreen.juegoIdGuerraDeCartas => const JuegoPortadaMeta(
        portadaAsset: 'assets/img/portadas/portadaGuerraDeCartas.png',
        accent: AppColors.rosa,
      ),
    MenuJuegoScreen.juegoIdDesconfio => const JuegoPortadaMeta(
        portadaAsset: 'assets/img/portadas/portadaDesconfio.png',
        accent: AppColors.azulSuave,
      ),
    MenuJuegoScreen.juegoIdJodete => const JuegoPortadaMeta(
        portadaAsset: 'assets/img/portadas/portadaJodete.png',
        accent: AppColors.violeta,
      ),
    juegoIdTutiFruti => const JuegoPortadaMeta(
        portadaAsset: 'assets/img/portadas/portadaTuttiFrutti.png',
        accent: AppColors.rosa,
      ),
    'canasta' => const JuegoPortadaMeta(
        portadaAsset: 'assets/img/portadas/portadaCanasta.png',
        accent: AppColors.mint,
      ),
    _ => const JuegoPortadaMeta(
        portadaAsset: _portadaProximamente,
        accent: AppColors.violeta,
      ),
  };
}
