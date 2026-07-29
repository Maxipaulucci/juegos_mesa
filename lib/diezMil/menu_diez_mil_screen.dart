import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/diezMil/motor.dart';
import 'package:app_juegos_mesa/diezMil/partida_diez_mil_screen.dart';
import 'package:app_juegos_mesa/diezMil/standby_store.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';

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
      onPartidaRapida: (ctx, estado, dados) async {
        await Navigator.of(ctx).push(
          MaterialPageRoute<void>(
            builder: (_) => PartidaDiezMilScreen(
              nombres: estado.nombres,
              modo: _modoDeDados(dados),
              partidaRapida: true,
              ajustesIniciales: estado.ajustes,
            ),
          ),
        );
      },
      onVsPc: (ctx, estado, dados) {
        final modo = _modoDeDados(dados);
        final resume =
            DiezMilStandByStore.consumirSiCoincide(modo, estado.dificultad);
        final nombres = resume?.nombres ?? const ['Jugador 1', 'PC'];
        Navigator.of(ctx).push(
          MaterialPageRoute<void>(
            builder: (_) => PartidaDiezMilScreen(
              nombres: nombres,
              modo: modo,
              contraPc: true,
              dificultadPc: resume?.dificultadPc ?? estado.dificultad,
              modoDios: resume?.modoDios ?? estado.modoDios,
              ajustesIniciales: resume?.ajustesIniciales ?? estado.ajustes,
              resume: resume,
            ),
          ),
        );
      },
      onIniciarDesdeSala: (ctx, inicio) {
        Navigator.of(ctx).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => PartidaDiezMilScreen(
              nombres: inicio.nombres,
              modo: _modoDeDados(inicio.dados),
              salaCodigo: inicio.salaCodigo,
              miNombre: inicio.miNombre,
            ),
          ),
        );
      },
    );
  }
}
