import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/generala/partida_generala_screen.dart';
import 'package:app_juegos_mesa/generala/standby_store.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de Generala: arma el [MenuJuegoScreen] y navega a la partida.
class MenuGeneralaScreen extends StatelessWidget {
  const MenuGeneralaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuJuegoScreen(
      titulo: 'Generala',
      juegoId: MenuJuegoScreen.juegoIdGenerala,
      modosDados: const [5],
      mostrarDificultad: false,
      onPartidaRapida: (ctx, estado, dados) async {
        await navegarConCarga<void>(
          ctx,
          mensaje: 'Iniciando partida',
          acento: AppColors.violeta,
          builder: (_) => PartidaGeneralaScreen(
            nombres: estado.nombres,
            partidaRapida: true,
            ajustesIniciales: estado.ajustes,
          ),
        );
      },
      onVsPc: (ctx, estado, dados) {
        final resume =
            GeneralaStandByStore.consumirSiCoincide(estado.dificultad);
        final nombres = resume?.nombres ?? const ['Jugador 1', 'PC'];
        navegarConCarga<void>(
          ctx,
          mensaje: 'Iniciando partida',
          acento: AppColors.violeta,
          builder: (_) => PartidaGeneralaScreen(
            nombres: nombres,
            contraPc: true,
            dificultadPc: resume?.dificultadPc ?? estado.dificultad,
            modoDios: resume?.modoDios ?? estado.modoDios,
            ajustesIniciales: resume?.ajustesIniciales ?? estado.ajustes,
            resume: resume,
          ),
        );
      },
      onIniciarDesdeSala: (ctx, inicio) {
        navegarConCarga<void>(
          ctx,
          replace: true,
          mensaje: 'Iniciando partida',
          acento: AppColors.violeta,
          builder: (_) => PartidaGeneralaScreen(
            nombres: inicio.nombres,
            salaCodigo: inicio.salaCodigo,
            miNombre: inicio.miNombre,
          ),
        );
      },
    );
  }
}
