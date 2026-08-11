import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/jodete/opciones_jodete.dart';
import 'package:app_juegos_mesa/jodete/partida_jodete_screen.dart';
import 'package:app_juegos_mesa/jodete/standby_store.dart';
import 'package:app_juegos_mesa/jodete/textos.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/menu/modificar_partida.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de Jodete (local / vs PC; online próximamente).
class MenuJodeteScreen extends StatefulWidget {
  const MenuJodeteScreen({super.key});

  @override
  State<MenuJodeteScreen> createState() => _MenuJodeteScreenState();
}

class _MenuJodeteScreenState extends State<MenuJodeteScreen> {
  OpcionesJodete _opciones = JodeteMenuConfig.opciones;

  Future<void> _abrirCartelModificar() async {
    var draft = _opciones;
    final ok = await mostrarCartelModificarPartida(
      context: context,
      buildOpciones: (dialogContext, setDialogState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilaToggleModificarPartida(
              titulo: 'Comodines',
              activo: draft.comodines,
              onChanged: (v) => setDialogState(
                () => draft = draft.copyWith(comodines: v),
              ),
              info: TextosJodete.infoComodines,
            ),
            const SizedBox(height: 8),
            FilaToggleModificarPartida(
              titulo: 'Levantar hasta tirar',
              activo: draft.levantarHastaTirar,
              onChanged: (v) => setDialogState(
                () => draft = draft.copyWith(levantarHastaTirar: v),
              ),
              info: TextosJodete.infoLevantarHastaTirar,
            ),
            const SizedBox(height: 8),
            FilaToggleModificarPartida(
              titulo: 'Puntaje por cartas (a 100)',
              activo: draft.puntajePorCartas,
              onChanged: (v) => setDialogState(
                () => draft = draft.copyWith(puntajePorCartas: v),
              ),
              info: TextosJodete.infoPuntajePorCartas,
            ),
            const SizedBox(height: 14),
            Opacity(
              opacity: draft.puntajePorCartas ? 0.45 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          draft.puntajePorCartas
                              ? 'Jugar a (modo cartas: 100)'
                              : 'Jugar a',
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Ayuda',
                        onPressed: () => mostrarInfoModificarPartida(
                          dialogContext,
                          titulo: 'Jugar a',
                          cuerpo: TextosJodete.infoObjetivo,
                        ),
                        icon: const Icon(
                          Icons.help_outline_rounded,
                          color: AppColors.textoSuave,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final pts in OpcionesJodete.objetivosPermitidos)
                        ChoiceChip(
                          label: Text(
                            '$pts puntos',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: !draft.puntajePorCartas &&
                                      draft.objetivoClamped == pts
                                  ? const Color(0xFF062018)
                                  : AppColors.texto,
                            ),
                          ),
                          selected: !draft.puntajePorCartas &&
                              draft.objetivoClamped == pts,
                          selectedColor: AppColors.mint,
                          backgroundColor: const Color(0xFF3A2A58),
                          onSelected: draft.puntajePorCartas
                              ? null
                              : (_) => setDialogState(
                                    () =>
                                        draft = draft.copyWith(objetivo: pts),
                                  ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
    if (ok && mounted) {
      setState(() => _opciones = draft);
      JodeteMenuConfig.actualizar(_opciones);
      if (JodeteStandByStore.peek()?.opciones != _opciones) {
        JodeteStandByStore.limpiar();
      }
    }
  }

  Future<void> _abrir({
    required BuildContext ctx,
    required List<String> nombres,
    bool contraPc = false,
    bool modoDios = false,
    DificultadPc dificultad = DificultadPc.medio,
    PartidaJodeteResume? resume,
  }) {
    JodeteMenuConfig.actualizar(_opciones);
    return navegarConCarga<void>(
      ctx,
      mensaje: resume != null ? 'Reanudando partida' : 'Repartiendo cartas',
      acento: AppColors.peligro,
      builder: (_) => PartidaJodeteScreen(
        nombres: resume?.nombres ?? nombres,
        contraPc: contraPc,
        modoDios: contraPc && modoDios,
        dificultad: dificultad,
        opciones: resume?.opciones ?? _opciones,
        resume: resume,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MenuJuegoScreen(
      titulo: TextosJodete.titulo,
      juegoId: MenuJuegoScreen.juegoIdJodete,
      modosDados: const [1],
      mostrarDificultad: true,
      mostrarJugadoresVsPc: true,
      opcionesCantidadJugadores: const [2, 3, 4],
      opcionesCantidadPc: const [1, 2, 3],
      onCantidadPcChanged: (_) => JodeteStandByStore.limpiar(),
      textoInfoModoDios: TextosJodete.infoModoDios,
      textosInfoDificultad: const {
        DificultadPc.facil: TextosJodete.infoDificultadFacil,
        DificultadPc.medio: TextosJodete.infoDificultadMedio,
        DificultadPc.dificil: TextosJodete.infoDificultadDificil,
      },
      extraTrasModoLocal: BotonModificarPartida(
        onPressed: _abrirCartelModificar,
      ),
      onPartidaRapida: (ctx, estado, _) async {
        await _abrir(ctx: ctx, nombres: estado.nombres);
      },
      onVsPc: (ctx, estado, _) {
        JodeteMenuConfig.actualizar(_opciones);
        registrarModoDiosMenu(
          MenuJuegoScreen.juegoIdJodete,
          estado.modoDios,
        );
        final resumeRaw = JodeteStandByStore.consumir();
        final resume = resumeRaw != null &&
                coincideCantidadPc(resumeRaw.nombres, estado.cantidadPc) &&
                resumeRaw.opciones == _opciones
            ? resumeRaw
            : null;
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
          modoDios: resume?.modoDios ?? estado.modoDios,
          dificultad: estado.dificultad,
          resume: resume,
        );
      },
      onIniciarDesdeSala: (ctx, inicio) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text(TextosJodete.onlineProximamente)),
        );
      },
    );
  }
}
