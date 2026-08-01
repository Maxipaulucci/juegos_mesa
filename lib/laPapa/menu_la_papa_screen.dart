import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/laPapa/opciones_la_papa.dart';
import 'package:app_juegos_mesa/laPapa/partida_la_papa_screen.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/menu/modificar_partida.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de La papa: mismo layout que Generala, con "Jugar solo" + modificar.
class MenuLaPapaScreen extends StatefulWidget {
  const MenuLaPapaScreen({super.key});

  @override
  State<MenuLaPapaScreen> createState() => _MenuLaPapaScreenState();
}

class _MenuLaPapaScreenState extends State<MenuLaPapaScreen> {
  OpcionesPapa _opciones = const OpcionesPapa();

  Future<void> _abrirPartida({
    required BuildContext ctx,
    required List<String> nombres,
    required MenuJuegoEstado estado,
    bool solo = false,
  }) {
    return navegarConCarga<void>(
      ctx,
      mensaje: _opciones.numerosAleatorios
          ? 'Preparando hoja'
          : 'Preparando colocación',
      acento: AppColors.mint,
      builder: (_) => PartidaLaPapaScreen(
        nombres: nombres,
        solo: solo,
        opciones: _opciones,
        ajustesIniciales: estado.ajustes,
      ),
    );
  }

  Future<void> _abrirCartelModificar() async {
    var draft = _opciones;
    final ok = await mostrarCartelModificarPartida(
      context: context,
      buildOpciones: (dialogContext, setDialogState) {
        void setOpc(OpcionesPapa next) {
          setDialogState(() => draft = next);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilaToggleModificarPartida(
              titulo: 'Agregar 3 vidas',
              activo: draft.conVidas,
              onChanged: (v) => setOpc(draft.copyWith(conVidas: v)),
              info:
                  'Cada jugador empieza con 3 vidas. Si falla, pierde una vida '
                  'pero sigue su turno. Sin vidas, termina la partida.',
            ),
            const SizedBox(height: 12),
            FilaToggleModificarPartida(
              titulo: 'Modo fantasma',
              activo: draft.modoFantasma,
              onChanged: (v) => setOpc(draft.copyWith(modoFantasma: v)),
              info:
                  'Solo se ven las líneas, el número actual y el siguiente. '
                  'El resto de números quedan ocultos.',
            ),
            const SizedBox(height: 12),
            FilaToggleModificarPartida(
              titulo: 'Mostrar cuadrícula',
              activo: draft.mostrarCuadricula,
              onChanged: (v) =>
                  setOpc(draft.copyWith(mostrarCuadricula: v)),
              info:
                  'Activado: se ven las líneas de la hoja (casillas).\n\n'
                  'Desactivado: la hoja queda en blanco, solo con números '
                  'y trazos.',
            ),
            const SizedBox(height: 12),
            FilaToggleModificarPartida(
              titulo: 'Números aleatorios',
              activo: draft.numerosAleatorios,
              onChanged: (v) =>
                  setOpc(draft.copyWith(numerosAleatorios: v)),
              info:
                  'Activado: la hoja se arma sola con números al azar.\n\n'
                  'Desactivado: antes de jugar, los jugadores colocan '
                  'los números por turnos (el 1er jugador / anfitrión '
                  'pone el 1, el otro el 2, y así sucesivamente).',
            ),
            const SizedBox(height: 12),
            FilaCantidadModificarPartida(
              etiqueta: 'Cantidad de números',
              valor: draft.cantidadNumerosClamped,
              min: OpcionesPapa.minCantidadNumeros,
              max: OpcionesPapa.maxCantidadNumeros,
              onChanged: (v) =>
                  setOpc(draft.copyWith(cantidadNumeros: v)),
            ),
          ],
        );
      },
    );
    if (ok && mounted) {
      setState(() => _opciones = draft);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MenuJuegoScreen(
      titulo: 'La papa',
      juegoId: MenuJuegoScreen.juegoIdLaPapa,
      modosDados: const [1],
      jugarSoloEnLugarDePc: true,
      extraTrasModoLocal: BotonModificarPartida(
        onPressed: _abrirCartelModificar,
      ),
      onPartidaRapida: (ctx, estado, _) async {
        await _abrirPartida(
          ctx: ctx,
          nombres: estado.nombres,
          estado: estado,
        );
      },
      onVsPc: (ctx, estado, _) {
        _abrirPartida(
          ctx: ctx,
          nombres: estado.nombres.isEmpty
              ? const ['Jugador']
              : estado.nombres,
          estado: estado,
          solo: true,
        );
      },
      onIniciarDesdeSala: (ctx, inicio) {
        navegarConCarga<void>(
          ctx,
          replace: true,
          mensaje: 'Preparando hoja',
          acento: AppColors.mint,
          builder: (_) => PartidaLaPapaScreen(
            nombres: inicio.nombres,
            opciones: _opciones,
          ),
        );
      },
    );
  }
}
