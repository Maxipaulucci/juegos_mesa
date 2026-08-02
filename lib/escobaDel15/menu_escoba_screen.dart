import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/escobaDel15/partida_escoba_screen.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de Escoba del 15: mismas entradas que Generala.
class MenuEscobaScreen extends StatelessWidget {
  const MenuEscobaScreen({super.key});

  Future<void> _abrir({
    required BuildContext ctx,
    required List<String> nombres,
    bool contraPc = false,
    DificultadPc? dificultadPc,
    String? salaCodigo,
    String? miNombre,
    bool replace = false,
    AjustesEstado? ajustes,
  }) {
    return navegarConCarga<void>(
      ctx,
      replace: replace,
      mensaje: 'Preparando cartas',
      acento: AppColors.azul,
      builder: (_) => PartidaEscobaScreen(
        nombres: nombres,
        contraPc: contraPc,
        dificultadPc: dificultadPc,
        salaCodigo: salaCodigo,
        miNombre: miNombre,
        ajustesIniciales: ajustes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MenuJuegoScreen(
      titulo: 'Escoba del 15',
      juegoId: MenuJuegoScreen.juegoIdEscobaDel15,
      modosDados: const [1],
      mostrarDificultad: true,
      onPartidaRapida: (ctx, estado, _) async {
        await _abrir(
          ctx: ctx,
          nombres: estado.nombres,
          ajustes: estado.ajustes,
        );
      },
      onVsPc: (ctx, estado, _) {
        final nombres = estado.nombres.length >= 2
            ? [estado.nombres.first, 'PC']
            : const ['Jugador 1', 'PC'];
        _abrir(
          ctx: ctx,
          nombres: nombres,
          contraPc: true,
          dificultadPc: estado.dificultad,
          ajustes: estado.ajustes,
        );
      },
      onIniciarDesdeSala: (ctx, inicio) {
        _abrir(
          ctx: ctx,
          nombres: inicio.nombres,
          salaCodigo: inicio.salaCodigo,
          miNombre: inicio.miNombre,
          replace: true,
        );
      },
    );
  }
}
