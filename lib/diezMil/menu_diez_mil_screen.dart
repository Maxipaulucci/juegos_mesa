import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/diezMil/motor.dart';
import 'package:app_juegos_mesa/diezMil/partida_diez_mil_screen.dart';
import 'package:app_juegos_mesa/diezMil/standby_store.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de Diez Mil: arma el [MenuJuegoScreen] y navega a la partida.
class MenuDiezMilScreen extends StatelessWidget {
  const MenuDiezMilScreen({super.key});

  static const juegoIdDiezMil = MenuJuegoScreen.juegoIdDiezMil;
  static const juegoIdGenerala = MenuJuegoScreen.juegoIdGenerala;

  Modo _modoDeDados(int dados) => dados == 6 ? Modo.seis : Modo.cinco;

  @override
  Widget build(BuildContext context) {
    return MenuJuegoScreen(
      titulo: 'Diez Mil',
      juegoId: MenuJuegoScreen.juegoIdDiezMil,
      modosDados: const [5, 6],
      mostrarDificultad: true,
      mostrarJugadoresVsPc: true,
      opcionesCantidadJugadores: const [2, 3, 4],
      onPartidaRapida: (ctx, estado, dados) async {
        await navegarConCarga<void>(
          ctx,
          mensaje: 'Iniciando partida',
          acento: AppColors.acento,
          builder: (_) => PartidaDiezMilScreen(
            nombres: estado.nombres,
            modo: _modoDeDados(dados),
            partidaRapida: true,
            ajustesIniciales: estado.ajustes,
          ),
        );
      },
      onVsPc: (ctx, estado, dados) {
        final modo = _modoDeDados(dados);
        final resume =
            DiezMilStandByStore.consumirSiCoincide(modo, estado.dificultad);
        final humano = estado.nombres.isNotEmpty
            ? estado.nombres.first
            : 'Jugador 1';
        final nombres = resume?.nombres ??
            nombresPartidaVsPc(
              humano: humano,
              total: estado.cantidadJugadores,
            );
        navegarConCarga<void>(
          ctx,
          mensaje: 'Iniciando partida',
          acento: AppColors.acento,
          builder: (_) => PartidaDiezMilScreen(
            nombres: nombres,
            modo: modo,
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
          acento: AppColors.acento,
          builder: (_) => PartidaDiezMilScreen(
            nombres: inicio.nombres,
            modo: _modoDeDados(inicio.dados),
            salaCodigo: inicio.salaCodigo,
            miNombre: inicio.miNombre,
          ),
        );
      },
    );
  }
}
