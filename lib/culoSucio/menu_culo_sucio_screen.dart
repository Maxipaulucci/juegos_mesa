import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/culoSucio/partida_culo_sucio_screen.dart';
import 'package:app_juegos_mesa/culoSucio/textos.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de Culo sucio v1 (local / vs PC; online próximamente).
class MenuCuloSucioScreen extends StatelessWidget {
  const MenuCuloSucioScreen({super.key});

  Future<void> _abrir({
    required BuildContext ctx,
    required List<String> nombres,
    bool contraPc = false,
    bool replace = false,
  }) {
    return navegarConCarga<void>(
      ctx,
      replace: replace,
      mensaje: 'Barajando el mazo',
      acento: AppColors.peligro,
      builder: (_) => PartidaCuloSucioScreen(
        nombres: nombres,
        contraPc: contraPc,
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
      onPartidaRapida: (ctx, estado, _) async {
        await _abrir(ctx: ctx, nombres: estado.nombres);
      },
      onVsPc: (ctx, estado, _) {
        final nombres = estado.nombres.length >= 2
            ? [estado.nombres.first, TextosCuloSucio.vsPcNombre]
            : const ['Jugador 1', TextosCuloSucio.vsPcNombre];
        _abrir(ctx: ctx, nombres: nombres, contraPc: true);
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
