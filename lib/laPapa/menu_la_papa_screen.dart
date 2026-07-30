import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/laPapa/partida_la_papa_screen.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de La papa: mismo layout que Generala, con "Jugar solo" en vez de vs PC.
class MenuLaPapaScreen extends StatelessWidget {
  const MenuLaPapaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuJuegoScreen(
      titulo: 'La papa',
      juegoId: MenuJuegoScreen.juegoIdLaPapa,
      modosDados: const [1],
      jugarSoloEnLugarDePc: true,
      onPartidaRapida: (ctx, estado, _) async {
        await navegarConCarga<void>(
          ctx,
          mensaje: 'Preparando hoja',
          acento: AppColors.mint,
          builder: (_) => PartidaLaPapaScreen(nombres: estado.nombres),
        );
      },
      onVsPc: (ctx, estado, _) {
        navegarConCarga<void>(
          ctx,
          mensaje: 'Preparando hoja',
          acento: AppColors.mint,
          builder: (_) => PartidaLaPapaScreen(
            nombres: estado.nombres.isEmpty
                ? const ['Jugador']
                : estado.nombres,
            solo: true,
          ),
        );
      },
      onIniciarDesdeSala: (ctx, inicio) {
        navegarConCarga<void>(
          ctx,
          replace: true,
          mensaje: 'Preparando hoja',
          acento: AppColors.mint,
          builder: (_) => PartidaLaPapaScreen(nombres: inicio.nombres),
        );
      },
    );
  }
}
