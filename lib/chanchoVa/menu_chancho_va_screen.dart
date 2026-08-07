import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/chanchoVa/opciones_chancho_va.dart';
import 'package:app_juegos_mesa/chanchoVa/partida_chancho_va_screen.dart';
import 'package:app_juegos_mesa/chanchoVa/standby_store.dart';
import 'package:app_juegos_mesa/chanchoVa/textos.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/menu/modificar_partida.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de Chancho va (vs PC; online próximamente).
class MenuChanchoVaScreen extends StatefulWidget {
  const MenuChanchoVaScreen({super.key});

  @override
  State<MenuChanchoVaScreen> createState() => _MenuChanchoVaScreenState();
}

class _MenuChanchoVaScreenState extends State<MenuChanchoVaScreen> {
  OpcionesChanchoVa _opciones = const OpcionesChanchoVa();

  Future<void> _abrirCartelModificar() async {
    var draft = _opciones;
    final ok = await mostrarCartelModificarPartida(
      context: context,
      buildOpciones: (dialogContext, setDialogState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilaToggleModificarPartida(
              titulo: 'Chancha',
              activo: draft.chancha,
              onChanged: (v) => setDialogState(
                () => draft = draft.copyWith(chancha: v),
              ),
              info: TextosChancho.infoOpcionChancha,
            ),
            const SizedBox(height: 12),
            FilaToggleModificarPartida(
              titulo: 'Sin espacio (CHANCHOVA)',
              activo: draft.sinEspacio,
              onChanged: (v) => setDialogState(
                () => draft = draft.copyWith(sinEspacio: v),
              ),
              info: TextosChancho.infoOpcionSinEspacio,
            ),
            const SizedBox(height: 12),
            FilaToggleModificarPartida(
              titulo: 'Fin al primer perdedor',
              activo: draft.finAlPrimerPerdedor,
              onChanged: (v) => setDialogState(
                () => draft = draft.copyWith(finAlPrimerPerdedor: v),
              ),
              info: TextosChancho.infoOpcionFinAlPrimerPerdedor,
            ),
          ],
        );
      },
    );
    if (ok && mounted) {
      setState(() => _opciones = draft);
    }
  }

  Future<void> _abrir({
    required BuildContext ctx,
    required List<String> nombres,
    bool contraPc = false,
    bool modoDios = false,
    AjustesEstado? ajustes,
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
        ajustesIniciales: ajustes,
        resume: resume,
        opciones: resume?.opciones ?? _opciones,
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
      mostrarMultijugadorLocal: false,
      mostrarJugadoresVsPc: true,
      opcionesCantidadJugadores: const [3, 4],
      textoInfoModoDios: TextosChancho.infoModoDios,
      extraTrasModoLocal: BotonModificarPartida(
        onPressed: _abrirCartelModificar,
      ),
      onPartidaRapida: (_, __, ___) async {},
      onVsPc: (ctx, estado, _) {
        final resume = ChanchoStandByStore.consumir();
        final humano = resume?.nombres.firstWhere(
              (n) => !TextosChancho.esPc(n),
              orElse: () => estado.nombres.isNotEmpty
                  ? estado.nombres.first
                  : 'Jugador 1',
            ) ??
            (estado.nombres.isNotEmpty ? estado.nombres.first : 'Jugador 1');
        final nombres = resume?.nombres ??
            TextosChancho.nombresVsPc(
              humano: humano,
              total: estado.cantidadJugadores.clamp(3, 4),
            );
        _abrir(
          ctx: ctx,
          nombres: nombres,
          contraPc: true,
          modoDios: resume?.modoDios ?? estado.modoDios,
          ajustes: resume?.ajustesIniciales ?? estado.ajustes,
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
