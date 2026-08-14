import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/diezMil/motor.dart';
import 'package:app_juegos_mesa/diezMil/opciones_diez_mil.dart';
import 'package:app_juegos_mesa/diezMil/partida_diez_mil_screen.dart';
import 'package:app_juegos_mesa/diezMil/standby_store.dart';
import 'package:app_juegos_mesa/diezMil/textos.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/menu/modificar_partida.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de Diez Mil: arma el [MenuJuegoScreen] y navega a la partida.
class MenuDiezMilScreen extends StatefulWidget {
  const MenuDiezMilScreen({super.key});

  @override
  State<MenuDiezMilScreen> createState() => _MenuDiezMilScreenState();
}

class _MenuDiezMilScreenState extends State<MenuDiezMilScreen> {
  OpcionesDiezMil _opciones = DiezMilMenuConfig.opciones;

  Future<void> _abrirCartelModificar() async {
    var draft = _opciones;
    final ok = await mostrarCartelModificarPartida(
      context: context,
      buildOpciones: (dialogContext, setDialogState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilaToggleModificarPartida(
              titulo: 'Jugar con 6 dados',
              activo: draft.seisDados,
              onChanged: (v) => setDialogState(
                () => draft = draft.copyWith(seisDados: v),
              ),
              info: TextosOpcionesDiezMil.infoSeisDados,
            ),
            const SizedBox(height: 8),
            FilaToggleModificarPartida(
              titulo: 'Escalera',
              activo: draft.escalera,
              onChanged: (v) => setDialogState(
                () => draft = draft.copyWith(escalera: v),
              ),
              info: TextosOpcionesDiezMil.infoEscalera,
            ),
            const SizedBox(height: 8),
            FilaToggleModificarPartida(
              titulo: 'Combos especiales',
              activo: draft.combosEspeciales,
              onChanged: (v) => setDialogState(
                () => draft = draft.copyWith(combosEspeciales: v),
              ),
              info: TextosOpcionesDiezMil.infoCombosEspeciales,
            ),
            const SizedBox(height: 8),
            FilaToggleModificarPartida(
              titulo: 'Escalera con 6→1',
              activo: draft.escaleraCircular,
              habilitado: draft.escalera,
              onChanged: (v) => setDialogState(
                () => draft = draft.copyWith(escaleraCircular: v),
              ),
              info: TextosOpcionesDiezMil.infoEscaleraCircular,
            ),
          ],
        );
      },
    );
    if (ok && mounted) {
      setState(() {
        _opciones = draft;
        DiezMilMenuConfig.actualizar(opciones: draft);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dados = _opciones.dados;
    return MenuJuegoScreen(
      titulo: 'Diez Mil',
      juegoId: MenuJuegoScreen.juegoIdDiezMil,
      modosDados: [dados],
      mostrarDificultad: true,
      mostrarJugadoresVsPc: true,
      opcionesCantidadJugadores: const [2, 3, 4],
      textosInfoDificultad: const {
        DificultadPc.facil: TextosDiezMil.infoDificultadFacil,
        DificultadPc.medio: TextosDiezMil.infoDificultadMedio,
        DificultadPc.dificil: TextosDiezMil.infoDificultadDificil,
      },
      extraTrasModoLocal: BotonModificarPartida(
        onPressed: _abrirCartelModificar,
      ),
      onPartidaRapida: (ctx, estado, _) async {
        DiezMilMenuConfig.actualizar(opciones: _opciones);
        await navegarConCarga<void>(
          ctx,
          mensaje: 'Iniciando partida',
          acento: AppColors.acento,
          builder: (_) => PartidaDiezMilScreen(
            nombres: estado.nombres,
            modo: _opciones.modo,
            opciones: _opciones,
            partidaRapida: true,
            ajustesIniciales: estado.ajustes,
          ),
        );
      },
      onVsPc: (ctx, estado, _) {
        DiezMilMenuConfig.actualizar(
          opciones: _opciones,
          dificultad: estado.dificultad,
          modoDios: estado.modoDios,
        );
        // Reanuda aunque hayan cambiado opciones/dificultad en el menú;
        // eso solo aplica al reiniciar dentro de la partida.
        final resume = DiezMilStandByStore.consumirVsPc(
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
          mensaje:
              resume != null ? 'Reanudando partida' : 'Iniciando partida',
          acento: AppColors.acento,
          builder: (_) => PartidaDiezMilScreen(
            nombres: nombres,
            modo: resume?.modo ?? _opciones.modo,
            opciones: resume?.opciones ?? _opciones,
            contraPc: true,
            dificultadPc: resume?.dificultadPc ?? estado.dificultad,
            modoDios: resume?.modoDios ?? estado.modoDios,
            ajustesIniciales: resume?.ajustesIniciales ?? estado.ajustes,
            resume: resume,
          ),
        );
      },
      onIniciarDesdeSala: (ctx, inicio) {
        final modo = inicio.dados == 6 ? Modo.seis : Modo.cinco;
        final opciones = _opciones.copyWith(seisDados: inicio.dados == 6);
        navegarConCarga<void>(
          ctx,
          replace: true,
          mensaje: 'Iniciando partida',
          acento: AppColors.acento,
          builder: (_) => PartidaDiezMilScreen(
            nombres: inicio.nombres,
            modo: modo,
            opciones: opciones,
            salaCodigo: inicio.salaCodigo,
            miNombre: inicio.miNombre,
          ),
        );
      },
    );
  }
}
