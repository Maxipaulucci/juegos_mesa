import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/unoSolo/partida_uno_solo_screen.dart';
import 'package:app_juegos_mesa/unoSolo/standby_store.dart';

/// Menú de Uno solo: mismo layout que La papa (solo / local / online).
class MenuUnoSoloScreen extends StatelessWidget {
  const MenuUnoSoloScreen({super.key});

  Future<void> _abrirPartida({
    required BuildContext ctx,
    required List<String> nombres,
    required MenuJuegoEstado estado,
    bool solo = false,
    PartidaUnoSoloResume? resume,
  }) {
    return navegarConCarga<void>(
      ctx,
      mensaje: 'Preparando tablero',
      acento: AppColors.mint,
      builder: (_) => PartidaUnoSoloScreen(
        nombres: resume?.nombres ?? nombres,
        solo: solo,
        ajustesIniciales: resume?.ajustesIniciales ?? estado.ajustes,
        resume: resume,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MenuJuegoScreen(
      titulo: 'Uno solo',
      juegoId: MenuJuegoScreen.juegoIdUnoSolo,
      modosDados: const [1],
      jugarSoloEnLugarDePc: true,
      onPartidaRapida: (ctx, estado, _) async {
        await _abrirPartida(
          ctx: ctx,
          nombres: estado.nombres,
          estado: estado,
        );
      },
      onVsPc: (ctx, estado, _) {
        final resume = UnoSoloStandByStore.consumir();
        _abrirPartida(
          ctx: ctx,
          nombres: resume?.nombres ??
              (estado.nombres.isEmpty
                  ? const ['Jugador']
                  : estado.nombres),
          estado: estado,
          solo: true,
          resume: resume,
        );
      },
      onIniciarDesdeSala: (ctx, inicio) {
        navegarConCarga<void>(
          ctx,
          replace: true,
          mensaje: 'Preparando tablero',
          acento: AppColors.mint,
          builder: (_) => PartidaUnoSoloScreen(
            nombres: inicio.nombres,
            salaCodigo: inicio.salaCodigo,
            miNombre: inicio.miNombre,
          ),
        );
      },
    );
  }
}
