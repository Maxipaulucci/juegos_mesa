import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/menu/modificar_partida.dart';
import 'package:app_juegos_mesa/shared/salas/resumen_opciones_online.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/unoSolo/opciones_uno_solo.dart';
import 'package:app_juegos_mesa/unoSolo/partida_uno_solo_screen.dart';
import 'package:app_juegos_mesa/unoSolo/standby_store.dart';

/// Menú de Uno solo: mismo layout que La papa (solo / local / online).
class MenuUnoSoloScreen extends StatefulWidget {
  const MenuUnoSoloScreen({super.key});

  @override
  State<MenuUnoSoloScreen> createState() => _MenuUnoSoloScreenState();
}

class _MenuUnoSoloScreenState extends State<MenuUnoSoloScreen> {
  OpcionesUnoSolo _opciones = const OpcionesUnoSolo();

  Future<void> _abrirCartelModificar() async {
    var draft = _opciones;
    final ok = await mostrarCartelModificarPartida(
      context: context,
      buildOpciones: (dialogContext, setDialogState) {
        return FilaToggleModificarPartida(
          titulo: 'Modo práctica',
          activo: draft.modoPractica,
          onChanged: (v) => setDialogState(
            () => draft = draft.copyWith(modoPractica: v),
          ),
          info:
              'Activado por defecto: durante la partida podés deshacer de a '
              'un salto hacia atrás (botón de deshacer). Si lo seguís '
              'tocando, volvés hasta el inicio del tablero.\n\n'
              'Sirve para probar caminos y corregir errores sin reiniciar '
              'toda la partida. Podés desactivarlo acá. No aplica en '
              'multijugador online.',
        );
      },
    );
    if (ok && mounted) {
      setState(() => _opciones = draft);
      UnoSoloMenuConfig.actualizar(_opciones);
    }
  }

  Future<void> _abrirPartida({
    required BuildContext ctx,
    required List<String> nombres,
    required MenuJuegoEstado estado,
    bool solo = false,
    PartidaUnoSoloResume? resume,
  }) {
    UnoSoloMenuConfig.actualizar(_opciones);
    registrarModoDiosMenu(MenuJuegoScreen.juegoIdUnoSolo, estado.modoDios);
    return navegarConCarga<void>(
      ctx,
      mensaje: 'Preparando tablero',
      acento: AppColors.mint,
      builder: (_) => PartidaUnoSoloScreen(
        nombres: resume?.nombres ?? nombres,
        solo: solo,
        // Siempre la config actual del menú (no la del resume viejo).
        modoDios: solo && estado.modoDios,
        opciones: _opciones,
        ajustesIniciales: resume?.ajustesIniciales ?? estado.ajustes,
        resume: resume,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MenuJuegoScreen(
      titulo: 'Uno solo',
      juegoId: MenuJuegoScreen.juegoIdUnoSolo,
      modosDados: const [1],
      jugarSoloEnLugarDePc: true,
      mostrarModoDiosEnSolo: true,
      textoInfoModoDios:
          'Solo aplica a “Jugar solo”.\n\n'
          'Te guía con la solución para dejar una sola ficha en el centro: '
          'una flecha marca la ficha que tenés que comer en cada paso, '
          'y los números indican el orden de eliminación.\n\n'
          'Es una ayuda muy fuerte: si preferís el desafío limpio, '
          'dejalo apagado.',
      resumenConfigOnline: () => [
        lineaOpcionOnline('Modo práctica', _opciones.modoPractica),
      ],
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
        final resume = UnoSoloStandByStore.consumir();
        _abrirPartida(
          ctx: ctx,
          nombres: resume?.nombres ??
              (estado.nombres.isEmpty
                  ? const ['Jugador']
                  : estado.nombres),
          estado: estado,
          solo: true,
          resume: resume,
        );
      },
      onIniciarDesdeSala: (ctx, inicio) {
        navegarConCarga<void>(
          ctx,
          replace: true,
          mensaje: 'Preparando tablero',
          acento: AppColors.mint,
          builder: (_) => PartidaUnoSoloScreen(
            nombres: inicio.nombres,
            salaCodigo: inicio.salaCodigo,
            miNombre: inicio.miNombre,
          ),
        );
      },
    );
  }
}
