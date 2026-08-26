import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_juegos_mesa/laPapa/la_papa_online_codec.dart';
import 'package:app_juegos_mesa/laPapa/motor_la_papa.dart';
import 'package:app_juegos_mesa/laPapa/opciones_la_papa.dart';
import 'package:app_juegos_mesa/laPapa/standby_store.dart';
import 'package:app_juegos_mesa/laPapa/textos.dart';
import 'package:app_juegos_mesa/laPapa/victoria_la_papa_overlay.dart';
import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/monedas/monedas_store.dart';
import 'package:app_juegos_mesa/shared/monedas/premiar_monedas_victoria_pc.dart';
import 'package:app_juegos_mesa/shared/partida_ui/epic_backdrop.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

class PartidaLaPapaScreen extends StatefulWidget {
  const PartidaLaPapaScreen({
    super.key,
    required this.nombres,
    this.solo = false,
    this.opciones = const OpcionesPapa(),
    this.ajustesIniciales = const AjustesEstado(),
    this.resume,
    this.salaCodigo,
    this.miNombre,
  });

  final List<String> nombres;
  final bool solo;
  final OpcionesPapa opciones;
  final AjustesEstado ajustesIniciales;
  final PartidaPapaResume? resume;
  final String? salaCodigo;
  final String? miNombre;

  @override
  State<PartidaLaPapaScreen> createState() => _PartidaLaPapaScreenState();
}

class _PartidaLaPapaScreenState extends State<PartidaLaPapaScreen> {
  late PartidaPapa _partida;
  late List<String> _nombres;
  late AjustesEstado _ajustes;
  late OpcionesPapa _opciones;
  final List<Offset> _trazoActual = [];
  /// Trazo con el que se perdió (o el último fallo con vidas).
  final List<Offset> _trazoFallido = [];
  /// Puentes (X) de la partida, en coords normalizadas 0..1.
  final List<Offset> _puentesNorm = [];
  final GlobalKey _hojaKey = GlobalKey();
  /// Posición de la lupa sin forzar rebuild de toda la pantalla.
  final ValueNotifier<Offset?> _lupaPunto = ValueNotifier<Offset?>(null);
  /// Índice entre las 4 esquinas relativas al dedo (ver [_LupaTrazoPapa.posiciones]).
  int _lupaPosicionIdx = 0;
  double _lupaDx = _LupaTrazoPapa.posiciones.first.dx;
  double _lupaDy = _LupaTrazoPapa.posiciones.first.dy;
  bool _dibujando = false;
  bool _inicioValido = false;
  bool _salioDelInicio = false;
  /// Solo este pointer alimenta el trazo (evita que el dedo del botón de lupa mate).
  int? _pointerDibujoId;
  Size? _boardSize;
  String? _avisoVida;
  String? _avisoGrosor;
  Timer? _avisoGrosorTimer;
  GrosorTrazoPapa _grosor = GrosorTrazoPapa.normal;
  bool _mostrarMenu = false;
  bool _mostrarAjustes = false;
  bool _confirmarRendicion = false;
  static const int _maxNombre = 15;

  /// Ciclo al tocar “Trazos” mientras dibujás: grueso → fino → normal → …
  static const _cicloGrosorAlDibujar = <GrosorTrazoPapa>[
    GrosorTrazoPapa.grueso,
    GrosorTrazoPapa.fino,
    GrosorTrazoPapa.normal,
  ];

  StreamSubscription<Sala>? _onlineSub;
  int _onlineVersion = 0;
  bool _publicandoOnline = false;
  bool _tableroPublicado = false;
  bool _esperandoTableroOnline = false;

  bool get _esOnline =>
      widget.salaCodigo != null &&
      widget.salaCodigo!.isNotEmpty &&
      widget.miNombre != null &&
      widget.miNombre!.isNotEmpty;

  bool get _esMiTurno {
    if (_partida.estaRendido(_partida.jugadorActual) && !widget.solo) {
      return false;
    }
    if (!_esOnline) return true;
    final yo = widget.miNombre;
    if (yo == null || _partida.estaRendido(yo)) return false;
    return _partida.jugadorActual == yo;
  }

  bool get _soyAnfitrionOnline =>
      _esOnline &&
      _partida.nombres.isNotEmpty &&
      _partida.nombres.first == widget.miNombre;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onTeclaAtajos);
    final resume = widget.resume;
    if (resume != null) {
      _nombres = List.of(resume.nombres);
      _ajustes = resume.ajustesIniciales;
      _opciones = resume.opciones;
      _partida = resume.partida;
      _grosor = resume.opciones.modificarGrosorTrazoEfectivo
          ? resume.grosor
          : GrosorTrazoPapa.normal;
      _boardSize = resume.boardSize;
      _trazoFallido
        ..clear()
        ..addAll(resume.trazoFallido);
      return;
    }

    _nombres = List.of(widget.nombres);
    _ajustes = widget.ajustesIniciales;
    _opciones = widget.opciones;
    if (!_opciones.modificarGrosorTrazoEfectivo) {
      _grosor = GrosorTrazoPapa.normal;
    }
    if (_esOnline) {
      // Placeholder hasta recibir / publicar el tablero compartido.
      _esperandoTableroOnline = true;
      _partida = nuevaPartidaPapa(
        nombres: _nombres,
        opciones: _opciones,
      );
      // Vaciar casillas hasta sync (evita jugar con hoja local distinta).
      for (var i = 0; i < _partida.casillas.length; i++) {
        _partida.casillas[i] = null;
      }
      _iniciarSincronizacionOnline();
      return;
    }

    _partida = nuevaPartidaPapa(
      nombres: _nombres,
      opciones: _opciones,
    );
  }

  bool get _esCelularPlatform {
    final p = defaultTargetPlatform;
    return p == TargetPlatform.android || p == TargetPlatform.iOS;
  }

  bool _onTeclaAtajos(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!mounted) return false;
    if (_mostrarMenu || _mostrarAjustes) return false;
    if (_partida.fase != FasePapa.jugando || _partida.terminada) return false;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.keyT) {
      // Atajo de grosor solo en PC / escritorio.
      if (_esCelularPlatform) return false;
      if (!_opciones.modificarGrosorTrazoEfectivo) return false;
      _ciclarGrosor();
      return true;
    }
    if (key == LogicalKeyboardKey.keyL) {
      if (!_opciones.mostrarLupaEfectiva) return false;
      _rotarPosicionLupa();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onTeclaAtajos);
    _avisoGrosorTimer?.cancel();
    _onlineSub?.cancel();
    _lupaPunto.dispose();
    super.dispose();
  }

  void _ciclarGrosor() {
    if (!_opciones.modificarGrosorTrazoEfectivo) return;
    final i = _cicloGrosorAlDibujar.indexOf(_grosor);
    final next = _cicloGrosorAlDibujar[(i + 1) % _cicloGrosorAlDibujar.length];
    _avisoGrosorTimer?.cancel();
    setState(() {
      _grosor = next;
      _avisoGrosor = 'Grosor: ${next.etiqueta}';
    });
    _avisoGrosorTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() => _avisoGrosor = null);
    });
  }

  void _onTrazosPressed() {
    if (!_opciones.modificarGrosorTrazoEfectivo) return;
    if (_dibujando) {
      _ciclarGrosor();
    } else {
      _abrirSelectorTrazos();
    }
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
    if (gameState['juego']?.toString() != 'laPapa') return;
    final version = (gameState['version'] as num?)?.toInt() ?? 0;
    if (version < _onlineVersion) return;
    if (_publicandoOnline && version <= _onlineVersion) return;

    final tieneTablero = papaTableroGenerado(gameState);
    if (!tieneTablero) {
      if (_soyAnfitrionOnline &&
          !_tableroPublicado &&
          _boardSize != null) {
        unawaited(_publicarTableroInicialOnline());
      }
      return;
    }

    if (version <= _onlineVersion && !_esperandoTableroOnline) return;

    final board = _boardSize ?? const Size(400, 800);
    setState(() {
      final optsMap = gameState['opciones'];
      if (optsMap is Map) {
        _opciones = decodePapaOpciones(Map<String, dynamic>.from(optsMap));
      }
      applyPapaGameState(
        _partida,
        gameState,
        boardSize: board,
        trazoFallidoOut: _trazoFallido,
      );
      _nombres = List.of(_partida.nombres);
      _onlineVersion = version;
      _esperandoTableroOnline = false;
      _tableroPublicado = true;
      if (!_esMiTurno) {
        _limpiarTrazo();
      }
    });
  }

  Future<void> _publicarTableroInicialOnline() async {
    if (!_esOnline || _tableroPublicado || _publicandoOnline) return;
    final generada = nuevaPartidaPapa(
      nombres: _nombres,
      opciones: _opciones,
    );
    setState(() {
      _partida = generada;
      _esperandoTableroOnline = false;
      _tableroPublicado = true;
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
        final board = _boardSize ?? const Size(400, 800);
        final gameState = encodePapaGameState(
          partida: _partida,
          version: _onlineVersion,
          opciones: _opciones,
          boardSize: board,
          trazoFallido: _trazoFallido,
        );
        try {
          final res = await SalaService.instance.actualizarJuego(
            codigo: codigo,
            gameState: gameState,
          );
          if (!res.ignored) {
            final v =
                (res.sala.gameState?['version'] as num?)?.toInt() ??
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

  void _reiniciar() {
    if (_esOnline) return;
    if (widget.solo) PapaStandByStore.limpiar();
    setState(() {
      _partida = nuevaPartidaPapa(
        nombres: _nombres,
        opciones: _opciones,
      );
      _trazoActual.clear();
      _trazoFallido.clear();
      _puentesNorm.clear();
      _dibujando = false;
      _inicioValido = false;
      _salioDelInicio = false;
      _lupaPunto.value = null;
      _avisoVida = null;
      _mostrarMenu = false;
      _mostrarAjustes = false;
      _confirmarRendicion = false;
      _aplicarPosicionLupa();
    });
  }

  void _limpiarTrazo() {
    _trazoActual.clear();
    _dibujando = false;
    _inicioValido = false;
    _salioDelInicio = false;
    _pointerDibujoId = null;
    _lupaPunto.value = null;
    _aplicarPosicionLupa();
  }

  List<Offset> _puentesEnHoja(Size boardSize) =>
      desnormalizarPuntosPapa(_puentesNorm, boardSize);

  void _agregarPuenteNorm(Offset contacto, Size boardSize) {
    final w = boardSize.width <= 1e-6 ? 1.0 : boardSize.width;
    final h = boardSize.height <= 1e-6 ? 1.0 : boardSize.height;
    _puentesNorm.add(
      Offset(
        (contacto.dx / w).clamp(0.0, 1.0),
        (contacto.dy / h).clamp(0.0, 1.0),
      ),
    );
  }

  /// Coloca un puente, resta una vida y deja seguir el trazo si quedan vidas.
  /// Devuelve true si hay que cortar (sin vidas / partida terminada).
  bool _colocarPuenteYRestarVida(Offset contacto, Size boardSize) {
    _agregarPuenteNorm(contacto, boardSize);
    final quien = _partida.jugadorActual;
    final termino = registrarFalloPapa(
      _partida,
      motivo: '$quien se quedó sin vidas al hacer un puente.',
    );
    if (termino || _partida.estaRendido(quien)) {
      _trazoFallido
        ..clear()
        ..addAll(normalizarPuntosPapa(_trazoActual, boardSize));
      _limpiarTrazo();
      if (!termino && _partida.estaRendido(quien)) {
        _avisoVida = '$quien quedó fuera · sigue la partida';
      } else {
        _avisoVida = null;
      }
      unawaited(_publicarEstadoOnline(forzar: true));
      return true;
    }
    final quedan = _partida.vidasDelActual() ?? 0;
    _avisoVida = '$quien hizo un puente · quedan $quedan';
    unawaited(_publicarEstadoOnline(forzar: true));
    return false;
  }

  /// Pasa por X existentes; cada X nueva resta una vida y puede seguir.
  /// Devuelve true si hay que cortar el trazo.
  bool _resolverChoquesConPuentes(
    Iterable<Offset?> contactos,
    Size boardSize,
  ) {
    final radio = radioPuentePapa(boardSize, _grosor);
    for (final c in contactos) {
      if (c == null) continue;
      if (cercaDePuentePapa(c, _puentesEnHoja(boardSize), radio)) continue;
      return _colocarPuenteYRestarVida(c, boardSize);
    }
    return false;
  }

  void _aplicarPosicionLupa() {
    final o = _LupaTrazoPapa.posiciones[
        _lupaPosicionIdx % _LupaTrazoPapa.posiciones.length];
    _lupaDx = o.dx;
    _lupaDy = o.dy;
  }

  void _rotarPosicionLupa() {
    // Solo cambia el offset visual: no toca el trazo ni evalúa choques.
    setState(() {
      _lupaPosicionIdx =
          (_lupaPosicionIdx + 1) % _LupaTrazoPapa.posiciones.length;
      _aplicarPosicionLupa();
    });
  }

  /// Usa la esquina elegida por el jugador (tecla L / botón).
  void _fijarLadoLupa(Offset local, Size boardSize) {
    _aplicarPosicionLupa();
  }

  void _actualizarLupa(Offset local) {
    if (!_opciones.mostrarLupaEfectiva) return;
    _lupaPunto.value = local;
  }

  Size _sincronizarTamanoHoja(Size boardSize) {
    // Con la partida terminada no reescalar: los píxeles del freehand
    // (p. ej. trazo de error) deben coincidir con boardSizeTrazo del overlay.
    if (_partida.terminada) {
      return _boardSize ?? boardSize;
    }
    final prev = _boardSize;
    if (prev != null &&
        ((prev.width - boardSize.width).abs() > 0.5 ||
            (prev.height - boardSize.height).abs() > 0.5)) {
      reescalarTrazosPapa(_partida, prev, boardSize);
      reescalarPuntosPapa(_trazoActual, prev, boardSize);
      reescalarPuntosPapa(_trazoFallido, prev, boardSize);
    }
    _boardSize = boardSize;
    if (_esOnline &&
        _soyAnfitrionOnline &&
        !_tableroPublicado &&
        _esperandoTableroOnline) {
      unawaited(_publicarTableroInicialOnline());
    }
    return boardSize;
  }

  bool _dentroHoja(Offset local, Size boardSize) {
    return local.dx >= 0 &&
        local.dy >= 0 &&
        local.dx <= boardSize.width &&
        local.dy <= boardSize.height;
  }

  Offset? _localEnHoja(Offset global) {
    final box = _hojaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return box.globalToLocal(global);
  }

  void _fallar(String motivo) {
    final board = _boardSize;
    final quien = _partida.jugadorActual;
    _trazoFallido
      ..clear()
      ..addAll(
        board == null
            ? _trazoActual
            : normalizarPuntosPapa(_trazoActual, board),
      );
    final termino = registrarFalloPapa(_partida, motivo: motivo);
    _limpiarTrazo();
    if (!termino) {
      if (_partida.estaRendido(quien)) {
        _avisoVida = '$quien quedó fuera · sigue la partida';
      } else {
        final quedan = _partida.vidasDelActual() ?? 0;
        _avisoVida =
            '$quien perdió una vida · quedan $quedan';
      }
    } else {
      _avisoVida = null;
    }
    unawaited(_publicarEstadoOnline(forzar: true));
  }

  void _onTapColocar(Offset local, Size boardSize) {
    if (_partida.fase != FasePapa.colocando) return;
    if (!_esMiTurno) return;
    for (var i = 0; i < totalCasillasPapa; i++) {
      if (rectCasillaPapa(i, boardSize).contains(local)) {
        final err = colocarNumeroEnCasillaPapa(
          _partida,
          i,
          excepcionGeneracion: _opciones.excepcionGeneracionNumeros,
        );
        setState(() {
          _avisoVida = err;
        });
        if (err == null) unawaited(_publicarEstadoOnline(forzar: true));
        return;
      }
    }
  }

  void _onPointerDown(Offset local, Size boardSize, int pointerId) {
    if (_mostrarMenu || _mostrarAjustes) return;
    if (_esperandoTableroOnline) return;
    if (_partida.fase == FasePapa.colocando) {
      _onTapColocar(local, boardSize);
      return;
    }
    if (_partida.terminada || _partida.fase != FasePapa.jugando) return;
    if (!_esMiTurno) return;
    // Ya hay un dedo dibujando: ignorar otros (p. ej. tocar “Mover lupa”).
    if (_dibujando) return;
    if (!_dentroHoja(local, boardSize)) return;
    final de = _partida.siguienteConectar;
    if (!cercaDeNumeroPapa(_partida, de, local, boardSize)) {
      return;
    }
    // Solo se puede empezar desde la zona habilitada (círculo achicado).
    if (!puntoEnZonaHabilitadaPapa(
      _partida,
      de,
      local,
      boardSize,
      grosorActual: _grosor,
    )) {
      return;
    }
    setState(() {
      _boardSize = boardSize;
      _dibujando = true;
      _inicioValido = true;
      _salioDelInicio = false;
      _pointerDibujoId = pointerId;
      _avisoVida = null;
      _trazoFallido.clear();
      _trazoActual
        ..clear()
        ..add(local);
    });
    _fijarLadoLupa(local, boardSize);
    _actualizarLupa(local);
  }

  void _onPointerMoveGlobal(Offset global, int pointerId) {
    if (_mostrarMenu || _mostrarAjustes) return;
    if (_partida.fase != FasePapa.jugando) return;
    if (!_dibujando || !_inicioValido || _partida.terminada) return;
    // Ignorar moves de otros dedos (botón lupa, etc.).
    if (_pointerDibujoId != null && pointerId != _pointerDibujoId) return;
    final boardSize = _boardSize;
    if (boardSize == null) return;
    final local = _localEnHoja(global);
    if (local == null) return;

    if (!_dentroHoja(local, boardSize)) {
      setState(() {
        _fallar(
          '${_partida.jugadorActual} se salió de la hoja. Fin de la partida.',
        );
      });
      return;
    }

    _actualizarLupa(local);

    if (_trazoActual.isNotEmpty) {
      final dist = (_trazoActual.last - local).distance;
      if (dist < 2.5) return;
      // Salto grande: no agregar el punto (evita “línea fantasma”); solo
      // comprobar choque del segmento si el dedo de dibujo realmente saltó.
      final cell = math.min(
        boardSize.width / columnasPapa,
        boardSize.height / filasPapa,
      );
      if (dist > math.max(72.0, cell * 1.35)) {
        final salto = [..._trazoActual, local];
        if (_opciones.puentesEfectivos) {
          final radio = radioPuentePapa(boardSize, _grosor);
          final xs = _puentesEnHoja(boardSize);
          final hit = primerChoqueConPreviosPapa(
            _partida,
            salto,
            boardSize: boardSize,
            grosorActual: _grosor,
            puentesIgnorar: xs,
            radioPuente: radio,
          );
          setState(() {
            _trazoActual.add(local);
            _resolverChoquesConPuentes([hit], boardSize);
          });
        } else if (trazoChocaConPreviosPapa(
          _partida,
          salto,
          boardSize: boardSize,
          grosorActual: _grosor,
        )) {
          setState(() {
            _trazoActual.add(local);
            _fallar(
              '${_partida.jugadorActual} tocó una línea. Fin de la partida.',
            );
          });
        }
        return;
      }
    }

    final de = _partida.siguienteConectar;
    final a = de + 1;
    final pts = [..._trazoActual, local];
    // Solo evaluar autochoque después de salir del número de origen.
    final yaSalio = _salioDelInicio ||
        !cercaDeNumeroPapa(_partida, de, local, boardSize);

    final bool chocaPrevios;
    final bool chocaPropio;
    Offset? hitPrevios;
    Offset? hitPropio;
    if (_opciones.puentesEfectivos) {
      final radio = radioPuentePapa(boardSize, _grosor);
      final xs = _puentesEnHoja(boardSize);
      hitPrevios = primerChoqueConPreviosPapa(
        _partida,
        pts,
        boardSize: boardSize,
        grosorActual: _grosor,
        puentesIgnorar: xs,
        radioPuente: radio,
      );
      hitPropio = yaSalio
          ? primerAutochocquePapa(
              pts,
              boardSize: boardSize,
              grosor: _grosor,
              puentesIgnorar: xs,
              radioPuente: radio,
            )
          : null;
      chocaPrevios = hitPrevios != null;
      chocaPropio = hitPropio != null;
    } else {
      chocaPrevios = trazoChocaConPreviosPapa(
        _partida,
        pts,
        boardSize: boardSize,
        grosorActual: _grosor,
      );
      chocaPropio = yaSalio &&
          trazoSeTocaASiMismoPapa(
            pts,
            boardSize: boardSize,
            grosor: _grosor,
          );
    }

    setState(() {
      _trazoActual.add(local);

      if (chocaPrevios || chocaPropio) {
        if (_opciones.puentesEfectivos) {
          final corto = _resolverChoquesConPuentes(
            [hitPrevios, hitPropio],
            boardSize,
          );
          if (corto) return;
        } else {
          _fallar(
            chocaPropio
                ? '${_partida.jugadorActual} tocó su propia línea. '
                    'Fin de la partida.'
                : '${_partida.jugadorActual} tocó una línea. Fin de la partida.',
          );
          return;
        }
      }

      if (!_salioDelInicio &&
          !cercaDeNumeroPapa(_partida, de, local, boardSize)) {
        _salioDelInicio = true;
      }

      if (!_opciones.permitirTrazoSobreNumerosEfectivo &&
          trazoTocaNumeroProhibidoPapa(
            _partida,
            _trazoActual,
            boardSize,
            yaSalioDelInicio: _salioDelInicio,
          )) {
        _fallar(
          '${_partida.jugadorActual} tocó un número. Fin de la partida.',
        );
        return;
      }

      // Tocar la zona habilitada marca al toque. Si una línea corta el círculo,
      // solo cuentan los lóbulos abiertos (sin cruzar esa tinta).
      if (_salioDelInicio &&
          cercaDeNumeroPapa(_partida, a, local, boardSize) &&
          _trazoActual.length >= 2) {
        if (puntaSobreTintaPreviaPapa(
          _partida,
          local,
          boardSize,
          grosorActual: _grosor,
        )) {
          final radio = radioPuentePapa(boardSize, _grosor);
          final sobrePuente = _opciones.puentesEfectivos &&
              cercaDePuentePapa(local, _puentesEnHoja(boardSize), radio);
          if (!sobrePuente) {
            _fallar(
              '${_partida.jugadorActual} tocó una línea. Fin de la partida.',
            );
            return;
          }
        }
        if (!puntoEnZonaHabilitadaPapa(
          _partida,
          a,
          local,
          boardSize,
          grosorActual: _grosor,
        )) {
          // Dentro del círculo pero en zona tapada: seguir trazando / chocar.
          return;
        }
        if (llegadaPorLadoBloqueadoPapa(
          _partida,
          a,
          _trazoActual,
          boardSize,
        )) {
          _fallar(
            '${_partida.jugadorActual} entró al número por un lado bloqueado. '
            'Fin de la partida.',
          );
          return;
        }
        aceptarTrazoPapa(
          _partida,
          _trazoActual,
          boardSize: boardSize,
          grosor: _grosor,
        );
        _trazoFallido.clear();
        _limpiarTrazo();
        unawaited(_publicarEstadoOnline(forzar: true));
      }
    });
  }

  void _onPointerUpOrCancel(int pointerId) {
    if (_partida.fase != FasePapa.jugando) return;
    // Otro dedo (botón lupa, etc.): no corta el trazo en curso.
    if (_pointerDibujoId != null && pointerId != _pointerDibujoId) return;
    if (!_dibujando || !_inicioValido) {
      setState(_limpiarTrazo);
      return;
    }
    if (_partida.terminada) {
      setState(() {
        _dibujando = false;
        _inicioValido = false;
        _salioDelInicio = false;
        _pointerDibujoId = null;
        _lupaPunto.value = null;
        _trazoActual.clear();
      });
      return;
    }

    setState(() {
      _fallar(
        '${_partida.jugadorActual} no terminó el trazo en el número. '
        'Fin de la partida.',
      );
    });
  }

  String get _prefijoTitulo {
    if (_opciones.modoInfernal) return 'La papa · Infernal';
    if (widget.solo) return 'La papa · Solo';
    if (_esOnline) return 'La papa · Online';
    return 'La papa';
  }

  String? _validarNombre(String nombre, int index) {
    if (nombre.isEmpty) return 'El nombre no puede estar vacío.';
    if (nombre.length > _maxNombre) {
      return 'Máximo $_maxNombre caracteres.';
    }
    final ocupado = _nombres.asMap().entries.any(
          (e) => e.key != index && e.value == nombre,
        );
    if (ocupado) return 'Ese nombre ya está en uso.';
    return null;
  }

  Future<void> _renombrarJugadorActual() async {
    if (_dibujando || _partida.terminada) return;
    final index = _partida.indiceTurno % _nombres.length;
    final actual = _nombres[index];
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
            style: TextStyle(color: AppColors.mint, fontSize: 18),
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
                  counterStyle:
                      const TextStyle(color: AppColors.textoSuave),
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final t = ctrl.text.trim();
                    if (_validarNombre(t, index) case final e?) {
                      setDialogState(() => error = e);
                      return;
                    }
                    Navigator.of(context).pop(t);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mint,
                    foregroundColor: const Color(0xFF062018),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'Guardar',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.peligro,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 4,
                    shadowColor: Colors.black54,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (nuevo == null || nuevo == actual || !mounted) return;
    setState(() {
      _nombres[index] = nuevo;
      _partida.nombres[index] = nuevo;
      if (_partida.ganador == actual) {
        _partida.ganador = nuevo;
      }
      final ri = _partida.rendidos.indexOf(actual);
      if (ri >= 0) _partida.rendidos[ri] = nuevo;
      final msg = _partida.mensajeFin;
      if (msg != null && msg.contains(actual)) {
        _partida.mensajeFin = msg.replaceAll(actual, nuevo);
      }
      for (var i = 0; i < _partida.trazos.length; i++) {
        final t = _partida.trazos[i];
        if (t.jugador == actual) {
          _partida.trazos[i] = TrazoPapa(
            puntos: t.puntos,
            de: t.de,
            a: t.a,
            jugador: nuevo,
            grosor: t.grosor,
          );
        }
      }
    });
  }

  Widget _chipNombre() {
    final nombre = _partida.jugadorActual;
    final puedeRenombrar = !_dibujando && !_partida.terminada;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: puedeRenombrar ? _renombrarJugadorActual : null,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: EdgeInsets.symmetric(
            vertical: puedeRenombrar ? 4 : 2,
            horizontal: puedeRenombrar ? 8 : 2,
          ),
          decoration: puedeRenombrar
              ? BoxDecoration(
                  color: const Color(0xFF0E061C),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.violeta.withValues(alpha: 0.7),
                    width: 1.2,
                  ),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  nombre.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: puedeRenombrar ? AppColors.texto : AppColors.mint,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (puedeRenombrar) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.edit_rounded,
                  size: 14,
                  color: AppColors.violeta.withValues(alpha: 0.95),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _abrirMenu() {
    if (_dibujando) return;
    setState(() {
      _mostrarMenu = true;
      _confirmarRendicion = false;
      _mostrarAjustes = false;
    });
  }

  void _abrirAjustes() {
    if (_dibujando) return;
    setState(() {
      _mostrarAjustes = true;
      _mostrarMenu = false;
      _confirmarRendicion = false;
    });
  }

  void _abrirReglas() {
    setState(() {
      _mostrarMenu = false;
      _confirmarRendicion = false;
    });
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
            reglasLaPapa(opciones: _opciones),
            style: const TextStyle(
              color: AppColors.texto,
              height: 1.35,
            ),
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

  void _salirAlMenu() {
    if (widget.solo) {
      if (_partida.terminada) {
        PapaStandByStore.limpiar();
      } else {
        // No guardar un trazo a medias: al volver empieza limpio.
        _limpiarTrazo();
        PapaStandByStore.guardar(
          PartidaPapaResume(
            partida: _partida,
            nombres: _nombres,
            opciones: _opciones,
            ajustesIniciales: _ajustes,
            grosor: _grosor,
            boardSize: _boardSize,
            trazoFallido: List.of(_trazoFallido),
          ),
        );
      }
    }
    Navigator.of(context).pop();
  }

  void _rendirse() {
    if (_partida.terminada) return;
    if (widget.solo) {
      _salirAlMenu();
      return;
    }
    final yo = _esOnline
        ? (widget.miNombre ?? _partida.jugadorActual)
        : _partida.jugadorActual;
    if (_partida.estaRendido(yo)) return;

    setState(() {
      _mostrarMenu = false;
      _confirmarRendicion = false;
      _limpiarTrazo();
      _trazoFallido.clear();
      _avisoVida = null;
      rendirsePapa(_partida, yo);
      if (!_partida.terminada) {
        _avisoVida = '$yo se rindió · sigue la partida';
      }
    });
    unawaited(_publicarEstadoOnline(forzar: true));
  }

  String get _mensajeEstado {
    if (_esperandoTableroOnline) {
      return _soyAnfitrionOnline
          ? 'Preparando hoja compartida…'
          : 'Esperando la hoja del anfitrión…';
    }
    if (_partida.terminada) return _partida.mensajeFin ?? 'Fin';
    if (_avisoVida != null) return _avisoVida!;
    if (_esOnline && !_esMiTurno) {
      return 'Turno de ${_partida.jugadorActual}…';
    }
    if (_partida.fase == FasePapa.colocando) {
      return '${_partida.jugadorActual}: colocá el '
          '${_partida.siguienteAColocar} '
          '(${_partida.siguienteAColocar - 1}/${_partida.maxNumero})';
    }
    final de = _partida.siguienteConectar;
    final a = de < _partida.maxNumero ? de + 1 : null;
    if (a == null) return '¡Completaste la hoja!';
    return 'Conectá $de → $a · soltá o salí de la hoja = perdés';
  }

  Widget _selectorGrosor({ValueChanged<GrosorTrazoPapa>? onElegir}) {
    return Row(
      children: [
        for (final g in GrosorTrazoPapa.values) ...[
          if (g != GrosorTrazoPapa.values.first) const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _dibujando
                    ? null
                    : () {
                        setState(() => _grosor = g);
                        onElegir?.call(g);
                      },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: _grosor == g
                        ? AppColors.mint.withValues(alpha: 0.18)
                        : const Color(0xFF1A0F2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _grosor == g
                          ? AppColors.mint
                          : AppColors.textoSuave.withValues(alpha: 0.35),
                      width: _grosor == g ? 1.8 : 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomPaint(
                        size: const Size(48, 14),
                        painter: _MuestraGrosorPainter(
                          ancho: g.ancho,
                          color: _grosor == g
                              ? AppColors.mint
                              : AppColors.textoSuave,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        g.etiqueta,
                        style: TextStyle(
                          color: _grosor == g
                              ? AppColors.mint
                              : AppColors.textoSuave,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _abrirSelectorTrazos() async {
    if (!_opciones.modificarGrosorTrazoEfectivo) return;
    if (_dibujando || _partida.terminada) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.carta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'TRAZOS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.mint,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Elegí el grosor del lápiz.\n'
                  'Mientras dibujás, tocá “Trazos” para ciclar '
                  'Grueso → Fino → Normal.\n'
                  'En PC también podés usar la tecla T.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textoSuave,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                StatefulBuilder(
                  builder: (context, setSheetState) {
                    return _selectorGrosor(
                      onElegir: (_) {
                        setSheetState(() {});
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _botonTrazos() {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: neonGlow(AppColors.mint, blur: 10),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _partida.terminada ? null : _onTrazosPressed,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.mint.withValues(alpha: 0.95),
                    AppColors.mint.withValues(alpha: 0.65),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.brush_rounded, color: Color(0xFF062018)),
                  const SizedBox(width: 8),
                  Text(
                    _dibujando ? 'Trazos · ${_grosor.etiqueta}' : 'Trazos',
                    style: const TextStyle(
                      color: Color(0xFF062018),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _esCelular(BuildContext context) {
    final p = Theme.of(context).platform;
    return p == TargetPlatform.android || p == TargetPlatform.iOS;
  }

  Widget _controlPosicionLupa(BuildContext context) {
    if (_esCelular(context)) {
      return SizedBox(
        width: double.infinity,
        height: 40,
        child: OutlinedButton.icon(
          onPressed: _rotarPosicionLupa,
          icon: const Icon(Icons.zoom_in_map_rounded, size: 18),
          label: const Text(
            'Mover lupa',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.azul,
            side: const BorderSide(color: AppColors.azul, width: 1.5),
            backgroundColor: AppColors.carta,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Text(
        'Tocá la tecla L para mover la posición de la lupa',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textoSuave,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _ayudaTeclaTrazo(BuildContext context) {
    if (!_opciones.modificarGrosorTrazoEfectivo) return const SizedBox.shrink();
    if (_esCelular(context)) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Text(
        'Tocá la tecla T para cambiar el grosor del trazo',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textoSuave,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final de = _partida.siguienteConectar;
    final a = de < _partida.maxNumero ? de + 1 : null;
    final vidas = _partida.vidasDelActual();
    final jugando =
        _partida.fase == FasePapa.jugando && !_partida.terminada;
    final esCelular = _esCelular(context);
    final permitirGrosor = _opciones.modificarGrosorTrazoEfectivo;
    final tieneControlesInferiores =
        _opciones.mostrarLupaEfectiva || permitirGrosor;
    final alturaControles = !jugando || !tieneControlesInferiores
        ? 0.0
        : (_opciones.mostrarLupaEfectiva ? 46.0 : 0.0) +
            (permitirGrosor && !esCelular ? 22.0 : 0.0) +
            (permitirGrosor ? 44.0 : 0.0) +
            16.0;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerMove: (e) =>
                _onPointerMoveGlobal(e.position, e.pointer),
            onPointerUp: (e) => _onPointerUpOrCancel(e.pointer),
            onPointerCancel: (e) => _onPointerUpOrCancel(e.pointer),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Positioned.fill(child: EpicBackdrop()),
                SafeArea(
                  child: Column(
                    children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                    child: Row(
                      children: [
                        _RoundIcon(
                          icon: Icons.menu,
                          onTap: _abrirMenu,
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  '$_prefijoTitulo · ',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.mint,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Flexible(child: _chipNombre()),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Nueva hoja',
                          onPressed: _reiniciar,
                          icon: const Icon(Icons.refresh_rounded,
                              color: AppColors.textoSuave),
                        ),
                        _RoundIcon(
                          icon: Icons.settings,
                          onTap: _abrirAjustes,
                        ),
                      ],
                    ),
                  ),
                  if (vidas != null &&
                      _partida.fase == FasePapa.jugando &&
                      !_partida.terminada)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < OpcionesPapa.vidasIniciales; i++)
                            Icon(
                              i < vidas
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: AppColors.peligro,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _mensajeEstado,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _partida.fase == FasePapa.perdido ||
                                (_avisoVida != null &&
                                    _partida.fase == FasePapa.colocando)
                            ? AppColors.peligro
                            : (_partida.fase == FasePapa.ganado
                                ? AppColors.mint
                                : (_avisoVida != null
                                    ? AppColors.peligro
                                    : AppColors.textoSuave)),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (!widget.solo && _partida.nombres.length > 1) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (var i = 0; i < _partida.nombres.length; i++)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.carta.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: !_partida.terminada &&
                                          i ==
                                              (_partida.indiceTurno %
                                                  _partida.nombres.length) &&
                                          !_partida.estaRendido(
                                            _partida.nombres[i],
                                          )
                                      ? AppColors.mint
                                      : AppColors.cartaBorde,
                                  width: !_partida.terminada &&
                                          i ==
                                              (_partida.indiceTurno %
                                                  _partida.nombres.length) &&
                                          !_partida.estaRendido(
                                            _partida.nombres[i],
                                          )
                                      ? 2
                                      : 1,
                                ),
                              ),
                              child: Text(
                                _partida.estaRendido(_partida.nombres[i])
                                    ? '${_partida.nombres[i]} (fuera)'
                                    : _partida.nombres[i],
                                style: TextStyle(
                                  color: _partida.estaRendido(
                                    _partida.nombres[i],
                                  )
                                      ? AppColors.textoSuave
                                      : AppColors.texto,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  decoration: _partida.estaRendido(
                                    _partida.nombres[i],
                                  )
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 2, 10, 4),
                          child: AspectRatio(
                            aspectRatio: columnasPapa / filasPapa,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.mint,
                                  width: 2,
                                ),
                                boxShadow: neonGlow(
                                  AppColors.mint,
                                  blur: 16,
                                ),
                              ),
                              // Tamaño real = área interna (sin borde),
                              // misma coordenada que los trazos guardados.
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final boardSize = _sincronizarTamanoHoja(
                                      Size(
                                        constraints.maxWidth,
                                        constraints.maxHeight,
                                      ),
                                    );
                                    return Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned.fill(
                                          child: Listener(
                                            onPointerDown: (e) {
                                              final box = _hojaKey
                                                      .currentContext
                                                      ?.findRenderObject()
                                                  as RenderBox?;
                                              if (box == null) return;
                                              final local = box
                                                  .globalToLocal(e.position);
                                              _onPointerDown(
                                                local,
                                                boardSize,
                                                e.pointer,
                                              );
                                            },
                                            child: CustomPaint(
                                              key: _hojaKey,
                                              size: boardSize,
                                              painter: _HojaPapaPainter(
                                                partida: _partida,
                                                trazoActual:
                                                    List.of(_trazoActual),
                                                trazoFallido:
                                                    List.of(_trazoFallido),
                                                puentes: List.of(_puentesNorm),
                                                boardSize: boardSize,
                                                numeroActual: de,
                                                numeroSiguiente: a,
                                                grosorActual: _grosor,
                                                mostrarCuadricula: _opciones
                                                    .mostrarCuadriculaEfectiva,
                                                miNombre: widget.miNombre,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (_opciones.mostrarLupaEfectiva)
                                          ValueListenableBuilder<Offset?>(
                                            valueListenable: _lupaPunto,
                                            builder: (context, foco, _) {
                                              if (!_dibujando ||
                                                  foco == null) {
                                                return const SizedBox.shrink();
                                              }
                                              return _LupaTrazoPapa(
                                                focus: foco,
                                                offsetLupa: Offset(
                                                  _lupaDx,
                                                  _lupaDy,
                                                ),
                                                boardSize: boardSize,
                                                partida: _partida,
                                                trazoActual:
                                                    List.of(_trazoActual),
                                                trazoFallido:
                                                    List.of(_trazoFallido),
                                                puentes: List.of(_puentesNorm),
                                                numeroActual: de,
                                                numeroSiguiente: a,
                                                grosorActual: _grosor,
                                                mostrarCuadricula: _opciones
                                                    .mostrarCuadriculaEfectiva,
                                                miNombre: widget.miNombre,
                                              );
                                            },
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: alturaControles,
                    child: jugando
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                            child: Column(
                              children: [
                                if (_opciones.mostrarLupaEfectiva) ...[
                                  _controlPosicionLupa(context),
                                  const SizedBox(height: 6),
                                ],
                                if (_opciones.modificarGrosorTrazoEfectivo) ...[
                                  _ayudaTeclaTrazo(context),
                                  _botonTrazos(),
                                ],
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
            ),
          ),
          if (_mostrarMenu)
            Positioned.fill(
              child: _MenuOverlay(
                jugador: _partida.jugadorActual,
                esSolo: widget.solo,
                partidaTerminada: _partida.terminada,
                confirmarRendicion: _confirmarRendicion && !widget.solo,
                onCerrar: () => setState(() {
                  _mostrarMenu = false;
                  _confirmarRendicion = false;
                }),
                onReglas: _abrirReglas,
                onSalirORendirse: _partida.terminada || widget.solo
                    ? _salirAlMenu
                    : () => setState(() => _confirmarRendicion = true),
                onConfirmarRendicion: _rendirse,
                onCancelarRendicion: () =>
                    setState(() => _confirmarRendicion = false),
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
          // Notificación superior de grosor al ciclar mientras dibujás.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: IgnorePointer(
                ignoring: _avisoGrosor == null,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  offset: _avisoGrosor == null
                      ? const Offset(0, -1.2)
                      : Offset.zero,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _avisoGrosor == null ? 0 : 1,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                      child: Material(
                        color: Colors.transparent,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.carta,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.mint,
                              width: 1.8,
                            ),
                            boxShadow: [
                              ...neonGlow(AppColors.mint, blur: 14),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.brush_rounded,
                                  color: AppColors.mint,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _avisoGrosor ?? '',
                                    style: const TextStyle(
                                      color: AppColors.texto,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_partida.terminada)
            Positioned.fill(
              child: PremiarMonedasVictoriaPc(
                aplicar: false,
                aplicarOnline: ganePartidaOnline(
                  online: _esOnline,
                  ganador: _partida.ganador,
                  miNombre: widget.miNombre,
                ),
                juegoId: MenuJuegoScreen.juegoIdLaPapa,
                salaCodigo: widget.salaCodigo,
                child: VictoriaLaPapaOverlay(
                  partida: _partida,
                  ganador: _partida.ganador,
                  subtitulo: _partida.mensajeFin,
                  animaciones: _ajustes.animaciones,
                  esSolo: widget.solo,
                  trazoFallido: List.of(_trazoFallido),
                  boardSizeTrazo: _boardSize,
                  onVolverAJugar: _reiniciar,
                  onVolver: _salirAlMenu,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.carta,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: AppColors.texto),
        ),
      ),
    );
  }
}

class _MenuOverlay extends StatelessWidget {
  const _MenuOverlay({
    required this.jugador,
    required this.esSolo,
    required this.partidaTerminada,
    required this.confirmarRendicion,
    required this.onCerrar,
    required this.onReglas,
    required this.onSalirORendirse,
    required this.onConfirmarRendicion,
    required this.onCancelarRendicion,
  });

  final String jugador;
  final bool esSolo;
  final bool partidaTerminada;
  final bool confirmarRendicion;
  final VoidCallback onCerrar;
  final VoidCallback onReglas;
  final VoidCallback onSalirORendirse;
  final VoidCallback onConfirmarRendicion;
  final VoidCallback onCancelarRendicion;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onCerrar,
        child: SafeArea(
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.acento, width: 2),
                      boxShadow: neonGlow(AppColors.acento, blur: 18),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'MENÚ',
                                style: TextStyle(
                                  color: AppColors.acento,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
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
                        const SizedBox(height: 4),
                        Text(
                          jugador.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.texto,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            shadows: [
                              Shadow(
                                color: AppColors.acento.withValues(alpha: 0.7),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          partidaTerminada
                              ? 'Partida terminada'
                              : 'Turno actual',
                          style: TextStyle(
                            color:
                                AppColors.textoSuave.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _ArcadeButton(
                          label: 'REGLAS',
                          icon: Icons.menu_book_rounded,
                          tono: _BotonTono.azul,
                          onPressed: onReglas,
                        ),
                        const SizedBox(height: 10),
                        if (partidaTerminada || esSolo)
                          _ArcadeButton(
                            label: 'SALIR',
                            icon: Icons.logout_rounded,
                            tono: _BotonTono.rojo,
                            onPressed: onSalirORendirse,
                          )
                        else if (!confirmarRendicion)
                          _ArcadeButton(
                            label: 'RENDIRSE',
                            icon: Icons.flag_rounded,
                            tono: _BotonTono.rojo,
                            onPressed: onSalirORendirse,
                          )
                        else ...[
                          const Text(
                            '¿Confirmás tu derrota?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.peligro,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _ArcadeButton(
                            label: 'CONFIRMAR RENDICIÓN',
                            icon: Icons.check_circle_outline,
                            tono: _BotonTono.rojo,
                            onPressed: onConfirmarRendicion,
                          ),
                          const SizedBox(height: 10),
                          _ArcadeButton(
                            label: 'CANCELAR',
                            icon: Icons.close,
                            tono: _BotonTono.violeta,
                            onPressed: onCancelarRendicion,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _BotonTono { violeta, azul, rojo }

class _ArcadeButton extends StatelessWidget {
  const _ArcadeButton({
    required this.label,
    required this.icon,
    required this.tono,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final _BotonTono tono;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    late final List<Color> colors;
    late final Color glow;
    late final Color fg;

    switch (tono) {
      case _BotonTono.violeta:
        colors = const [
          Color(0xFFCE93D8),
          Color(0xFFAB47BC),
          Color(0xFF6A1B9A),
        ];
        glow = AppColors.rosa;
        fg = Colors.white;
      case _BotonTono.azul:
        colors = const [
          Color(0xFF81D4FA),
          Color(0xFF29B6F6),
          Color(0xFF0277BD),
        ];
        glow = AppColors.azul;
        fg = Colors.white;
      case _BotonTono.rojo:
        colors = const [
          Color(0xFFFF8A80),
          Color(0xFFFF5252),
          Color(0xFFC62828),
        ];
        glow = AppColors.peligro;
        fg = Colors.white;
    }

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: enabled ? neonGlow(glow, blur: 16) : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Ink(
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: colors,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white70, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: fg),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LupaTrazoPapa extends StatelessWidget {
  const _LupaTrazoPapa({
    required this.focus,
    required this.offsetLupa,
    required this.boardSize,
    required this.partida,
    required this.trazoActual,
    required this.trazoFallido,
    required this.puentes,
    required this.numeroActual,
    required this.numeroSiguiente,
    required this.grosorActual,
    required this.mostrarCuadricula,
    this.miNombre,
  });

  static const diametro = 118.0;
  static const zoom = 2.35;
  /// Las 4 esquinas relativas al dedo/cursor (ciclo con L / botón).
  static const posiciones = <Offset>[
    Offset(-52, -70), // arriba-izquierda
    Offset(52, -70), // arriba-derecha
    Offset(-52, 70), // abajo-izquierda
    Offset(52, 70), // abajo-derecha
  ];

  final Offset focus;
  final Offset offsetLupa;
  final Size boardSize;
  final PartidaPapa partida;
  final List<Offset> trazoActual;
  final List<Offset> trazoFallido;
  final List<Offset> puentes;
  final int numeroActual;
  final int? numeroSiguiente;
  final GrosorTrazoPapa grosorActual;
  final bool mostrarCuadricula;
  final String? miNombre;

  @override
  Widget build(BuildContext context) {
    const r = diametro / 2;

    return Positioned(
      left: focus.dx + offsetLupa.dx - r,
      top: focus.dy + offsetLupa.dy - r,
      width: diametro,
      height: diametro,
      child: IgnorePointer(
        child: CustomPaint(
          size: const Size(diametro, diametro),
          painter: _LupaPapaPainter(
            focus: focus,
            boardSize: boardSize,
            zoom: zoom,
            hoja: _HojaPapaPainter(
              partida: partida,
              trazoActual: trazoActual,
              trazoFallido: trazoFallido,
              puentes: puentes,
              boardSize: boardSize,
              numeroActual: numeroActual,
              numeroSiguiente: numeroSiguiente,
              grosorActual: grosorActual,
              mostrarCuadricula: mostrarCuadricula,
              miNombre: miNombre,
            ),
          ),
        ),
      ),
    );
  }
}

class _LupaPapaPainter extends CustomPainter {
  _LupaPapaPainter({
    required this.focus,
    required this.boardSize,
    required this.zoom,
    required this.hoja,
  });

  final Offset focus;
  final Size boardSize;
  final double zoom;
  final _HojaPapaPainter hoja;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radio = size.width / 2;

    canvas.drawCircle(
      center.translate(1.5, 2.5),
      radio,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radio - 1)),
    );

    canvas.translate(center.dx, center.dy);
    canvas.scale(zoom);
    canvas.translate(-focus.dx, -focus.dy);

    final paper = Rect.fromLTWH(0, 0, boardSize.width, boardSize.height);
    // Fuera de la hoja (para que el borde mint se note cerca del límite).
    canvas.drawRect(
      paper.inflate(500),
      Paint()..color = const Color(0xFF0A1A14),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(paper, const Radius.circular(6)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(paper, const Radius.circular(6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.mint,
    );
    hoja.paint(canvas, boardSize);
    canvas.restore();

    canvas.drawCircle(
      center,
      radio - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.mint,
    );
    canvas.drawCircle(
      center,
      radio - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.85),
    );

    // Cruz suave en el centro (punto bajo el dedo).
    final cruz = Paint()
      ..color = AppColors.mint.withValues(alpha: 0.55)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const arm = 7.0;
    canvas.drawLine(
      center.translate(-arm, 0),
      center.translate(arm, 0),
      cruz,
    );
    canvas.drawLine(
      center.translate(0, -arm),
      center.translate(0, arm),
      cruz,
    );
  }

  @override
  bool shouldRepaint(covariant _LupaPapaPainter oldDelegate) =>
      oldDelegate.focus != focus ||
      oldDelegate.boardSize != boardSize ||
      oldDelegate.zoom != zoom;
}

class _HojaPapaPainter extends CustomPainter {
  _HojaPapaPainter({
    required this.partida,
    required this.trazoActual,
    required this.trazoFallido,
    required this.puentes,
    required this.boardSize,
    required this.numeroActual,
    required this.numeroSiguiente,
    required this.grosorActual,
    this.mostrarCuadricula = true,
    this.miNombre,
  });

  final PartidaPapa partida;
  final List<Offset> trazoActual;
  final List<Offset> trazoFallido;
  /// Puentes del intento (coords normalizadas 0..1).
  final List<Offset> puentes;
  final Size boardSize;
  final int numeroActual;
  final int? numeroSiguiente;
  final GrosorTrazoPapa grosorActual;
  final bool mostrarCuadricula;
  final String? miNombre;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / columnasPapa;
    final cellH = size.height / filasPapa;

    if (mostrarCuadricula) {
      final gridPaint = Paint()
        ..color = const Color(0xFF2A1450).withValues(alpha: 0.55)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      for (var c = 0; c <= columnasPapa; c++) {
        final x = c * cellW;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (var r = 0; r <= filasPapa; r++) {
        final y = r * cellH;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    final colocando = partida.fase == FasePapa.colocando;
    final fantasma =
        partida.modoFantasma && partida.fase == FasePapa.jugando;

    for (var i = 0; i < partida.casillas.length; i++) {
      final n = partida.casillas[i];
      if (n == null) continue;
      if (fantasma && n != numeroActual && n != numeroSiguiente) {
        continue;
      }
      final c = centroCasillaPapa(i, size);
      final destacado = !partida.terminada &&
          !colocando &&
          (n == numeroActual || n == numeroSiguiente);
      if (destacado) {
        canvas.drawCircle(
          c,
          math.min(cellW, cellH) * 0.26,
          Paint()
            ..color = (n == numeroActual ? AppColors.mint : AppColors.peligro)
                .withValues(alpha: 0.22)
            ..style = PaintingStyle.fill,
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: '$n',
          style: TextStyle(
            color: destacado
                ? (n == numeroActual
                    ? const Color(0xFF0A7A4A)
                    : AppColors.peligro)
                : const Color(0xFF1A0A33),
            fontWeight: FontWeight.w900,
            fontSize: math.min(cellW, cellH) * (destacado ? 0.28 : 0.24),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }

    final ultimo = partida.trazos.isEmpty ? null : partida.trazos.last;
    for (final t in partida.trazos) {
      final pts = puntosTrazoEnHojaPapa(t, size);
      final esUltimoRival = miNombre != null &&
          identical(t, ultimo) &&
          t.jugador != miNombre;
      if (esUltimoRival) {
        _dibujarPolyline(
          canvas,
          pts,
          Paint()
            ..color = AppColors.mint.withValues(alpha: 0.45)
            ..strokeWidth = t.grosor.ancho + 4
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke,
        );
      }
      _dibujarPolyline(
        canvas,
        pts,
        Paint()
          ..color = esUltimoRival ? AppColors.mint : const Color(0xFF1A0A33)
          ..strokeWidth = t.grosor.ancho + (esUltimoRival ? 0.8 : 0)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }

    if (trazoFallido.length >= 2) {
      final fallidoPts = puntosParecenNormalizadosPapa(trazoFallido)
          ? desnormalizarPuntosPapa(trazoFallido, size)
          : trazoFallido;
      _dibujarPolyline(
        canvas,
        fallidoPts,
        Paint()
          ..color = AppColors.peligro
          ..strokeWidth = grosorActual.ancho + 0.3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    } else if (trazoFallido.length == 1) {
      final p = puntosParecenNormalizadosPapa(trazoFallido)
          ? desnormalizarPuntosPapa(trazoFallido, size).first
          : trazoFallido.first;
      canvas.drawCircle(
        p,
        math.max(2.5, grosorActual.ancho * 0.7),
        Paint()..color = AppColors.peligro,
      );
    }

    if (trazoActual.length >= 2) {
      _dibujarPolyline(
        canvas,
        trazoActual,
        Paint()
          ..color = AppColors.mint
          ..strokeWidth = grosorActual.ancho + 0.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    } else if (trazoActual.length == 1) {
      canvas.drawCircle(
        trazoActual.first,
        math.max(2.0, grosorActual.ancho * 0.65),
        Paint()..color = AppColors.mint,
      );
    }

    if (puentes.isNotEmpty) {
      final xs = puntosParecenNormalizadosPapa(puentes)
          ? desnormalizarPuntosPapa(puentes, size)
          : puentes;
      final arm = radioPuentePapa(size, grosorActual) * 0.85;
      final xPaint = Paint()
        ..color = AppColors.peligro
        ..strokeWidth = math.max(2.2, grosorActual.ancho * 0.55)
        ..strokeCap = StrokeCap.round;
      for (final p in xs) {
        canvas.drawLine(
          p.translate(-arm, -arm),
          p.translate(arm, arm),
          xPaint,
        );
        canvas.drawLine(
          p.translate(arm, -arm),
          p.translate(-arm, arm),
          xPaint,
        );
      }
    }
  }

  void _dibujarPolyline(Canvas canvas, List<Offset> pts, Paint paint) {
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HojaPapaPainter oldDelegate) => true;
}

class _MuestraGrosorPainter extends CustomPainter {
  _MuestraGrosorPainter({required this.ancho, required this.color});

  final double ancho;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawLine(
      Offset(2, y),
      Offset(size.width - 2, y),
      Paint()
        ..color = color
        ..strokeWidth = ancho
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _MuestraGrosorPainter oldDelegate) =>
      oldDelegate.ancho != ancho || oldDelegate.color != color;
}
