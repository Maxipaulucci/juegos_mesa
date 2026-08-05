import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/culoSucio/opciones_culo_sucio.dart';
import 'package:app_juegos_mesa/culoSucio/partida_culo_sucio_screen.dart';
import 'package:app_juegos_mesa/culoSucio/standby_store.dart';
import 'package:app_juegos_mesa/culoSucio/textos.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/menu/modificar_partida.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de Culo sucio v1 (local / vs PC; online próximamente).
class MenuCuloSucioScreen extends StatefulWidget {
  const MenuCuloSucioScreen({super.key});

  @override
  State<MenuCuloSucioScreen> createState() => _MenuCuloSucioScreenState();
}

class _MenuCuloSucioScreenState extends State<MenuCuloSucioScreen> {
  OpcionesCuloSucio _opciones = const OpcionesCuloSucio();

  Future<void> _abrirCartelModificar() async {
    var draft = _opciones;
    final ok = await mostrarCartelModificarPartida(
      context: context,
      buildOpciones: (dialogContext, setDialogState) {
        return FilaToggleModificarPartida(
          titulo: 'Comodines',
          activo: draft.comodines,
          onChanged: (v) => setDialogState(
            () => draft = draft.copyWith(comodines: v),
          ),
          info:
              'Activado: el mazo lleva 50 cartas (48 + 2 comodines).\n\n'
              'Desactivado: mazo de 48 cartas, sin comodines.\n\n'
              'Viene desactivado por defecto.\n\n'
              'Si cambiás esta opción, se descarta una partida vs PC '
              'guardada en memoria.',
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
    PartidaCuloSucioResume? resume,
    bool replace = false,
  }) {
    return navegarConCarga<void>(
      ctx,
      replace: replace,
      mensaje: resume != null ? 'Reanudando partida' : 'Barajando el mazo',
      acento: AppColors.peligro,
      builder: (_) => PartidaCuloSucioScreen(
        nombres: resume?.nombres ?? nombres,
        contraPc: contraPc,
        modoDios: contraPc && (resume?.modoDios ?? modoDios),
        opciones: resume?.opciones ?? _opciones,
        resume: resume,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MenuJuegoScreen(
      titulo: TextosCuloSucio.titulo,
      juegoId: MenuJuegoScreen.juegoIdCuloSucioV1,
      modosDados: const [1],
      mostrarDificultad: false,
      textoInfoModoDios: TextosCuloSucio.infoModoDios,
      extraTrasModoLocal: BotonModificarPartida(
        onPressed: _abrirCartelModificar,
      ),
      onPartidaRapida: (ctx, estado, _) async {
        await _abrir(ctx: ctx, nombres: estado.nombres);
      },
      onVsPc: (ctx, estado, _) {
        final resume = CuloSucioStandByStore.consumirSiCoincide(_opciones);
        final nombres = resume?.nombres ??
            (estado.nombres.length >= 2
                ? [estado.nombres.first, TextosCuloSucio.vsPcNombre]
                : const ['Jugador 1', TextosCuloSucio.vsPcNombre]);
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
            content: Text('Online de Culo sucio v1 próximamente'),
          ),
        );
      },
    );
  }
}
