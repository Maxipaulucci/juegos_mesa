import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/culoSucioV2/culo_sucio_v2_online_codec.dart';
import 'package:app_juegos_mesa/culoSucioV2/menu_partida_culo_sucio_v2.dart';
import 'package:app_juegos_mesa/culoSucioV2/motor_culo_sucio_v2.dart';
import 'package:app_juegos_mesa/culoSucioV2/opciones_culo_sucio_v2.dart';
import 'package:app_juegos_mesa/culoSucioV2/standby_store.dart';
import 'package:app_juegos_mesa/culoSucioV2/textos.dart';
import 'package:app_juegos_mesa/culoSucioV2/victoria_culo_sucio_v2_overlay.dart';
import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/cartas/carta_espanola_skin.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/partida_ui/cambio_jugador_overlay.dart';
import 'package:app_juegos_mesa/shared/partida_ui/epic_backdrop.dart';
import 'package:app_juegos_mesa/shared/partida_ui/reiniciar_partida_pc.dart';
import 'package:app_juegos_mesa/shared/partida_ui/nombre_jugador_editable.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Partida local / vs PC / online de Culo sucio v2.
class PartidaCuloSucioV2Screen extends StatefulWidget {
  const PartidaCuloSucioV2Screen({
    super.key,
    required this.nombres,
    this.contraPc = false,
    this.modoDios = false,
    this.opciones = const OpcionesCuloSucioV2(),
    this.resume,
    this.salaCodigo,
    this.miNombre,
    this.ajustesIniciales,
  });

  final List<String> nombres;
  final bool contraPc;
  final bool modoDios;
  final OpcionesCuloSucioV2 opciones;
  final PartidaCuloSucioV2Resume? resume;
  final String? salaCodigo;
  final String? miNombre;
  final AjustesEstado? ajustesIniciales;

  @override
  State<PartidaCuloSucioV2Screen> createState() =>
      _PartidaCuloSucioV2ScreenState();
}

class _PartidaCuloSucioV2ScreenState extends State<PartidaCuloSucioV2Screen> {
  late PartidaCuloSucioV2 _partida;
  late List<String> _nombres;
  late OpcionesCuloSucioV2 _opciones;
  late bool _modoDios;
  AjustesEstado _ajustes = const AjustesEstado();
  bool _mostrarMenu = false;
  bool _mostrarAjustes = false;
  bool _confirmarRendicion = false;
  bool _robando = false;
  int _pcToken = 0;
  /// Índices seleccionados en la mano para formar un par inicial.
  final List<int> _seleccionPar = [];
  /// Carta del rival revelada antes de robarla.
  int? _indiceRevelando;
  /// Nombre del jugador cuya carta está revelada ([_indiceRevelando]).
  String? _revelandoDeNombre;
  /// Tras un robo, hay que confirmar el par tocando las cartas marcadas.
  bool _esperandoDescartarPar = false;
  /// Índice del 1 de oro seleccionado para reordenarlo en la mano.
  int? _indiceCuloMoviendo;
  /// Índice en la mano del humano que la PC está por robar.
  int? _indiceRobadaPorPc;
  /// Carta que alguien se está llevando (overlay grande).
  CartaCuloSucioV2? _cartaQueSeLlevaPc;
  /// Quién se lleva [_cartaQueSeLlevaPc] (nombre para el cartel).
  String? _nombreQuienSeLleva;
  /// A quién se la sacan (para el texto de estado).
  String? _nombreVictimaRobo;
  /// Carta que el rival online te acaba de sacar (overlay).
  CartaCuloSucioV2? _cartaQueTeSacaron;
  int _roboRivalToken = 0;
  int? _roboRivalVersionMostrada;
  /// Multijugador local: hay que aceptar el cambio antes de ver la mano.
  bool _cambioJugadorPendiente = false;
  /// Quién está mirando el dispositivo (mano de abajo) en hot-seat.
  String? _nombreVistaLocal;

  StreamSubscription<Sala>? _onlineSub;
  int _onlineVersion = 0;
  bool _esperandoMazoOnline = false;
  bool _mazoPublicado = false;
  bool _publicandoOnline = false;

  bool get _esOnline =>
      widget.salaCodigo != null &&
      widget.salaCodigo!.isNotEmpty &&
      widget.miNombre != null &&
      widget.miNombre!.isNotEmpty;

  bool get _soyAnfitrionOnline =>
      _esOnline &&
      widget.nombres.isNotEmpty &&
      widget.nombres.first == widget.miNombre;

  bool get _modoDiosActivo =>
      _modoDios && widget.contraPc && !_esOnline;

  bool get _esLocalHotSeat => !_esOnline && !widget.contraPc;

  JugadorCuloSucioV2 get _jugadorVistaLocal {
    final nombre = _nombreVistaLocal ?? _partida.jugadores.first.nombre;
    return _partida.jugadores.firstWhere(
      (j) => j.nombre == nombre,
      orElse: () => _partida.jugadores.first,
    );
  }

  /// Mano propia (abajo).
  JugadorCuloSucioV2 get _yo {
    if (_esOnline) {
      return _partida.jugadores.firstWhere(
        (j) => j.nombre == widget.miNombre,
        orElse: () => _partida.jugadores.first,
      );
    }
    if (_esLocalHotSeat) return _jugadorVistaLocal;
    return _partida.jugadores.firstWhere(
      (j) => !esNombrePc(j.nombre),
      orElse: () => _partida.jugadores.first,
    );
  }

  /// Manos ajenas (arriba), en orden de mesa desde el siguiente a [_yo].
  List<JugadorCuloSucioV2> get _oponentes {
    final todos = _partida.jugadores;
    final yo = _yo;
    final idx = todos.indexWhere((j) => j.nombre == yo.nombre);
    if (idx < 0) {
      return [for (final j in todos) if (j.nombre != yo.nombre) j];
    }
    return [
      for (var i = 1; i < todos.length; i++)
        todos[(idx + i) % todos.length],
    ];
  }

  /// A quién se le puede robar en el turno actual.
  JugadorCuloSucioV2 get _objetivoRobo => _partida.rivalActual;

  bool _manoOponenteBocaArriba(JugadorCuloSucioV2 j) =>
      _modoDiosActivo && esNombrePc(j.nombre);

  bool get _esMiTurnoOnline =>
      !_esOnline || _partida.jugadorActual.nombre == widget.miNombre;

  bool get _esTurnoHumano {
    if (_partida.terminada) return false;
    if (_esperandoMazoOnline) return false;
    if (_esLocalHotSeat && _cambioJugadorPendiente) return false;
    if (_esperandoDescartarPar) return true;
    if (_fasePares) {
      if (_esOnline) return !_yo.paresInicialesListos;
      if (widget.contraPc) {
        return !esNombrePc(_partida.jugadorActual.nombre);
      }
      return _jugadorVistaLocal.nombre == _partida.jugadorActual.nombre;
    }
    if (_esOnline) return _esMiTurnoOnline;
    if (_esLocalHotSeat) {
      return _jugadorVistaLocal.nombre == _partida.jugadorActual.nombre;
    }
    return !esNombrePc(_partida.jugadorActual.nombre);
  }

  bool get _esTurnoPc =>
      !_esOnline &&
      widget.contraPc &&
      !_partida.terminada &&
      _partida.enJuego &&
      !_esperandoDescartarPar &&
      esNombrePc(_partida.jugadorActual.nombre);

  bool get _fasePares => _partida.descartandoPares;

  bool get _puedoDescartarPares =>
      _fasePares && _esTurnoHumano && !_robando && !_esperandoMazoOnline;

  bool get _puedoMoverCulo =>
      _opciones.moverCuloSucio &&
      _partida.enJuego &&
      _esTurnoHumano &&
      !_robando &&
      !_esperandoDescartarPar &&
      !_esperandoMazoOnline &&
      !_cambioJugadorPendiente &&
      _yo.mano.any((c) => c.esCuloSucio);

  bool get _debeMostrarVictoria {
    if (_partida.ganador == null || _partida.perdedor == null) return false;
    if (_esOnline) return _partida.ganador == widget.miNombre;
    if (_esLocalHotSeat) return true;
    return !esNombrePc(_partida.ganador!);
  }

  String get _textoEstado {
    if (_partida.terminada) return '';
    if (_esLocalHotSeat && _cambioJugadorPendiente) return '';
    if (_esperandoMazoOnline) return TextosCuloSucioV2.esperandoMazoOnline;
    if (_fasePares) {
      if (_esOnline) {
        if (_yo.paresInicialesListos) {
          return TextosCuloSucioV2.esperandoRivalPares;
        }
        return TextosCuloSucioV2.sacandoPares;
      }
      if (!_esTurnoHumano) {
        return TextosCuloSucioV2.esperandoRivalPares;
      }
      return TextosCuloSucioV2.sacandoPares;
    }
    if (_esperandoDescartarPar) return '';
    if (_indiceCuloMoviendo != null) {
      return _ajustes.animaciones
          ? TextosCuloSucioV2.culoSeleccionado
          : TextosCuloSucioV2.culoSeleccionadoSinAnimacion;
    }
    if (_cartaQueSeLlevaPc != null || _cartaQueTeSacaron != null) {
      return _cartaQueTeSacaron != null
          ? TextosCuloSucioV2.rivalTeSaco
          : _textoEstadoRoboPc;
    }
    if (_esTurnoPc) return TextosCuloSucioV2.esperandoPc;
    if (_esOnline && !_esMiTurnoOnline) {
      return TextosCuloSucioV2.esperandoTuTurno;
    }
    if (_esTurnoHumano) {
      if (_puedoMoverCulo) {
        final hint = _ajustes.animaciones
            ? TextosCuloSucioV2.moverCulo
            : TextosCuloSucioV2.moverCuloSinAnimacion;
        return '${TextosCuloSucioV2.robaUna}\n$hint';
      }
      return TextosCuloSucioV2.robaUna;
    }
    return 'Turno de ${_partida.jugadorActual.nombre}';
  }

  String get _textoEstadoRoboPc {
    final quien = _nombreQuienSeLleva ?? 'PC';
    final victima = _nombreVictimaRobo;
    if (victima == null || victima == _yo.nombre) {
      return '¡$quien eligió una de tus cartas!';
    }
    return '¡$quien eligió una carta de $victima!';
  }

  String get _tituloOverlayRobo {
    if (_cartaQueTeSacaron != null) return TextosCuloSucioV2.rivalTeSaco;
    final quien = (_nombreQuienSeLleva ?? 'PC').toUpperCase();
    return '$quien SE LLEVA';
  }

  void _pedirCambioJugador() {
    if (!_esLocalHotSeat || _partida.terminada) return;
    setState(() {
      _cambioJugadorPendiente = true;
      _seleccionPar.clear();
      _esperandoDescartarPar = false;
      _indiceCuloMoviendo = null;
      _limpiarAvisoJugada();
    });
  }

  /// Pide cambio solo si el turno pasó a otro jugador.
  void _pedirCambioJugadorSiCorresponde() {
    if (!_esLocalHotSeat || _partida.terminada) return;
    if (_partida.jugadorActual.nombre == _nombreVistaLocal) return;
    _pedirCambioJugador();
  }

  void _aceptarCambioJugador() {
    if (!_cambioJugadorPendiente) return;
    setState(() {
      _cambioJugadorPendiente = false;
      _nombreVistaLocal = _partida.jugadorActual.nombre;
      _seleccionPar.clear();
      _indiceCuloMoviendo = null;
    });
  }

  @override
  void initState() {
    super.initState();
    final resume = widget.resume;
    _nombres = List.of(resume?.nombres ?? widget.nombres);
    _modoDios = widget.modoDios;
    if (resume != null && !_esOnline) {
      _partida = resume.partida;
      _opciones = resume.opciones;
      _modoDios = resume.modoDios;
      _ajustes = resume.ajustesIniciales;
      _nombres = List.of(resume.nombres);
      WidgetsBinding.instance.addPostFrameCallback((_) => _talVezTurnoPc());
      return;
    }
    _opciones = widget.opciones;
    _ajustes = widget.ajustesIniciales ?? const AjustesEstado();
    if (_esOnline) {
      _esperandoMazoOnline = true;
      _partida = nuevaPartidaCuloSucioV2(
        nombres: _nombres,
        contraPc: false,
        online: true,
      );
      for (final j in _partida.jugadores) {
        j.mano.clear();
        j.descartes.clear();
        j.paresInicialesListos = false;
      }
      _iniciarSincronizacionOnline();
      return;
    }
    _partida = nuevaPartidaCuloSucioV2(
      nombres: _nombres,
      contraPc: widget.contraPc,
    );
    if (_esLocalHotSeat) {
      _nombreVistaLocal = _partida.jugadorActual.nombre;
      _cambioJugadorPendiente = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _talVezTurnoPc());
    }
  }

  @override
  void dispose() {
    _onlineSub?.cancel();
    _pcToken++;
    _roboRivalToken++;
    super.dispose();
  }

  void _iniciarSincronizacionOnline() {
    final codigo = widget.salaCodigo;
    if (codigo == null) return;
    if (_onlineVersion < 1) _onlineVersion = 1;
    unawaited(() async {
      try {
        final sala = await SalaService.instance.obtener(codigo);
        if (mounted) _onSalaOnlineActualizada(sala);
      } catch (_) {}
    }());
    _onlineSub = SalaService.instance
        .watch(codigo, intervalo: const Duration(milliseconds: 400))
        .listen(_onSalaOnlineActualizada);
  }

  void _onSalaOnlineActualizada(Sala sala) {
    if (!mounted || !_esOnline) return;
    final gameState = sala.gameState;
    if (gameState == null) return;

    final juego = gameState['juego']?.toString();
    if (juego != 'culoSucioV2') {
      if (_soyAnfitrionOnline && !_mazoPublicado) {
        unawaited(_publicarMazoInicialOnline());
      }
      return;
    }

    final version = (gameState['version'] as num?)?.toInt() ?? 0;
    if (version < _onlineVersion) return;
    if (_publicandoOnline && version <= _onlineVersion) return;

    final tieneMazo = culoSucioV2PartidaGenerada(gameState);
    if (!tieneMazo) {
      if (_soyAnfitrionOnline && !_mazoPublicado) {
        unawaited(_publicarMazoInicialOnline());
      }
      return;
    }

    if (version <= _onlineVersion && !_esperandoMazoOnline) return;

    setState(() {
      applyCuloSucioV2GameState(_partida, gameState);
      _opciones = opcionesDesdeCuloSucioV2GameState(gameState, _opciones);
      _onlineVersion = version;
      _esperandoMazoOnline = false;
      _mazoPublicado = true;
      if (!_esMiTurnoOnline) {
        _esperandoDescartarPar = false;
        _seleccionPar.clear();
        _indiceRevelando = null;
        _revelandoDeNombre = null;
        _indiceCuloMoviendo = null;
      }
      _talVezMostrarRoboDelRival(version);
    });
  }

  void _talVezMostrarRoboDelRival(int version) {
    final carta = _partida.ultimaRobada;
    final de = _partida.ultimaRobadaDe;
    final por = _partida.ultimaRobadaPor;
    if (carta == null || de == null || por == null) return;
    if (de != widget.miNombre || por == widget.miNombre) return;
    if (_roboRivalVersionMostrada == version) return;
    _roboRivalVersionMostrada = version;
    _cartaQueTeSacaron = carta;
    final token = ++_roboRivalToken;
    unawaited(() async {
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      if (!mounted || token != _roboRivalToken) return;
      setState(() => _cartaQueTeSacaron = null);
    }());
  }

  Future<void> _publicarMazoInicialOnline() async {
    if (!_esOnline || _mazoPublicado || _publicandoOnline) return;
    final generada = nuevaPartidaCuloSucioV2(
      nombres: _nombres,
      contraPc: false,
      online: true,
    );
    setState(() {
      _partida = generada;
      _esperandoMazoOnline = false;
      _mazoPublicado = true;
    });
    await _publicarEstadoOnline(forzar: true);
  }

  Future<void> _publicarEstadoOnline({bool forzar = false}) async {
    if (!_esOnline) return;
    final codigo = widget.salaCodigo;
    if (codigo == null) return;

    _publicandoOnline = true;
    try {
      for (var intento = 0; intento < 4; intento++) {
        _onlineVersion++;
        final gameState = encodeCuloSucioV2GameState(
          partida: _partida,
          version: _onlineVersion,
          opciones: _opciones,
        );
        try {
          final res = await SalaService.instance.actualizarJuego(
            codigo: codigo,
            gameState: gameState,
          );
          if (!res.ignored) {
            final v = (res.sala.gameState?['version'] as num?)?.toInt() ??
                _onlineVersion;
            _onlineVersion = v;
            return;
          }
          final remoteV = res.sala.gameVersion;
          if (remoteV >= _onlineVersion) {
            _onlineVersion = remoteV;
            if (!forzar) return;
          }
          await Future<void>.delayed(
            Duration(milliseconds: 60 * (intento + 1)),
          );
        } catch (_) {
          await Future<void>.delayed(
            Duration(milliseconds: 100 * (intento + 1)),
          );
        }
      }
    } finally {
      _publicandoOnline = false;
    }
  }

  void _guardarResumeSiCorresponde() {
    if (!widget.contraPc || _esOnline) return;
    if (_partida.terminada) {
      CuloSucioV2StandByStore.limpiar();
      return;
    }
    CuloSucioV2StandByStore.guardar(
      PartidaCuloSucioV2Resume(
        partida: _partida,
        nombres: _nombres,
        modoDios: _modoDios,
        opciones: _opciones,
        ajustesIniciales: _ajustes,
      ),
    );
  }

  void _mostrarDialogoReglas() {
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
            TextosCuloSucioV2.reglasCompletas(),
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

  void _salirAlMenu({required bool guardar}) {
    _pcToken++;
    _roboRivalToken++;
    _onlineSub?.cancel();
    if (guardar) {
      _guardarResumeSiCorresponde();
    } else {
      CuloSucioV2StandByStore.limpiar();
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  static const int _maxNombre = 15;

  bool _esPcNombre(String nombre) => esNombrePc(nombre);

  bool _puedeRenombrar(int index) {
    if (_esOnline) return false;
    if (_partida.terminada) return false;
    if (index < 0 || index >= _partida.jugadores.length) return false;
    final j = _partida.jugadores[index];
    if (j.rendido) return false;
    return !_esPcNombre(j.nombre);
  }

  void _rendirse() {
    if (_partida.terminada) return;
    if (!_esLocalHotSeat && !_esOnline) return;
    final yo = _esOnline ? _yo : _partida.jugadorActual;
    if (yo.rendido) return;

    setState(() {
      _mostrarMenu = false;
      _confirmarRendicion = false;
      _seleccionPar.clear();
      _esperandoDescartarPar = false;
      _indiceCuloMoviendo = null;
      _limpiarAvisoJugada();
      rendirseCuloSucioV2(_partida, yo.nombre);
    });

    if (_esOnline) {
      unawaited(_publicarEstadoOnline(forzar: true));
      return;
    }
    if (!_partida.terminada) {
      _pedirCambioJugadorSiCorresponde();
    }
  }

  String? _validarNombre(String nombre, int index) {
    if (nombre.isEmpty) return 'El nombre no puede estar vacío.';
    if (nombre.length > _maxNombre) {
      return 'Máximo $_maxNombre caracteres.';
    }
    if (_esPcNombre(nombre)) {
      return 'Ese nombre está reservado para la PC.';
    }
    final ocupado = _partida.jugadores.asMap().entries.any(
          (e) => e.key != index && e.value.nombre == nombre,
        );
    if (ocupado) return 'Ese nombre ya está en uso.';
    return null;
  }

  Future<void> _renombrarJugador(int index) async {
    if (!_puedeRenombrar(index)) return;
    final actual = _partida.jugadores[index].nombre;
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
                  if (_validarNombre(t, index) case final e?) {
                    setDialogState(() => error = e);
                    return;
                  }
                  Navigator.of(context).pop(t);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final t = ctrl.text.trim();
                  if (_validarNombre(t, index) case final e?) {
                    setDialogState(() => error = e);
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
      if (index < _nombres.length) _nombres[index] = nuevo;
      if (_partida.perdedor == actual) _partida.perdedor = nuevo;
      if (_partida.ganador == actual) _partida.ganador = nuevo;
      if (_partida.ultimaRobadaDe == actual) {
        _partida.ultimaRobadaDe = nuevo;
      }
      if (_partida.ultimaRobadaPor == actual) {
        _partida.ultimaRobadaPor = nuevo;
      }
      if (_nombreVistaLocal == actual) _nombreVistaLocal = nuevo;
      final msg = _partida.mensajeFin;
      if (msg != null && msg.contains(actual)) {
        _partida.mensajeFin = msg.replaceAll(actual, nuevo);
      }
    });
  }

  void _limpiarAvisoJugada() {
    _partida.ultimaRobada = null;
    _partida.ultimaRobadaDe = null;
    _partida.ultimaRobadaPor = null;
    _partida.ultimoPar = null;
  }

  Future<void> _talVezTurnoPc() async {
    if (_esOnline) return;
    if (!_esTurnoPc || _robando) return;
    final token = ++_pcToken;
    // Si todavía se muestra un ¡Par!, dejarlo 1 s más antes de seguir.
    if (_partida.ultimoPar != null) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted || token != _pcToken) return;
      if (!_esTurnoPc || _robando) return;
    }
    setState(_limpiarAvisoJugada);
    // Si no hay autodetección de par, la espera de 2 s ya ocurrió tras el robo.
    await Future<void>.delayed(
      _opciones.detectarParTrasRobo
          ? const Duration(milliseconds: 750)
          : const Duration(milliseconds: 200),
    );
    if (!mounted || token != _pcToken) return;
    if (!_esTurnoPc) return;

    final hacia = _partida.jugadorActual;
    final de = _partida.rivalActual;
    if (de.sinCartas || !esNombrePc(hacia.nombre)) {
      return;
    }
    final idx = math.Random().nextInt(de.mano.length);
    final cartaElegida = de.mano[idx];
    final robaAlHumano = de.nombre == _yo.nombre;

    setState(() {
      _robando = true;
      _cartaQueSeLlevaPc = cartaElegida;
      _nombreQuienSeLleva = hacia.nombre;
      _nombreVictimaRobo = de.nombre;
      if (robaAlHumano) {
        _indiceRobadaPorPc = idx;
      } else {
        // También revelar en la mano del rival afectado.
        _revelandoDeNombre = de.nombre;
        _indiceRevelando = idx;
      }
    });
    // Tiempo para que el usuario vea qué carta se llevan.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted || token != _pcToken) return;

    robarCartaCuloSucioV2(
      _partida,
      de: de,
      indiceEnManoDe: idx,
      hacia: hacia,
    );
    if (!mounted) return;
    setState(() {
      _indiceRobadaPorPc = null;
      _cartaQueSeLlevaPc = null;
      _nombreQuienSeLleva = null;
      _nombreVictimaRobo = null;
      _indiceRevelando = null;
      _revelandoDeNombre = null;
      _robando = false;
    });
    // Deja ver el aviso de robada / par (+1 s si fue par).
    await Future<void>.delayed(
      _partida.ultimoPar != null
          ? const Duration(milliseconds: 1700)
          : const Duration(milliseconds: 700),
    );
    if (!mounted || token != _pcToken) return;
    setState(_limpiarAvisoJugada);
    if (!_partida.terminada) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (mounted) _talVezTurnoPc();
    }
  }

  Future<void> _robarDeRival(int indice) async {
    if (!_partida.enJuego ||
        _robando ||
        _esperandoDescartarPar ||
        !_esTurnoHumano ||
        (_esOnline && !_esMiTurnoOnline)) {
      return;
    }
    final hacia = _yo;
    final de = _objetivoRobo;
    if (hacia.nombre != _partida.jugadorActual.nombre) return;
    if (de.nombre == hacia.nombre) return;
    if (indice < 0 || indice >= de.mano.length) return;

    setState(() {
      _limpiarAvisoJugada();
      _robando = true;
      _revelandoDeNombre = de.nombre;
      _indiceRevelando = indice;
      _indiceCuloMoviendo = null;
    });
    // Mostrar la carta boca arriba un momento antes de llevarla a la mano.
    await Future<void>.delayed(const Duration(milliseconds: 950));
    if (!mounted) return;

    final detectarPar = _opciones.detectarParTrasRobo;
    final parPendiente = <int>[];
    final err = robarCartaCuloSucioV2(
      _partida,
      de: de,
      indiceEnManoDe: indice,
      hacia: hacia,
      autoDescartarPar: false,
      dejarParEnMano: !detectarPar,
      parPendienteOut: detectarPar ? parPendiente : null,
    );
    if (!mounted) return;
    setState(() {
      _indiceRevelando = null;
      _revelandoDeNombre = null;
      _robando = false;
      if (detectarPar && err == null && parPendiente.length >= 2) {
        _esperandoDescartarPar = true;
        _seleccionPar
          ..clear()
          ..addAll(parPendiente);
      } else {
        _esperandoDescartarPar = false;
        _seleccionPar.clear();
      }
    });
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (_esOnline) {
      unawaited(_publicarEstadoOnline(forzar: _partida.terminada));
      // No limpiar ultimaRobada: el rival necesita ver qué carta le sacaron.
      return;
    }
    if (_esperandoDescartarPar) return;
    // Con autodetección: aviso breve (+1 s si hay par). Sin ella: 2 s antes de que robe el rival.
    // En local: breve pausa y cartel de cambio de jugador.
    await Future<void>.delayed(
      _esLocalHotSeat
          ? const Duration(milliseconds: 700)
          : (detectarPar
              ? (_partida.ultimoPar != null
                  ? const Duration(milliseconds: 1700)
                  : const Duration(milliseconds: 700))
              : const Duration(seconds: 2)),
    );
    if (!mounted) return;
    setState(_limpiarAvisoJugada);
    if (_partida.terminada) return;
    if (_esLocalHotSeat) {
      _pedirCambioJugadorSiCorresponde();
      return;
    }
    if (detectarPar) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (mounted) _talVezTurnoPc();
  }

  void _tocarParTrasRobo(int indice) {
    if (!_esperandoDescartarPar || _seleccionPar.length < 2) return;
    if (!_seleccionPar.contains(indice)) return;
    final jugador = _yo;
    final err = descartarParTrasRoboCuloSucioV2(
      _partida,
      jugador: jugador,
      indiceA: _seleccionPar[0],
      indiceB: _seleccionPar[1],
    );
    setState(() {
      _esperandoDescartarPar = false;
      _seleccionPar.clear();
    });
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (_esOnline) {
      unawaited(_publicarEstadoOnline(forzar: _partida.terminada));
      return;
    }
    // Deja ver el ¡Par! (+1 s) y luego lo limpia al completar el turno.
    Future<void>(() async {
      await Future<void>.delayed(const Duration(milliseconds: 1700));
      if (!mounted) return;
      setState(_limpiarAvisoJugada);
      if (_partida.terminada) return;
      if (_esLocalHotSeat) {
        _pedirCambioJugadorSiCorresponde();
        return;
      }
      _talVezTurnoPc();
    });
  }

  void _reordenarCuloEnMano(int desde, int hacia) {
    if (!_opciones.moverCuloSucio) return;
    if (!_partida.enJuego || _robando || _esperandoDescartarPar) return;
    if (_yo.nombre != _partida.jugadorActual.nombre) return;
    final mano = _partida.jugadorActual.mano;
    if (desde < 0 || desde >= mano.length) return;
    if (hacia < 0 || hacia >= mano.length) return;
    if (!mano[desde].esCuloSucio) return;

    final err = moverCuloSucioEnManoCuloSucioV2(
      _partida,
      jugador: _partida.jugadorActual,
      desde: desde,
      hacia: hacia,
    );
    if (!mounted) return;
    setState(() => _indiceCuloMoviendo = null);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (_esOnline) {
      unawaited(_publicarEstadoOnline());
    }
  }

  void _tocarManoParaMoverCulo(int indice) {
    if (!_opciones.moverCuloSucio || _ajustes.animaciones) return;
    if (!_partida.enJuego || _robando || _esperandoDescartarPar) return;
    if (_yo.nombre != _partida.jugadorActual.nombre) return;
    final mano = _partida.jugadorActual.mano;
    if (indice < 0 || indice >= mano.length) return;

    final seleccionado = _indiceCuloMoviendo;
    if (seleccionado == null) {
      if (!mano[indice].esCuloSucio) return;
      setState(() => _indiceCuloMoviendo = indice);
      return;
    }

    if (seleccionado == indice) {
      setState(() => _indiceCuloMoviendo = null);
      return;
    }

    final err = intercambiarCuloSucioEnManoCuloSucioV2(
      _partida,
      jugador: _partida.jugadorActual,
      desde: seleccionado,
      hacia: indice,
    );
    if (!mounted) return;
    setState(() => _indiceCuloMoviendo = null);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (_esOnline) {
      unawaited(_publicarEstadoOnline());
    }
  }

  void _tocarCartaManoParaPar(int indice) {
    if (!_puedoDescartarPares) return;
    if (_seleccionPar.contains(indice)) {
      setState(() => _seleccionPar.remove(indice));
      return;
    }
    if (_seleccionPar.isEmpty) {
      setState(() => _seleccionPar.add(indice));
      return;
    }

    final jugador = _yo;
    final primero = _seleccionPar.first;
    if (primero < 0 ||
        primero >= jugador.mano.length ||
        indice >= jugador.mano.length) {
      setState(() {
        _seleccionPar
          ..clear()
          ..add(indice);
      });
      return;
    }

    if (jugador.mano[primero].numero != jugador.mano[indice].numero) {
      // Número distinto: la nueva carta queda como única selección.
      setState(() {
        _seleccionPar
          ..clear()
          ..add(indice);
      });
      return;
    }

    final err = descartarParManualCuloSucioV2(
      _partida,
      jugador: jugador,
      indiceA: primero,
      indiceB: indice,
    );
    setState(() => _seleccionPar.clear());
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (_esOnline) {
      unawaited(_publicarEstadoOnline());
    }
  }

  void _confirmarParesListos() {
    if (!_puedoDescartarPares) return;
    final err = confirmarParesInicialesListos(_partida, jugador: _yo);
    setState(() => _seleccionPar.clear());
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (_esOnline) {
      unawaited(_publicarEstadoOnline(forzar: true));
    }
    if (_esLocalHotSeat && !_partida.terminada) {
      _pedirCambioJugadorSiCorresponde();
      return;
    }
    if (_partida.enJuego) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _talVezTurnoPc());
    }
  }

  void _eliminarParesAutomaticamente() {
    if (!_puedoDescartarPares) return;
    final err = descartarTodosParesInicialesCuloSucioV2(
      _partida,
      jugador: _yo,
    );
    setState(() => _seleccionPar.clear());
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (_esOnline) {
      unawaited(_publicarEstadoOnline());
    }
  }

  void _reiniciar() {
    if (_esOnline) {
      _salirAlMenu(guardar: false);
      return;
    }
    _pcToken++;
    CuloSucioV2StandByStore.limpiar();
    setState(() {
      // Aplicar config actual del menú al reiniciar.
      _opciones = CuloSucioV2MenuConfig.opciones;
      _modoDios = modoDiosElegidoEnMenu(
        MenuJuegoScreen.juegoIdCuloSucioV2,
        fallback: widget.modoDios,
      );
      if (widget.contraPc) {
        final pcs = cantidadPcElegidaEnMenu(MenuJuegoScreen.juegoIdCuloSucioV2) ??
            cantidadPcEnNombres(_nombres);
        _nombres = reconstruirNombresVsPc(
          actuales: _nombres,
          cantidadPc: pcs.clamp(1, 3),
        );
      }
      _partida = nuevaPartidaCuloSucioV2(
        nombres: _nombres,
        contraPc: widget.contraPc,
      );
      _robando = false;
      _mostrarMenu = false;
      _mostrarAjustes = false;
      _confirmarRendicion = false;
      _seleccionPar.clear();
      _indiceRevelando = null;
      _revelandoDeNombre = null;
      _esperandoDescartarPar = false;
      _indiceRobadaPorPc = null;
      _cartaQueSeLlevaPc = null;
      _nombreQuienSeLleva = null;
      _nombreVictimaRobo = null;
      _cartaQueTeSacaron = null;
      _indiceCuloMoviendo = null;
      _nombreVistaLocal = _esLocalHotSeat ? _partida.jugadorActual.nombre : null;
      _cambioJugadorPendiente = _esLocalHotSeat;
    });
    if (!_esLocalHotSeat) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _talVezTurnoPc());
    }
  }

  Future<void> _pedirReiniciarVsPc() async {
    if (!widget.contraPc || _esOnline) return;
    final ok = await confirmarReiniciarPartidaPc(context);
    if (!ok || !mounted) return;
    _reiniciar();
  }

  Color _colorPalo(PaloCuloSucioV2 palo) => switch (palo) {
        PaloCuloSucioV2.oro => const Color(0xFFFFC107),
        PaloCuloSucioV2.copa => const Color(0xFFFF5252),
        PaloCuloSucioV2.espada => const Color(0xFF40C4FF),
        PaloCuloSucioV2.basto => const Color(0xFF69F0AE),
      };

  IconData _iconoPalo(PaloCuloSucioV2 palo) => switch (palo) {
        PaloCuloSucioV2.oro => Icons.monetization_on_outlined,
        PaloCuloSucioV2.copa => Icons.wine_bar_outlined,
        PaloCuloSucioV2.espada => Icons.bolt_outlined,
        PaloCuloSucioV2.basto => Icons.park_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final manoAbajo = (_esOnline || widget.contraPc || _esLocalHotSeat)
        ? _yo
        : _partida.jugadorActual;
    final oponentes = (_esOnline || widget.contraPc || _esLocalHotSeat)
        ? _oponentes
        : [
            for (final j in _partida.jugadores)
              if (j.nombre != manoAbajo.nombre) j,
          ];
    final objetivoRobo = _objetivoRobo;
    final compactaOponentes = oponentes.length > 1;
    // Con varios rivales: solo una mano grande (arriba); el resto chicas
    // para que entren en pantalla.
    final altoSlotGrande = compactaOponentes ? 108.0 : 132.0;
    final altoSlotChico = 64.0;
    // Prioridad visual: quien tiene el turno (si es rival) o a quién se roba.
    final nombreManoGrande = () {
      if (oponentes.isEmpty) return null;
      if (_esperandoDescartarPar) return objetivoRobo.nombre;
      final enTurno = oponentes
          .where((o) => o.nombre == _partida.jugadorActual.nombre)
          .toList();
      if (enTurno.isNotEmpty) return enTurno.first.nombre;
      return objetivoRobo.nombre;
    }();
    final oponentesVis = nombreManoGrande == null
        ? oponentes
        : [
            ...oponentes.where((o) => o.nombre == nombreManoGrande),
            ...oponentes.where((o) => o.nombre != nombreManoGrande),
          ];
    final yoTurno = manoAbajo;
    final destacarMiMano = !_fasePares && _esTurnoHumano;
    final resaltandoRoboEnMiMano = _indiceRobadaPorPc != null ||
        (_cartaQueSeLlevaPc != null && _nombreVictimaRobo == _yo.nombre);
    // Tu mano: altura fija; solo resalta borde en tu turno / si te roban.
    const altoSlotMiMano = 148.0;

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
          _mostrarAjustes = false;
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
              child: Column(
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
                        const Expanded(
                          child: Text(
                            TextosCuloSucioV2.titulo,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.texto,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (widget.contraPc && !_esOnline)
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
                            color: AppColors.texto,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        for (var i = 0;
                            i < _partida.jugadores.length;
                            i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _ChipJugador(
                              nombre: _partida.jugadores[i].rendido
                                  ? '${_partida.jugadores[i].nombre} (fuera)'
                                  : _partida.jugadores[i].nombre,
                              cartas: _partida.jugadores[i].mano.length,
                              activo: !_partida.terminada &&
                                  !_partida.jugadores[i].rendido &&
                                  _partida.indiceTurno == i,
                              perdido: _partida.perdedor ==
                                  _partida.jugadores[i].nombre,
                              ganado: _partida.ganador ==
                                  _partida.jugadores[i].nombre,
                              rendido: _partida.jugadores[i].rendido,
                              puedeRenombrar: _puedeRenombrar(i),
                              onRenombrar: _puedeRenombrar(i)
                                  ? () => _renombrarJugador(i)
                                  : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: _textoEstado.isEmpty
                        ? const SizedBox.shrink()
                        : Center(
                            child: Text(
                              _textoEstado,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _esTurnoHumano
                                    ? AppColors.acento
                                    : AppColors.textoSuave,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                                height: 1.15,
                              ),
                            ),
                          ),
                  ),
                  if (!_fasePares) ...[
                    const SizedBox(height: 10),
                    Expanded(
                      flex: oponentesVis.length > 1 ? 3 : 2,
                      child: oponentesVis.isEmpty
                          ? const SizedBox.shrink()
                          : SingleChildScrollView(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0;
                                      i < oponentesVis.length;
                                      i++) ...[
                                    if (i > 0) const SizedBox(height: 6),
                                    Builder(
                                      builder: (context) {
                                        final oponente = oponentesVis[i];
                                        final esObjetivoRoboHumano =
                                            _esTurnoHumano &&
                                                !_esperandoMazoOnline &&
                                                oponente.nombre ==
                                                    objetivoRobo.nombre &&
                                                !oponente.sinCartas &&
                                                !oponente.rendido;
                                        // No se puede robar mientras confirmás el par,
                                        // pero la mano rival mantiene el tamaño normal.
                                        final sePuedeRobar =
                                            esObjetivoRoboHumano &&
                                                !_robando &&
                                                !_esperandoDescartarPar;
                                        final esTurnoDeEste =
                                            !_partida.terminada &&
                                                !_fasePares &&
                                                oponente.nombre ==
                                                    _partida
                                                        .jugadorActual.nombre;
                                        final manoGrande = compactaOponentes
                                            ? oponente.nombre ==
                                                nombreManoGrande
                                            : true;
                                        final manoDestacada = esTurnoDeEste ||
                                            esObjetivoRoboHumano ||
                                            (_esperandoDescartarPar &&
                                                oponente.nombre ==
                                                    objetivoRobo.nombre);
                                        final altoSlot = manoGrande
                                            ? altoSlotGrande
                                            : altoSlotChico;
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              oponentesVis.length == 1
                                                  ? '${TextosCuloSucioV2.manoRival}: ${oponente.nombre}'
                                                  : '${TextosCuloSucioV2.manoDe} ${oponente.nombre}',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: manoDestacada
                                                    ? AppColors.acento
                                                    : AppColors.textoSuave,
                                                fontWeight: FontWeight.w700,
                                                fontSize:
                                                    manoGrande ? 14 : 12,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            SizedBox(
                                              height: altoSlot,
                                              width: double.infinity,
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    12,
                                                  ),
                                                  border: Border.all(
                                                    color: manoDestacada
                                                        ? AppColors.acento
                                                            .withValues(
                                                          alpha: 0.55,
                                                        )
                                                        : Colors.transparent,
                                                    width: 1.2,
                                                  ),
                                                ),
                                                child: _FilaCartas(
                                                  cartas: oponente.mano,
                                                  bocaArriba:
                                                      _manoOponenteBocaArriba(
                                                    oponente,
                                                  ),
                                                  compacta: !manoGrande,
                                                  anchoCarta: manoGrande
                                                      ? (compactaOponentes
                                                          ? 56
                                                          : 68)
                                                      : 36,
                                                  altoCarta: manoGrande
                                                      ? (compactaOponentes
                                                          ? 84
                                                          : 102)
                                                      : 50,
                                                  indiceRevelado:
                                                      _revelandoDeNombre ==
                                                              oponente.nombre
                                                          ? _indiceRevelando
                                                          : null,
                                                  colorPalo: _colorPalo,
                                                  iconoPalo: _iconoPalo,
                                                  onTapIndex: sePuedeRobar
                                                      ? _robarDeRival
                                                      : null,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: (_cartaQueSeLlevaPc == null &&
                                (_partida.ultimaRobada != null ||
                                    _partida.ultimoPar != null))
                            ? _AvisoJugada(
                                robada: _partida.ultimaRobada,
                                par: _partida.ultimoPar,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    Text(
                      '${TextosCuloSucioV2.tuMano}: ${manoAbajo.nombre}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: (destacarMiMano || resaltandoRoboEnMiMano)
                            ? AppColors.acento
                            : AppColors.mint.withValues(
                                alpha: _esperandoDescartarPar ? 0 : 1,
                              ),
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: altoSlotMiMano,
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (destacarMiMano || resaltandoRoboEnMiMano)
                                ? AppColors.acento.withValues(alpha: 0.55)
                                : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        child: Opacity(
                          opacity: _esperandoDescartarPar ? 0 : 1,
                          child: IgnorePointer(
                            ignoring: _esperandoDescartarPar,
                            child: _FilaCartas(
                              cartas: manoAbajo.mano,
                              bocaArriba: !_cambioJugadorPendiente,
                              compacta: false,
                              anchoCarta: destacarMiMano ? 76 : 68,
                              altoCarta: destacarMiMano ? 114 : 102,
                              colorPalo: _colorPalo,
                              iconoPalo: _iconoPalo,
                              seleccionados: _esperandoDescartarPar
                                  ? _seleccionPar
                                  : (_indiceCuloMoviendo != null
                                      ? [_indiceCuloMoviendo!]
                                      : (_indiceRobadaPorPc != null
                                          ? [_indiceRobadaPorPc!]
                                          : const [])),
                              atenuarNoSeleccionados:
                                  _indiceCuloMoviendo != null,
                              bloquearNoSeleccionados: false,
                              onReordenarCulo: (_puedoMoverCulo &&
                                      _ajustes.animaciones)
                                  ? _reordenarCuloEnMano
                                  : null,
                              onArrastrandoCulo: (_puedoMoverCulo &&
                                      _ajustes.animaciones)
                                  ? (indice) => setState(
                                        () => _indiceCuloMoviendo = indice,
                                      )
                                  : null,
                              onTapIndex: _esperandoDescartarPar
                                  ? (i) async => _tocarParTrasRobo(i)
                                  : ((!_ajustes.animaciones &&
                                          (_puedoMoverCulo ||
                                              _indiceCuloMoviendo != null))
                                      ? (i) async =>
                                          _tocarManoParaMoverCulo(i)
                                      : null),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    Expanded(
                      child: _ZonaParesDescartados(
                        descartes: yoTurno.descartes,
                        colorPalo: _colorPalo,
                        iconoPalo: _iconoPalo,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A0A33),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.violeta,
                            width: 1.6,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${TextosCuloSucioV2.tuMano}: ${manoAbajo.nombre}',
                                    style: const TextStyle(
                                      color: AppColors.mint,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (_puedoDescartarPares &&
                                    _opciones.eliminarParesAuto) ...[
                                  Material(
                                    color: Colors.transparent,
                                    shape: const CircleBorder(),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () {
                                        showDialog<void>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor:
                                                const Color(0xFF1A0A33),
                                            title: const Text(
                                              TextosCuloSucioV2
                                                  .eliminarParesAuto,
                                              style: TextStyle(
                                                color: AppColors.texto,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            content: const Text(
                                              TextosCuloSucioV2
                                                  .infoEliminarParesAuto,
                                              style: TextStyle(
                                                color: AppColors.textoSuave,
                                                height: 1.35,
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(),
                                                child: const Text('Entendido'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      customBorder: const CircleBorder(),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.info_outline_rounded,
                                          size: 18,
                                          color: AppColors.textoSuave,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: manoTieneParCuloSucioV2(
                                              manoAbajo.mano)
                                          ? _eliminarParesAutomaticamente
                                          : null,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2A1050),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: manoTieneParCuloSucioV2(
                                                    manoAbajo.mano)
                                                ? AppColors.acento
                                                : AppColors.cartaBorde,
                                            width: 1.4,
                                          ),
                                        ),
                                        child: Text(
                                          TextosCuloSucioV2.eliminarParesAuto,
                                          style: TextStyle(
                                            color: manoTieneParCuloSucioV2(
                                                    manoAbajo.mano)
                                                ? AppColors.acento
                                                : AppColors.textoSuave,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            _ManoDosFilas(
                              cartas: manoAbajo.mano,
                              colorPalo: _colorPalo,
                              iconoPalo: _iconoPalo,
                              seleccionados: _puedoDescartarPares
                                  ? _seleccionPar
                                  : const [],
                              onTapIndex: _puedoDescartarPares
                                  ? (i) async => _tocarCartaManoParaPar(i)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_puedoDescartarPares)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: manoTieneParCuloSucioV2(manoAbajo.mano)
                                ? null
                                : _confirmarParesListos,
                            child: const Text(TextosCuloSucioV2.listoPares),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (_cartaQueSeLlevaPc != null || _cartaQueTeSacaron != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _tituloOverlayRobo,
                            style: const TextStyle(
                              color: AppColors.rosa,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 14),
                          CartaEspanolaSkin(
                            numero: (_cartaQueTeSacaron ?? _cartaQueSeLlevaPc)!
                                .numero,
                            etiqueta:
                                (_cartaQueTeSacaron ?? _cartaQueSeLlevaPc)!
                                    .etiqueta,
                            palo: switch ((_cartaQueTeSacaron ??
                                    _cartaQueSeLlevaPc)!
                                .palo) {
                              PaloCuloSucioV2.oro => PaloEspanolVisual.oro,
                              PaloCuloSucioV2.copa => PaloEspanolVisual.copa,
                              PaloCuloSucioV2.espada =>
                                PaloEspanolVisual.espada,
                              PaloCuloSucioV2.basto => PaloEspanolVisual.basto,
                            },
                            seleccionada: true,
                            width: 92,
                            height: 138,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_esperandoDescartarPar) ...[
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.42),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${TextosCuloSucioV2.tuMano}: ${manoAbajo.nombre}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.mint,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: altoSlotMiMano,
                        width: double.infinity,
                        child: _FilaCartas(
                          cartas: manoAbajo.mano,
                          bocaArriba: true,
                          compacta: false,
                          anchoCarta: 76,
                          altoCarta: 114,
                          colorPalo: _colorPalo,
                          iconoPalo: _iconoPalo,
                          seleccionados: _seleccionPar,
                          atenuarNoSeleccionados: true,
                          bloquearNoSeleccionados: true,
                          onTapIndex: (i) async => _tocarParTrasRobo(i),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: IgnorePointer(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                        child: Material(
                          elevation: 16,
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0xF01A0A33),
                          shadowColor: Colors.black,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 340),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: colorSeleccionCartaEspanola
                                    .withValues(alpha: 0.85),
                                width: 1.2,
                              ),
                            ),
                            child: const Text(
                              TextosCuloSucioV2.notifPuedeEliminarPar,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.texto,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (_esLocalHotSeat &&
                _cambioJugadorPendiente &&
                !_partida.terminada)
              Positioned.fill(
                child: CambioJugadorOverlay(
                  nombreJugador: _partida.jugadorActual.nombre,
                  titulo: TextosCuloSucioV2.cambioDeJugador,
                  botonLabel: TextosCuloSucioV2.aceptarCambioJugador,
                  onAceptar: _aceptarCambioJugador,
                ),
              ),
            if (_mostrarAjustes)
              Positioned.fill(
                child: AjustesOverlay(
                  ajustes: _ajustes,
                  onChanged: (a) => setState(() {
                    final cambioAnim = a.animaciones != _ajustes.animaciones;
                    _ajustes = a;
                    if (cambioAnim) _indiceCuloMoviendo = null;
                  }),
                  onCerrar: () => setState(() => _mostrarAjustes = false),
                ),
              ),
            if (_mostrarMenu)
              Positioned.fill(
                child: MenuPartidaCuloSucioV2(
                  jugador: _esOnline
                      ? (widget.miNombre ?? _yo.nombre)
                      : (widget.contraPc
                          ? _yo.nombre
                          : _partida.jugadorActual.nombre),
                  partidaTerminada: _partida.terminada,
                  permitirRendirse: _esLocalHotSeat || _esOnline,
                  confirmarRendicion:
                      _confirmarRendicion && (_esLocalHotSeat || _esOnline),
                  onCerrar: () => setState(() {
                    _mostrarMenu = false;
                    _confirmarRendicion = false;
                  }),
                  onReglas: () {
                    setState(() {
                      _mostrarMenu = false;
                      _confirmarRendicion = false;
                    });
                    _mostrarDialogoReglas();
                  },
                  onSalirORendirse: _partida.terminada ||
                          !(_esLocalHotSeat || _esOnline)
                      ? () {
                          setState(() {
                            _mostrarMenu = false;
                            _confirmarRendicion = false;
                          });
                          _salirAlMenu(
                            guardar: !_esOnline &&
                                widget.contraPc &&
                                !_partida.terminada,
                          );
                        }
                      : () => setState(() => _confirmarRendicion = true),
                  onConfirmarRendicion: _rendirse,
                  onCancelarRendicion: () =>
                      setState(() => _confirmarRendicion = false),
                ),
              ),
            if (_partida.terminada)
              Positioned.fill(
                child: _debeMostrarVictoria
                    ? VictoriaCuloSucioV2Overlay(
                        partida: _partida,
                        onVolverAJugar: _reiniciar,
                        onVolver: () => _salirAlMenu(guardar: false),
                      )
                    : DerrotaCuloSucioV2Overlay(
                        partida: _partida,
                        onOtraVez: _reiniciar,
                        onVolver: () => _salirAlMenu(guardar: false),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChipJugador extends StatelessWidget {
  const _ChipJugador({
    required this.nombre,
    required this.cartas,
    required this.activo,
    required this.perdido,
    required this.ganado,
    this.rendido = false,
    this.puedeRenombrar = false,
    this.onRenombrar,
  });

  final String nombre;
  final int cartas;
  final bool activo;
  final bool perdido;
  final bool ganado;
  final bool rendido;
  final bool puedeRenombrar;
  final VoidCallback? onRenombrar;

  @override
  Widget build(BuildContext context) {
    final borde = perdido
        ? AppColors.peligro
        : ganado
            ? AppColors.mint
            : activo
                ? AppColors.acento
                : AppColors.cartaBorde;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.carta.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borde,
          width: activo || perdido || ganado ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          NombreJugadorEditable(
            nombre: nombre,
            puedeRenombrar: puedeRenombrar,
            onRenombrar: onRenombrar,
            fontSize: 13,
            tachado: rendido,
            colorTexto: perdido
                ? AppColors.peligro
                : ganado
                    ? AppColors.mint
                    : rendido
                        ? AppColors.textoSuave
                        : AppColors.texto,
          ),
          Text(
            rendido
                ? 'rendido'
                : '$cartas carta${cartas == 1 ? '' : 's'}',
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZonaParesDescartados extends StatelessWidget {
  const _ZonaParesDescartados({
    required this.descartes,
    required this.colorPalo,
    required this.iconoPalo,
  });

  final List<CartaCuloSucioV2> descartes;
  final Color Function(PaloCuloSucioV2) colorPalo;
  final IconData Function(PaloCuloSucioV2) iconoPalo;

  @override
  Widget build(BuildContext context) {
    final pares = descartes.length ~/ 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        children: [
          Text(
            '$pares par${pares == 1 ? '' : 'es'} descartado${pares == 1 ? '' : 's'}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: descartes.isEmpty
                ? const Center(
                    child: Text(
                      'Acá se van a ver los pares que saques',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textoSuave,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      const Text(
                        TextosCuloSucioV2.paresDescartados,
                        style: TextStyle(
                          color: AppColors.textoSuave,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Ocupar casi todo el alto del contenedor.
                            final alto = (constraints.maxHeight - 12)
                                .clamp(88.0, 150.0);
                            final ancho = alto * (68 / 102);
                            return _FilaCartas(
                              cartas: descartes,
                              bocaArriba: true,
                              compacta: false,
                              anchoCarta: ancho,
                              altoCarta: alto,
                              colorPalo: colorPalo,
                              iconoPalo: iconoPalo,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AvisoJugada extends StatelessWidget {
  const _AvisoJugada({
    required this.robada,
    required this.par,
  });

  final CartaCuloSucioV2? robada;
  final List<CartaCuloSucioV2>? par;

  @override
  Widget build(BuildContext context) {
    final texto = par != null && par!.length >= 2
        ? '¡Par! ${par![0].etiqueta} + ${par![1].etiqueta}'
        : (robada == null
            ? ''
            : 'Robó: ${robada!.etiqueta}');
    if (texto.isEmpty) return const SizedBox.shrink();
    final color = par != null
        ? AppColors.mint
        : (robada?.esCuloSucio == true
            ? AppColors.peligro
            : AppColors.acento);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.carta.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ManoDosFilas extends StatelessWidget {
  const _ManoDosFilas({
    required this.cartas,
    required this.colorPalo,
    required this.iconoPalo,
    this.onTapIndex,
    this.seleccionados = const [],
  });

  final List<CartaCuloSucioV2> cartas;
  final Color Function(PaloCuloSucioV2) colorPalo;
  final IconData Function(PaloCuloSucioV2) iconoPalo;
  final Future<void> Function(int index)? onTapIndex;
  final List<int> seleccionados;

  @override
  Widget build(BuildContext context) {
    if (cartas.isEmpty) {
      return const Center(
        child: Text('—', style: TextStyle(color: AppColors.textoSuave)),
      );
    }
    final mitad = (cartas.length + 1) ~/ 2;
    final fila1 = cartas.sublist(0, mitad);
    final fila2 = cartas.sublist(mitad);
    Widget fila({
      required List<CartaCuloSucioV2> cards,
      required int base,
    }) {
      return _FilaCartas(
        cartas: cards,
        bocaArriba: true,
        colorPalo: colorPalo,
        iconoPalo: iconoPalo,
        seleccionados: seleccionados,
        indiceBase: base,
        onTapIndex: onTapIndex,
      );
    }

    if (fila2.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          height: 124,
          child: fila(cards: fila1, base: 0),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 124, child: fila(cards: fila1, base: 0)),
          const SizedBox(height: 8),
          SizedBox(height: 124, child: fila(cards: fila2, base: mitad)),
        ],
      ),
    );
  }
}

class _FilaCartas extends StatefulWidget {
  const _FilaCartas({
    required this.cartas,
    required this.bocaArriba,
    required this.colorPalo,
    required this.iconoPalo,
    this.onTapIndex,
    this.compacta = false,
    this.seleccionados = const [],
    this.atenuarNoSeleccionados = false,
    this.bloquearNoSeleccionados = false,
    this.indiceBase = 0,
    this.indiceRevelado,
    this.anchoCarta,
    this.altoCarta,
    this.onReordenarCulo,
    this.onArrastrandoCulo,
  });

  final List<CartaCuloSucioV2> cartas;
  final bool bocaArriba;
  final Color Function(PaloCuloSucioV2) colorPalo;
  final IconData Function(PaloCuloSucioV2) iconoPalo;
  final Future<void> Function(int index)? onTapIndex;
  final bool compacta;
  final List<int> seleccionados;
  /// Si true, las cartas no seleccionadas quedan semitransparentes.
  final bool atenuarNoSeleccionados;
  /// Si true, no se pueden tocar las no seleccionadas (p. ej. confirmar par).
  final bool bloquearNoSeleccionados;
  /// Índice real de la primera carta de esta fila (para manos partidas).
  final int indiceBase;
  /// Carta que se está revelando (boca arriba) antes de robarla.
  final int? indiceRevelado;
  /// Tamaño custom (p. ej. pares descartados). Si null, usa compacta / normal.
  final double? anchoCarta;
  final double? altoCarta;
  /// Si no es null, el 1 de oro se puede arrastrar para reordenar.
  final void Function(int desde, int hacia)? onReordenarCulo;
  /// Notifica el índice del 1 de oro mientras se arrastra (null al soltar).
  final void Function(int? indice)? onArrastrandoCulo;

  @override
  State<_FilaCartas> createState() => _FilaCartasState();
}

class _FilaCartasState extends State<_FilaCartas> {
  final _scroll = ScrollController();
  final _rowKey = GlobalKey();
  bool _hayIzquierda = false;
  bool _hayDerecha = false;

  int? _dragCuloIndex;
  int? _insertCuloIndex;
  double _dragDx = 0;
  double _dragDy = 0;
  /// Punto X local donde se agarró la carta (para no saltar si tocás la derecha).
  double _grabLocalX = 0;

  double get _anchoCarta =>
      widget.anchoCarta ?? (widget.compacta ? 40.0 : 68.0);
  double get _altoCarta =>
      widget.altoCarta ?? (widget.compacta ? 56.0 : 102.0);
  double get _gap => widget.compacta ? 4.0 : 6.0;
  double get _pasoScroll => _anchoCarta + _gap;
  static const double _deslizamiento = 14;
  bool get _arrastrandoCulo => _dragCuloIndex != null;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_actualizarFlechas);
    WidgetsBinding.instance.addPostFrameCallback((_) => _actualizarFlechas());
  }

  @override
  void didUpdateWidget(covariant _FilaCartas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cartas.length != widget.cartas.length ||
        oldWidget.compacta != widget.compacta ||
        oldWidget.anchoCarta != widget.anchoCarta ||
        oldWidget.altoCarta != widget.altoCarta) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _actualizarFlechas());
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_actualizarFlechas);
    _scroll.dispose();
    super.dispose();
  }

  void _actualizarFlechas() {
    if (!mounted || !_scroll.hasClients) return;
    final pos = _scroll.position;
    final viewW = pos.viewportDimension;
    if (viewW <= 0) return;
    final n = widget.cartas.length;
    final padH = widget.compacta ? 56.0 : 68.0;
    final contenido = n == 0
        ? 0.0
        : n * _anchoCarta + (n - 1) * _gap + padH;
    // Flechas solo si las cartas no entran en el ancho visible.
    final desborda = contenido > viewW + 8;
    final izq = desborda && pos.pixels > 2;
    final der =
        desborda && pos.pixels < pos.maxScrollExtent - 2;
    if (izq != _hayIzquierda || der != _hayDerecha) {
      setState(() {
        _hayIzquierda = izq;
        _hayDerecha = der;
      });
    }
  }

  void _desplazar(double delta) {
    if (!_scroll.hasClients) return;
    final destino =
        (_scroll.offset + delta).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      destino,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  double _shiftXParaIndice(int index) {
    final from = _dragCuloIndex;
    final to = _insertCuloIndex;
    if (from == null || to == null || from == to) return 0;
    final paso = _pasoScroll;
    if (from < to) {
      // Mueve a la derecha: las cartas (from, to] corren a la izquierda.
      if (index > from && index <= to) return -paso;
    } else {
      // Mueve a la izquierda: las cartas [to, from) corren a la derecha.
      if (index >= to && index < from) return paso;
    }
    return 0;
  }

  int _indiceInsercionDesdeGlobal(double globalX) {
    final box = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return _dragCuloIndex ?? 0;
    // Referencia = borde izquierdo de la carta, no el dedo/cursor.
    final localX =
        box.globalToLocal(Offset(globalX - _grabLocalX, 0)).dx;
    final n = widget.cartas.length;
    if (n <= 0) return 0;
    final paso = _pasoScroll;
    final w = _anchoCarta;
    // Las cartas están centradas en el Row (no pegadas a la izquierda).
    final contenido = n * w + (n - 1) * _gap;
    final origen = math.max(0.0, (box.size.width - contenido) / 2);
    var idx = 0;
    for (var i = 0; i < n; i++) {
      final mid = origen + i * paso + w / 2;
      if (localX < mid) {
        idx = i;
        break;
      }
      idx = i;
    }
    return idx.clamp(0, n - 1);
  }

  void _autoScrollDuranteDrag(double globalX) {
    if (!_scroll.hasClients) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(Offset(globalX, 0)).dx;
    const margen = 40.0;
    final ancho = box.size.width;
    double delta = 0;
    if (local < margen) {
      delta = -10;
    } else if (local > ancho - margen) {
      delta = 10;
    }
    if (delta == 0) return;
    final destino = (_scroll.offset + delta)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.jumpTo(destino);
  }

  void _iniciarDragCulo(int index, Offset localPosition) {
    // Primero marcar selección: misma subida lenta que el modo sin arrastre.
    widget.onArrastrandoCulo?.call(widget.indiceBase + index);
    setState(() {
      _dragCuloIndex = index;
      _insertCuloIndex = index;
      _dragDx = 0;
      _dragDy = 0;
      _grabLocalX = localPosition.dx.clamp(0.0, _anchoCarta);
    });
  }

  void _actualizarDragCulo(DragUpdateDetails details) {
    if (_dragCuloIndex == null) return;
    final nuevo = _indiceInsercionDesdeGlobal(details.globalPosition.dx);
    _autoScrollDuranteDrag(details.globalPosition.dx);
    setState(() {
      _dragDx += details.delta.dx;
      _dragDy = (_dragDy + details.delta.dy).clamp(0.0, 16.0);
      if (nuevo != _insertCuloIndex) {
        _insertCuloIndex = nuevo;
      }
    });
  }

  void _soltarDragCulo() {
    final from = _dragCuloIndex;
    final to = _insertCuloIndex;
    _dragCuloIndex = null;
    _insertCuloIndex = null;
    _dragDx = 0;
    _dragDy = 0;
    _grabLocalX = 0;
    widget.onArrastrandoCulo?.call(null);
    if (from != null && to != null && from != to) {
      widget.onReordenarCulo?.call(
        widget.indiceBase + from,
        widget.indiceBase + to,
      );
    } else if (mounted) {
      setState(() {});
    }
  }

  void _cancelarDragCulo() {
    setState(() {
      _dragCuloIndex = null;
      _insertCuloIndex = null;
      _dragDx = 0;
      _dragDy = 0;
      _grabLocalX = 0;
    });
    widget.onArrastrandoCulo?.call(null);
  }

  Widget _flecha({
    required bool izquierda,
    required bool visible,
  }) {
    if (!visible) return const SizedBox.shrink();
    return Material(
      color: AppColors.carta.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _desplazar(izquierda ? -_pasoScroll : _pasoScroll),
        child: Padding(
          padding: EdgeInsets.all(widget.compacta ? 4 : 6),
          child: Icon(
            izquierda
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            color: AppColors.acento,
            size: widget.compacta ? 22 : 28,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cartas.isEmpty) {
      return const Center(
        child: Text(
          '—',
          style: TextStyle(color: AppColors.textoSuave),
        ),
      );
    }
    final w = _anchoCarta;
    final h = _altoCarta;

    return LayoutBuilder(
      builder: (context, constraints) {
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
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.hardEdge,
            children: [
              NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  _actualizarFlechas();
                  return false;
                },
                child: Listener(
                  onPointerSignal: (signal) {
                    if (signal is! PointerScrollEvent) return;
                    if (!_scroll.hasClients) return;
                    // Rueda vertical → desplazamiento horizontal de la mano.
                    final delta = signal.scrollDelta.dx.abs() >
                            signal.scrollDelta.dy.abs()
                        ? signal.scrollDelta.dx
                        : signal.scrollDelta.dy;
                    if (delta == 0) return;
                    final destino = (_scroll.offset + delta).clamp(
                      0.0,
                      _scroll.position.maxScrollExtent,
                    );
                    _scroll.jumpTo(destino);
                  },
                  child: ScrollConfiguration(
                    behavior: const _ManoScrollBehaviorV2(),
                    child: SingleChildScrollView(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      physics: (widget.onReordenarCulo != null ||
                              _arrastrandoCulo)
                          ? const NeverScrollableScrollPhysics()
                          : const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.compacta ? 28 : 34,
                        vertical: 4,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: math.max(
                            0,
                            constraints.maxWidth -
                                (widget.compacta ? 56 : 68),
                          ),
                        ),
                        child: Row(
                          key: _rowKey,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var index = 0;
                                index < widget.cartas.length;
                                index++) ...[
                              if (index > 0) SizedBox(width: _gap),
                              Builder(
                                builder: (context) {
                                  final c = widget.cartas[index];
                                  final indiceReal =
                                      widget.indiceBase + index;
                                  final color = widget.colorPalo(c.palo);
                                  final seleccionada = widget.seleccionados
                                      .contains(indiceReal);
                                  final visible = widget.bocaArriba ||
                                      widget.indiceRevelado == indiceReal;
                                  final esCuloArrastrable =
                                      widget.onReordenarCulo != null &&
                                          c.esCuloSucio &&
                                          visible;
                                  final esLaQueArrastro =
                                      _dragCuloIndex == index;
                                  final card = AnimatedSwitcher(
                                    duration:
                                        const Duration(milliseconds: 320),
                                    switchInCurve: Curves.easeOut,
                                    switchOutCurve: Curves.easeIn,
                                    transitionBuilder: (child, animation) {
                                      return AnimatedBuilder(
                                        animation: animation,
                                        child: child,
                                        builder: (context, child) {
                                          final angle =
                                              (1 - animation.value) * 1.5708;
                                          return Transform(
                                            alignment: Alignment.center,
                                            transform: Matrix4.identity()
                                              ..setEntry(3, 2, 0.0015)
                                              ..rotateY(angle),
                                            child: child,
                                          );
                                        },
                                      );
                                    },
                                    child: _CartaSkinV2(
                                      key: ValueKey<String>(
                                        visible
                                            ? '${indiceReal}_up'
                                            : '${indiceReal}_down',
                                      ),
                                      carta: c,
                                      bocaArriba: visible,
                                      compacta: widget.compacta,
                                      seleccionada: seleccionada ||
                                          widget.indiceRevelado ==
                                              indiceReal,
                                      color: color,
                                      icono: widget.iconoPalo(c.palo),
                                      width: w,
                                      height: h,
                                    ),
                                  );
                                  final marcada = seleccionada ||
                                      widget.indiceRevelado == indiceReal;
                                  final atenuar = (widget
                                              .atenuarNoSeleccionados &&
                                          widget.seleccionados.isNotEmpty &&
                                          !seleccionada) ||
                                      (_arrastrandoCulo && !esLaQueArrastro);
                                  // Slot fijo: al seleccionar sube sin achicarse.
                                  Widget child = AnimatedOpacity(
                                    duration:
                                        const Duration(milliseconds: 180),
                                    opacity: atenuar ? 0.34 : 1,
                                    child: SizedBox(
                                      width: w,
                                      height: h + _deslizamiento,
                                      child: AnimatedAlign(
                                        duration: const Duration(
                                          milliseconds: 380,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        alignment: marcada
                                            ? Alignment.topCenter
                                            : Alignment.bottomCenter,
                                        child: card,
                                      ),
                                    ),
                                  );

                                  final shift = _shiftXParaIndice(index);
                                  if (_arrastrandoCulo && !esLaQueArrastro) {
                                    child = AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      transform: Matrix4.translationValues(
                                        shift,
                                        0,
                                        0,
                                      ),
                                      child: child,
                                    );
                                  }

                                  // Árbol estable para el 1 de oro: si el
                                  // Material se agrega al agarrar, AnimatedAlign
                                  // se reinicia y la carta “teletransporta”.
                                  if (esCuloArrastrable) {
                                    child = Transform.translate(
                                      offset: Offset(
                                        esLaQueArrastro ? _dragDx : 0,
                                        esLaQueArrastro ? _dragDy : 0,
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        elevation: esLaQueArrastro ? 10 : 0,
                                        shadowColor: Colors.black54,
                                        borderRadius: BorderRadius.circular(
                                          widget.compacta ? 10 : 14,
                                        ),
                                        child: child,
                                      ),
                                    );
                                    return GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onPanStart: (details) =>
                                          _iniciarDragCulo(
                                        index,
                                        details.localPosition,
                                      ),
                                      onPanUpdate: _actualizarDragCulo,
                                      onPanEnd: (_) => _soltarDragCulo(),
                                      onPanCancel: _cancelarDragCulo,
                                      child: child,
                                    );
                                  }

                                  if (widget.onTapIndex == null) {
                                    return child;
                                  }
                                  if (widget.bloquearNoSeleccionados &&
                                      widget.seleccionados.isNotEmpty &&
                                      !seleccionada) {
                                    return IgnorePointer(child: child);
                                  }
                                  // Sin hover visible si no está seleccionada;
                                  // InkWell transparente para que el tap
                                  // funcione bien dentro del scroll.
                                  if (!seleccionada) {
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () =>
                                            widget.onTapIndex!(indiceReal),
                                        splashColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        overlayColor:
                                            const WidgetStatePropertyAll(
                                          Colors.transparent,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          widget.compacta ? 10 : 14,
                                        ),
                                        child: child,
                                      ),
                                    );
                                  }
                                  return Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(
                                      widget.compacta ? 10 : 14,
                                    ),
                                    child: InkWell(
                                      onTap: () =>
                                          widget.onTapIndex!(indiceReal),
                                      borderRadius: BorderRadius.circular(
                                        widget.compacta ? 10 : 14,
                                      ),
                                      splashColor:
                                          colorSeleccionCartaEspanola
                                              .withValues(alpha: 0.25),
                                      highlightColor:
                                          colorSeleccionCartaEspanola
                                              .withValues(alpha: 0.18),
                                      hoverColor: colorSeleccionCartaEspanola
                                          .withValues(alpha: 0.22),
                                      child: child,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 2,
                child: _flecha(izquierda: true, visible: _hayIzquierda),
              ),
              Positioned(
                right: 2,
                child: _flecha(izquierda: false, visible: _hayDerecha),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Misma skin visual compartida (CartaEspanolaSkin).
class _CartaSkinV2 extends StatelessWidget {
  const _CartaSkinV2({
    super.key,
    required this.carta,
    required this.bocaArriba,
    required this.compacta,
    required this.seleccionada,
    required this.color,
    required this.icono,
    required this.width,
    required this.height,
  });

  final CartaCuloSucioV2 carta;
  final bool bocaArriba;
  final bool compacta;
  final bool seleccionada;
  final Color color;
  final IconData icono;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CartaEspanolaSkin(
      numero: carta.numero,
      etiqueta: carta.etiqueta,
      palo: switch (carta.palo) {
        PaloCuloSucioV2.oro => PaloEspanolVisual.oro,
        PaloCuloSucioV2.copa => PaloEspanolVisual.copa,
        PaloCuloSucioV2.espada => PaloEspanolVisual.espada,
        PaloCuloSucioV2.basto => PaloEspanolVisual.basto,
      },
      seleccionada: seleccionada,
      compacta: compacta,
      bocaArriba: bocaArriba,
      resaltarPeligro: carta.esCuloSucio,
      width: width,
      height: height,
    );
  }
}

/// Permite arrastrar la mano con dedo, mouse, stylus y trackpad.
class _ManoScrollBehaviorV2 extends MaterialScrollBehavior {
  const _ManoScrollBehaviorV2();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}
