import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/culoSucioV2/partida_culo_sucio_v2_screen.dart';
import 'package:app_juegos_mesa/culoSucioV2/standby_store.dart';
import 'package:app_juegos_mesa/culoSucioV2/textos.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de Culo sucio v2 (local / vs PC; online próximamente).
class MenuCuloSucioV2Screen extends StatelessWidget {
  const MenuCuloSucioV2Screen({super.key});

  Future<void> _abrir({
    required BuildContext ctx,
    required List<String> nombres,
    bool contraPc = false,
    bool modoDios = false,
    PartidaCuloSucioV2Resume? resume,
  }) {
    return navegarConCarga<void>(
      ctx,
      mensaje: resume != null ? 'Reanudando partida' : 'Repartiendo cartas',
      acento: AppColors.acentoSuave,
      builder: (_) => PartidaCuloSucioV2Screen(
        nombres: resume?.nombres ?? nombres,
        contraPc: contraPc,
        modoDios: contraPc && (resume?.modoDios ?? modoDios),
        resume: resume,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MenuJuegoScreen(
      titulo: TextosCuloSucioV2.titulo,
      juegoId: MenuJuegoScreen.juegoIdCuloSucioV2,
      modosDados: const [1],
      mostrarDificultad: false,
      textoInfoModoDios: TextosCuloSucioV2.infoModoDios,
      onPartidaRapida: (ctx, estado, _) async {
        await _abrir(ctx: ctx, nombres: estado.nombres);
      },
      onVsPc: (ctx, estado, _) {
        final resume = CuloSucioV2StandByStore.consumir();
        final nombres = resume?.nombres ??
            (estado.nombres.length >= 2
                ? [estado.nombres.first, TextosCuloSucioV2.vsPcNombre]
                : const ['Jugador 1', TextosCuloSucioV2.vsPcNombre]);
        _abrir(
          ctx: ctx,
          nombres: nombres,
          contraPc: true,
          modoDios: resume?.modoDios ?? estado.modoDios,
          resume: resume,
        );
      },
      onIniciarDesdeSala: (ctx, inicio) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Online de Culo sucio v2 próximamente'),
          ),
        );
      },
    );
  }
}
