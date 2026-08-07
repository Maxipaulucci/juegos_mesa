import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/chanchoVa/partida_chancho_va_screen.dart';
import 'package:app_juegos_mesa/chanchoVa/standby_store.dart';
import 'package:app_juegos_mesa/chanchoVa/textos.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de Chancho va (local / vs PC; online próximamente).
class MenuChanchoVaScreen extends StatelessWidget {
  const MenuChanchoVaScreen({super.key});

  Future<void> _abrir({
    required BuildContext ctx,
    required List<String> nombres,
    bool contraPc = false,
    bool modoDios = false,
    PartidaChanchoResume? resume,
    bool replace = false,
  }) {
    return navegarConCarga<void>(
      ctx,
      replace: replace,
      mensaje: resume != null ? 'Reanudando partida' : 'Preparando Chancho va',
      acento: AppColors.acentoSuave,
      builder: (_) => PartidaChanchoVaScreen(
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
      titulo: TextosChancho.titulo,
      juegoId: MenuJuegoScreen.juegoIdChanchoVa,
      modosDados: const [1],
      mostrarDificultad: false,
      textoInfoModoDios: TextosChancho.infoModoDios,
      onPartidaRapida: (ctx, estado, _) async {
        final nombres = estado.nombres.length >= 2
            ? estado.nombres.take(4).toList()
            : const ['Jugador 1', 'Jugador 2'];
        await _abrir(ctx: ctx, nombres: nombres);
      },
      onVsPc: (ctx, estado, _) {
        final resume = ChanchoStandByStore.consumir();
        final nombres = resume?.nombres ??
            (estado.nombres.isNotEmpty
                ? [estado.nombres.first, TextosChancho.vsPcNombre]
                : const ['Jugador 1', TextosChancho.vsPcNombre]);
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
          const SnackBar(content: Text(TextosChancho.onlineProximamente)),
        );
      },
    );
  }
}
