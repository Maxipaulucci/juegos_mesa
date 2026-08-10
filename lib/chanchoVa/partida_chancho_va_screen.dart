import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/chanchoVa/chancho_va_online_codec.dart';
import 'package:app_juegos_mesa/chanchoVa/fin_ronda_chancho_va_overlay.dart';
import 'package:app_juegos_mesa/chanchoVa/menu_partida_chancho_va.dart';
import 'package:app_juegos_mesa/chanchoVa/motor_chancho_va.dart';
import 'package:app_juegos_mesa/chanchoVa/opciones_chancho_va.dart';
import 'package:app_juegos_mesa/chanchoVa/standby_store.dart';
import 'package:app_juegos_mesa/chanchoVa/textos.dart';
import 'package:app_juegos_mesa/chanchoVa/victoria_chancho_va_overlay.dart';
import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/cartas/carta_espanola_skin.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/partida_ui/epic_backdrop.dart';
import 'package:app_juegos_mesa/shared/partida_ui/nombre_jugador_editable.dart';
import 'package:app_juegos_mesa/shared/partida_ui/reiniciar_partida_pc.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Partida de Chancho va (vs PC / online).
class PartidaChanchoVaScreen extends StatefulWidget {
  const PartidaChanchoVaScreen({
    super.key,
    required this.nombres,
    this.contraPc = true,
    this.salaCodigo,
    this.miNombre,
    this.modoDios = false,
    this.ajustesIniciales,
    this.resume,
    this.opciones = const OpcionesChanchoVa(),
  });

  final List<String> nombres;
  final bool contraPc;
  final String? salaCodigo;
  final String? miNombre;
  final bool modoDios;
  final AjustesEstado? ajustesIniciales;
  final PartidaChanchoResume? resume;
  final OpcionesChanchoVa opciones;

  @override
  State<PartidaChanchoVaScreen> createState() => _PartidaChanchoVaScreenState();
}

class _PartidaChanchoVaScreenState extends State<PartidaChanchoVaScreen>
    with SingleTickerProviderStateMixin {
  late PartidaChancho _partida;
  late List<String> _nombres;
  final Set<int> _numerosElegidos = {};
  int? _cantidadAnuncio = 1;
  DireccionChancho? _direccionAnuncio = DireccionChancho.derecha;
  final List<CartaChancho> _seleccionLocal = [];
  int _pcToken = 0;
  /// Tras PC abre Chancho, el humano puede decir aunque no tenga cuarteto.
  bool _chanchoVisiblePorCarrera = false;
  /// Nombre de la PC que lanzó CHANCHA (el humano debe responder o no).
  String? _quienLanzoChancha;
  /// Online: humano desafiado por CHANCHA de una PC (null = local / único humano).
  String? _objetivoChancha;
  bool _cronoEsRespuestaChancha = false;
  final math.Random _rng = math.Random();
  AjustesEstado _ajustes = const AjustesEstado();
  late OpcionesChanchoVa _opciones;
  bool _mostrarMenu = false;
  bool _mostrarAjustes = false;
  bool _mostrarCartelNumeros = false;
  final List<int> _borradorNumeros = [];
  late final AnimationController _cronoChancho;
  Timer? _timerChanchaPc;
  Timer? _timerNotiTope;
  String? _notiTopeTexto;

  StreamSubscription<Sala>? _onlineSub;
  int _onlineVersion = 0;
  bool _publicandoOnline = false;
  bool _dealPublicado = false;
  bool _esperandoDealOnline = false;

  static const _duracionCronoChancho = Duration(milliseconds: 1000);
  static const _segundosCronoChancho = 1.0;

  bool get _esOnline =>
      widget.salaCodigo != null &&
      widget.salaCodigo!.isNotEmpty &&
      widget.miNombre != null &&
      widget.miNombre!.isNotEmpty;

  bool get _soyAnfitrionOnline {
    if (!_esOnline) return false;
    for (final n in _nombres) {
      if (!TextosChancho.esPc(n)) return n == widget.miNombre;
    }
    return false;
  }

  bool get _modoDiosActivo =>
      widget.modoDios && widget.contraPc && !_esOnline;

  bool _esPc(JugadorChancho j) => TextosChancho.esPc(j.nombre);

  JugadorChancho get _yo {
    if (_esOnline) {
      return _partida.jugadores.firstWhere(
        (j) => j.nombre == widget.miNombre,
        orElse: () => _partida.jugadores.first,
      );
    }
    return _partida.jugadores.firstWhere(
      (j) => !_esPc(j),
      orElse: () => _partida.jugadores.first,
    );
  }

  List<JugadorChancho> get _pcs => _partida.jugadores
      .where((j) => _esPc(j) && !j.eliminado)
      .toList(growable: false);

  /// Rivales en orden de mesa (siguiente a [_yo] en adelante).
  List<JugadorChancho> get _oponentes {
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

  /// 1 rival → arriba; 2 → costados; 3 → izquierda, arriba y derecha.
  /// “Derecha” del pase = siguiente en la mesa (ops[0]).
  ({
    JugadorChancho? izquierda,
    JugadorChancho? arriba,
    JugadorChancho? derecha,
  }) get _asientosOponentes {
    final ops = _oponentes;
    return switch (ops.length) {
      0 => (izquierda: null, arriba: null, derecha: null),
      1 => (izquierda: null, arriba: ops[0], derecha: null),
      2 => (izquierda: ops[1], arriba: null, derecha: ops[0]),
      _ => (izquierda: ops[2], arriba: ops[1], derecha: ops[0]),
    };
  }

  bool get _humanoActivo => !_yo.eliminado;

  bool get _esTurnoHumanoAnuncio {
    if (_partida.terminada || !_humanoActivo) return false;
    if (_partida.fase != FaseChancho.anunciando) return false;
    return _partida.jugadorActual.nombre == _yo.nombre;
  }

  bool get _puedoElegirNumeros {
    if (_partida.fase != FaseChancho.eligiendoNumeros) return false;
    if (!_humanoActivo || _esperandoDealOnline) return false;
    return _partida.jugadorActual.nombre == _yo.nombre;
  }

  bool get _puedoElegirCartas {
    if (!_humanoActivo || _yo.seleccionPaseConfirmada) return false;
    if (_partida.fase == FaseChancho.eligiendoCartas) return true;
    // Antes de anunciar: se eligen las cartas a pasar.
    if (_esTurnoHumanoAnuncio && _cantidadAnuncio != null) return true;
    return false;
  }

  int get _cupoSeleccion {
    if (_partida.fase == FaseChancho.eligiendoCartas) {
      return _partida.anuncioActual?.cantidad ?? 0;
    }
    if (_esTurnoHumanoAnuncio) return _cantidadAnuncio ?? 0;
    return 0;
  }

  bool get _puedeAnunciarPase =>
      _esTurnoHumanoAnuncio &&
      _cantidadAnuncio != null &&
      _direccionAnuncio != null &&
      _seleccionLocal.length == _cantidadAnuncio;

  bool get _mostrarBotonChancho {
    if (_partida.terminada || _partida.enFinRonda || !_humanoActivo) {
      return false;
    }
    if (_partida.fase == FaseChancho.eligiendoNumeros) return false;
    if (_yo.dijoChancho) return false;
    if (_yo.tieneCuarteto) return true;
    if (_chanchoVisiblePorCarrera && _partida.quienAbrioChancho != null) {
      return true;
    }
    return false;
  }

  bool get _chanchoHabilitado =>
      _mostrarBotonChancho &&
      (_yo.tieneCuarteto || _partida.quienAbrioChancho != null);

  bool get _hayDesafioChancha => _quienLanzoChancha != null;

  /// El humano puede lanzar CHANCHA una vez por ronda (hasta el próximo Chancho).
  bool get _puedeLanzarChancha {
    if (!_opciones.chancha || !_humanoActivo) return false;
    if (!widget.contraPc || _partida.terminada || _partida.enFinRonda) {
      return false;
    }
    if (_hayDesafioChancha) return false;
    if (_partida.fase == FaseChancho.eligiendoNumeros) return false;
    if (_pcs.isEmpty) return false;
    if (!puedeLanzarChanchaRonda(_partida, _yo.nombre)) return false;
    return true;
  }

  /// Responder al CHANCHA que lanzó una PC (botón inferior).
  bool get _puedeResponderChancha {
    if (!_opciones.chancha || !_hayDesafioChancha) return false;
    if (_partida.terminada || _partida.enFinRonda || !_humanoActivo) {
      return false;
    }
    if (_esOnline &&
        _objetivoChancha != null &&
        _objetivoChancha != widget.miNombre) {
      return false;
    }
    return true;
  }

  bool get _soyObjetivoChancha =>
      !_esOnline ||
      _objetivoChancha == null ||
      _objetivoChancha == widget.miNombre;

  String get _textoEstado {
    if (_partida.terminada) return '';
    if (_esperandoDealOnline) return 'Esperando repartida…';
    if (_hayDesafioChancha) {
      if (_esOnline && !_soyObjetivoChancha) {
        return '¡${_quienLanzoChancha!} dijo CHANCHA a ${_objetivoChancha!}!';
      }
      return '¡${_quienLanzoChancha!} dijo CHANCHA!';
    }
    return switch (_partida.fase) {
      FaseChancho.eligiendoNumeros => _puedoElegirNumeros
          ? TextosChancho.eligeNumeros
          : 'Esperando números…',
      FaseChancho.anunciando => _esTurnoHumanoAnuncio
          ? TextosChancho.anunciando
          : 'Esperando a ${_partida.jugadorActual.nombre}…',
      FaseChancho.eligiendoCartas => _yo.seleccionPaseConfirmada
          ? 'Esperando al resto…'
          : TextosChancho.eligiendoCartas,
      FaseChancho.carreraChancho => TextosChancho.carrera,
      FaseChancho.finRonda => 'Fin de la ronda',
      FaseChancho.terminada => '',
    };
  }

  @override
  void initState() {
    super.initState();
    _cronoChancho = AnimationController(
      vsync: this,
      duration: _duracionCronoChancho,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _onTimeoutChancho();
        }
      });
    _timerChanchaPc = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _intentarChanchaPc();
    });
    final resume = widget.resume;
    _ajustes = resume?.ajustesIniciales ??
        widget.ajustesIniciales ??
        const AjustesEstado();
    _opciones = resume?.opciones ?? widget.opciones;
    _nombres = List.of(resume?.nombres ?? widget.nombres);
    if (resume != null) {
      _partida = resume.partida;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _talVezPc();
        if (_partida.fase == FaseChancho.carreraChancho &&
            !_yo.dijoChancho) {
          _iniciarCronometroChancho();
        }
      });
      return;
    }
    if (_esOnline) {
      _esperandoDealOnline = true;
      _partida = nuevaPartidaChancho(
        nombres: _nombres,
        contraPc: true,
        sinEspacio: _opciones.sinEspacio,
        finAlPrimerPerdedor: _opciones.finAlPrimerPerdedor,
      );
      _iniciarSincronizacionOnline();
      return;
    }
    _partida = nuevaPartidaChancho(
      nombres: _nombres,
      contraPc: true,
      sinEspacio: _opciones.sinEspacio,
      finAlPrimerPerdedor: _opciones.finAlPrimerPerdedor,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_partida.fase == FaseChancho.eligiendoNumeros) {
        _abrirCartelNumeros();
      } else {
        _talVezPc();
      }
    });
  }

  @override
  void dispose() {
    _onlineSub?.cancel();
    _pcToken++;
    _timerChanchaPc?.cancel();
    _timerNotiTope?.cancel();
    _cronoChancho.dispose();
    super.dispose();
  }

  /// Toast violeta arriba: no empuja el layout ni tapa botones (IgnorePointer).
  void _mostrarNotiTope(String texto) {
    _timerNotiTope?.cancel();
    setState(() => _notiTopeTexto = texto);
    _timerNotiTope = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      setState(() => _notiTopeTexto = null);
    });
  }

  static const int _maxNombre = 15;

  bool _puedeRenombrar(int index) {
    if (_esOnline) return false;
    if (!widget.contraPc) return false;
    if (_partida.terminada) return false;
    if (index < 0 || index >= _partida.jugadores.length) return false;
    final j = _partida.jugadores[index];
    if (j.eliminado) return false;
    return !_esPc(j);
  }

  String? _validarNombre(String nombre, int index) {
    if (nombre.isEmpty) return 'El nombre no puede estar vacío.';
    if (nombre.length > _maxNombre) {
      return 'Máximo $_maxNombre caracteres.';
    }
    if (TextosChancho.esPc(nombre)) {
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
      if (_partida.quienAbrioChancho == actual) {
        _partida.quienAbrioChancho = nuevo;
      }
      for (var i = 0; i < _partida.ordenChancho.length; i++) {
        if (_partida.ordenChancho[i] == actual) {
          _partida.ordenChancho[i] = nuevo;
        }
      }
      if (_partida.yaDijeronChanchaRonda.remove(actual)) {
        _partida.yaDijeronChanchaRonda.add(nuevo);
      }
      if (_partida.perdedor == actual) _partida.perdedor = nuevo;
      if (_partida.ganador == actual) _partida.ganador = nuevo;
      final msg = _partida.mensajeFin;
      if (msg != null && msg.contains(actual)) {
        _partida.mensajeFin = msg.replaceAll(actual, nuevo);
      }
      for (final e in _partida.historialLetras) {
        if (e.jugador == actual) e.jugador = nuevo;
      }
      final r = _partida.ultimoResumenRonda;
      if (r != null) {
        _partida.ultimoResumenRonda = ResumenRondaChancho(
          motivo: r.motivo,
          chanchoDe: r.chanchoDe == actual ? nuevo : r.chanchoDe,
          chancho: r.chancho == actual ? nuevo : r.chancho,
        );
      }
      if (_quienLanzoChancha == actual) _quienLanzoChancha = nuevo;
      if (_objetivoChancha == actual) _objetivoChancha = nuevo;
    });
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
    if (juego != 'chanchoVa') {
      if (_soyAnfitrionOnline && !_dealPublicado) {
        unawaited(_publicarDealInicialOnline());
      }
      return;
    }

    final version = (gameState['version'] as num?)?.toInt() ?? 0;
    if (version < _onlineVersion) return;
    if (_publicandoOnline && version <= _onlineVersion) return;

    final tieneDeal = chanchoPartidaGenerada(gameState);
    if (!tieneDeal) {
      if (_soyAnfitrionOnline && !_dealPublicado) {
        unawaited(_publicarDealInicialOnline());
      }
      return;
    }

    if (version <= _onlineVersion && !_esperandoDealOnline) return;

    final remoteChancha = gameState['quienLanzoChancha']?.toString();
    final chanchaRemota = (remoteChancha != null && remoteChancha.isNotEmpty)
        ? remoteChancha
        : null;
    final remoteObjetivo = gameState['objetivoChancha']?.toString();
    final objetivoRemoto =
        (remoteObjetivo != null && remoteObjetivo.isNotEmpty)
            ? remoteObjetivo
            : null;
    final chanchaNueva =
        chanchaRemota != null && chanchaRemota != _quienLanzoChancha;
    final eraEsperandoDeal = _esperandoDealOnline;
    final faseAntes = _partida.fase;

    setState(() {
      applyChanchoGameState(_partida, gameState);
      final opts = decodeOpcionesChancho(gameState['opciones']);
      _opciones = opts;
      _onlineVersion = version;
      _esperandoDealOnline = false;
      _dealPublicado = true;
      _quienLanzoChancha = chanchaRemota;
      _objetivoChancha = chanchaRemota == null ? null : objetivoRemoto;
      if (_partida.fase == FaseChancho.carreraChancho &&
          _humanoActivo &&
          !_yo.dijoChancho) {
        _chanchoVisiblePorCarrera = true;
      }
      if (_partida.fase != FaseChancho.eligiendoCartas &&
          _partida.fase != FaseChancho.anunciando) {
        _seleccionLocal.clear();
      }
    });

    if (chanchaRemota == null) {
      if (_cronoEsRespuestaChancha) _detenerCronometroChancho();
    } else if (chanchaNueva &&
        _soyObjetivoChancha &&
        chanchaRemota != widget.miNombre) {
      _iniciarCronometroRespuestaChancha();
    }

    if (_partida.fase == FaseChancho.carreraChancho &&
        _humanoActivo &&
        !_yo.dijoChancho &&
        !_cronoChancho.isAnimating) {
      _iniciarCronometroChancho();
    } else if (_partida.fase != FaseChancho.carreraChancho &&
        !_cronoEsRespuestaChancha &&
        _cronoChancho.isAnimating) {
      _detenerCronometroChancho();
    }

    if (_puedoElegirNumeros &&
        (eraEsperandoDeal || faseAntes != FaseChancho.eligiendoNumeros)) {
      unawaited(_abrirCartelNumeros());
    }

    if (_soyAnfitrionOnline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _autoConfirmarPcSiCorresponde();
        _talVezPc();
        _talVezChanchoPc();
      });
    }
  }

  Future<void> _publicarDealInicialOnline() async {
    if (!_esOnline || _dealPublicado || _publicandoOnline) return;
    final generada = nuevaPartidaChancho(
      nombres: _nombres,
      contraPc: true,
      sinEspacio: _opciones.sinEspacio,
      finAlPrimerPerdedor: _opciones.finAlPrimerPerdedor,
    );
    setState(() {
      _partida = generada;
      _esperandoDealOnline = false;
      _dealPublicado = true;
    });
    await _publicarEstadoOnline(forzar: true);
    if (!mounted) return;
    if (_puedoElegirNumeros) {
      unawaited(_abrirCartelNumeros());
    }
  }

  Future<void> _publicarEstadoOnline({bool forzar = false}) async {
    if (!_esOnline) return;
    final codigo = widget.salaCodigo;
    if (codigo == null) return;

    _publicandoOnline = true;
    try {
      for (var intento = 0; intento < 4; intento++) {
        _onlineVersion++;
        final gameState = encodeChanchoGameState(
          partida: _partida,
          version: _onlineVersion,
          opciones: _opciones,
          quienLanzoChancha: _quienLanzoChancha,
          objetivoChancha: _objetivoChancha,
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

  Future<void> _abrirCartelNumeros() async {
    if (!_puedoElegirNumeros) return;
    if (_partida.fase != FaseChancho.eligiendoNumeros) return;
    if (_mostrarCartelNumeros) return;
    setState(() {
      _borradorNumeros.clear();
      _mostrarCartelNumeros = true;
    });
  }

  void _toggleNumeroBorrador(int n) {
    final cupo = _partida.cantidadJugadores;
    setState(() {
      if (_borradorNumeros.contains(n)) {
        _borradorNumeros.remove(n);
      } else if (_borradorNumeros.length < cupo) {
        _borradorNumeros.add(n);
      }
    });
  }

  void _confirmarNumerosCartel() {
    if (!_mostrarCartelNumeros) return;
    final cupo = _partida.cantidadJugadores;
    if (_borradorNumeros.length != cupo) return;
    final elegidos = List<int>.of(_borradorNumeros);
    final err = aplicarNumerosElegidosChancho(_partida, elegidos);
    setState(() {
      _mostrarCartelNumeros = false;
      _borradorNumeros.clear();
      _numerosElegidos
        ..clear()
        ..addAll(elegidos);
      _seleccionLocal.clear();
    });
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (_esOnline) unawaited(_publicarEstadoOnline(forzar: true));
    _talVezPc();
  }

  void _defaultsAnuncioArgentinos() {
    _cantidadAnuncio = 1;
    _direccionAnuncio = DireccionChancho.derecha;
  }

  void _cicloCantidad() {
    if (!_esTurnoHumanoAnuncio) return;
    setState(() {
      final actual = _cantidadAnuncio ?? 0;
      _cantidadAnuncio = actual >= 4 ? 1 : actual + 1;
      while (_seleccionLocal.length > _cantidadAnuncio!) {
        _seleccionLocal.removeLast();
      }
    });
  }

  void _cicloDireccion() {
    if (!_esTurnoHumanoAnuncio) return;
    setState(() {
      final dirs = DireccionChancho.values;
      final i = _direccionAnuncio == null
          ? -1
          : dirs.indexOf(_direccionAnuncio!);
      _direccionAnuncio = dirs[(i + 1) % dirs.length];
    });
  }

  void _confirmarAnuncio() {
    if (!_puedeAnunciarPase) return;
    final c = _cantidadAnuncio!;
    final d = _direccionAnuncio!;
    final cartas = List<CartaChancho>.of(_seleccionLocal);
    final err = anunciarPaseChancho(
      _partida,
      cantidad: c,
      direccion: d,
      anunciante: _yo,
    );
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    final errSel = confirmarSeleccionPaseChancho(
      _partida,
      jugador: _yo,
      cartas: cartas,
    );
    setState(() => _seleccionLocal.clear());
    if (errSel != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errSel)));
      return;
    }
    if (_esOnline) unawaited(_publicarEstadoOnline());
    _despuesDeAnuncio();
  }

  void _repetirAnuncio() {
    if (!_esTurnoHumanoAnuncio) return;
    final u = _partida.ultimoAnuncio;
    if (u == null) return;
    setState(() {
      _cantidadAnuncio = u.cantidad;
      _direccionAnuncio = u.direccion;
      while (_seleccionLocal.length > u.cantidad) {
        _seleccionLocal.removeLast();
      }
    });
  }

  void _despuesDeAnuncio() {
    _autoConfirmarPcSiCorresponde();
    setState(() {});
  }

  void _toggleCarta(CartaChancho c) {
    if (!_puedoElegirCartas) return;
    final cupo = _cupoSeleccion;
    if (cupo <= 0) return;
    setState(() {
      if (_seleccionLocal.contains(c)) {
        _seleccionLocal.remove(c);
      } else if (_seleccionLocal.length < cupo) {
        _seleccionLocal.add(c);
      } else {
        // Cupo lleno: tocando otra carta reemplaza la más antigua.
        _seleccionLocal.removeAt(0);
        _seleccionLocal.add(c);
      }
    });
    // Si la PC anunció, al completar la cantidad el pase se confirma solo.
    if (_partida.fase == FaseChancho.eligiendoCartas &&
        _seleccionLocal.length == cupo) {
      _confirmarCartasLocal();
    }
  }

  void _confirmarCartasLocal() {
    if (!_puedoElegirCartas) return;
    final err = confirmarSeleccionPaseChancho(
      _partida,
      jugador: _yo,
      cartas: List.of(_seleccionLocal),
    );
    setState(() => _seleccionLocal.clear());
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (_esOnline) unawaited(_publicarEstadoOnline());
    if (_partida.fase == FaseChancho.eligiendoCartas) {
      // Espera a que el resto confirme.
      setState(() {});
      if (_soyAnfitrionOnline) _autoConfirmarPcSiCorresponde();
    } else {
      // Pase ejecutado.
      _chanchoVisiblePorCarrera = false;
      unawaited(_despuesDePase());
    }
  }

  Future<void> _despuesDePase() async {
    setState(() {});
    if (_partida.terminada) return;
    if (_partida.fase == FaseChancho.anunciando) {
      setState(() {
        _defaultsAnuncioArgentinos();
        _seleccionLocal.clear();
      });
      if (_intentarChanchaPc()) return;
    }
    // Primero Chancho (si una PC armó cuarteto). Hay que await para no
    // cancelar el token con el próximo _talVezPc.
    await _talVezChanchoPc();
    if (!mounted || _partida.terminada) return;
    if (_partida.fase == FaseChancho.carreraChancho ||
        _partida.fase == FaseChancho.finRonda) {
      return;
    }
    if (_partida.fase == FaseChancho.anunciando) {
      await _talVezPc();
    }
  }

  void _decirChancho() {
    if (_hayDesafioChancha) return;
    if (!_chanchoHabilitado) return;
    _detenerCronometroChancho();
    final err = decirChanchoVa(_partida, jugador: _yo);
    setState(() {
      _seleccionLocal.clear();
    });
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (_esOnline) unawaited(_publicarEstadoOnline());
    if (_partida.fase == FaseChancho.carreraChancho) {
      _chanchoVisiblePorCarrera = true;
      _talVezChanchoPc();
    } else {
      _alResolverRonda();
    }
  }

  void _iniciarCronometroChancho() {
    if (!widget.contraPc || _partida.terminada || !_humanoActivo) return;
    if (_yo.dijoChancho) return;
    _cronoEsRespuestaChancha = false;
    _cronoChancho.forward(from: 0);
    setState(() {});
  }

  void _iniciarCronometroRespuestaChancha() {
    if (!widget.contraPc || _partida.terminada) return;
    _cronoEsRespuestaChancha = true;
    _cronoChancho.forward(from: 0);
    setState(() {});
  }

  void _detenerCronometroChancho() {
    if (_cronoChancho.isAnimating || _cronoChancho.value > 0) {
      _cronoChancho.stop();
      _cronoChancho.reset();
    }
    _cronoEsRespuestaChancha = false;
  }

  void _onTimeoutChancho() {
    if (_cronoEsRespuestaChancha) {
      _onTimeoutRespuestaChancha();
      return;
    }
    if (!mounted || _partida.terminada || _yo.dijoChancho) return;

    // Online: cada humano se suma a la carrera al timeout; no cortar si sigue.
    if (_esOnline) {
      if (!_yo.dijoChancho && _partida.quienAbrioChancho != null) {
        decirChanchoVa(_partida, jugador: _yo);
        setState(() {});
        unawaited(_publicarEstadoOnline());
      }
      if (_partida.terminada ||
          _partida.enFinRonda ||
          _partida.fase == FaseChancho.anunciando) {
        _alResolverRonda();
      } else if (_soyAnfitrionOnline) {
        _talVezChanchoPc();
      }
      return;
    }

    // Una PC abrió Chancho y el humano no apretó a tiempo → letra al humano.
    final abrio = _partida.quienAbrioChancho;
    if (abrio != null && TextosChancho.esPc(abrio)) {
      penalizarJugadorChancho(
        _partida,
        _yo,
        motivo: MotivoPenalizacionChancho.ultimoEnChancho,
      );
      _alResolverRonda();
      return;
    }

    // Respaldo: completar carrera con el humano último.
    for (final pc in _pcs) {
      if (pc.dijoChancho) continue;
      if (pc.tieneCuarteto || _partida.quienAbrioChancho != null) {
        decirChanchoVa(_partida, jugador: pc);
        _chanchoVisiblePorCarrera = true;
      }
      if (_partida.terminada ||
          _partida.fase == FaseChancho.finRonda ||
          _partida.fase == FaseChancho.anunciando) {
        break;
      }
    }
    if (!_yo.dijoChancho && _partida.quienAbrioChancho != null) {
      decirChanchoVa(_partida, jugador: _yo);
    }
    _alResolverRonda();
  }

  /// Tras anotar letra: cartel de fin de ronda, victoria o seguir jugando.
  void _alResolverRonda() {
    _detenerCronometroChancho();
    _quienLanzoChancha = null;
    _objetivoChancha = null;
    setState(() {
      _chanchoVisiblePorCarrera = false;
    });
    if (_partida.terminada || _partida.enFinRonda) return;
    if (_partida.fase == FaseChancho.anunciando) {
      setState(() {
        _defaultsAnuncioArgentinos();
        _seleccionLocal.clear();
      });
      _talVezPc();
    }
  }

  void _continuarTrasFinRonda() {
    if (_esOnline && !_soyAnfitrionOnline) return;
    continuarTrasFinRondaChancho(_partida);
    setState(() {
      _defaultsAnuncioArgentinos();
      _seleccionLocal.clear();
    });
    if (_esOnline) unawaited(_publicarEstadoOnline());
    _talVezPc();
  }

  /// Tras CHANCHA: la ronda sigue (misma mano / mismo anunciante).
  void _despuesDeChancha() {
    _quienLanzoChancha = null;
    _objetivoChancha = null;
    // Solo cortar el cronómetro del desafío Chancha, no el de Chancho.
    if (_cronoEsRespuestaChancha) {
      _detenerCronometroChancho();
    }
    setState(() {});
    if (_esOnline) unawaited(_publicarEstadoOnline());
    if (_partida.terminada) return;
    if (_partida.fase == FaseChancho.anunciando) {
      _talVezPc();
    }
  }

  /// El humano lanza CHANCHA: 50% la PC “cae” y pierde; si no, pierde el humano.
  void _lanzarChancha() {
    if (!_puedeLanzarChancha) return;
    final pcs = _pcs;
    if (pcs.isEmpty) return;
    marcarChanchaUsadaEnRonda(_partida, _yo.nombre);
    final pcCae = _rng.nextDouble() < 0.5;
    if (pcCae) {
      final pc = pcs[_rng.nextInt(pcs.length)];
      penalizarJugadorChancho(
        _partida,
        pc,
        motivo: MotivoPenalizacionChancho.chancha,
        lanzadorChancha: _yo.nombre,
      );
      if (mounted) {
        _mostrarNotiTope('¡${pc.nombre} cayó en CHANCHA!');
      }
    } else {
      penalizarJugadorChancho(
        _partida,
        _yo,
        motivo: MotivoPenalizacionChancho.chancha,
        lanzadorChancha: _yo.nombre,
      );
      if (mounted) {
        _mostrarNotiTope('Nadie cayó. Se te anota una letra.');
      }
    }
    _despuesDeChancha();
  }

  /// El humano toca el botón inferior durante el desafío de la PC.
  void _responderChanchaDePc() {
    if (!_puedeResponderChancha) return;
    final lanzador = _quienLanzoChancha ?? 'PC';
    penalizarJugadorChancho(
      _partida,
      _yo,
      motivo: MotivoPenalizacionChancho.chancha,
      lanzadorChancha: lanzador,
    );
    if (mounted) {
      _mostrarNotiTope('Caíste en CHANCHA. Se te anota una letra.');
    }
    _despuesDeChancha();
  }

  void _onTimeoutRespuestaChancha() {
    if (!mounted || _partida.terminada || !_hayDesafioChancha) return;
    if (!_soyObjetivoChancha) return;
    final nombre = _quienLanzoChancha!;
    JugadorChancho? quien;
    for (final j in _partida.jugadores) {
      if (j.nombre == nombre) {
        quien = j;
        break;
      }
    }
    if (quien != null) {
      penalizarJugadorChancho(
        _partida,
        quien,
        motivo: MotivoPenalizacionChancho.chancha,
        lanzadorChancha: nombre,
      );
      if (mounted) {
        _mostrarNotiTope('No tocaste. Se le anota una letra a $nombre.');
      }
    }
    _despuesDeChancha();
  }

  /// 10% de chance de que alguna PC te tire CHANCHA (una vez por PC y ronda).
  bool _intentarChanchaPc() {
    if (_esOnline && !_soyAnfitrionOnline) return false;
    if (!_opciones.chancha) return false;
    if (!widget.contraPc || _partida.terminada) return false;
    if (_partida.enFinRonda) return false;
    if (_hayDesafioChancha) return false;
    if (_partida.fase == FaseChancho.eligiendoNumeros) return false;
    if (_cronoChancho.isAnimating) return false;
    final pcsDisponibles = _pcs
        .where((pc) => puedeLanzarChanchaRonda(_partida, pc.nombre))
        .toList(growable: false);
    if (pcsDisponibles.isEmpty) return false;
    if (_rng.nextDouble() >= 0.10) return false;
    final humanos = _partida.jugadores
        .where((j) => !_esPc(j) && !j.eliminado)
        .toList(growable: false);
    if (humanos.isEmpty) return false;
    final objetivo = humanos[_rng.nextInt(humanos.length)];
    final pc = pcsDisponibles[_rng.nextInt(pcsDisponibles.length)];
    marcarChanchaUsadaEnRonda(_partida, pc.nombre);
    _quienLanzoChancha = pc.nombre;
    _objetivoChancha = objetivo.nombre;
    if (_soyObjetivoChancha) {
      _iniciarCronometroRespuestaChancha();
    }
    if (_esOnline) unawaited(_publicarEstadoOnline());
    return true;
  }

  Future<void> _talVezPc() async {
    if (_esOnline && !_soyAnfitrionOnline) return;
    if (!widget.contraPc || _partida.terminada) return;
    if (_partida.enFinRonda) return;
    if (_hayDesafioChancha) return;
    final token = ++_pcToken;

    if (_partida.fase == FaseChancho.eligiendoNumeros) {
      // Humano elige números aunque sea vs PC (primer jugador).
      return;
    }

    // Cualquier PC con cuarteto debe decir Chancho antes de anunciar/pasar.
    if (_pcs.any((pc) => pc.tieneCuarteto && !pc.dijoChancho)) {
      await _talVezChanchoPc();
      if (!mounted || token != _pcToken) return;
      if (_partida.fase != FaseChancho.anunciando &&
          _partida.fase != FaseChancho.eligiendoCartas) {
        return;
      }
    }

    if (_partida.fase == FaseChancho.anunciando &&
        _esPc(_partida.jugadorActual)) {
      if (_intentarChanchaPc()) return;
      final anunciante = _partida.jugadorActual;
      if (_esPc(anunciante) && anunciante.tieneCuarteto) {
        await _talVezChanchoPc();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted || token != _pcToken) return;
      if (_hayDesafioChancha) return;
      final pc = _partida.jugadorActual;
      if (!_esPc(pc)) return;
      if (pc.tieneCuarteto) {
        await _talVezChanchoPc();
        return;
      }
      final anuncio = planificarAnuncioPcChancho(pc, _partida.ultimoAnuncio);
      anunciarPaseChancho(
        _partida,
        cantidad: anuncio.cantidad,
        direccion: anuncio.direccion,
        anunciante: pc,
      );
      setState(() {
        _cantidadAnuncio = anuncio.cantidad;
        _direccionAnuncio = anuncio.direccion;
      });
      _autoConfirmarPcSiCorresponde();
      if (_esOnline) unawaited(_publicarEstadoOnline());
      // Humano debe elegir cartas.
      setState(() {});
      return;
    }

    if (_partida.fase == FaseChancho.eligiendoCartas) {
      _autoConfirmarPcSiCorresponde();
    }

    await _talVezChanchoPc();
  }

  void _autoConfirmarPcSiCorresponde() {
    if (!widget.contraPc) return;
    if (_esOnline && !_soyAnfitrionOnline) return;
    if (_partida.fase != FaseChancho.eligiendoCartas) return;
    final anuncio = _partida.anuncioActual;
    if (anuncio == null) return;

    // Si alguna PC ya tiene cuarteto, abre Chancho en vez de romper la mano.
    if (_pcs.any((pc) => pc.tieneCuarteto && !pc.dijoChancho)) {
      unawaited(_talVezChanchoPc());
      return;
    }

    var confirmoAlguno = false;
    for (final pc in _pcs) {
      if (pc.seleccionPaseConfirmada) continue;
      if (_partida.fase != FaseChancho.eligiendoCartas) break;
      if (pc.tieneCuarteto) {
        unawaited(_talVezChanchoPc());
        return;
      }
      final cartas = elegirCartasPcChancho(pc, anuncio.cantidad);
      if (cartas.length != anuncio.cantidad) {
        // Sin cartas válidas (p. ej. cuarteto): priorizar Chancho.
        unawaited(_talVezChanchoPc());
        return;
      }
      confirmarSeleccionPaseChancho(
        _partida,
        jugador: pc,
        cartas: cartas,
      );
      confirmoAlguno = true;
    }
    if (confirmoAlguno && _esOnline) {
      unawaited(_publicarEstadoOnline());
    }
    if (_partida.fase != FaseChancho.eligiendoCartas) {
      _chanchoVisiblePorCarrera = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_despuesDePase());
      });
    }
  }

  Future<void> _talVezChanchoPc() async {
    if (_esOnline && !_soyAnfitrionOnline) return;
    if (!widget.contraPc || _partida.terminada) return;
    if (_partida.enFinRonda) return;
    if (_hayDesafioChancha) return;

    final pendientes = _pcs
        .where((pc) => !pc.dijoChancho && pcDeberiaDecirChancho(_partida, pc))
        .toList();
    if (pendientes.isEmpty) return;

    final token = ++_pcToken;
    final yaAbierta = _partida.quienAbrioChancho != null;
    await Future<void>.delayed(
      Duration(milliseconds: yaAbierta ? 200 : 120),
    );
    if (!mounted || token != _pcToken) return;

    var dijoAlguno = false;
    for (final pc in pendientes) {
      if (_partida.terminada) break;
      if (pc.dijoChancho) continue;
      if (!pcDeberiaDecirChancho(_partida, pc)) continue;
      decirChanchoVa(_partida, jugador: pc);
      dijoAlguno = true;
      setState(() {
        _chanchoVisiblePorCarrera = true;
      });
      if (_partida.fase != FaseChancho.carreraChancho) break;
      // Pequeña pausa entre PCs en la carrera.
      if (pendientes.length > 1) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        if (!mounted || token != _pcToken) return;
      }
    }

    if (dijoAlguno && _esOnline) {
      unawaited(_publicarEstadoOnline());
    }

    if (_partida.fase == FaseChancho.carreraChancho &&
        _humanoActivo &&
        !_yo.dijoChancho) {
      _iniciarCronometroChancho();
    } else if (_partida.fase == FaseChancho.finRonda ||
        _partida.fase == FaseChancho.anunciando ||
        _partida.terminada) {
      _alResolverRonda();
    }
  }

  void _reiniciar() {
    if (_esOnline && !_soyAnfitrionOnline) return;
    ChanchoStandByStore.limpiar();
    _detenerCronometroChancho();
    setState(() {
      if (widget.contraPc && !_esOnline) {
        final pcs = cantidadPcElegidaEnMenu(MenuJuegoScreen.juegoIdChanchoVa) ??
            cantidadPcEnNombres(_nombres);
        _nombres = reconstruirNombresVsPc(
          actuales: _nombres,
          cantidadPc: pcs.clamp(2, 3),
          minTotal: 3,
          maxTotal: 4,
          armarNombres: (humano, total) => TextosChancho.nombresVsPc(
            humano: humano,
            total: total,
          ),
        );
      }
      _partida = nuevaPartidaChancho(
        nombres: _nombres,
        contraPc: true,
        sinEspacio: _opciones.sinEspacio,
        finAlPrimerPerdedor: _opciones.finAlPrimerPerdedor,
      );
      _numerosElegidos.clear();
      _defaultsAnuncioArgentinos();
      _seleccionLocal.clear();
      _chanchoVisiblePorCarrera = false;
      _quienLanzoChancha = null;
      _objetivoChancha = null;
      _mostrarMenu = false;
      _mostrarAjustes = false;
      _mostrarCartelNumeros = false;
      _borradorNumeros.clear();
    });
    if (_esOnline) {
      unawaited(_publicarEstadoOnline(forzar: true));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_puedoElegirNumeros) _abrirCartelNumeros();
      _talVezPc();
    });
  }

  Future<void> _pedirReiniciarVsPc() async {
    if (!widget.contraPc || _esOnline) return;
    final ok = await confirmarReiniciarPartidaPc(context);
    if (!ok || !mounted) return;
    _reiniciar();
  }

  void _salir({required bool guardar}) {
    _pcToken++;
    _detenerCronometroChancho();
    if (_esOnline) {
      // Online: no guardar standby local.
    } else if (guardar && widget.contraPc && !_partida.terminada) {
      ChanchoStandByStore.guardar(
        PartidaChanchoResume(
          partida: _partida,
          nombres: _nombres,
          ajustesIniciales: _ajustes,
          modoDios: widget.modoDios,
          opciones: _opciones,
        ),
      );
    } else {
      ChanchoStandByStore.limpiar();
    }
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
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
            TextosChancho.reglas(),
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

  PaloEspanolVisual _paloVisual(PaloChancho p) => switch (p) {
        PaloChancho.oro => PaloEspanolVisual.oro,
        PaloChancho.copa => PaloEspanolVisual.copa,
        PaloChancho.espada => PaloEspanolVisual.espada,
        PaloChancho.basto => PaloEspanolVisual.basto,
      };

  String _labelDir(DireccionChancho? d) => switch (d) {
        null => TextosChancho.direccion,
        DireccionChancho.izquierda => TextosChancho.izquierda,
        DireccionChancho.derecha => TextosChancho.derecha,
        DireccionChancho.centro => TextosChancho.centro,
      };

  /// Cartel del anuncio ajeno mientras elegís cartas.
  bool get _mostrarCartelAnuncioPc {
    if (_partida.fase != FaseChancho.eligiendoCartas) return false;
    if (_partida.anuncioActual == null) return false;
    return _partida.jugadorActual.nombre != _yo.nombre;
  }

  /// Vista previa del anuncio mientras el humano elige cantidad/dirección.
  bool get _mostrarCartelAnuncioHumano =>
      _esTurnoHumanoAnuncio &&
      _cantidadAnuncio != null &&
      _direccionAnuncio != null;

  _CartelAnuncioPc? get _cartelAnuncioActivo {
    if (_mostrarCartelAnuncioPc) {
      return _CartelAnuncioPc(
        titulo: '${_partida.jugadorActual.nombre} dijo',
        texto: _textoAnuncioNatural(_partida.anuncioActual!),
      );
    }
    if (_mostrarCartelAnuncioHumano) {
      return _CartelAnuncioPc(
        titulo: '${_yo.nombre} elige',
        texto: _textoAnuncioNatural(
          AnuncioChancho(
            cantidad: _cantidadAnuncio!,
            direccion: _direccionAnuncio!,
          ),
        ),
      );
    }
    return null;
  }

  String _textoAnuncioNatural(AnuncioChancho a) {
    final dir = switch (a.direccion) {
      DireccionChancho.izquierda => 'a la izquierda',
      DireccionChancho.derecha => 'a la derecha',
      DireccionChancho.centro => 'al centro',
    };
    return '${a.cantidad} $dir';
  }

  String? get _textoElegirCartas {
    if (!_puedoElegirCartas) return null;
    final cupo = _cupoSeleccion;
    if (cupo <= 0) return null;
    return 'Elegí $cupo carta(s) (${_seleccionLocal.length}/$cupo)';
  }

  @override
  Widget build(BuildContext context) {
    final mano = _yo.mano;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_mostrarAjustes) {
          setState(() => _mostrarAjustes = false);
          return;
        }
        if (_mostrarMenu) {
          setState(() => _mostrarMenu = false);
          return;
        }
        setState(() {
          _mostrarMenu = true;
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(() {
                            _mostrarMenu = true;
                            _mostrarAjustes = false;
                          }),
                          icon: const Icon(Icons.menu, color: AppColors.texto),
                        ),
                        const Expanded(
                          child: Text(
                            TextosChancho.titulo,
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
                            color: AppColors.textoSuave,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _MarcadorLetras(
                      jugadores: _partida.jugadores,
                      puedeRenombrar: _puedeRenombrar,
                      onRenombrar: _renombrarJugador,
                      anuncianteNombre: !_partida.terminada &&
                              _partida.fase != FaseChancho.eligiendoNumeros
                          ? _partida.jugadorActual.nombre
                          : null,
                    ),
                    if (_textoEstado.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _textoEstado,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.acento,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final asientos = _asientosOponentes;
                          final cartel = _cartelAnuncioActivo;
                          Widget manoMesa(JugadorChancho j, {required bool lateral}) {
                            return _ManoMesaChancho(
                              jugador: j,
                              lateral: lateral,
                              bocaArriba: _modoDiosActivo && _esPc(j),
                              esAnunciante:
                                  j.nombre == _partida.jugadorActual.nombre &&
                                      !_partida.terminada &&
                                      _partida.fase !=
                                          FaseChancho.eligiendoNumeros,
                              confirmoPase: _partida.fase ==
                                      FaseChancho.eligiendoCartas &&
                                  j.seleccionPaseConfirmada,
                              paloVisual: _paloVisual,
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (asientos.izquierda != null) ...[
                                SizedBox(
                                  width: 78,
                                  child: manoMesa(
                                    asientos.izquierda!,
                                    lateral: true,
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Column(
                                  children: [
                                    if (asientos.arriba != null) ...[
                                      manoMesa(
                                        asientos.arriba!,
                                        lateral: false,
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                    Expanded(
                                      child: cartel == null
                                          ? const SizedBox.shrink()
                                          : LayoutBuilder(
                                              builder: (context, constraints) {
                                                return Center(
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: ConstrainedBox(
                                                      constraints:
                                                          BoxConstraints(
                                                        maxWidth:
                                                            constraints
                                                                .maxWidth,
                                                      ),
                                                      child: cartel,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                              if (asientos.derecha != null) ...[
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 78,
                                  child: manoMesa(
                                    asientos.derecha!,
                                    lateral: true,
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                    Text(
                      '${TextosChancho.tuMano}: ${_yo.nombre}',
                      style: const TextStyle(
                        color: AppColors.mint,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_textoElegirCartas != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _textoElegirCartas!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textoSuave,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 132,
                      width: double.infinity,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var i = 0; i < mano.length; i++) ...[
                                    if (i > 0) const SizedBox(width: 8),
                                    _CartaManoChancho(
                                      carta: mano[i],
                                      seleccionada:
                                          _seleccionLocal.contains(mano[i]),
                                      onTap: _puedoElegirCartas
                                          ? () => _toggleCarta(mano[i])
                                          : null,
                                      palo: _paloVisual(mano[i].palo),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _BotonAccion(
                            label: _cantidadAnuncio == null
                                ? TextosChancho.cantidad
                                : '${TextosChancho.cantidad}: $_cantidadAnuncio',
                            onPressed:
                                _esTurnoHumanoAnuncio ? _cicloCantidad : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _BotonAccion(
                            label: _labelDir(_direccionAnuncio),
                            onPressed:
                                _esTurnoHumanoAnuncio ? _cicloDireccion : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Opacity(
                            opacity:
                                _partida.ultimoAnuncio != null ? 1 : 0.35,
                            child: _BotonAccion(
                              label: TextosChancho.repetir,
                              onPressed: _esTurnoHumanoAnuncio &&
                                      _partida.ultimoAnuncio != null
                                  ? _repetirAnuncio
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed:
                            _puedeAnunciarPase ? _confirmarAnuncio : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.mint,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor:
                              AppColors.carta.withValues(alpha: 0.5),
                          disabledForegroundColor:
                              AppColors.textoSuave.withValues(alpha: 0.6),
                        ),
                        child: const Text(
                          TextosChancho.titulo,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_opciones.chancha) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton(
                          onPressed:
                              _puedeLanzarChancha ? _lanzarChancha : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: _puedeLanzarChancha
                                ? AppColors.acentoSuave
                                : AppColors.carta,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppColors.carta.withValues(alpha: 0.5),
                          ),
                          child: const Text(
                            TextosChancho.chancha,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_cronoChancho.isAnimating) ...[
                      AnimatedBuilder(
                        animation: _cronoChancho,
                        builder: (context, _) {
                          final resto =
                              (_segundosCronoChancho * (1 - _cronoChancho.value))
                                  .clamp(0.0, _segundosCronoChancho);
                          return Column(
                            children: [
                              Text(
                                '${resto.toStringAsFixed(1)} s',
                                style: const TextStyle(
                                  color: AppColors.acento,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: 1 - _cronoChancho.value,
                                  minHeight: 8,
                                  backgroundColor:
                                      AppColors.carta.withValues(alpha: 0.7),
                                  color: resto <= 0.5
                                      ? AppColors.peligro
                                      : AppColors.acento,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          );
                        },
                      ),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: _puedeResponderChancha
                            ? _responderChanchaDePc
                            : (_chanchoHabilitado ? _decirChancho : null),
                        style: FilledButton.styleFrom(
                          backgroundColor: (_puedeResponderChancha ||
                                  _chanchoHabilitado)
                              ? AppColors.peligro
                              : AppColors.carta,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.carta.withValues(alpha: 0.5),
                        ),
                        child: Text(
                          _puedeResponderChancha
                              ? TextosChancho.chancha
                              : TextosChancho.chancho,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_notiTopeTexto != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: IgnorePointer(
                    child: _NotiTopeChancho(texto: _notiTopeTexto!),
                  ),
                ),
              ),
            if (_mostrarCartelNumeros)
              Positioned.fill(
                child: _overlayElegirNumeros(),
              ),
            if (_partida.enFinRonda)
              Positioned.fill(
                child: _conBarraSuperiorLibre(
                  child: FinRondaChanchoOverlay(
                    partida: _partida,
                    onContinuar: _continuarTrasFinRonda,
                    continuarHabilitado: !_esOnline || _soyAnfitrionOnline,
                    labelContinuar: _esOnline && !_soyAnfitrionOnline
                        ? 'ESPERANDO AL ANFITRIÓN…'
                        : null,
                  ),
                ),
              ),
            // Solo menú y ajustes encima del oscuro (no reiniciar).
            if (!_partida.terminada &&
                (_mostrarCartelNumeros || _partida.enFinRonda) &&
                !_mostrarMenu &&
                !_mostrarAjustes)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(() {
                            _mostrarMenu = true;
                            _mostrarAjustes = false;
                          }),
                          icon: const Icon(Icons.menu, color: AppColors.texto),
                        ),
                        const Spacer(),
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
                ),
              ),
            if (_partida.terminada)
              Positioned.fill(
                child: VictoriaChanchoOverlay(
                  partida: _partida,
                  animaciones: _ajustes.animaciones,
                  onVolverAJugar: _reiniciar,
                  onVolver: () => _salir(guardar: false),
                ),
              ),
            // Menú y ajustes por encima de carteles de juego.
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
                child: MenuPartidaChanchoVa(
                  jugador: _yo.nombre,
                  partidaTerminada: _partida.terminada,
                  onCerrar: () => setState(() => _mostrarMenu = false),
                  onReglas: () {
                    setState(() => _mostrarMenu = false);
                    _mostrarReglas();
                  },
                  onSalir: () {
                    setState(() => _mostrarMenu = false);
                    _salir(
                      guardar:
                          !_esOnline && widget.contraPc && !_partida.terminada,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Deja clickeable la barra superior (menú / ajustes).
  Widget _conBarraSuperiorLibre({required Widget child}) {
    final topLibre = MediaQuery.paddingOf(context).top + 56;
    return Column(
      children: [
        IgnorePointer(child: SizedBox(height: topLibre)),
        Expanded(child: child),
      ],
    );
  }

  /// Cartel de números: oscurece toda la pantalla (menú/ajustes van encima).
  Widget _overlayElegirNumeros() {
    final cupo = _partida.cantidadJugadores;
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${TextosChancho.eligeNumeros} ($cupo)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.acento,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final n in numerosChanchoDisponibles)
                        Builder(
                          builder: (context) {
                            final sel = _borradorNumeros.contains(n);
                            return Opacity(
                              opacity: sel ? 0.45 : 1,
                              child: OutlinedButton(
                                onPressed: () => _toggleNumeroBorrador(n),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.texto,
                                  side: BorderSide(
                                    color: sel
                                        ? AppColors.acento
                                        : AppColors.cartaBorde,
                                    width: sel ? 2 : 1.2,
                                  ),
                                  minimumSize: const Size(44, 44),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                child: Text(
                                  '$n',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _borradorNumeros.isEmpty
                        ? 'Cartas con N°:'
                        : 'Cartas con N°: ${_borradorNumeros.join('-')}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _borradorNumeros.length == cupo
                        ? _confirmarNumerosCartel
                        : null,
                    child: const Text(TextosChancho.confirmarNumeros),
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

class _NotiTopeChancho extends StatelessWidget {
  const _NotiTopeChancho({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(48, 6, 48, 0),
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6A3DE8),
                  Color(0xFF4A1FB8),
                  Color(0xFF3B158F),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.violeta.withValues(alpha: 0.95),
                width: 1.4,
              ),
              boxShadow: [
                ...neonGlow(AppColors.violeta, blur: 12),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.acento,
                      shape: BoxShape.circle,
                      boxShadow: neonGlow(AppColors.acento, blur: 6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      texto,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        height: 1.2,
                        letterSpacing: 0.2,
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

class _CartelAnuncioPc extends StatelessWidget {
  const _CartelAnuncioPc({
    required this.titulo,
    required this.texto,
  });

  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.azul, width: 2),
        boxShadow: neonGlow(AppColors.azul, blur: 14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            titulo,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textoSuave.withValues(alpha: 0.95),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            texto,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.acento,
              fontWeight: FontWeight.w900,
              fontSize: 26,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarcadorLetras extends StatelessWidget {
  const _MarcadorLetras({
    required this.jugadores,
    required this.puedeRenombrar,
    required this.onRenombrar,
    this.anuncianteNombre,
  });

  final List<JugadorChancho> jugadores;
  final bool Function(int index) puedeRenombrar;
  final Future<void> Function(int index) onRenombrar;
  final String? anuncianteNombre;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < jugadores.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0A33),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: anuncianteNombre == jugadores[i].nombre
                      ? AppColors.acento
                      : AppColors.violeta,
                  width: anuncianteNombre == jugadores[i].nombre ? 1.8 : 1,
                ),
              ),
              child: Column(
                children: [
                  NombreJugadorEditable(
                    nombre: jugadores[i].nombre,
                    puedeRenombrar: puedeRenombrar(i),
                    onRenombrar:
                        puedeRenombrar(i) ? () => onRenombrar(i) : null,
                    fontSize: 12,
                    tachado: jugadores[i].eliminado,
                    colorTexto: jugadores[i].eliminado
                        ? AppColors.textoSuave
                        : AppColors.texto,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    jugadores[i].letrasTexto,
                    style: TextStyle(
                      color: jugadores[i].eliminado
                          ? AppColors.peligro
                          : AppColors.acento,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ManoMesaChancho extends StatelessWidget {
  const _ManoMesaChancho({
    required this.jugador,
    required this.lateral,
    required this.bocaArriba,
    required this.esAnunciante,
    required this.confirmoPase,
    required this.paloVisual,
  });

  final JugadorChancho jugador;
  final bool lateral;
  final bool bocaArriba;
  final bool esAnunciante;
  final bool confirmoPase;
  final PaloEspanolVisual Function(PaloChancho) paloVisual;

  static const double _w = 42;
  static const double _h = 60;

  @override
  Widget build(BuildContext context) {
    final cartas = jugador.mano;
    final titulo = jugador.eliminado
        ? '${jugador.nombre} (fuera)'
        : jugador.nombre;

    final etiqueta = Text(
      confirmoPase ? '$titulo · ✓' : titulo,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: esAnunciante ? AppColors.acento : AppColors.textoSuave,
        fontWeight: FontWeight.w800,
        fontSize: 11,
      ),
    );

    Widget cartaWidget(CartaChancho c) {
      return CartaEspanolaSkin(
        numero: c.numero,
        etiqueta: c.etiqueta,
        palo: paloVisual(c.palo),
        bocaArriba: bocaArriba,
        compacta: true,
        width: _w,
        height: _h,
      );
    }

    final mano = cartas.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Sin cartas',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textoSuave.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        : lateral
            ? Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final overlap = cartas.length <= 4
                        ? 10.0
                        : (constraints.maxHeight / cartas.length).clamp(8.0, 14.0);
                    final totalH = _h + (cartas.length - 1) * overlap;
                    return Center(
                      child: SizedBox(
                        height: totalH.clamp(0, constraints.maxHeight),
                        width: _w + 4,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (var i = 0; i < cartas.length; i++)
                              Positioned(
                                top: i * overlap,
                                left: 2,
                                child: cartaWidget(cartas[i]),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            : SizedBox(
                height: _h + 4,
                width: double.infinity,
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < cartas.length; i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          cartaWidget(cartas[i]),
                        ],
                      ],
                    ),
                  ),
                ),
              );

    return Opacity(
      opacity: jugador.eliminado ? 0.45 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: esAnunciante
                ? AppColors.acento.withValues(alpha: 0.65)
                : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: lateral
              ? Column(
                  children: [
                    etiqueta,
                    const SizedBox(height: 4),
                    mano,
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    etiqueta,
                    const SizedBox(height: 4),
                    mano,
                  ],
                ),
        ),
      ),
    );
  }
}

class _CartaManoChancho extends StatelessWidget {
  const _CartaManoChancho({
    required this.carta,
    required this.seleccionada,
    required this.palo,
    this.onTap,
  });

  final CartaChancho carta;
  final bool seleccionada;
  final PaloEspanolVisual palo;
  final VoidCallback? onTap;

  static const double _cardW = 78;
  static const double _cardH = 118;
  static const double _deslizamiento = 14;

  @override
  Widget build(BuildContext context) {
    final skin = CartaEspanolaSkin(
      numero: carta.numero,
      etiqueta: carta.etiqueta,
      palo: palo,
      seleccionada: seleccionada,
      width: _cardW,
      height: _cardH,
    );
    // Slot fijo: al seleccionar, la carta queda arriba (como en Escoba).
    final tarjeta = SizedBox(
      width: _cardW,
      height: _cardH + _deslizamiento,
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        alignment:
            seleccionada ? Alignment.topCenter : Alignment.bottomCenter,
        child: skin,
      ),
    );
    if (onTap == null) return tarjeta;
    // Sin hover si no está seleccionada (evita el rectángulo feo).
    // Con selección, el InkWell pinta el sombreado en el hueco de abajo.
    if (!seleccionada) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: tarjeta,
      );
    }
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: colorSeleccionCartaEspanola.withValues(alpha: 0.25),
        highlightColor: colorSeleccionCartaEspanola.withValues(alpha: 0.18),
        hoverColor: colorSeleccionCartaEspanola.withValues(alpha: 0.22),
        child: tarjeta,
      ),
    );
  }
}

class _BotonAccion extends StatelessWidget {
  const _BotonAccion({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}
