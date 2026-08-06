import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/casitaRobada/partida_casita_screen.dart';
import 'package:app_juegos_mesa/casitaRobada/standby_store.dart';
import 'package:app_juegos_mesa/casitaRobada/textos.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de Casita robada (local / vs PC; online próximamente).
class MenuCasitaRobadaScreen extends StatelessWidget {
  const MenuCasitaRobadaScreen({super.key});

  Future<void> _abrir({
    required BuildContext ctx,
    required List<String> nombres,
    bool contraPc = false,
    bool modoDios = false,
    PartidaCasitaResume? resume,
    bool replace = false,
  }) {
    return navegarConCarga<void>(
      ctx,
      replace: replace,
      mensaje: resume != null ? 'Reanudando partida' : 'Repartiendo cartas',
      acento: AppColors.mint,
      builder: (_) => PartidaCasitaScreen(
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
      titulo: TextosCasita.titulo,
      juegoId: MenuJuegoScreen.juegoIdCasitaRobada,
      modosDados: const [1],
      mostrarDificultad: false,
      textoInfoModoDios: TextosCasita.infoModoDios,
      onPartidaRapida: (ctx, estado, _) async {
        await _abrir(ctx: ctx, nombres: estado.nombres);
      },
      onVsPc: (ctx, estado, _) {
        final resume = CasitaStandByStore.consumir();
        final nombres = resume?.nombres ??
            (estado.nombres.length >= 2
                ? [estado.nombres.first, TextosCasita.vsPcNombre]
                : const ['Jugador 1', TextosCasita.vsPcNombre]);
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
          const SnackBar(content: Text(TextosCasita.onlineProximamente)),
        );
      },
    );
  }
}
