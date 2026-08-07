import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/chanchoVa/chancho_va_online_codec.dart';
import 'package:app_juegos_mesa/chanchoVa/opciones_chancho_va.dart';
import 'package:app_juegos_mesa/chanchoVa/partida_chancho_va_screen.dart';
import 'package:app_juegos_mesa/chanchoVa/standby_store.dart';
import 'package:app_juegos_mesa/chanchoVa/textos.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/carga/pantalla_carga.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/menu/modificar_partida.dart';
import 'package:app_juegos_mesa/shared/salas/sala_form_store.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Menú de Chancho va (vs PC + online: 2 humanos + 1–2 PCs).
class MenuChanchoVaScreen extends StatefulWidget {
  const MenuChanchoVaScreen({super.key});

  @override
  State<MenuChanchoVaScreen> createState() => _MenuChanchoVaScreenState();
}

class _MenuChanchoVaScreenState extends State<MenuChanchoVaScreen> {
  OpcionesChanchoVa _opciones = const OpcionesChanchoVa();

  void _sincronizarStoreSala(MenuJuegoEstado? estado) {
    if (estado != null) {
      // Online: siempre 2 humanos + N PCs (máx. 4 asientos → hasta 2 PCs).
      SalaFormStore.totalJugadoresChancho =
          (2 + estado.cantidadPc).clamp(3, 4);
    }
    SalaFormStore.opcionesChancho = encodeOpcionesChancho(
      _opciones,
      totalJugadores: SalaFormStore.totalJugadoresChancho,
    );
  }

  Future<void> _abrirCartelModificar() async {
    var draft = _opciones;
    final ok = await mostrarCartelModificarPartida(
      context: context,
      buildOpciones: (dialogContext, setDialogState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilaToggleModificarPartida(
              titulo: 'Chancha',
              activo: draft.chancha,
              onChanged: (v) => setDialogState(
                () => draft = draft.copyWith(chancha: v),
              ),
              info: TextosChancho.infoOpcionChancha,
            ),
            const SizedBox(height: 12),
            FilaToggleModificarPartida(
              titulo: 'Sin espacio (CHANCHOVA)',
              activo: draft.sinEspacio,
              onChanged: (v) => setDialogState(
                () => draft = draft.copyWith(sinEspacio: v),
              ),
              info: TextosChancho.infoOpcionSinEspacio,
            ),
            const SizedBox(height: 12),
            FilaToggleModificarPartida(
              titulo: 'Fin al primer perdedor',
              activo: draft.finAlPrimerPerdedor,
              onChanged: (v) => setDialogState(
                () => draft = draft.copyWith(finAlPrimerPerdedor: v),
              ),
              info: TextosChancho.infoOpcionFinAlPrimerPerdedor,
            ),
          ],
        );
      },
    );
    if (ok && mounted) {
      setState(() => _opciones = draft);
      _sincronizarStoreSala(null);
    }
  }

  Future<void> _abrir({
    required BuildContext ctx,
    required List<String> nombres,
    bool contraPc = false,
    bool modoDios = false,
    AjustesEstado? ajustes,
    PartidaChanchoResume? resume,
    bool replace = false,
    String? salaCodigo,
    String? miNombre,
  }) {
    return navegarConCarga<void>(
      ctx,
      replace: replace,
      mensaje: resume != null
          ? 'Reanudando partida'
          : (salaCodigo != null ? 'Conectando Chancho va' : 'Preparando Chancho va'),
      acento: AppColors.acentoSuave,
      builder: (_) => PartidaChanchoVaScreen(
        nombres: resume?.nombres ?? nombres,
        contraPc: contraPc,
        modoDios: contraPc &&
            salaCodigo == null &&
            (resume?.modoDios ?? modoDios),
        ajustesIniciales: ajustes,
        resume: resume,
        opciones: resume?.opciones ?? _opciones,
        salaCodigo: salaCodigo,
        miNombre: miNombre,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MenuJuegoScreen(
      titulo: TextosChancho.titulo,
      juegoId: MenuJuegoScreen.juegoIdChanchoVa,
      modosDados: const [1],
      mostrarDificultad: false,
      mostrarMultijugadorLocal: false,
      mostrarJugadoresVsPc: true,
      opcionesCantidadPc: const [1, 2, 3],
      textoInfoModoDios: TextosChancho.infoModoDios,
      lobbyHumanosExactos: 2,
      lobbyTextoAyudaHumanos:
          'Chancho online: exactamente 2 personas. '
          'Las PCs (según “Cantidad de PC”) se agregan al iniciar.',
      onPrepararSala: _sincronizarStoreSala,
      extraTrasModoLocal: BotonModificarPartida(
        onPressed: _abrirCartelModificar,
      ),
      onPartidaRapida: (_, __, ___) async {},
      onVsPc: (ctx, estado, _) {
        _sincronizarStoreSala(estado);
        final resume = ChanchoStandByStore.consumir();
        final humano = resume?.nombres.firstWhere(
              (n) => !TextosChancho.esPc(n),
              orElse: () => estado.nombres.isNotEmpty
                  ? estado.nombres.first
                  : 'Jugador 1',
            ) ??
            (estado.nombres.isNotEmpty ? estado.nombres.first : 'Jugador 1');
        final nombres = resume?.nombres ??
            TextosChancho.nombresVsPc(
              humano: humano,
              total: estado.totalVsPc,
            );
        _abrir(
          ctx: ctx,
          nombres: nombres,
          contraPc: true,
          modoDios: resume?.modoDios ?? estado.modoDios,
          ajustes: resume?.ajustesIniciales ?? estado.ajustes,
          resume: resume,
        );
      },
      onIniciarDesdeSala: (ctx, inicio) {
        final humanos = inicio.nombres
            .where((n) => !TextosChancho.esPc(n))
            .toList(growable: false);
        if (humanos.length != 2) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text(
                'Chancho online requiere exactamente 2 personas reales.',
              ),
            ),
          );
          return;
        }
        // Preferir mesa del seed (humanos + PCs). Si falta, completar localmente.
        final nombres = inicio.nombres.length >= 3
            ? List<String>.from(inicio.nombres)
            : nombresMesaChanchoOnline(
                humanos: humanos,
                totalJugadores: SalaFormStore.totalJugadoresChancho,
              );
        _sincronizarStoreSala(
          MenuJuegoEstado(
            ajustes: const AjustesEstado(),
            modoDios: false,
            decidirOrden: false,
            dificultad: DificultadPc.medio,
            nombres: nombres,
            cantidadJugadores: nombres.length.clamp(2, 4),
            cantidadPc: (nombres.length - 2).clamp(1, 3),
          ),
        );
        _abrir(
          ctx: ctx,
          nombres: nombres,
          contraPc: true,
          ajustes: const AjustesEstado(),
          replace: true,
          salaCodigo: inicio.salaCodigo,
          miNombre: inicio.miNombre,
        );
      },
    );
  }
}
