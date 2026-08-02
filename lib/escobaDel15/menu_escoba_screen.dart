import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/escobaDel15/partida_escoba_screen.dart';
import 'package:app_juegos_mesa/escobaDel15/standby_store.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de Escoba del 15 (sin selector de dificultad: una sola IA).
class MenuEscobaScreen extends StatelessWidget {
  const MenuEscobaScreen({super.key});

  Future<void> _abrir({
    required BuildContext ctx,
    required List<String> nombres,
    bool contraPc = false,
    String? salaCodigo,
    String? miNombre,
    bool replace = false,
    AjustesEstado? ajustes,
    PartidaEscobaResume? resume,
    bool modoDios = false,
  }) {
    return navegarConCarga<void>(
      ctx,
      replace: replace,
      mensaje: 'Preparando cartas',
      acento: AppColors.azul,
      builder: (_) => PartidaEscobaScreen(
        nombres: nombres,
        contraPc: contraPc,
        salaCodigo: salaCodigo,
        miNombre: miNombre,
        ajustesIniciales: ajustes,
        resume: resume,
        modoDios: resume?.modoDios ?? modoDios,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MenuJuegoScreen(
      titulo: 'Escoba del 15',
      juegoId: MenuJuegoScreen.juegoIdEscobaDel15,
      modosDados: const [1],
      mostrarDificultad: false,
      onPartidaRapida: (ctx, estado, _) async {
        await _abrir(
          ctx: ctx,
          nombres: estado.nombres,
          ajustes: estado.ajustes,
          modoDios: estado.modoDios,
        );
      },
      onVsPc: (ctx, estado, _) {
        final resume = EscobaStandByStore.consumir();
        final nombres = resume?.nombres ??
            (estado.nombres.length >= 2
                ? [estado.nombres.first, 'PC']
                : const ['Jugador 1', 'PC']);
        _abrir(
          ctx: ctx,
          nombres: nombres,
          contraPc: true,
          ajustes: resume?.ajustesIniciales ?? estado.ajustes,
          resume: resume,
          modoDios: resume?.modoDios ?? estado.modoDios,
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
