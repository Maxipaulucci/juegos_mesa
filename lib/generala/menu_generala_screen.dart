import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/generala/opciones_generala.dart';
import 'package:app_juegos_mesa/generala/partida_generala_screen.dart';
import 'package:app_juegos_mesa/generala/standby_store.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/menu/modificar_partida.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de Generala: arma el [MenuJuegoScreen] y navega a la partida.
class MenuGeneralaScreen extends StatefulWidget {
  const MenuGeneralaScreen({super.key});

  @override
  State<MenuGeneralaScreen> createState() => _MenuGeneralaScreenState();
}

class _MenuGeneralaScreenState extends State<MenuGeneralaScreen> {
  OpcionesGenerala _opciones = const OpcionesGenerala();

  Future<void> _abrirCartelModificar() async {
    var draft = _opciones;
    final ok = await mostrarCartelModificarPartida(
      context: context,
      buildOpciones: (dialogContext, setDialogState) {
        return FilaToggleModificarPartida(
          titulo: 'Escalera con 6→1',
          activo: draft.escaleraCircular,
          onChanged: (v) => setDialogState(
            () => draft = draft.copyWith(escaleraCircular: v),
          ),
          info:
              'Activado: la escalera puede “dar la vuelta”: después del 6 '
              'sigue el 1 (por ejemplo 4-5-6-1-2 también vale).\n\n'
              'Desactivado: solo valen 1-2-3-4-5 y 2-3-4-5-6.',
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
      titulo: 'Generala',
      juegoId: MenuJuegoScreen.juegoIdGenerala,
      modosDados: const [5],
      mostrarDificultad: false,
      mostrarJugadoresVsPc: true,
      opcionesCantidadJugadores: const [2, 3, 4],
      onCantidadPcChanged: (_) => GeneralaStandByStore.limpiar(),
      extraTrasModoLocal: BotonModificarPartida(
        onPressed: _abrirCartelModificar,
      ),
      onPartidaRapida: (ctx, estado, dados) async {
        await navegarConCarga<void>(
          ctx,
          mensaje: 'Iniciando partida',
          acento: AppColors.violeta,
          builder: (_) => PartidaGeneralaScreen(
            nombres: estado.nombres,
            partidaRapida: true,
            ajustesIniciales: estado.ajustes,
            opciones: _opciones,
          ),
        );
      },
      onVsPc: (ctx, estado, dados) {
        final resume = GeneralaStandByStore.consumirSiCoincide(
          estado.dificultad,
          cantidadPc: estado.cantidadPc,
        );
        final humano = estado.nombres.isNotEmpty
            ? estado.nombres.first
            : 'Jugador 1';
        final nombres = resume?.nombres ??
            nombresPartidaVsPc(
              humano: humano,
              total: estado.totalVsPc,
            );
        navegarConCarga<void>(
          ctx,
          mensaje: 'Iniciando partida',
          acento: AppColors.violeta,
          builder: (_) => PartidaGeneralaScreen(
            nombres: nombres,
            contraPc: true,
            dificultadPc: resume?.dificultadPc ?? estado.dificultad,
            modoDios: resume?.modoDios ?? estado.modoDios,
            ajustesIniciales: resume?.ajustesIniciales ?? estado.ajustes,
            resume: resume,
            opciones: _opciones,
          ),
        );
      },
      onIniciarDesdeSala: (ctx, inicio) {
        navegarConCarga<void>(
          ctx,
          replace: true,
          mensaje: 'Iniciando partida',
          acento: AppColors.violeta,
          builder: (_) => PartidaGeneralaScreen(
            nombres: inicio.nombres,
            salaCodigo: inicio.salaCodigo,
            miNombre: inicio.miNombre,
            opciones: _opciones,
          ),
        );
      },
    );
  }
}
