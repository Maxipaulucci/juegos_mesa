import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/escobaDel15/opciones_escoba.dart';
import 'package:app_juegos_mesa/escobaDel15/partida_escoba_screen.dart';
import 'package:app_juegos_mesa/escobaDel15/standby_store.dart';
import 'package:app_juegos_mesa/escobaDel15/textos.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/menu/modificar_partida.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de Escoba del 15 (sin selector de dificultad: una sola IA).
class MenuEscobaScreen extends StatefulWidget {
  const MenuEscobaScreen({super.key});

  @override
  State<MenuEscobaScreen> createState() => _MenuEscobaScreenState();
}

class _MenuEscobaScreenState extends State<MenuEscobaScreen> {
  OpcionesEscoba _opciones = const OpcionesEscoba();

  Future<void> _abrirCartelModificar() async {
    var draft = _opciones;
    final ok = await mostrarCartelModificarPartida(
      context: context,
      buildOpciones: (dialogContext, setDialogState) {
        return FilaToggleModificarPartida(
          titulo: TextosEscoba.escobasAutomaticasInicio,
          activo: draft.escobasAutomaticasInicio,
          onChanged: (v) => setDialogState(
            () => draft = draft.copyWith(escobasAutomaticasInicio: v),
          ),
          info: TextosEscoba.infoEscobasAutomaticasInicio,
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
        opciones: resume?.opciones ?? _opciones,
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
      mostrarJugadoresVsPc: true,
      opcionesCantidadJugadores: const [2, 3, 4],
      extraTrasModoLocal: BotonModificarPartida(
        onPressed: _abrirCartelModificar,
      ),
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
