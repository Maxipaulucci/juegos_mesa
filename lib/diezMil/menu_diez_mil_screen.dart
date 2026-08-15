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

  Future<void> _abrirPartidaVsPc({
    required BuildContext ctx,
    required MenuJuegoEstado estado,
    PartidaDiezMilResume? resume,
  }) async {
    DiezMilMenuConfig.actualizar(
      opciones: _opciones,
      dificultad: estado.dificultad,
      modoDios: estado.modoDios,
    );
    final humano = estado.nombres.isNotEmpty
        ? estado.nombres.first
        : 'Jugador 1';
    final nombres = resume?.nombres ??
        nombresPartidaVsPc(
          humano: humano,
          total: estado.totalVsPc,
        );
    await navegarConCarga<void>(
      ctx,
      mensaje: resume != null ? 'Reanudando partida' : 'Iniciando partida',
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
    if (mounted) setState(() {});
  }

  Future<void> _continuarPartidaVsPc(BuildContext ctx) async {
    final resume = DiezMilStandByStore.consumirVsPc();
    if (resume == null) {
      if (mounted) setState(() {});
      return;
    }
    await navegarConCarga<void>(
      ctx,
      mensaje: 'Reanudando partida',
      acento: AppColors.acento,
      builder: (_) => PartidaDiezMilScreen(
        nombres: resume.nombres,
        modo: resume.modo,
        opciones: resume.opciones,
        contraPc: true,
        dificultadPc: resume.dificultadPc,
        modoDios: resume.modoDios,
        ajustesIniciales: resume.ajustesIniciales,
        resume: resume,
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dados = _opciones.dados;
    final puedeContinuar = DiezMilStandByStore.hayPartidaVsPcPendiente;

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
      onCantidadPcChanged: (_) {
        // No borramos el standby: podés volver a la cantidad anterior y
        // seguir con Continuar partida.
        if (mounted) setState(() {});
      },
      extraTrasModoLocal: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          if (puedeContinuar) ...[
            OutlinedButton.icon(
              onPressed: () => _continuarPartidaVsPc(context),
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text(
                'Continuar partida',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.acento,
                side: const BorderSide(color: AppColors.acento, width: 1.6),
                backgroundColor: AppColors.acento.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: 12),
          ],
          BotonModificarPartida(
            onPressed: _abrirCartelModificar,
          ),
        ],
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
        // Siempre partida nueva: el resume se usa solo con "Continuar partida".
        DiezMilStandByStore.limpiar();
        _abrirPartidaVsPc(ctx: ctx, estado: estado);
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
