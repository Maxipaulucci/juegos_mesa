import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/jodete/ia_jodete.dart';
import 'package:app_juegos_mesa/jodete/menu_partida_jodete.dart';
import 'package:app_juegos_mesa/jodete/motor_jodete.dart';
import 'package:app_juegos_mesa/jodete/opciones_jodete.dart';
import 'package:app_juegos_mesa/jodete/resumen_ronda_jodete_overlay.dart';
import 'package:app_juegos_mesa/jodete/standby_store.dart';
import 'package:app_juegos_mesa/jodete/textos.dart';
import 'package:app_juegos_mesa/jodete/victoria_jodete_overlay.dart';
import 'package:app_juegos_mesa/escobaDel15/marcador_palitos.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/cartas/carta_espanola_skin.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/partida_ui/cambio_jugador_overlay.dart';
import 'package:app_juegos_mesa/shared/partida_ui/epic_backdrop.dart';
import 'package:app_juegos_mesa/shared/partida_ui/reiniciar_partida_pc.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

class PartidaJodeteScreen extends StatefulWidget {
  const PartidaJodeteScreen({
    super.key,
    required this.nombres,
    this.contraPc = false,
    this.modoDios = false,
    this.dificultad = DificultadPc.medio,
    this.opciones = const OpcionesJodete(),
    this.resume,
  });

  final List<String> nombres;
  final bool contraPc;
  final bool modoDios;
  final DificultadPc dificultad;
  final OpcionesJodete opciones;
  final PartidaJodeteResume? resume;

  @override
  State<PartidaJodeteScreen> createState() => _PartidaJodeteScreenState();
}

class _PartidaJodeteScreenState extends State<PartidaJodeteScreen> {
  late PartidaJodete _partida;
  late bool _modoDios;
  late DificultadPc _dificultad;
  late OpcionesJodete _opciones;
  AjustesEstado _ajustes = const AjustesEstado();

  CartaJodete? _seleccion;
  bool _mostrarMenu = false;
  bool _confirmarRendicion = false;
  bool _mostrarAjustes = false;
  bool _esperandoCambioJugador = false;
  bool _eligiendoPalo = false;
  CartaJodete? _cartaPendientePalo;
  bool _jugandoPc = false;
  int _pcToken = 0;
  final _rng = math.Random();

  /// Evita tirar/levantar dos veces en el mismo turno.
  bool _yaActuoEsteTurno = false;
  int _turnoDeLaAccion = -1;

  /// Tras “VER GANADOR” en el resumen de la ronda final.
  bool _resumenCerrado = false;

  /// Overlay central (estilo Culo sucio v2) cuando la PC tira o levanta.
  CartaJodete? _cartaOverlayPc;
  String? _tituloOverlayPc;
  bool _overlaySoloDorso = false;

  bool get _esLocalHotSeat => !widget.contraPc;

  bool get _modoDiosActivo => widget.contraPc && _modoDios;

  JugadorJodete get _humanoPrincipal => _partida.jugadores.firstWhere(
        (j) => !esNombrePc(j.nombre),
        orElse: () => _partida.jugadores.first,
      );

  /// Mano que se muestra abajo: siempre la tuya vs PC; en local, el del turno.
  JugadorJodete get _vistaLocal =>
      _esLocalHotSeat ? _partida.jugadorActual : _humanoPrincipal;

  bool get _turnoDePc =>
      widget.contraPc &&
      _partida.jugando &&
      esNombrePc(_partida.jugadorActual.nombre);

  bool get _puedeJugarHumano {
    _asegurarFlagTurno();
    return _partida.jugando &&
        !_turnoDePc &&
        !_jugandoPc &&
        !_esperandoCambioJugador &&
        !_eligiendoPalo &&
        !_yaActuoEsteTurno &&
        _partida.jugadorActual.enJuego;
  }

  bool get _mostrarResumenRonda =>
      _partida.ultimoResultado != null &&
      !_resumenCerrado &&
      (_partida.enFinRonda || _partida.terminada);

  bool get _mostrarVictoria =>
      _partida.terminada &&
      (_resumenCerrado || _partida.ultimoResultado == null);

  void _asegurarFlagTurno() {
    final t = _partida.indiceTurno;
    if (t != _turnoDeLaAccion) {
      _turnoDeLaAccion = t;
      _yaActuoEsteTurno = false;
    }
  }

  void _marcarAccionDeTurno() {
    _turnoDeLaAccion = _partida.indiceTurno;
    _yaActuoEsteTurno = true;
  }

  /// 11/12 con 2 jugadores dejan el mismo índice: hay que permitir la nueva jugada.
  void _desbloquearSiMismoJugadorSigue(int indiceAntes) {
    if (_partida.indiceTurno == indiceAntes) {
      _yaActuoEsteTurno = false;
      _turnoDeLaAccion = indiceAntes;
    }
  }

  @override
  void initState() {
    super.initState();
    final resume = widget.resume;
    if (resume != null) {
      _partida = resume.partida;
      _modoDios = resume.modoDios;
      _dificultad = resume.dificultad;
      _opciones = resume.opciones;
      _ajustes = resume.ajustesIniciales ?? const AjustesEstado();
    } else {
      _modoDios = widget.modoDios;
      _dificultad = widget.dificultad;
      _opciones = widget.opciones;
      _partida = nuevaPartidaJodete(
        nombres: widget.nombres,
        contraPc: widget.contraPc,
        rng: _rng,
        incluirComodines: _opciones.comodines,
        objetivo: _opciones.objetivoEfectivo,
        puntajePorCartas: _opciones.puntajePorCartas,
      );
    }
    if (_esLocalHotSeat) {
      _esperandoCambioJugador = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezPc());
  }

  void _guardarStandby() {
    if (!widget.contraPc || _partida.terminada) return;
    JodeteStandByStore.guardar(
      PartidaJodeteResume(
        partida: _partida,
        nombres: [for (final j in _partida.jugadores) j.nombre],
        modoDios: _modoDios,
        dificultad: _dificultad,
        opciones: _opciones,
        ajustesIniciales: _ajustes,
      ),
    );
  }

  void _salirAlMenu({required bool guardar}) {
    if (guardar) {
      _guardarStandby();
    } else if (widget.contraPc) {
      JodeteStandByStore.limpiar();
    }
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  void _reiniciar() {
    JodeteStandByStore.limpiar();
    var nombres = [for (final j in _partida.jugadores) j.nombre];
    setState(() {
      _modoDios = modoDiosElegidoEnMenu(
        MenuJuegoScreen.juegoIdJodete,
        fallback: widget.modoDios,
      );
      if (widget.contraPc) {
        final pcs = cantidadPcElegidaEnMenu(
              MenuJuegoScreen.juegoIdJodete,
            ) ??
            cantidadPcEnNombres(nombres);
        nombres = reconstruirNombresVsPc(
          actuales: nombres,
          cantidadPc: pcs.clamp(1, 3),
        );
      }
      _partida = nuevaPartidaJodete(
        nombres: nombres,
        contraPc: widget.contraPc,
        rng: _rng,
        incluirComodines: _opciones.comodines,
        objetivo: _opciones.objetivoEfectivo,
        puntajePorCartas: _opciones.puntajePorCartas,
      );
      _seleccion = null;
      _mostrarMenu = false;
      _mostrarAjustes = false;
      _confirmarRendicion = false;
      _eligiendoPalo = false;
      _cartaPendientePalo = null;
      _esperandoCambioJugador = _esLocalHotSeat;
      _jugandoPc = false;
      _yaActuoEsteTurno = false;
      _turnoDeLaAccion = -1;
      _resumenCerrado = false;
      _limpiarOverlayPc();
    });
    _talVezPc();
  }

  Future<void> _pedirReiniciarVsPc() async {
    if (!widget.contraPc) return;
    final ok = await confirmarReiniciarPartidaPc(context);
    if (!ok || !mounted) return;
    _reiniciar();
  }

  void _mostrarReglas() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.carta,
        title: const Text(
          'Reglas',
          style: TextStyle(
            color: AppColors.mint,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            reglasJodete(
              comodines: _opciones.comodines,
              objetivo: _partida.objetivo,
              puntajePorCartas: _partida.puntajePorCartas,
            ),
            style: const TextStyle(color: AppColors.texto, height: 1.35),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  PaloEspanolVisual _paloVisual(PaloJodete p) => switch (p) {
        PaloJodete.oro => PaloEspanolVisual.oro,
        PaloJodete.copa => PaloEspanolVisual.copa,
        PaloJodete.espada => PaloEspanolVisual.espada,
        PaloJodete.basto => PaloEspanolVisual.basto,
      };

  void _toggleCarta(CartaJodete c) {
    if (!_puedeJugarHumano) return;
    setState(() {
      _seleccion = _seleccion == c ? null : c;
    });
  }

  Future<void> _confirmarTirar() async {
    if (!_puedeJugarHumano || _seleccion == null) return;
    final carta = _seleccion!;
    if (!puedeJugarCartaJodete(_partida, carta)) {
      setState(() => _seleccion = null);
      return;
    }
    if (carta.pideElegirPalo) {
      // La elección de palo completa la única jugada del turno.
      _marcarAccionDeTurno();
      setState(() {
        _cartaPendientePalo = carta;
        _eligiendoPalo = true;
      });
      return;
    }
    _marcarAccionDeTurno();
    _aplicarJugada(carta, null);
  }

  void _elegirPalo(PaloJodete palo) {
    final carta = _cartaPendientePalo;
    if (carta == null || !_eligiendoPalo) return;
    setState(() {
      _eligiendoPalo = false;
      _cartaPendientePalo = null;
    });
    _aplicarJugada(carta, palo);
  }

  void _aplicarJugada(CartaJodete carta, PaloJodete? palo) {
    final antes = _partida.indiceTurno;
    final err = jugarCartaJodete(
      _partida,
      carta,
      paloElegido: palo,
      rng: _rng,
    );
    if (err != null) {
      // Falló: se puede reintentar en el mismo turno.
      setState(() {
        _yaActuoEsteTurno = false;
        _seleccion = null;
        _eligiendoPalo = false;
        _cartaPendientePalo = null;
      });
      return;
    }
    final cambioAOtroHumano = _esLocalHotSeat &&
        _partida.indiceTurno != antes &&
        !esNombrePc(_partida.jugadorActual.nombre);
    setState(() {
      _seleccion = null;
      _desbloquearSiMismoJugadorSigue(antes);
      // Bloquear UI al instante (antes de mostrar la mano del siguiente).
      if (cambioAOtroHumano) _esperandoCambioJugador = true;
    });
    _despuesDeJugada(antes);
  }

  void _levantar() {
    if (!_puedeJugarHumano) return;
    _marcarAccionDeTurno();
    final antes = _partida.indiceTurno;
    final sigue =
        levantarPorNoJugarJodete(
          _partida,
          rng: _rng,
          hastaPoderTirar: _opciones.levantarHastaTirar,
        );
    final cambioAOtroHumano = _esLocalHotSeat &&
        _partida.indiceTurno != antes &&
        !esNombrePc(_partida.jugadorActual.nombre);
    setState(() {
      _seleccion = null;
      if (sigue) {
        // Levantó hasta poder tirar: desbloquear para Tirar.
        _yaActuoEsteTurno = false;
        _turnoDeLaAccion = _partida.indiceTurno;
      } else {
        _desbloquearSiMismoJugadorSigue(antes);
      }
      if (cambioAOtroHumano) _esperandoCambioJugador = true;
    });
    _despuesDeJugada(antes);
  }

  /// Si hay doses pendientes y no tenés un 2, levantás solo.
  bool get _debeAutoLevantarPendienteDos {
    if (!_puedeJugarHumano || !_partida.hayPendienteDos) return false;
    return !_partida.jugadorActual.mano.any((c) => c.esDos);
  }

  Future<void> _talVezAutoLevantarPendienteDos() async {
    if (!_debeAutoLevantarPendienteDos) return;
    // Un instante para leer el aviso antes de levantar.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted || !_debeAutoLevantarPendienteDos) return;
    _marcarAccionDeTurno();
    final antes = _partida.indiceTurno;
    levantarPorNoJugarJodete(_partida, rng: _rng);
    final cambioAOtroHumano = _esLocalHotSeat &&
        _partida.indiceTurno != antes &&
        !esNombrePc(_partida.jugadorActual.nombre);
    setState(() {
      _seleccion = null;
      if (cambioAOtroHumano) _esperandoCambioJugador = true;
    });
    _despuesDeJugada(antes);
  }

  bool get _hastaPoderTirar => _opciones.levantarHastaTirar;

  void _despuesDeJugada(int indiceAntes) {
    if (_partida.terminada || _partida.enFinRonda) {
      setState(() {
        _seleccion = null;
        _eligiendoPalo = false;
        _cartaPendientePalo = null;
        _esperandoCambioJugador = false;
      });
      return;
    }
    if (_esLocalHotSeat &&
        _partida.indiceTurno != indiceAntes &&
        !esNombrePc(_partida.jugadorActual.nombre)) {
      if (!_esperandoCambioJugador) {
        setState(() => _esperandoCambioJugador = true);
      }
      return;
    }
    setState(() {});
    if (_debeAutoLevantarPendienteDos) {
      unawaited(_talVezAutoLevantarPendienteDos());
      return;
    }
    _talVezPc();
  }

  void _continuarRonda() {
    if (_partida.terminada) {
      setState(() => _resumenCerrado = true);
      return;
    }
    if (!_partida.enFinRonda) return;
    setState(() {
      siguienteRondaJodete(_partida, _rng);
      _seleccion = null;
      _eligiendoPalo = false;
      _cartaPendientePalo = null;
      _yaActuoEsteTurno = false;
      _turnoDeLaAccion = -1;
      _resumenCerrado = false;
      _limpiarOverlayPc();
      _esperandoCambioJugador = _esLocalHotSeat;
    });
    if (!_esperandoCambioJugador) {
      _talVezPc();
    }
  }

  void _limpiarOverlayPc() {
    _cartaOverlayPc = null;
    _tituloOverlayPc = null;
    _overlaySoloDorso = false;
  }

  Future<void> _mostrarOverlayPc({
    required String titulo,
    CartaJodete? carta,
    bool soloDorso = false,
    int ms = 1200,
  }) async {
    if (!mounted) return;
    setState(() {
      _tituloOverlayPc = titulo;
      _cartaOverlayPc = carta;
      _overlaySoloDorso = soloDorso;
    });
    await Future<void>.delayed(Duration(milliseconds: ms));
    if (!mounted) return;
    setState(_limpiarOverlayPc);
  }

  Future<void> _talVezPc() async {
    if (!_turnoDePc || !_partida.jugando || _jugandoPc) return;
    final token = ++_pcToken;
    _jugandoPc = true;
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted || token != _pcToken || !_turnoDePc) {
      _jugandoPc = false;
      return;
    }

    while (mounted &&
        token == _pcToken &&
        _turnoDePc &&
        _partida.jugando) {
      final plan = planificarJugadaPcJodete(
        _partida,
        dificultad: _dificultad,
        rng: _rng,
      );
      final idxAntes = _partida.indiceTurno;
      final nombrePc = _partida.jugadorActual.nombre.toUpperCase();

      if (plan.levantar) {
        final n = _partida.hayPendienteDos
            ? _partida.pendienteDos
            : (_hastaPoderTirar ? 0 : 1);
        await _mostrarOverlayPc(
          titulo: n > 1
              ? '$nombrePc LEVANTA $n'
              : n == 0
                  ? '$nombrePc LEVANTA HASTA TIRAR'
                  : '$nombrePc LEVANTA',
          soloDorso: true,
        );
        if (!mounted || token != _pcToken) break;
        levantarPorNoJugarJodete(
          _partida,
          rng: _rng,
          hastaPoderTirar: _hastaPoderTirar,
        );
      } else if (plan.carta != null) {
        await _mostrarOverlayPc(
          titulo: '$nombrePc TIRA',
          carta: plan.carta,
        );
        if (!mounted || token != _pcToken) break;
        jugarCartaJodete(
          _partida,
          plan.carta!,
          paloElegido: plan.paloElegido,
          rng: _rng,
        );
      }
      if (!mounted || token != _pcToken) break;
      setState(() {});
      if (!_partida.jugando) break;
      // Misma PC sigue (no debería pasar con 1 carta/turno, salvo bug).
      if (_partida.indiceTurno == idxAntes && _turnoDePc) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        continue;
      }
      break;
    }
    _jugandoPc = false;
    if (mounted) setState(() {});
  }

  Widget _cartaWidget(
    CartaJodete c, {
    required bool seleccionada,
    double w = 68,
    double h = 102,
  }) {
    if (c.esComodin) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6A1B9A), Color(0xFF1A0A33)],
          ),
          border: Border.all(
            color: seleccionada
                ? colorSeleccionCartaEspanola
                : AppColors.acento,
            width: seleccionada ? 2.4 : 2,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_rounded, color: AppColors.acento, size: 28),
            SizedBox(height: 4),
            Text(
              'Comodín',
              style: TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }
    return CartaEspanolaSkin(
      numero: c.numero!,
      etiqueta: c.etiqueta,
      palo: _paloVisual(c.palo!),
      seleccionada: seleccionada,
      width: w,
      height: h,
    );
  }

  @override
  Widget build(BuildContext context) {
    final actual = _partida.jugadorActual;
    final vista = _vistaLocal;
    final mano = vista.mano;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_mostrarAjustes) {
          setState(() => _mostrarAjustes = false);
          return;
        }
        if (_mostrarMenu) {
          setState(() {
            _mostrarMenu = false;
            _confirmarRendicion = false;
          });
          return;
        }
        setState(() {
          _mostrarMenu = true;
          _confirmarRendicion = false;
        });
      },
      child: Scaffold(
      backgroundColor: AppColors.fondo,
      body: Stack(
        children: [
          const Positioned.fill(
            child: EpicBackdrop(centerY: 0.45, fadeRayosAlCentro: true),
          ),
          SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => setState(() {
                              _mostrarMenu = true;
                              _confirmarRendicion = false;
                              _mostrarAjustes = false;
                            }),
                            icon: const Icon(Icons.menu, color: AppColors.texto),
                          ),
                          Expanded(
                            child: Text(
                              TextosJodete.titulo,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.texto,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          if (widget.contraPc)
                            BotonReiniciarPartidaPc(
                              onPressed: _pedirReiniciarVsPc,
                            ),
                          IconButton(
                            onPressed: () => setState(() {
                              _mostrarAjustes = true;
                              _mostrarMenu = false;
                            }),
                            icon: const Icon(
                              Icons.settings,
                              color: AppColors.textoSuave,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final j in _partida.jugadores)
                          _chipJugador(j),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_partida.ultimaJugada != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _partida.ultimaJugada!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.acento,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Column(
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _paloVigenteIndicador(),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _mazoWidget(),
                                const SizedBox(width: 18),
                                if (_partida.cimaDescarte != null)
                                  _cartaWidget(
                                    _partida.cimaDescarte!,
                                    seleccionada: false,
                                    w: 78,
                                    h: 118,
                                  )
                                else
                                  const SizedBox(width: 78, height: 118),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          _turnoDePc
                              ? '${actual.nombre} está pensando…'
                              : (_partida.hayPendienteDos
                                  ? '¡${vista.nombre}! Tirás un 2 o levantás ${_partida.pendienteDos}'
                                  : 'Turno de ${actual.nombre}'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _partida.hayPendienteDos
                                ? AppColors.peligro
                                : (_turnoDePc
                                    ? AppColors.rosa
                                    : AppColors.mint),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tu mano - ${mano.length} carta${mano.length == 1 ? '' : 's'}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textoSuave,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 140,
                          child: _ManoJodete(
                            cartas: mano,
                            seleccion: _seleccion,
                            animaciones: _ajustes.animaciones,
                            puedeElegir: _puedeJugarHumano,
                            onTap: _toggleCarta,
                            buildCarta: (c, {required sel}) =>
                                _cartaWidget(c, seleccionada: sel),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: SizedBox(
                            height: 48,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed:
                                        _puedeJugarHumano ? _levantar : null,
                                    child: Text(
                                      _partida.hayPendienteDos
                                          ? 'Levantar ${_partida.pendienteDos}'
                                          : TextosJodete.levantar,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _puedeJugarHumano &&
                                            _seleccion != null &&
                                            puedeJugarCartaJodete(
                                              _partida,
                                              _seleccion!,
                                            )
                                        ? () => unawaited(_confirmarTirar())
                                        : null,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.azul,
                                      foregroundColor: Colors.black,
                                    ),
                                    child: const Text(TextosJodete.tirar),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_tituloOverlayPc != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.35),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _tituloOverlayPc!,
                              style: const TextStyle(
                                color: AppColors.rosa,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (_overlaySoloDorso)
                              _dorsoCartaGrande()
                            else if (_cartaOverlayPc != null)
                              _cartaWidget(
                                _cartaOverlayPc!,
                                seleccionada: true,
                                w: 92,
                                h: 138,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (_eligiendoPalo)
                Positioned.fill(
                  child: _OverlayElegirPalo(
                    onElegir: _elegirPalo,
                    paloVisual: _paloVisual,
                  ),
                ),
              if (_esperandoCambioJugador && _partida.jugando)
                Positioned.fill(
                  child: CambioJugadorOverlay(
                    nombreJugador: actual.nombre,
                    onAceptar: () {
                      setState(() => _esperandoCambioJugador = false);
                      if (_debeAutoLevantarPendienteDos) {
                        unawaited(_talVezAutoLevantarPendienteDos());
                      } else {
                        _talVezPc();
                      }
                    },
                  ),
                ),
              if (_mostrarResumenRonda)
                Positioned.fill(
                  child: ResumenRondaJodeteOverlay(
                    resultado: _partida.ultimoResultado!,
                    onContinuar: _continuarRonda,
                    esFinPartida: _partida.terminada,
                  ),
                ),
              if (_mostrarAjustes)
                Positioned.fill(
                  child: AjustesOverlay(
                    ajustes: _ajustes,
                    onChanged: (a) => setState(() => _ajustes = a),
                    onCerrar: () => setState(() => _mostrarAjustes = false),
                  ),
                ),
              if (_mostrarMenu)
                Positioned.fill(
                  child: MenuPartidaJodete(
                    jugador: vista.nombre,
                    partidaTerminada: _partida.terminada,
                    confirmarRendicion: _confirmarRendicion,
                    permitirRendirse: _esLocalHotSeat,
                    onCerrar: () => setState(() {
                      _mostrarMenu = false;
                      _confirmarRendicion = false;
                    }),
                    onReglas: () {
                      setState(() => _mostrarMenu = false);
                      _mostrarReglas();
                    },
                    onSalirORendirse: () {
                      if (_esLocalHotSeat && !_partida.terminada) {
                        setState(() => _confirmarRendicion = true);
                      } else {
                        // vs PC: salir guarda; partida terminada: no guardar.
                        _salirAlMenu(guardar: !_partida.terminada);
                      }
                    },
                    onConfirmarRendicion: () {
                      setState(() {
                        _mostrarMenu = false;
                        _confirmarRendicion = false;
                        rendirseJodete(_partida, actual.nombre);
                        if (!_partida.terminada && _esLocalHotSeat) {
                          _esperandoCambioJugador = true;
                        }
                      });
                    },
                    onCancelarRendicion: () =>
                        setState(() => _confirmarRendicion = false),
                  ),
                ),
              if (_mostrarVictoria)
                Positioned.fill(
                  child: VictoriaJodeteOverlay(
                    partida: _partida,
                    gane: !widget.contraPc ||
                        _partida.ganador == _humanoPrincipal.nombre,
                    animaciones: _ajustes.animaciones,
                    onVolverAJugar: _reiniciar,
                    onVolver: () => _salirAlMenu(guardar: false),
                  ),
                ),
            ],
          ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _chipJugador(JugadorJodete j) {
    final turno = _partida.jugando &&
        _partida.jugadorActual.nombre == j.nombre &&
        j.enJuego;
    final ver = _modoDiosActivo && esNombrePc(j.nombre);
    final fuera = j.rendido || j.puestoRonda != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: AppColors.carta.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: turno
              ? AppColors.mint
              : AppColors.textoSuave.withValues(alpha: 0.3),
          width: turno ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            j.rendido
                ? '${j.nombre} (fuera)'
                : (j.puestoRonda != null
                    ? '${j.nombre} (${j.puestoRonda}º)'
                    : j.nombre),
            style: TextStyle(
              color: fuera ? AppColors.textoSuave : AppColors.texto,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              decoration: j.rendido ? TextDecoration.lineThrough : null,
            ),
          ),
          const SizedBox(height: 4),
          MarcadorPalitosEscoba(
            puntos: j.puntos,
            color: AppColors.acento,
            tamanoGrupo: 22,
          ),
          Text(
            '${j.puntos} pts · ${j.mano.length} cartas',
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (ver && j.mano.isNotEmpty)
            SizedBox(
              height: 36,
              child: ListView.separated(
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                itemCount: j.mano.length,
                separatorBuilder: (_, __) => const SizedBox(width: 2),
                itemBuilder: (_, i) =>
                    _cartaWidget(j.mano[i], seleccionada: false, w: 24, h: 36),
              ),
            ),
        ],
      ),
    );
  }

  /// Indicador de palo (mismo estilo que el de Desconfío / Pozo).
  Widget _paloVigenteIndicador() {
    final palo = _partida.paloVigente;
    final sentido =
        _partida.sentido == SentidoJodete.horario ? '→' : '←';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          TextosJodete.paloVigente,
          style: TextStyle(
            color: AppColors.textoSuave,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        CartaEspanolaSkin(
          numero: 0,
          etiqueta: nombrePaloJodete(palo).toLowerCase(),
          palo: _paloVisual(palo),
          width: 56,
          height: 84,
        ),
        const SizedBox(height: 4),
        Text(
          sentido,
          style: const TextStyle(
            color: AppColors.textoSuave,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _dorsoCartaGrande() {
    return Container(
      width: 92,
      height: 138,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B1D6E), Color(0xFF1A0A33)],
        ),
        border: Border.all(
          color: colorSeleccionCartaEspanola,
          width: 2.4,
        ),
        boxShadow: neonGlow(colorSeleccionCartaEspanola, blur: 16),
      ),
      child: const Center(
        child: Icon(Icons.style, color: AppColors.acento, size: 36),
      ),
    );
  }

  Widget _mazoWidget() {
    final puede = _puedeJugarHumano;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: puede ? _levantar : null,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              width: 78,
              height: 118,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3B1D6E), Color(0xFF1A0A33)],
                ),
                border: Border.all(color: AppColors.acento, width: 2),
              ),
              child: const Center(
                child: Icon(Icons.style, color: AppColors.acento, size: 32),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Mazo ${_partida.mazo.length}',
          style: const TextStyle(
            color: AppColors.textoSuave,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _OverlayElegirPalo extends StatelessWidget {
  const _OverlayElegirPalo({
    required this.onElegir,
    required this.paloVisual,
  });

  final ValueChanged<PaloJodete> onElegir;
  final PaloEspanolVisual Function(PaloJodete) paloVisual;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF3B1D6E),
                Color(0xFF1A0A33),
                Color(0xFF2A1050),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.acento, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                TextosJodete.elegirPalo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.acento,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tocá una carta para declarar el palo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textoSuave,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final p in PaloJodete.values) ...[
                      if (p != PaloJodete.values.first)
                        const SizedBox(width: 10),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onElegir(p),
                          borderRadius: BorderRadius.circular(14),
                          child: CartaEspanolaSkin(
                            numero: 0,
                            etiqueta: nombrePaloJodete(p).toLowerCase(),
                            palo: paloVisual(p),
                            width: 78,
                            height: 118,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManoJodete extends StatelessWidget {
  const _ManoJodete({
    required this.cartas,
    required this.seleccion,
    required this.animaciones,
    required this.puedeElegir,
    required this.onTap,
    required this.buildCarta,
  });

  final List<CartaJodete> cartas;
  final CartaJodete? seleccion;
  final bool animaciones;
  final bool puedeElegir;
  final ValueChanged<CartaJodete> onTap;
  final Widget Function(CartaJodete c, {required bool sel}) buildCarta;

  static const double _deslizamiento = 14;
  static const double _cardW = 68;
  static const double _cardH = 102;

  @override
  Widget build(BuildContext context) {
    if (cartas.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A0A33).withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.violeta.withValues(alpha: 0.55),
            width: 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: const Text('—', style: TextStyle(color: AppColors.textoSuave)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A33).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.violeta.withValues(alpha: 0.55),
          width: 1.2,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth - 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < cartas.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Builder(
                      builder: (context) {
                        final c = cartas[i];
                        final sel = seleccion == c;
                        return Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: puedeElegir ? () => onTap(c) : null,
                            borderRadius: BorderRadius.circular(14),
                            splashColor: sel
                                ? colorSeleccionCartaEspanola.withValues(
                                    alpha: 0.25,
                                  )
                                : Colors.transparent,
                            highlightColor: sel
                                ? colorSeleccionCartaEspanola.withValues(
                                    alpha: 0.18,
                                  )
                                : Colors.transparent,
                            hoverColor: sel
                                ? colorSeleccionCartaEspanola.withValues(
                                    alpha: 0.22,
                                  )
                                : Colors.transparent,
                            child: SizedBox(
                              width: _cardW,
                              height: _cardH + _deslizamiento,
                              child: AnimatedAlign(
                                duration: animaciones
                                    ? const Duration(milliseconds: 380)
                                    : Duration.zero,
                                curve: Curves.easeOutCubic,
                                alignment: sel
                                    ? Alignment.topCenter
                                    : Alignment.bottomCenter,
                                child: buildCarta(c, sel: sel),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
