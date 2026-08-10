import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/guerraDeCartas/opciones_guerra.dart';
import 'package:app_juegos_mesa/guerraDeCartas/partida_guerra_screen.dart';
import 'package:app_juegos_mesa/guerraDeCartas/standby_store.dart';
import 'package:app_juegos_mesa/guerraDeCartas/textos.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/menu/modificar_partida.dart';
import 'package:app_juegos_mesa/shared/orden/decidir_orden_screen.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de Guerra de cartas (local / vs PC; online próximamente).
class MenuGuerraScreen extends StatefulWidget {
  const MenuGuerraScreen({super.key});

  @override
  State<MenuGuerraScreen> createState() => _MenuGuerraScreenState();
}

class _MenuGuerraScreenState extends State<MenuGuerraScreen> {
  OpcionesGuerra _opciones = const OpcionesGuerra();

  Future<void> _abrirCartelModificar() async {
    var draft = _opciones;
    final ok = await mostrarCartelModificarPartida(
      context: context,
      buildOpciones: (dialogContext, setDialogState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilaToggleModificarPartida(
              titulo: 'Vidas',
              activo: draft.vidasActivas,
              onChanged: (v) => setDialogState(
                () => draft = draft.copyWith(vidasActivas: v),
              ),
              info: TextosGuerra.infoOpcionVidas,
            ),
          ],
        );
      },
    );
    if (ok && mounted) {
      setState(() => _opciones = draft);
      GuerraMenuConfig.actualizar(_opciones);
      if (GuerraStandByStore.peek()?.opciones != _opciones) {
        GuerraStandByStore.limpiar();
      }
    }
  }

  Future<void> _abrir({
    required BuildContext ctx,
    required List<String> nombres,
    bool contraPc = false,
    bool modoDios = false,
    PartidaGuerraResume? resume,
    bool replace = false,
  }) {
    GuerraMenuConfig.actualizar(_opciones);
    return navegarConCarga<void>(
      ctx,
      replace: replace,
      mensaje: resume != null ? 'Reanudando partida' : 'Repartiendo cartas',
      acento: AppColors.azul,
      builder: (_) => PartidaGuerraScreen(
        nombres: resume?.nombres ?? nombres,
        contraPc: contraPc,
        // Siempre la config actual del menú (no la del resume viejo).
        modoDios: contraPc && modoDios,
        opciones: _opciones,
        resume: resume,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MenuJuegoScreen(
      titulo: TextosGuerra.titulo,
      juegoId: MenuJuegoScreen.juegoIdGuerraDeCartas,
      modosDados: const [1],
      mostrarDificultad: false,
      mostrarJugadoresVsPc: true,
      opcionesCantidadJugadores: const [2, 3, 4],
      opcionesCantidadPc: const [1, 2, 3],
      onCantidadPcChanged: (_) => GuerraStandByStore.limpiar(),
      decidirOrdenTipoMazo: TipoMazoOrden.ingles,
      textoInfoModoDios: TextosGuerra.infoModoDios,
      extraTrasModoLocal: BotonModificarPartida(
        onPressed: _abrirCartelModificar,
      ),
      onPartidaRapida: (ctx, estado, _) async {
        await _abrir(ctx: ctx, nombres: estado.nombres);
      },
      onVsPc: (ctx, estado, _) {
        GuerraMenuConfig.actualizar(_opciones);
        registrarModoDiosMenu(
          MenuJuegoScreen.juegoIdGuerraDeCartas,
          estado.modoDios,
        );
        final resume = GuerraStandByStore.consumirSiCoincide(_opciones);
        final resumeOk = resume != null &&
                coincideCantidadPc(resume.nombres, estado.cantidadPc)
            ? resume
            : null;
        final humano = estado.nombres.isNotEmpty
            ? estado.nombres.first
            : 'Jugador 1';
        final nombres = resumeOk?.nombres ??
            nombresPartidaVsPc(
              humano: humano,
              total: estado.totalVsPc,
            );
        _abrir(
          ctx: ctx,
          nombres: nombres,
          contraPc: true,
          modoDios: estado.modoDios,
          resume: resumeOk,
        );
      },
      onIniciarDesdeSala: (ctx, inicio) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text(TextosGuerra.onlineProximamente)),
        );
      },
    );
  }
}
