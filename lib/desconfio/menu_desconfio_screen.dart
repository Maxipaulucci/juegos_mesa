import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/desconfio/partida_desconfio_screen.dart';
import 'package:app_juegos_mesa/desconfio/standby_store.dart';
import 'package:app_juegos_mesa/desconfio/textos.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de Desconfío (local / vs PC; online próximamente).
class MenuDesconfioScreen extends StatelessWidget {
  const MenuDesconfioScreen({super.key});

  Future<void> _abrir({
    required BuildContext ctx,
    required List<String> nombres,
    bool contraPc = false,
    bool modoDios = false,
    DificultadPc dificultad = DificultadPc.medio,
    PartidaDesconfioResume? resume,
  }) {
    return navegarConCarga<void>(
      ctx,
      mensaje: resume != null ? 'Reanudando partida' : 'Repartiendo cartas',
      acento: AppColors.azulSuave,
      builder: (_) => PartidaDesconfioScreen(
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
      titulo: TextosDesconfio.titulo,
      juegoId: MenuJuegoScreen.juegoIdDesconfio,
      modosDados: const [1],
      mostrarDificultad: true,
      mostrarJugadoresVsPc: true,
      opcionesCantidadJugadores: const [2, 3, 4],
      opcionesCantidadPc: const [1, 2, 3],
      onCantidadPcChanged: (_) => DesconfioStandByStore.limpiar(),
      textoInfoModoDios: TextosDesconfio.infoModoDios,
      onPartidaRapida: (ctx, estado, _) async {
        await _abrir(ctx: ctx, nombres: estado.nombres);
      },
      onVsPc: (ctx, estado, _) {
        final resumeRaw = DesconfioStandByStore.consumir();
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
          modoDios: estado.modoDios,
          dificultad: estado.dificultad,
          resume: resume,
        );
      },
      onIniciarDesdeSala: (ctx, inicio) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text(TextosDesconfio.onlineProximamente)),
        );
      },
    );
  }
}
