import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/culoSucioV2/opciones_culo_sucio_v2.dart';
import 'package:app_juegos_mesa/culoSucioV2/partida_culo_sucio_v2_screen.dart';
import 'package:app_juegos_mesa/culoSucioV2/standby_store.dart';
import 'package:app_juegos_mesa/culoSucioV2/textos.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/menu/modificar_partida.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de Culo sucio v2 (vs PC / online).
class MenuCuloSucioV2Screen extends StatefulWidget {
  const MenuCuloSucioV2Screen({super.key});

  @override
  State<MenuCuloSucioV2Screen> createState() => _MenuCuloSucioV2ScreenState();
}

class _MenuCuloSucioV2ScreenState extends State<MenuCuloSucioV2Screen> {
  OpcionesCuloSucioV2 _opciones = const OpcionesCuloSucioV2();

  Future<void> _abrirCartelModificar() async {
    var draft = _opciones;
    final ok = await mostrarCartelModificarPartida(
      context: context,
      buildOpciones: (dialogContext, setDialogState) {
        return FilaToggleModificarPartida(
          titulo: 'Eliminar pares automáticamente',
          activo: draft.eliminarParesAuto,
          onChanged: (v) => setDialogState(
            () => draft = draft.copyWith(eliminarParesAuto: v),
          ),
          info:
              'Activado: en la fase inicial aparece el botón para '
              'sacar de golpe todos los pares de tu mano.\n\n'
              'Desactivado: solo podés sacar pares tocando de a dos cartas '
              'del mismo número.\n\n'
              'Viene activado por defecto.',
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
    PartidaCuloSucioV2Resume? resume,
    String? salaCodigo,
    String? miNombre,
    bool replace = false,
  }) {
    return navegarConCarga<void>(
      ctx,
      replace: replace,
      mensaje: salaCodigo != null
          ? 'Conectando partida'
          : resume != null
              ? 'Reanudando partida'
              : 'Repartiendo cartas',
      acento: AppColors.acentoSuave,
      builder: (_) => PartidaCuloSucioV2Screen(
        nombres: resume?.nombres ?? nombres,
        contraPc: contraPc,
        modoDios: contraPc && (resume?.modoDios ?? modoDios),
        opciones: resume?.opciones ?? _opciones,
        resume: resume,
        salaCodigo: salaCodigo,
        miNombre: miNombre,
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
      mostrarMultijugadorLocal: false,
      textoInfoModoDios: TextosCuloSucioV2.infoModoDios,
      extraTrasModoLocal: BotonModificarPartida(
        onPressed: _abrirCartelModificar,
      ),
      onPartidaRapida: (_, __, ___) async {},
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
