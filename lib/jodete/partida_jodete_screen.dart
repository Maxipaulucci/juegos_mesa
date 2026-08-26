import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/jodete/ia_jodete.dart';
import 'package:app_juegos_mesa/jodete/menu_partida_jodete.dart';
import 'package:app_juegos_mesa/jodete/modo_dios_jodete.dart';
import 'package:app_juegos_mesa/jodete/motor_jodete.dart';
import 'package:app_juegos_mesa/jodete/opciones_jodete.dart';
import 'package:app_juegos_mesa/jodete/resumen_ronda_jodete_overlay.dart';
import 'package:app_juegos_mesa/jodete/historial_jodete.dart';
import 'package:app_juegos_mesa/jodete/standby_store.dart';
import 'package:app_juegos_mesa/jodete/textos.dart';
import 'package:app_juegos_mesa/jodete/victoria_jodete_overlay.dart';
import 'package:app_juegos_mesa/escobaDel15/marcador_palitos.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/cartas/animacion_orden_mano.dart';
import 'package:app_juegos_mesa/shared/cartas/boton_ordenar_mano.dart';
import 'package:app_juegos_mesa/shared/cartas/carta_espanola_skin.dart';
import 'package:app_juegos_mesa/shared/cartas/ordenar_mano_cartas.dart';
import 'package:app_juegos_mesa/shared/cartas/reordenar_carta_mano.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/monedas/monedas_store.dart';
import 'package:app_juegos_mesa/shared/monedas/premiar_monedas_victoria_pc.dart';
import 'package:app_juegos_mesa/shared/partida_ui/cambio_jugador_overlay.dart';
import 'package:app_juegos_mesa/shared/partida_ui/epic_backdrop.dart';
import 'package:app_juegos_mesa/shared/partida_ui/reiniciar_partida_pc.dart';
import 'package:app_juegos_mesa/shared/partida_ui/nombre_jugador_editable.dart';
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
  /// Último modo de orden aplicado con el botón (null = aún no se usó).
  ModoOrdenManoCartas? _modoOrdenMano;
  /// Se incrementa al ordenar para disparar la animación de deslizamiento.
  int _ordenAnimGen = 0;
  /// Copia del orden de la mano justo antes del último ordenado automático.
  List<CartaJodete>? _ordenAntesAnim;
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

  static const int _maxNombre = 15;

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
      _partida.enFinRonda && _partida.ultimoResultado != null;

  bool get _mostrarVictoria => _partida.terminada;

  bool get _puedeTirarSeleccion =>
      _puedeJugarHumano &&
      _seleccion != null &&
      puedeJugarCartaJodete(_partida, _seleccion!);

  bool _puedeRenombrar(JugadorJodete j) {
    if (_partida.terminada) return false;
    if (j.rendido) return false;
    if (j.puestoRonda != null) return false;
    return !esNombrePc(j.nombre);
  }

  String? _validarNombre(String nombre, int index) {
    final t = nombre.trim();
    if (t.isEmpty) return 'El nombre no puede estar vacío.';
    if (t.length > _maxNombre) return 'Máximo $_maxNombre caracteres.';
    if (esNombrePc(t)) return 'Ese nombre está reservado para la PC.';
    final ocupado = _partida.jugadores.asMap().entries.any(
          (e) => e.key != index && e.value.nombre == t,
        );
    if (ocupado) return 'Ese nombre ya está en uso.';
    return null;
  }

  Future<void> _renombrarJugador(int index) async {
    if (index < 0 || index >= _partida.jugadores.length) return;
    final j = _partida.jugadores[index];
    if (!_puedeRenombrar(j)) return;
    final actual = j.nombre;

    final ctrl = TextEditingController(text: actual);
    String? error;

    final nuevo = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.carta,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Cambiar nombre',
            style: TextStyle(color: AppColors.acento, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Máximo 15 caracteres.',
                style: TextStyle(color: AppColors.textoSuave, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: _maxNombre,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: AppColors.texto),
                decoration: InputDecoration(
                  hintText: 'Nombre del jugador',
                  errorText: error,
                  counterStyle: const TextStyle(color: AppColors.textoSuave),
                ),
                onSubmitted: (_) {
                  final t = ctrl.text.trim();
                  final err = _validarNombre(t, index);
                  if (err != null) {
                    setDialogState(() => error = err);
                    return;
                  }
                  Navigator.of(context).pop(t);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final t = ctrl.text.trim();
                  final err = _validarNombre(t, index);
                  if (err != null) {
                    setDialogState(() => error = err);
                    return;
                  }
                  Navigator.of(context).pop(t);
                },
                child: const Text('Guardar'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.peligro,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );

    if (nuevo == null || nuevo == actual || !mounted) return;
    setState(() {
      _partida.jugadores[index].nombre = nuevo;
      if (_partida.ganador == actual) _partida.ganador = nuevo;
      final msg = _partida.mensajeFin;
      if (msg != null && msg.contains(actual)) {
        _partida.mensajeFin = msg.replaceAll(actual, nuevo);
      }
    });
  }

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
        apilarDoses: _opciones.apilarDoses,
        ganarConEspecial: _opciones.ganarConEspecial,
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
      _opciones = JodeteMenuConfig.opciones;
      _dificultad = widget.dificultad;
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
        apilarDoses: _opciones.apilarDoses,
        ganarConEspecial: _opciones.ganarConEspecial,
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

  int get _idxManoForzar => _partida.jugadores.indexOf(_humanoPrincipal);

  Future<void> _abrirForzarCartas() async {
    if (!_modoDiosActivo || !_partida.jugando || _jugandoPc) return;
    final idx = _idxManoForzar;
    if (idx < 0) return;

    final resultado = await mostrarForzarCartasJodete(
      context: context,
      disponibles: cartasDisponiblesForzarJodete(_partida),
      manoInicial: List.of(_humanoPrincipal.mano),
      pozoInicial: _partida.cimaDescarte,
    );
    if (resultado == null || !mounted) return;

    final antes = _partida.indiceTurno;
    setState(() {
      _seleccion = null;
      _eligiendoPalo = false;
      _cartaPendientePalo = null;
      if (resultado.pozo != null) {
        forzarCimaDescarteJodete(_partida, resultado.pozo!);
      }
      forzarManoJodete(_partida, idx, resultado.mano);
    });
    _despuesDeJugada(antes);
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
              apilarDoses: _partida.apilarDoses,
              ganarConEspecial: _partida.ganarConEspecial,
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
    if (_seleccion == c) {
      if (puedeJugarCartaJodete(_partida, c)) {
        unawaited(_confirmarTirar());
        return;
      }
      setState(() => _seleccion = null);
      return;
    }
    setState(() => _seleccion = c);
  }

  void _reordenarMano(int desde, int hacia) {
    final mano = _vistaLocal.mano;
    if (desde < 0 || hacia < 0 || desde >= mano.length || hacia >= mano.length) {
      return;
    }
    if (desde == hacia) return;
    final carta = mano.removeAt(desde);
    mano.insert(hacia, carta);
    setState(() {});
  }

  void _ciclarOrdenMano() {
    final mano = _vistaLocal.mano;
    if (mano.length < 2) return;
    // Copia antes de ordenar in-place: sin esto no hay deltas ni animación.
    final ordenAntes = List<CartaJodete>.of(mano);
    final modo = ciclarOrdenManoCartas(
      mano,
      modoActual: _modoOrdenMano,
      claves: (c) => ClavesOrdenCarta(
        numero: c.numero ?? 0,
        palo: c.palo?.index ?? 0,
        esComodin: c.esComodin,
      ),
    );
    setState(() {
      _modoOrdenMano = modo;
      _ordenAntesAnim = ordenAntes;
      _ordenAnimGen++;
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
    _marcarAccionDeTurno();
    _aplicarJugada(carta, palo);
  }

  void _cancelarElegirPalo() {
    if (!_eligiendoPalo) return;
    setState(() {
      _eligiendoPalo = false;
      _cartaPendientePalo = null;
      _yaActuoEsteTurno = false;
    });
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

  /// Si hay 2/comodín pendientes y no podés responder, levantás (tras 2 s).
  bool get _debeAutoLevantarPendienteDos {
    if (!_puedeJugarHumano) return false;
    if (_partida.hayPendienteDos) {
      if (!_partida.apilarDoses) return true;
      return !_partida.jugadorActual.mano.any((c) => c.esDos);
    }
    if (_partida.hayPendienteComodin) {
      if (!_partida.apilaComodines) return true;
      return !_partida.jugadorActual.mano.any((c) => c.esComodin);
    }
    return false;
  }

  Future<void> _talVezAutoLevantarPendienteDos() async {
    if (!_debeAutoLevantarPendienteDos) return;
    // 2 s para que no se note al toque si tenías un 2 o no.
    await Future<void>.delayed(const Duration(seconds: 2));
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
    if (!_partida.enFinRonda) return;
    setState(() {
      siguienteRondaJodete(_partida, _rng);
      _seleccion = null;
      _eligiendoPalo = false;
      _cartaPendientePalo = null;
      _yaActuoEsteTurno = false;
      _turnoDeLaAccion = -1;
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
        final n = _partida.hayPendienteLevantar
            ? _partida.cantidadPendienteLevantar
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
                        for (final entry
                            in _partida.jugadores.asMap().entries)
                          _chipJugador(entry.value, entry.key),
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _paloVigenteIndicador(),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Equilibra el ancho del historial para
                                        // que mazo + pozo queden en el mismo centro.
                                        const SizedBox(width: 38),
                                        _mazoWidget(),
                                        const SizedBox(width: 18),
                                        SizedBox(
                                          width: 116,
                                          height: 140,
                                          child: Stack(
                                            children: [
                                              SizedBox(
                                                width: 78,
                                                child: _descarteWidget(),
                                              ),
                                              Positioned(
                                                top: 36,
                                                left: 84,
                                                child: _botonHistorial(),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (_modoDiosActivo)
                                          Transform.translate(
                                            offset: const Offset(-38, 0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const SizedBox(width: 12),
                                                _botonModoDios(),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        _turnoDePc
                                            ? '${actual.nombre} está pensando…'
                                            : (_partida.hayPendienteComodin
                                                ? (_partida.apilaComodines
                                                    ? '¡${vista.nombre}! Tirás un comodín o levantás ${_partida.pendienteComodin}'
                                                    : '¡${vista.nombre}! Levantás ${_partida.pendienteComodin}')
                                                : (_partida.hayPendienteDos
                                                    ? (_partida.apilarDoses
                                                        ? '¡${vista.nombre}! Tirás un 2 o levantás ${_partida.pendienteDos}'
                                                        : '¡${vista.nombre}! Levantás ${_partida.pendienteDos}')
                                                    : 'Turno de ${actual.nombre}')),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _partida.hayPendienteLevantar
                                              ? AppColors.peligro
                                              : (_turnoDePc
                                                  ? AppColors.rosa
                                                  : AppColors.mint),
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 40,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Text(
                                            'Tu mano - ${mano.length} carta${mano.length == 1 ? '' : 's'}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: AppColors.textoSuave,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          // Fuera del contenedor de cartas, arriba a la derecha.
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                right: 10,
                                              ),
                                              child: BotonOrdenarMano(
                                                size: 38,
                                                onPressed: mano.length < 2
                                                    ? null
                                                    : _ciclarOrdenMano,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      height: 140,
                                      child: _ManoJodete(
                                        cartas: mano,
                                        seleccion: _seleccion,
                                        animaciones: _ajustes.animaciones,
                                        puedeElegir: _puedeJugarHumano,
                                        onTap: _toggleCarta,
                                        onReordenar: _reordenarMano,
                                        ordenAnimGen: _ordenAnimGen,
                                        ordenAntesAnim: _ordenAntesAnim,
                                        buildCarta: (c, {required sel}) =>
                                            _cartaWidget(
                                          c,
                                          seleccionada: sel,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        0,
                                        12,
                                        12,
                                      ),
                                      child: SizedBox(
                                        height: 48,
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: _puedeJugarHumano
                                                    ? _levantar
                                                    : null,
                                                child: Text(
                                                  _partida.hayPendienteLevantar
                                                      ? 'Levantar ${_partida.cantidadPendienteLevantar}'
                                                      : TextosJodete.levantar,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: FilledButton(
                                                onPressed: _puedeTirarSeleccion
                                                    ? () => unawaited(
                                                          _confirmarTirar(),
                                                        )
                                                    : null,
                                                style: FilledButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.azul,
                                                  foregroundColor: Colors.black,
                                                ),
                                                child: const Text(
                                                  TextosJodete.tirar,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
                    onCerrar: _cancelarElegirPalo,
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
                    objetivo: _partida.objetivo,
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
                  child: PremiarMonedasVictoriaPc(
                    aplicar: widget.contraPc &&
                        _partida.ganador == _humanoPrincipal.nombre,
                    juegoId: MenuJuegoScreen.juegoIdJodete,
                    child: VictoriaJodeteOverlay(
                      partida: _partida,
                      gane: !widget.contraPc ||
                          _partida.ganador == _humanoPrincipal.nombre,
                      animaciones: _ajustes.animaciones,
                      onVolverAJugar: _reiniciar,
                      onVolver: () => _salirAlMenu(guardar: false),
                    ),
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

  Widget _chipJugador(JugadorJodete j, int index) {
    final esMio = _esLocalHotSeat
        ? (widget.nombres.isNotEmpty
            ? j.nombre == widget.nombres.first
            : j.nombre == _partida.jugadores.first.nombre)
        : j.nombre == _humanoPrincipal.nombre;
    final turno = _partida.jugando &&
        _partida.jugadorActual.nombre == j.nombre &&
        j.enJuego;
    final ver = _modoDiosActivo && esNombrePc(j.nombre);
    final fuera = j.rendido || j.puestoRonda != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          // Cuando el nombre es editable, `NombreJugadorEditable` agrega padding
          // (icono lápiz). Para que todas las tarjetas tengan la misma altura,
          // fijamos el alto del área del nombre.
          SizedBox(
            height: 30,
            child: NombreJugadorEditable(
              nombre: j.rendido
                  ? '${j.nombre} (fuera)'
                  : (j.puestoRonda != null
                      ? '${j.nombre} (${j.puestoRonda}º)'
                      : j.nombre),
              puedeRenombrar: _puedeRenombrar(j),
              onRenombrar: _puedeRenombrar(j)
                  ? () => _renombrarJugador(index)
                  : null,
              colorTexto: fuera ? AppColors.textoSuave : AppColors.texto,
              fontSize: 12,
              tachado: j.rendido,
              mayusculas: false,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 14,
                child: MarcadorPalitosEscoba(
                  puntos: j.puntos,
                  color: _partida.objetivo == 30
                      ? Colors.white
                      : AppColors.acento,
                  colorDesdeUmbral:
                      _partida.objetivo == 30 ? AppColors.azul : null,
                  umbralColor: _partida.objetivo == 30 ? 15 : null,
                  tamanoGrupo: 14,
                ),
              ),
              if (j.puntos > 0) const SizedBox(width: 6),
              Text(
                '${j.puntos} pts',
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          Visibility(
            visible: !esMio,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${j.mano.length} carta${j.mano.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
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

  Widget _descarteWidget() {
    final cima = _partida.cimaDescarte;
    final puedeTirar = _puedeTirarSeleccion;
    return Column(
      children: [
        GestureDetector(
          onTap: puedeTirar ? () => unawaited(_confirmarTirar()) : null,
          child: cima != null
              ? _cartaWidget(
                  cima,
                  seleccionada: puedeTirar,
                  w: 78,
                  h: 118,
                )
              : const SizedBox(width: 78, height: 118),
        ),
        const SizedBox(height: 4),
        Text(
          TextosJodete.descarte,
          style: TextStyle(
            color: puedeTirar ? AppColors.mint : AppColors.textoSuave,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _botonHistorial() {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          mostrarCartasTiradasJodete(
            context: context,
            partida: _partida,
          );
        },
        child: const SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            Icons.history_rounded,
            color: AppColors.textoSuave,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _botonModoDios() {
    final activo =
        _modoDiosActivo && _partida.jugando && !_jugandoPc && !_eligiendoPalo;
    return Padding(
      padding: const EdgeInsets.only(top: 38),
      child: Material(
        color: AppColors.carta,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: activo ? () => unawaited(_abrirForzarCartas()) : null,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.textoSuave.withValues(alpha: 0.5),
              ),
            ),
            child: const Icon(
              Icons.bug_report,
              size: 20,
              color: AppColors.textoSuave,
            ),
          ),
        ),
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
    required this.onCerrar,
    required this.paloVisual,
  });

  final ValueChanged<PaloJodete> onElegir;
  final VoidCallback onCerrar;
  final PaloEspanolVisual Function(PaloJodete) paloVisual;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCerrar,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.72),
              ),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 18),
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
                    Row(
                      children: [
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Text(
                              TextosJodete.elegirPalo,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.acento,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onCerrar,
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.texto,
                          ),
                        ),
                      ],
                    ),
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
          ),
        ],
      ),
    );
  }
}

class _ManoJodete extends StatefulWidget {
  const _ManoJodete({
    required this.cartas,
    required this.seleccion,
    required this.animaciones,
    required this.puedeElegir,
    required this.onTap,
    required this.buildCarta,
    this.onReordenar,
    this.ordenAnimGen = 0,
    this.ordenAntesAnim,
  });

  final List<CartaJodete> cartas;
  final CartaJodete? seleccion;
  final bool animaciones;
  final bool puedeElegir;
  final ValueChanged<CartaJodete> onTap;
  final void Function(int desde, int hacia)? onReordenar;
  final Widget Function(CartaJodete c, {required bool sel}) buildCarta;
  /// Generación de ordenado automático (botón); 0 = sin animación de sort.
  final int ordenAnimGen;

  /// Orden de la mano justo antes del último sort (copia; no la lista viva).
  final List<CartaJodete>? ordenAntesAnim;

  @override
  State<_ManoJodete> createState() => _ManoJodeteState();
}

class _ManoJodeteState extends State<_ManoJodete> {
  final _scroll = ScrollController();
  final _rowKey = GlobalKey();
  final _reorden = ReordenarCartaManoDrag();
  bool _priorizarReorden = false;
  Map<Object, double> _dxOrden = const {};
  int _genOrden = 0;

  static const double _cardW = 68;
  static const double _cardH = 102;
  static const double _gap = 6;

  bool get _arrastrando => _reorden.arrastrando;
  /// Capacidad de reorden (no depende del turno: el árbol de widgets se mantiene).
  bool get _tieneReorden => widget.onReordenar != null;
  bool get _bloquearScroll => _arrastrando || _priorizarReorden;

  void _setPriorizarReorden(bool v) {
    if (!mounted) return;
    if (!v && _arrastrando) return;
    if (_priorizarReorden == v) return;
    setState(() => _priorizarReorden = v);
  }

  void _limpiarAnimOrden() {
    if (_dxOrden.isEmpty) return;
    _dxOrden = const {};
  }

  @override
  void didUpdateWidget(covariant _ManoJodete oldWidget) {
    super.didUpdateWidget(oldWidget);

    final mismoGen = widget.ordenAnimGen == oldWidget.ordenAnimGen;
    final largoCambio = oldWidget.cartas.length != widget.cartas.length;
    final turnoCambio = oldWidget.puedeElegir != widget.puedeElegir;

    // Turno / robar / tirar: la mano no debe “resbalar” por deltas viejos.
    if (turnoCambio || (mismoGen && largoCambio)) {
      _limpiarAnimOrden();
      if (largoCambio &&
          widget.cartas.length > oldWidget.cartas.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scroll.hasClients) return;
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        });
      }
      if (mismoGen) return;
    }

    if (!mismoGen &&
        widget.ordenAnimGen > 0 &&
        widget.animaciones &&
        widget.ordenAntesAnim != null &&
        widget.ordenAntesAnim!.length == widget.cartas.length &&
        widget.cartas.isNotEmpty) {
      // Usar la copia previa: la lista viva ya está ordenada in-place.
      _dxOrden = deltasInicioOrdenMano(
        antes: <Object>[for (final c in widget.ordenAntesAnim!) c],
        despues: <Object>[for (final c in widget.cartas) c],
        paso: _cardW + _gap,
      );
      _genOrden = widget.ordenAnimGen;
      // Tras la animación, descartar deltas para que un rebuild no las repita.
      Future<void>.delayed(kDuracionAnimacionOrdenMano, () {
        if (!mounted) return;
        if (_genOrden != widget.ordenAnimGen) return;
        setState(_limpiarAnimOrden);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int _indiceInsercionDesdeGlobal(double globalX) {
    return indiceInsercionDesdeGlobalReorden(
      rowKey: _rowKey,
      drag: _reorden,
      globalX: globalX,
      cantidad: widget.cartas.length,
      anchoCarta: _cardW,
      gap: _gap,
    );
  }

  void _iniciarDrag(int index, Offset localPosition) {
    setState(() {
      _reorden.iniciar(
        index: index,
        localPosition: localPosition,
        anchoCarta: _cardW,
      );
    });
  }

  void _actualizarDrag(DragUpdateDetails details) {
    if (!_reorden.arrastrando) return;
    autoScrollDuranteDragReorden(
      scroll: _scroll,
      context: context,
      globalX: details.globalPosition.dx,
    );
    setState(() {
      _reorden.actualizar(
        details: details,
        indiceInsercionDesdeGlobal: _indiceInsercionDesdeGlobal,
      );
    });
  }

  void _soltarDrag() {
    final resultado = _reorden.soltar();
    _priorizarReorden = false;
    if (resultado != null) {
      widget.onReordenar?.call(resultado.desde, resultado.hacia);
    } else if (mounted) {
      setState(() {});
    }
  }

  void _cancelarDrag() {
    setState(() {
      _reorden.cancelar();
      _priorizarReorden = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cartas.isEmpty) {
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
          final minW = constraints.maxWidth - 24;
          final n = widget.cartas.length;
          final contentW =
              n == 0 ? 0.0 : n * _cardW + (n - 1) * _gap;
          final filaW = math.max(minW, contentW);
          return SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            // Solo bloquea scroll al tocar/arrastrar la carta seleccionada.
            physics: physicsScrollManoReorden(bloquearPorReorden: _bloquearScroll),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SizedBox(
              width: filaW,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    key: _rowKey,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < widget.cartas.length; i++) ...[
                        if (i > 0) const SizedBox(width: _gap),
                        Builder(
                          key: ValueKey<String>('slot_${widget.cartas[i].id}'),
                          builder: (context) {
                            final c = widget.cartas[i];
                            final sel = widget.seleccion == c;
                            final esLaQueArrastro = _reorden.dragIndex == i;
                            final atenuar =
                                _arrastrando && !esLaQueArrastro;

                            // Árbol estable: mismos padres al seleccionar.
                            Widget child = CartaOpacidadReorden(
                              esLaQueArrastro: esLaQueArrastro,
                              atenuar: atenuar,
                              child: CartaSlotSeleccion(
                                seleccionada: sel,
                                // Sin animar subida/bajada al cambiar de turno.
                                animaciones:
                                    widget.animaciones && widget.puedeElegir,
                                width: _cardW,
                                height: _cardH,
                                child: widget.buildCarta(c, sel: sel),
                              ),
                            );

                            child = CartaDeslizOrdenMano(
                              key: ValueKey<String>(
                                'ord_${c.id}_$_genOrden',
                              ),
                              dxInicial: _dxOrden[c] ?? 0,
                              animaciones: widget.animaciones,
                              child: child,
                            );

                            child = CartaConHuecoReorden(
                              arrastrandoMano: _arrastrando,
                              esLaQueArrastro: esLaQueArrastro,
                              shiftX: _reorden.shiftX(i, _cardW + _gap),
                              duration: widget.animaciones
                                  ? kDuracionHuecoReordenMano
                                  : Duration.zero,
                              child: child,
                            );

                            child = CartaArrastreVisualReorden(
                              esLaQueArrastro: esLaQueArrastro,
                              dragDx: _reorden.dragDx,
                              dragDy: _reorden.dragDy,
                              ocultarEnSlot: true,
                              borderRadius: BorderRadius.circular(14),
                              child: child,
                            );

                            // Árbol estable en cambios de turno/selección:
                            // mismos padres siempre; solo cambian los callbacks.
                            final puedeInteractuar = widget.puedeElegir;
                            final puedeArrastrar =
                                _tieneReorden && sel && puedeInteractuar;

                            return Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              child: Listener(
                                onPointerDown: puedeArrastrar
                                    ? (_) => _setPriorizarReorden(true)
                                    : null,
                                onPointerUp: puedeArrastrar
                                    ? (_) => _setPriorizarReorden(false)
                                    : null,
                                onPointerCancel: puedeArrastrar
                                    ? (_) => _setPriorizarReorden(false)
                                    : null,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: puedeInteractuar
                                      ? () => widget.onTap(c)
                                      : null,
                                  onPanStart: puedeArrastrar
                                      ? (details) => _iniciarDrag(
                                            i,
                                            details.localPosition,
                                          )
                                      : null,
                                  onPanUpdate: _arrastrando
                                      ? _actualizarDrag
                                      : null,
                                  onPanEnd: _arrastrando
                                      ? (_) => _soltarDrag()
                                      : null,
                                  onPanCancel: _arrastrando
                                      ? _cancelarDrag
                                      : null,
                                  child: child,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                  if (_reorden.dragIndex != null)
                    CartaFlotanteReorden(
                      rowKey: _rowKey,
                      index: _reorden.dragIndex!,
                      cantidad: widget.cartas.length,
                      anchoCarta: _cardW,
                      gap: _gap,
                      dragDx: _reorden.dragDx,
                      dragDy: _reorden.dragDy,
                      borderRadius: BorderRadius.circular(14),
                      child: CartaSlotSeleccion(
                        seleccionada: true,
                        animaciones: false,
                        width: _cardW,
                        height: _cardH,
                        child: widget.buildCarta(
                          widget.cartas[_reorden.dragIndex!],
                          sel: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
