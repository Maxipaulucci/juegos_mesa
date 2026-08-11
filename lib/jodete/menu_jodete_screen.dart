import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/jodete/partida_jodete_screen.dart';
import 'package:app_juegos_mesa/jodete/standby_store.dart';
import 'package:app_juegos_mesa/jodete/textos.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de Jodete (local / vs PC; online próximamente).
class MenuJodeteScreen extends StatelessWidget {
  const MenuJodeteScreen({super.key});

  Future<void> _abrir({
    required BuildContext ctx,
    required List<String> nombres,
    bool contraPc = false,
    bool modoDios = false,
    DificultadPc dificultad = DificultadPc.medio,
    PartidaJodeteResume? resume,
  }) {
    return navegarConCarga<void>(
      ctx,
      mensaje: resume != null ? 'Reanudando partida' : 'Repartiendo cartas',
      acento: AppColors.peligro,
      builder: (_) => PartidaJodeteScreen(
        nombres: resume?.nombres ?? nombres,
        contraPc: contraPc,
        modoDios: contraPc && modoDios,
        dificultad: dificultad,
        resume: resume,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MenuJuegoScreen(
      titulo: TextosJodete.titulo,
      juegoId: MenuJuegoScreen.juegoIdJodete,
      modosDados: const [1],
      mostrarDificultad: true,
      mostrarJugadoresVsPc: true,
      opcionesCantidadJugadores: const [2, 3, 4],
      opcionesCantidadPc: const [1, 2, 3],
      onCantidadPcChanged: (_) => JodeteStandByStore.limpiar(),
      textoInfoModoDios: TextosJodete.infoModoDios,
      textosInfoDificultad: const {
        DificultadPc.facil: TextosJodete.infoDificultadFacil,
        DificultadPc.medio: TextosJodete.infoDificultadMedio,
        DificultadPc.dificil: TextosJodete.infoDificultadDificil,
      },
      onPartidaRapida: (ctx, estado, _) async {
        await _abrir(ctx: ctx, nombres: estado.nombres);
      },
      onVsPc: (ctx, estado, _) {
        registrarModoDiosMenu(
          MenuJuegoScreen.juegoIdJodete,
          estado.modoDios,
        );
        final resumeRaw = JodeteStandByStore.consumir();
        final resume = resumeRaw != null &&
                coincideCantidadPc(resumeRaw.nombres, estado.cantidadPc)
            ? resumeRaw
            : null;
        final humano = estado.nombres.isNotEmpty
            ? estado.nombres.first
            : 'Jugador 1';
        final nombres = resume?.nombres ??
            nombresPartidaVsPc(
              humano: humano,
              total: estado.totalVsPc,
            );
        _abrir(
          ctx: ctx,
          nombres: nombres,
          contraPc: true,
          modoDios: resume?.modoDios ?? estado.modoDios,
          dificultad: estado.dificultad,
          resume: resume,
        );
      },
      onIniciarDesdeSala: (ctx, inicio) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text(TextosJodete.onlineProximamente)),
        );
      },
    );
  }
}
