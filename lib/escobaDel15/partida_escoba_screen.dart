import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/escobaDel15/escoba_online_codec.dart';
import 'package:app_juegos_mesa/escobaDel15/marcador_palitos.dart';
import 'package:app_juegos_mesa/escobaDel15/menu_partida_escoba.dart';
import 'package:app_juegos_mesa/escobaDel15/motor_escoba.dart';
import 'package:app_juegos_mesa/escobaDel15/opciones_escoba.dart';
import 'package:app_juegos_mesa/escobaDel15/resumen_ronda_escoba_overlay.dart';
import 'package:app_juegos_mesa/escobaDel15/standby_store.dart';
import 'package:app_juegos_mesa/escobaDel15/textos.dart';
import 'package:app_juegos_mesa/escobaDel15/victoria_escoba_overlay.dart';
import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/cartas/animacion_orden_mano.dart';
import 'package:app_juegos_mesa/shared/cartas/boton_ordenar_mano.dart';
import 'package:app_juegos_mesa/shared/cartas/carta_espanola_skin.dart';
import 'package:app_juegos_mesa/shared/cartas/ordenar_mano_cartas.dart';
import 'package:app_juegos_mesa/shared/cartas/reordenar_carta_mano.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/monedas/monedas_store.dart';
import 'package:app_juegos_mesa/shared/monedas/premiar_monedas_victoria_pc.dart';
import 'package:app_juegos_mesa/shared/partida_ui/epic_backdrop.dart';
import 'package:app_juegos_mesa/shared/partida_ui/reiniciar_partida_pc.dart';
import 'package:app_juegos_mesa/shared/partida_ui/nombre_jugador_editable.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Partida de Escoba del 15.
class PartidaEscobaScreen extends StatefulWidget {
  const PartidaEscobaScreen({
    super.key,
    required this.nombres,
    this.contraPc = false,
    this.salaCodigo,
    this.miNombre,
    this.ajustesIniciales,
    this.resume,
    this.modoDios = false,
    this.opciones = const OpcionesEscoba(),
  });

  final List<String> nombres;
  final bool contraPc;
  final String? salaCodigo;
  final String? miNombre;
  final AjustesEstado? ajustesIniciales;
  final PartidaEscobaResume? resume;
  final bool modoDios;
  final OpcionesEscoba opciones;

  @override
  State<PartidaEscobaScreen> createState() => _PartidaEscobaScreenState();
}

class _PartidaEscobaScreenState extends State<PartidaEscobaScreen> {
  late PartidaEscoba _partida;
  late List<String> _nombres;
  late OpcionesEscoba _opciones;
  AjustesEstado _ajustes = const AjustesEstado();
  bool _mostrarMenu = false;
  bool _mostrarAjustes = false;
  bool _confirmarRendicion = false;
  String? _aviso;
  CartaEscoba? _cartaSeleccionada;
  final List<CartaEscoba> _mesaSeleccion = [];
  /// Último modo de orden aplicado con el botón (null = aún no se usó).
  ModoOrdenManoCartas? _modoOrdenMano;
  /// Se incrementa al ordenar para disparar la animación de deslizamiento.
  int _ordenAnimGen = 0;
  /// Copia del orden de la mano justo antes del último ordenado automático.
  List<CartaEscoba>? _ordenAntesAnim;
  bool _pcMostrandoJugada = false;
  String? _mensajePc;
  int _pcToken = 0;
  /// Cuántas cartas de mesa se muestran (revelado izq→der).
  int _mesaReveladas = 4;
  bool _revelandoMesa = false;
  int _reveladoToken = 0;

  StreamSubscription<Sala>? _onlineSub;
  int _onlineVersion = 0;
  bool _publicandoOnline = false;
  bool _mazoPublicado = false;
  bool _esperandoMazoOnline = false;
  Map<String, dynamic>? _ultimaJugadaParaPublicar;

  bool get _esOnline =>
      widget.salaCodigo != null &&
      widget.salaCodigo!.isNotEmpty &&
      widget.miNombre != null &&
      widget.miNombre!.isNotEmpty;

  bool get _esMiTurno =>
      !_esOnline || _partida.jugadorActual.nombre == widget.miNombre;

  bool get _soyAnfitrionOnline =>
      _esOnline &&
      _partida.jugadores.isNotEmpty &&
      _partida.jugadores.first.nombre == widget.miNombre;

  bool get _esperandoRivalOnline =>
      _esOnline && (!_esMiTurno || _esperandoMazoOnline);

  bool get _mostrarResumenRonda {
    final r = _partida.ultimoResultado;
    if (r == null) return false;
    return _partida.fase == FaseEscoba.finRonda;
  }

  bool get _esPcTurno {
    if (!widget.contraPc) return false;
    return esNombrePc(_partida.jugadorActual.nombre);
  }

  bool get _bloquearHumano =>
      _esPcTurno ||
      _pcMostrandoJugada ||
      _esperandoRivalOnline ||
      _revelandoMesa ||
      (_esOnline && !_esMiTurno);

  List<CartaEscoba> get _mesaParaMostrar {
    if (!_opciones.escobasAutomaticasInicio ||
        _mesaReveladas >= _partida.mesa.length) {
      return _partida.mesa;
    }
    return _partida.mesa.take(_mesaReveladas).toList();
  }

  JugadorEscoba get _manoVisible {
    if (_esOnline) {
      return _partida.jugadores.firstWhere(
        (j) => j.nombre == widget.miNombre,
        orElse: () => _partida.jugadores.first,
      );
    }
    if (!widget.contraPc) return _partida.jugadorActual;
    return _partida.jugadores.firstWhere(
      (j) => !esNombrePc(j.nombre),
      orElse: () => _partida.jugadores.first,
    );
  }

  static const int _maxNombre = 15;

  bool _puedeRenombrar(int index) {
    if (_partida.terminada || _esOnline) return false;
    if (index < 0 || index >= _partida.jugadores.length) return false;
    return !esNombrePc(_partida.jugadores[index].nombre);
  }

  String? _validarNombre(String nombre, int index) {
    if (nombre.isEmpty) return 'El nombre no puede estar vacío.';
    if (nombre.length > _maxNombre) {
      return 'Máximo $_maxNombre caracteres.';
    }
    if (esNombrePc(nombre)) return 'Ese nombre está reservado.';
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
      final anterior = _partida.jugadores[index].nombre;
      _partida.jugadores[index].nombre = nuevo;
      _nombres[index] = nuevo;
      if (_partida.ganador == anterior) {
        _partida.ganador = nuevo;
      }
      if (_partida.mensajeFin != null &&
          _partida.mensajeFin!.contains(anterior)) {
        _partida.mensajeFin =
            _partida.mensajeFin!.replaceFirst(anterior, nuevo);
      }
    });
  }

  int get _sumaMesa =>
      _mesaSeleccion.fold<int>(0, (s, c) => s + c.valorSuma);

  int get _sumaSeleccion {
    final mano = _cartaSeleccionada?.valorSuma ?? 0;
    return mano + _sumaMesa;
  }

  bool get _haySeleccion =>
      _cartaSeleccionada != null || _mesaSeleccion.isNotEmpty;

  bool get _faltaCartaMano =>
      _cartaSeleccionada == null &&
      _mesaSeleccion.isNotEmpty &&
      _sumaMesa == 15;

  bool get _puedeCapturar =>
      !_bloquearHumano &&
      _cartaSeleccionada != null &&
      _mesaSeleccion.isNotEmpty &&
      _sumaSeleccion == 15;

  bool get _puedeTirar =>
      !_bloquearHumano &&
      _cartaSeleccionada != null &&
      _sumaSeleccion != 15;

  String get _textoEstadoPartida {
    if (_esperandoMazoOnline) {
      return _soyAnfitrionOnline
          ? 'Preparando mazo compartido…'
          : 'Esperando el mazo del anfitrión…';
    }
    if (_revelandoMesa) return 'Revelando la mesa…';
    if (_partida.fase == FaseEscoba.finRonda) return 'Fin de ronda';
    if (_pcMostrandoJugada) return '¡Mirá la jugada de la PC!';
    if (_esPcTurno) return 'Turno de la PC…';
    if (_esOnline && !_esMiTurno) {
      return 'Turno de ${_partida.jugadorActual.nombre}…';
    }
    if (!_haySeleccion) {
      return _mensajePc != null
          ? 'Tu turno'
          : 'Elegí cartas de la mesa y/o de tu mano';
    }
    return 'Suma: $_sumaSeleccion / 15'
        '${_puedeCapturar ? ' · ¡listo para capturar!' : _cartaSeleccionada == null ? ' · falta tu carta' : ''}';
  }

  @override
  void initState() {
    super.initState();
    final resume = widget.resume;
    if (resume != null) {
      _nombres = List.of(resume.nombres);
      _ajustes = resume.ajustesIniciales;
      _opciones = resume.opciones;
      _partida = resume.partida;
      _mesaReveladas = _partida.mesa.length;
      _limpiarSeleccion();
      _mensajePc = null;
      _pcMostrandoJugada = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezPc());
      return;
    }
    _nombres = List.of(widget.nombres);
    _ajustes = widget.ajustesIniciales ?? const AjustesEstado();
    _opciones = widget.opciones;
    if (_esOnline) {
      _esperandoMazoOnline = true;
      _partida = nuevaPartidaEscoba(nombres: _nombres);
      // Vaciar hasta sync (evita jugar con mazo local distinto).
      _partida.mazo.clear();
      _partida.mesa.clear();
      for (final j in _partida.jugadores) {
        j.mano.clear();
        j.capturadas.clear();
        j.combos.clear();
      }
      _mesaReveladas = 0;
      _iniciarSincronizacionOnline();
      return;
    }
    _partida = nuevaPartidaEscoba(nombres: _nombres);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_revelarMesaYEscobasAuto(luegoPc: true));
    });
  }

  /// Revela la mesa de izquierda a derecha si la opción está activa;
  /// aplica escobas automáticas al terminar.
  Future<void> _revelarMesaYEscobasAuto({bool luegoPc = false}) async {
    if (!mounted) return;
    if (!_opciones.escobasAutomaticasInicio || _partida.mesa.length < 4) {
      setState(() {
        _mesaReveladas = _partida.mesa.length;
        _revelandoMesa = false;
      });
      if (luegoPc) _talVezPc();
      return;
    }

    final token = ++_reveladoToken;
    _pcToken++; // cancela PC a mitad de revelado
    setState(() {
      _revelandoMesa = true;
      _mesaReveladas = 0;
      _limpiarSeleccion();
        _aviso = null;
      });

    for (var i = 1; i <= 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 480));
      if (!mounted || token != _reveladoToken) return;
      setState(() => _mesaReveladas = i);

      // Tras el par izquierdo: si suma 15, lo marca seleccionado.
      if (i == 2 && mesaParIzquierdoEsEscoba(_partida.mesa)) {
        setState(() {
          _mesaSeleccion
            ..clear()
            ..addAll(_partida.mesa.take(2));
        });
      }
    }
    if (!mounted || token != _reveladoToken) return;

    final ambosEscoba = mesaParIzquierdoEsEscoba(_partida.mesa) &&
        mesaParDerechoEsEscoba(_partida.mesa);

    if (ambosEscoba) {
      // Selecciona las 2 escobas un momento y luego las adjudica.
      setState(() {
        _mesaSeleccion
          ..clear()
          ..addAll(_partida.mesa);
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted || token != _reveladoToken) return;
    }

    final resultado = aplicarEscobasAutomaticasInicio(_partida);
    if (!mounted || token != _reveladoToken) return;

      setState(() {
      _revelandoMesa = false;
      _mesaReveladas = _partida.mesa.length;
      _limpiarSeleccion();
      if (resultado == null) {
        _aviso = null;
      } else if (resultado.dosParesEscoba) {
        _aviso =
            '¡2 escobas al repartir! → ${resultado.nombreBeneficiario}';
      } else if (resultado.mesaSuma15) {
        _aviso =
            'Mesa = 15 → ${resultado.nombreBeneficiario} suma 1 escoba';
      }
    });

    if (luegoPc && mounted) _talVezPc();
  }

  @override
  void dispose() {
    _onlineSub?.cancel();
    _pcToken++;
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
    // Si el seed del servidor no es Escoba (p. ej. deploy viejo), el anfitrión
    // publica el mazo y sobreescribe el estado.
    if (juego != 'escobaDel15') {
      if (_soyAnfitrionOnline && !_mazoPublicado) {
        unawaited(_publicarMazoInicialOnline());
      }
      return;
    }

    final version = (gameState['version'] as num?)?.toInt() ?? 0;
    if (version < _onlineVersion) return;
    if (_publicandoOnline && version <= _onlineVersion) return;

    final tieneMazo = escobaPartidaGenerada(gameState);
    if (!tieneMazo) {
      if (_soyAnfitrionOnline && !_mazoPublicado) {
        unawaited(_publicarMazoInicialOnline());
      }
      return;
    }

    if (version <= _onlineVersion && !_esperandoMazoOnline) return;

    final ultima = gameState['ultimaJugada'];
    Map<String, dynamic>? jugadaMap;
    if (ultima is Map) {
      jugadaMap = Map<String, dynamic>.from(ultima);
    }

      setState(() {
      applyEscobaGameState(_partida, gameState);
      _nombres = [for (final j in _partida.jugadores) j.nombre];
      _onlineVersion = version;
      _esperandoMazoOnline = false;
      _mazoPublicado = true;
      if (!_esMiTurno) {
        _limpiarSeleccion();
      }
      final desc = jugadaMap?['descripcion']?.toString();
      final quien = jugadaMap?['jugador']?.toString();
      if (desc != null &&
          quien != null &&
          quien != widget.miNombre) {
        // Mostrar lo que hizo el rival aunque ahora sea mi turno.
        _mensajePc = desc;
        _aviso = null;
      } else if (_esMiTurno) {
        _mensajePc = null;
      }
    });
  }

  Future<void> _publicarMazoInicialOnline() async {
    if (!_esOnline || _mazoPublicado || _publicandoOnline) return;
    final generada = nuevaPartidaEscoba(nombres: _nombres);
    if (_opciones.escobasAutomaticasInicio) {
      aplicarEscobasAutomaticasInicio(generada);
    }
    setState(() {
      _partida = generada;
      _esperandoMazoOnline = false;
      _mazoPublicado = true;
      _mesaReveladas = generada.mesa.length;
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
        final gameState = encodeEscobaGameState(
          partida: _partida,
          version: _onlineVersion,
          ultimaJugada: _ultimaJugadaParaPublicar,
          opciones: _opciones,
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

  void _limpiarSeleccion() {
        _cartaSeleccionada = null;
        _mesaSeleccion.clear();
    _aviso = null;
  }

  Future<void> _talVezPc() async {
    if (_esOnline) return;
    if (!mounted || !_esPcTurno || _partida.terminada) return;
    if (_partida.fase == FaseEscoba.finRonda) return;
    if (_partida.fase == FaseEscoba.ganado) return;
    final token = _pcToken;

    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted || token != _pcToken) return;
    if (!_esPcTurno || _partida.fase != FaseEscoba.jugando) return;

    final jugada = planificarTurnoPcEscoba(_partida);
    if (jugada == null) return;

    setState(() {
      _pcMostrandoJugada = true;
      _mensajePc = jugada.descripcion;
      _cartaSeleccionada = jugada.carta;
      _mesaSeleccion
        ..clear()
        ..addAll(jugada.mesaElegida ?? const []);
      _aviso = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted || token != _pcToken) return;

    setState(() {
      ejecutarJugadaPcEscoba(_partida, jugada);
      _pcMostrandoJugada = false;
      _cartaSeleccionada = null;
      _mesaSeleccion.clear();
      _aviso = _mensajePc;
    });

    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted || token != _pcToken) return;
    if (_partida.fase == FaseEscoba.jugando && _esPcTurno) {
      setState(() {
        _mensajePc = null;
        _aviso = null;
      });
      await _talVezPc();
    }
  }

  Future<void> _seleccionarMano(CartaEscoba carta) async {
    if (_partida.fase != FaseEscoba.jugando || _bloquearHumano) return;
    setState(() {
      _mensajePc = null;
      if (_cartaSeleccionada == carta) {
        _cartaSeleccionada = null;
        if (_mesaSeleccion.isEmpty) {
          _aviso = null;
        } else if (_sumaMesa == 15) {
          _aviso =
              '¡Debés elegir una carta de tu mano sí o sí para poder capturar!';
        } else {
          _aviso = 'Suma del pozo: $_sumaMesa / 15';
        }
        return;
      }
      _cartaSeleccionada = carta;
      if (_mesaSeleccion.isEmpty) {
        _aviso =
            'Elegí cartas de la mesa o tocá TIRAR para dejar ${carta.etiqueta}';
      } else {
        final suma = carta.valorSuma + _sumaMesa;
        _aviso = suma == 15
            ? '¡Suma 15! Solo podés capturar, no tirar.'
            : 'Suma: $suma / 15';
      }
    });
  }

  void _reordenarMano(int desde, int hacia) {
    if (_bloquearHumano || _partida.fase != FaseEscoba.jugando) return;
    final mano = _manoVisible.mano;
    if (desde < 0 ||
        hacia < 0 ||
        desde >= mano.length ||
        hacia >= mano.length) {
      return;
    }
    if (desde == hacia) return;
    final carta = mano.removeAt(desde);
    mano.insert(hacia, carta);
    setState(() {});
    if (_esOnline) unawaited(_publicarEstadoOnline());
  }

  void _ciclarOrdenMano() {
    if (_bloquearHumano || _partida.fase != FaseEscoba.jugando) return;
    final mano = _manoVisible.mano;
    if (mano.length < 2) return;
    // Copia antes de ordenar in-place: sin esto no hay deltas ni animación.
    final ordenAntes = List<CartaEscoba>.of(mano);
    final modo = ciclarOrdenManoCartas(
      mano,
      modoActual: _modoOrdenMano,
      claves: (c) => ClavesOrdenCarta(
        numero: c.numero,
        palo: c.palo.index,
      ),
    );
    setState(() {
      _modoOrdenMano = modo;
      _ordenAntesAnim = ordenAntes;
      _ordenAnimGen++;
    });
    if (_esOnline) unawaited(_publicarEstadoOnline());
  }

  void _toggleMesa(CartaEscoba c) {
    if (_partida.fase != FaseEscoba.jugando || _bloquearHumano) return;
    setState(() {
      _mensajePc = null;
      if (_mesaSeleccion.contains(c)) {
        _mesaSeleccion.remove(c);
      } else {
        _mesaSeleccion.add(c);
      }
      if (_cartaSeleccionada == null && _mesaSeleccion.isEmpty) {
        _aviso = null;
      } else if (_cartaSeleccionada == null && _sumaMesa == 15) {
        _aviso =
            '¡Debés elegir una carta de tu mano sí o sí para poder capturar!';
      } else if (_cartaSeleccionada == null) {
        _aviso = 'Suma del pozo: $_sumaMesa / 15';
      } else if (_mesaSeleccion.isNotEmpty) {
        final suma = _cartaSeleccionada!.valorSuma + _sumaMesa;
        _aviso = suma == 15
            ? '¡Suma 15! Solo podés capturar, no tirar.'
            : 'Suma: $suma / 15';
      }
    });
  }

  void _tirarAMesa() {
    if (_esOnline && !_esMiTurno) return;
    final carta = _cartaSeleccionada;
    if (carta == null || !_puedeTirar) return;
    final jugador = _partida.jugadorActual.nombre;
    final err = jugarCartaEscoba(_partida, carta, forzarTirar: true);
    setState(() {
      _aviso = err;
      if (err == null) {
        _ultimaJugadaParaPublicar = encodeUltimaJugadaEscoba(
          jugador: jugador,
          carta: carta,
          tiro: true,
        );
        _mensajePc = null;
        _limpiarSeleccion();
      }
    });
    if (err == null) {
      unawaited(_publicarEstadoOnline());
      _talVezPc();
    }
  }

  void _confirmarCaptura() {
    if (_esOnline && !_esMiTurno) return;
    final carta = _cartaSeleccionada;
    if (carta == null || !_puedeCapturar) return;
    final jugador = _partida.jugadorActual.nombre;
    final mesa = List.of(_mesaSeleccion);
    final err = jugarCartaEscoba(
      _partida,
      carta,
      mesaElegida: mesa,
    );
    setState(() {
      _aviso = err;
      if (err == null) {
        _ultimaJugadaParaPublicar = encodeUltimaJugadaEscoba(
          jugador: jugador,
          carta: carta,
          mesaElegida: mesa,
          tiro: false,
        );
        _mensajePc = null;
        _limpiarSeleccion();
      }
    });
    if (err == null) {
      unawaited(_publicarEstadoOnline());
      _talVezPc();
    }
  }

  void _continuarRonda() {
    if (_esOnline && !_soyAnfitrionOnline) return;
    final r = _partida.ultimoResultado;
    final avisoPozo = (r != null &&
            r.idxLlevoPozo != null &&
            r.cartasPozoFinal.isNotEmpty)
        ? 'Pozo final → ${r.detalles[r.idxLlevoPozo!].nombre}: '
            '${r.cartasPozoFinal.map((c) => c.etiqueta).join(' · ')}'
        : null;
    setState(() {
      siguienteRondaEscoba(_partida);
      _partida.ultimoResultado = null;
      _ultimaJugadaParaPublicar = null;
      _limpiarSeleccion();
      _mensajePc = null;
      _aviso = avisoPozo;
      _mesaReveladas = _opciones.escobasAutomaticasInicio ? 0 : _partida.mesa.length;
    });
    if (_esOnline) {
      // Online: aplicar al toque (sin animación) para sincronizar estado.
      if (_opciones.escobasAutomaticasInicio) {
        final res = aplicarEscobasAutomaticasInicio(_partida);
        setState(() {
          _mesaReveladas = _partida.mesa.length;
          if (res?.dosParesEscoba == true) {
            _aviso =
                '¡2 escobas al repartir! → ${res!.nombreBeneficiario}';
          } else if (res?.mesaSuma15 == true) {
            _aviso =
                'Mesa = 15 → ${res!.nombreBeneficiario} suma 1 escoba';
          }
        });
      }
      unawaited(_publicarEstadoOnline());
      return;
    }
    unawaited(_publicarEstadoOnline());
    if (_partida.fase == FaseEscoba.jugando) {
      unawaited(_revelarMesaYEscobasAuto(luegoPc: true));
    }
  }

  void _volverAJugar() {
    if (_esOnline) return;
    EscobaStandByStore.limpiar();
    setState(() {
      if (widget.contraPc) {
        final pcs = cantidadPcElegidaEnMenu(MenuJuegoScreen.juegoIdEscobaDel15) ??
            cantidadPcEnNombres(_nombres);
        _nombres = reconstruirNombresVsPc(actuales: _nombres, cantidadPc: pcs);
      }
      _partida = nuevaPartidaEscoba(nombres: _nombres);
      _limpiarSeleccion();
      _mensajePc = null;
      _pcMostrandoJugada = false;
      _mostrarMenu = false;
      _mostrarAjustes = false;
      _confirmarRendicion = false;
      _mesaReveladas = _opciones.escobasAutomaticasInicio ? 0 : _partida.mesa.length;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_revelarMesaYEscobasAuto(luegoPc: true));
    });
  }

  Future<void> _pedirReiniciarVsPc() async {
    if (!widget.contraPc || _esOnline) return;
    final ok = await confirmarReiniciarPartidaPc(context);
    if (!ok || !mounted) return;
    _volverAJugar();
  }

  void _salirAlMenu() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _salirGuardandoResumeYVolverAlMenu() {
    if (!widget.contraPc) return;
    if (_partida.terminada) {
      EscobaStandByStore.limpiar();
      _salirAlMenu();
      return;
    }
    EscobaStandByStore.guardar(
      PartidaEscobaResume(
        partida: _partida,
        nombres: _nombres,
        ajustesIniciales: _ajustes,
        modoDios: widget.modoDios,
        opciones: _opciones,
      ),
    );
    _pcToken++;
    _salirAlMenu();
  }

  int get _idxManoForzar {
    if (widget.contraPc) {
      return _partida.jugadores.indexWhere((j) => !esNombrePc(j.nombre));
    }
    return _partida.indiceTurno % _partida.jugadores.length;
  }

  Future<void> _abrirForzarCartas() async {
    if (_esOnline) return;
    if (!widget.modoDios || _partida.terminada || _bloquearHumano) return;
    if (_partida.fase != FaseEscoba.jugando) return;

    final cupoMesa = _partida.mesa.length;
    final cupoMano = _manoVisible.mano.length;
    if (cupoMesa == 0 && cupoMano == 0) {
      setState(() => _aviso = 'No hay cartas en mesa ni en mano para forzar.');
      return;
    }

    final capturadas = <CartaEscoba>{
      for (final j in _partida.jugadores) ...j.capturadas,
    };

    final resultado = await showDialog<_ForzarCartasResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DialogoForzarCartasEscoba(
        mesaInicial: List.of(_partida.mesa),
        manoInicial: List.of(_manoVisible.mano),
        cupoMesa: cupoMesa,
        cupoMano: cupoMano,
        excluidas: capturadas,
      ),
    );
    if (resultado == null || !mounted) return;

    setState(() {
      _limpiarSeleccion();
      _mensajePc = null;

      final mesaElegidas = List.of(resultado.mesa);
      final manoElegidas = List.of(resultado.mano);

      final mesaFinal = completarCartasEscobaConAzar(
        mesaElegidas,
        cupoMesa,
        ocupadas: {...manoElegidas, ...capturadas},
      );
      final manoFinal = completarCartasEscobaConAzar(
        manoElegidas,
        cupoMano,
        ocupadas: {...mesaFinal, ...capturadas},
      );

      if (cupoMesa > 0) forzarMesaEscoba(_partida, mesaFinal);
      if (cupoMano > 0) {
        final idx = _idxManoForzar;
        if (idx >= 0) forzarManoEscoba(_partida, idx, manoFinal);
      }

      // Con escobas automáticas: si la mesa forzada tiene 2 pares de 15
      // (o suma 15), se adjudican al jugador de turno.
      String aviso = 'Cartas forzadas aplicadas.';
      if (_opciones.escobasAutomaticasInicio && _partida.mesa.length == 4) {
        final auto = aplicarEscobasAutomaticasInicio(_partida);
        _mesaReveladas = _partida.mesa.length;
        if (auto?.dosParesEscoba == true) {
          aviso =
              '¡2 escobas al repartir! → ${auto!.nombreBeneficiario}';
        } else if (auto?.mesaSuma15 == true) {
          aviso =
              'Mesa = 15 → ${auto!.nombreBeneficiario} suma 1 escoba';
        }
      }
      _aviso = aviso;
    });
  }

  void _rendirse() {
    if (_partida.terminada) return;
    if (widget.contraPc && !_esOnline) return;
    final yo = _esOnline
        ? (widget.miNombre ?? _partida.jugadorActual.nombre)
        : _partida.jugadorActual.nombre;
    final ya = _partida.jugadores.where((j) => j.nombre == yo);
    if (ya.isEmpty || ya.first.rendido) return;

    setState(() {
      _mostrarMenu = false;
      _confirmarRendicion = false;
      _limpiarSeleccion();
      _mensajePc = null;
      _pcMostrandoJugada = false;
      rendirseEscoba(_partida, yo);
      _aviso = _partida.terminada
          ? null
          : '$yo se rindió. La partida continúa.';
      _ultimaJugadaParaPublicar = null;
    });
    unawaited(_publicarEstadoOnline(forzar: true));

    // Online con más de un activo: el que se rinde vuelve al menú.
    if (_esOnline && !_partida.terminada && mounted) {
      Navigator.of(context).pop();
      return;
    }
    if (_partida.fase == FaseEscoba.jugando) _talVezPc();
  }

  void _abrirCombos(JugadorEscoba jugador) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.carta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _HojaCombosJugador(
        jugador: jugador,
        esRondaAnterior: _partida.reiniciarCombosEnProximaJugada,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mano = _manoVisible;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Stack(
        children: [
          const Positioned.fill(
            child: EpicBackdrop(centerY: 0.45, fadeRayosAlCentro: true),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => setState(() {
                          _mostrarMenu = true;
                          _confirmarRendicion = false;
                        }),
                        icon: const Icon(Icons.menu, color: AppColors.texto),
                      ),
                      const Expanded(
                        child: Center(
                        child: Text(
                            'Escoba del 15',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                            color: AppColors.mint,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      ),
                      if (widget.contraPc && !_esOnline)
                        BotonReiniciarPartidaPc(onPressed: _pedirReiniciarVsPc),
                      IconButton(
                        onPressed: () =>
                            setState(() => _mostrarAjustes = true),
                        icon: const Icon(
                          Icons.settings,
                          color: AppColors.textoSuave,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _MarcadoresFila(
                    partida: _partida,
                    onVerCartas: _abrirCombos,
                    puedeRenombrar: _puedeRenombrar,
                    onRenombrar: _renombrarJugador,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                  Text(
                          _textoEstadoPartida,
                    textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _pcMostrandoJugada ||
                                    _puedeCapturar ||
                                    (_esOnline &&
                                        !_esMiTurno &&
                                        !_esperandoMazoOnline)
                                ? AppColors.mint
                                : AppColors.textoSuave,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                        if ((_faltaCartaMano && !_bloquearHumano) ||
                            _mensajePc != null ||
                            _aviso != null) ...[
                    const SizedBox(height: 6),
                          SizedBox(
                            height: 40,
                            child: _faltaCartaMano && !_bloquearHumano
                                ? Container(
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.acento
                                          .withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppColors.acento,
                                        width: 1.8,
                                      ),
                                      boxShadow:
                                          neonGlow(AppColors.acento, blur: 10),
                                    ),
                                    child: const Text(
                                      '👆 ¡Debés elegir una carta de tu mano sí o sí!',
                      textAlign: TextAlign.center,
                                      style: TextStyle(
                        color: AppColors.acento,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: _mensajePc != null
                                        ? BoxDecoration(
                                            color: AppColors.rosa
                                                .withValues(alpha: 0.16),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                              color: AppColors.rosa,
                                              width: 1.6,
                                            ),
                                          )
                                        : null,
                                    child: Text(
                                      _mensajePc ?? _aviso!,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _mensajePc != null
                                            ? AppColors.rosa
                                            : (_puedeCapturar
                                                ? AppColors.mint
                                                : AppColors.acento),
                                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                                      ),
                                    ),
                      ),
                    ),
                  ],
                        const SizedBox(height: 6),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final mesaLabel = _pcMostrandoJugada &&
                                      _mesaSeleccion.isNotEmpty
                                  ? 'MESA · PC elige ${_mesaSeleccion.length}'
                                  : _mesaSeleccion.isEmpty
                                      ? 'MESA (pozo)'
                                      : 'MESA · ${_mesaSeleccion.length} seleccionada(s)';
                              final mostrarPcCarta = _pcMostrandoJugada &&
                                  _cartaSeleccionada != null;
                              final mostrarZonaPc = widget.contraPc ||
                                  (_esOnline && !_esperandoMazoOnline);
                              final textoPc = widget.contraPc
                                  ? (_esPcTurno ? 'PC está eligiendo…' : '')
                                  : (_esMiTurno
                                      ? 'Tu turno'
                                      : (_mensajePc ??
                                          'Esperando a ${_partida.jugadorActual.nombre}…'));
                              return FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: constraints.maxWidth,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(
                                        height: 28,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Text(
                                              mesaLabel,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                      color: AppColors.azul,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                                            if (widget.modoDios && !_esOnline)
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Material(
                                                  color: AppColors.carta,
                                                  shape: const CircleBorder(),
                                                  child: InkWell(
                                                    customBorder:
                                                        const CircleBorder(),
                                                    onTap: (_partida
                                                                .terminada ||
                                                            _bloquearHumano ||
                                                            _partida.fase !=
                                                                FaseEscoba
                                                                    .jugando)
                                                        ? null
                                                        : _abrirForzarCartas,
                                                    child: Container(
                                                      width: 36,
                                                      height: 36,
                                                      decoration:
                                                          BoxDecoration(
                                                        shape:
                                                            BoxShape.circle,
                                                        border: Border.all(
                                                          color: AppColors
                                                              .textoSuave
                                                              .withValues(
                                                                  alpha: 0.5),
                                                        ),
                                                      ),
                                                      child: const Icon(
                                                        Icons.bug_report,
                                                        size: 18,
                                                        color: AppColors
                                                            .textoSuave,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        height: 112,
                    child: _ZonaCartas(
                                          cartas: _mesaParaMostrar,
                      seleccionadas: _mesaSeleccion,
                                          animaciones: _ajustes.animaciones,
                                          onTap: (_bloquearHumano ||
                                                  _partida.fase !=
                                                      FaseEscoba.jugando)
                                              ? null
                                              : _toggleMesa,
                                        ),
                                      ),
                    const SizedBox(height: 8),
                                      Center(child: _mazoEscobaWidget()),
                                      if (mostrarZonaPc) ...[
                                        const SizedBox(height: 8),
                                        if (mostrarPcCarta)
                    Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                      children: [
                                              const Text(
                                                'LA PC JUEGA CON',
                                                style: TextStyle(
                                                  color: AppColors.rosa,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 11,
                                                  letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 10),
                                              _CartaTexto(
                                                carta: _cartaSeleccionada!,
                                                seleccionada: true,
                                                animaciones:
                                                    _ajustes.animaciones,
                                              ),
                                            ],
                                          )
                                        else if (textoPc.isNotEmpty)
                                          Text(
                                            textoPc,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: _esOnline && !_esMiTurno
                                                  ? AppColors.rosa
                                                  : AppColors.textoSuave,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                  Text(
                          'TU MANO · ${mano.nombre}',
                          textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.mint,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                        // Fuera del contenedor de cartas, arriba a la derecha.
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: BotonOrdenarMano(
                              size: 38,
                              onPressed: mano.mano.length < 2 ||
                                      _bloquearHumano ||
                                      _partida.fase != FaseEscoba.jugando
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
                    // Alto fijo: carta completa + subida de selección + padding.
                    height: 160,
                    child: _ManoEscoba(
                      cartas: mano.mano,
                      seleccion: _bloquearHumano ? null : _cartaSeleccionada,
                      animaciones: _ajustes.animaciones,
                      puedeElegir: !(_bloquearHumano ||
                          _partida.fase != FaseEscoba.jugando),
                      onTap: (c) => unawaited(_seleccionarMano(c)),
                      onReordenar: _reordenarMano,
                      ordenAnimGen: _ordenAnimGen,
                      ordenAntesAnim: _ordenAntesAnim,
                    ),
                  ),
                    const SizedBox(height: 10),
                  SizedBox(
                    height: 54,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _puedeTirar ? _tirarAMesa : null,
                            child: Text(
                              _cartaSeleccionada == null || _bloquearHumano
                                  ? 'Tirar'
                                  : _sumaSeleccion == 15
                                      ? 'Tirar (bloqueado)'
                                      : 'Tirar (${_cartaSeleccionada!.valorSuma})',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.mint,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppColors.mint.withValues(alpha: 0.38),
                              disabledForegroundColor:
                                  Colors.white.withValues(alpha: 0.78),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed:
                                _puedeCapturar ? _confirmarCaptura : null,
                            child: Text(
                              _puedeCapturar
                                  ? 'Capturar ($_sumaSeleccion)'
                                  : 'Capturar',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_mostrarResumenRonda && _partida.ultimoResultado != null)
            Positioned.fill(
              child: ResumenRondaEscobaOverlay(
                resultado: _partida.ultimoResultado!,
                onContinuar: _continuarRonda,
                continuarHabilitado: !_esOnline || _soyAnfitrionOnline,
                labelContinuar: _esOnline && !_soyAnfitrionOnline
                    ? 'ESPERANDO AL ANFITRIÓN…'
                    : null,
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
              child: MenuPartidaEscoba(
                jugador: widget.contraPc
                    ? _manoVisible.nombre
                    : _partida.jugadorActual.nombre,
                partidaTerminada: _partida.terminada,
                esContraPc: widget.contraPc,
                confirmarRendicion:
                    _confirmarRendicion && !widget.contraPc,
                onCerrar: () => setState(() {
                  _mostrarMenu = false;
                  _confirmarRendicion = false;
                }),
                onReglas: () {
                  setState(() => _mostrarMenu = false);
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
                          reglasEscobaDel15(),
                          style: const TextStyle(color: AppColors.texto),
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
                },
                onSalirORendirse: _partida.terminada
                    ? () {
                        EscobaStandByStore.limpiar();
                        _salirAlMenu();
                      }
                    : (widget.contraPc
                        ? _salirGuardandoResumeYVolverAlMenu
                        : () => setState(() => _confirmarRendicion = true)),
                onConfirmarRendicion: _rendirse,
                onCancelarRendicion: () =>
                    setState(() => _confirmarRendicion = false),
              ),
            ),
          if (_partida.terminada)
            Positioned.fill(
              child: PremiarMonedasVictoriaPc(
                aplicar: ganoHumanoEnVsPc(
                  contraPc: widget.contraPc,
                  online: _esOnline,
                  ganador: _partida.ganador,
                ),
                child: VictoriaEscobaOverlay(
                  partida: _partida,
                  animaciones: _ajustes.animaciones,
                  onVolverAJugar: _volverAJugar,
                  mostrarVolverAJugar: !_esOnline,
                  onVolver: () {
                    EscobaStandByStore.limpiar();
                    _salirAlMenu();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Mazo visual (mismo estilo que Jodete); solo muestra cuántas quedan.
  Widget _mazoEscobaWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 112,
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

class _MarcadoresFila extends StatelessWidget {
  const _MarcadoresFila({
    required this.partida,
    required this.onVerCartas,
    required this.puedeRenombrar,
    required this.onRenombrar,
  });

  final PartidaEscoba partida;
  final ValueChanged<JugadorEscoba> onVerCartas;
  final bool Function(int index) puedeRenombrar;
  final Future<void> Function(int index) onRenombrar;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
      child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < partida.jugadores.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
              decoration: BoxDecoration(
                color: AppColors.carta.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !partida.jugadores[i].rendido &&
                          i == partida.indiceTurno % partida.jugadores.length
                      ? AppColors.mint
                      : AppColors.textoSuave.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NombreJugadorEditable(
                        nombre: partida.jugadores[i].rendido
                            ? '${partida.jugadores[i].nombre} (fuera)'
                            : partida.jugadores[i].nombre,
                        puedeRenombrar: puedeRenombrar(i),
                        onRenombrar: puedeRenombrar(i)
                            ? () => onRenombrar(i)
                            : null,
                      fontSize: 12,
                        colorTexto: partida.jugadores[i].rendido
                            ? AppColors.textoSuave
                            : AppColors.texto,
                        tachado: partida.jugadores[i].rendido,
                  ),
                  const SizedBox(height: 4),
                  MarcadorPalitosEscoba(
                    puntos: partida.jugadores[i].puntos,
                    color: AppColors.acento,
                    tamanoGrupo: 22,
                  ),
                  Text(
                    '${partida.jugadores[i].puntos} pts'
                    '${partida.jugadores[i].escobasRonda > 0 ? ' · ${partida.jugadores[i].escobasRonda} escoba(s)' : ''}',
                    style: const TextStyle(
                      color: AppColors.textoSuave,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                  ),
                  const SizedBox(width: 6),
                  Material(
                    color: AppColors.azul.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onVerCartas(partida.jugadores[i]),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.style_rounded,
                              color: AppColors.azul,
                              size: 18,
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Cartas',
                              style: TextStyle(
                                color: AppColors.azul,
                                fontWeight: FontWeight.w900,
                                fontSize: 9,
              ),
            ),
          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HojaCombosJugador extends StatelessWidget {
  const _HojaCombosJugador({
    required this.jugador,
    required this.esRondaAnterior,
  });

  final JugadorEscoba jugador;
  final bool esRondaAnterior;

  @override
  Widget build(BuildContext context) {
    final n = jugador.combos.length;
    final combos = [
      for (var i = n - 1; i >= 0; i--) jugador.combos[i],
    ];
    final maxH = MediaQuery.sizeOf(context).height * 0.7;

    return SafeArea(
      child: SizedBox(
        height: maxH,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textoSuave.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Cartas de ${jugador.nombre}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mint,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                esRondaAnterior
                    ? 'Última ronda · orden #n → #1 (★ = escoba)'
                    : 'Orden #n → #1 · la más reciente arriba (★ = escoba)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: combos.isEmpty
                    ? const Center(
                        child: Text(
                          'Todavía no agarró ningún combo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textoSuave,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: combos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final combo = combos[i];
                          final numero = n - i;
                          final esUltima = i == 0;
                          final titulo = combo.esPozoFinal
                              ? 'Pozo final'
                              : (combo.escoba ? 'Escoba' : 'Captura');
                          final colorMarca = combo.escoba
                              ? AppColors.acento
                              : (esUltima ? AppColors.mint : AppColors.azul);
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: colorMarca.withValues(alpha: 0.75),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      combo.escoba
                                          ? '#$numero ★'
                                          : '#$numero',
                                      style: TextStyle(
                                        color: colorMarca,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        titulo,
                                        style: const TextStyle(
                                          color: AppColors.texto,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    if (esUltima)
                                      const Text(
                                        'más reciente',
                                        style: TextStyle(
                                          color: AppColors.mint,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  combo.resumen,
                                  style: const TextStyle(
                                    color: AppColors.textoSuave,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZonaCartas extends StatelessWidget {
  const _ZonaCartas({
    required this.cartas,
    required this.animaciones,
    this.seleccionadas = const [],
    this.onTap,
  });

  final List<CartaEscoba> cartas;
  final List<CartaEscoba> seleccionadas;
  final bool animaciones;
  final ValueChanged<CartaEscoba>? onTap;

  @override
  Widget build(BuildContext context) {
    if (cartas.isEmpty) {
      return Center(
        child: Text(
          '— vacía —',
          style: TextStyle(
            color: AppColors.textoSuave.withValues(alpha: 0.7),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final minW = constraints.maxWidth;
        final n = cartas.length;
        const cardW = 72.0;
        const gap = 8.0;
        final contentW = n == 0 ? 0.0 : n * cardW + (n - 1) * gap;
        final filaW = math.max(minW, contentW);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: filaW,
            height: constraints.maxHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
          children: [
                for (var i = 0; i < cartas.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
              _CartaTexto(
                    carta: cartas[i],
                    seleccionada: seleccionadas.contains(cartas[i]),
                    animaciones: animaciones,
                    onTap: onTap == null ? null : () => onTap!(cartas[i]),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Mano del jugador con arrastre para reordenar (misma lógica shared).
class _ManoEscoba extends StatefulWidget {
  const _ManoEscoba({
    required this.cartas,
    required this.seleccion,
    required this.animaciones,
    required this.puedeElegir,
    required this.onTap,
    this.onReordenar,
    this.ordenAnimGen = 0,
    this.ordenAntesAnim,
  });

  final List<CartaEscoba> cartas;
  final CartaEscoba? seleccion;
  final bool animaciones;
  final bool puedeElegir;
  final ValueChanged<CartaEscoba> onTap;
  final void Function(int desde, int hacia)? onReordenar;

  /// Generación de ordenado automático (botón); 0 = sin animación de sort.
  final int ordenAnimGen;

  /// Orden de la mano justo antes del último sort (copia; no la lista viva).
  final List<CartaEscoba>? ordenAntesAnim;

  @override
  State<_ManoEscoba> createState() => _ManoEscobaState();
}

class _ManoEscobaState extends State<_ManoEscoba> {
  final _scroll = ScrollController();
  final _rowKey = GlobalKey();
  final _reorden = ReordenarCartaManoDrag();
  bool _priorizarReorden = false;
  Map<Object, double> _dxOrden = const {};
  int _genOrden = 0;

  static const double _cardW = 72;
  static const double _cardH = 112;
  static const double _gap = 8;

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
  void didUpdateWidget(covariant _ManoEscoba oldWidget) {
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
      _dxOrden = deltasInicioOrdenMano(
        antes: <Object>[for (final c in widget.ordenAntesAnim!) c],
        despues: <Object>[for (final c in widget.cartas) c],
        paso: _cardW + _gap,
      );
      _genOrden = widget.ordenAnimGen;
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

  Widget _skin(CartaEscoba c, {required bool sel}) {
    return CartaEspanolaSkin(
      numero: c.numero,
      etiqueta: c.etiqueta,
      palo: paloEspanolDeEscoba(c.palo),
      seleccionada: sel,
      subtitulo: 'vale ${c.valorSuma}',
      width: _cardW,
      height: _cardH,
    );
  }

  @override
  Widget build(BuildContext context) {
    final altoSlot = _cardH + kDeslizamientoSeleccionCarta;

    final contenedor = BoxDecoration(
      color: const Color(0xFF1A0A33).withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: AppColors.violeta.withValues(alpha: 0.55),
        width: 1.2,
      ),
    );
    if (widget.cartas.isEmpty) {
      return Container(
        decoration: contenedor,
        alignment: Alignment.center,
        child: Text(
          '— vacía —',
          style: TextStyle(
            color: AppColors.textoSuave.withValues(alpha: 0.7),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return Container(
      decoration: contenedor,
      clipBehavior: Clip.hardEdge,
      alignment: Alignment.bottomCenter,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minW = constraints.maxWidth - 24;
          final n = widget.cartas.length;
          final contentW = n == 0 ? 0.0 : n * _cardW + (n - 1) * _gap;
          final filaW = math.max(minW, contentW);
          return SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            // Solo bloquea scroll al tocar/arrastrar la carta seleccionada.
            physics: physicsScrollManoReorden(bloquearPorReorden: _bloquearScroll),
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            child: SizedBox(
              width: filaW,
              height: altoSlot,
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
                          key: ValueKey<String>(
                            'slot_${widget.cartas[i].etiqueta}',
                          ),
                          builder: (context) {
                            final c = widget.cartas[i];
                            final sel = widget.seleccion == c;
                            final esLaQueArrastro = _reorden.dragIndex == i;
                            final atenuar =
                                _arrastrando && !esLaQueArrastro;

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
                                child: _skin(c, sel: sel),
                              ),
                            );

                            child = CartaDeslizOrdenMano(
                              key: ValueKey<String>(
                                'ord_${c.etiqueta}_$_genOrden',
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

                            // Árbol estable en cambios de turno/selección.
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
                        child: _skin(
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

class _CartaTexto extends StatelessWidget {
  const _CartaTexto({
    required this.carta,
    required this.seleccionada,
    required this.animaciones,
    this.onTap,
    this.compacta = false,
  });

  final CartaEscoba carta;
  final bool seleccionada;
  final bool animaciones;
  final VoidCallback? onTap;
  final bool compacta;

  static const double _deslizamiento = 14;

  @override
  Widget build(BuildContext context) {
    final cardW = compacta ? 56.0 : 72.0;
    final cardH = compacta ? 84.0 : 112.0;
    final skin = CartaEspanolaSkin(
      numero: carta.numero,
      etiqueta: carta.etiqueta,
      palo: paloEspanolDeEscoba(carta.palo),
      seleccionada: seleccionada,
      compacta: compacta,
      subtitulo: 'vale ${carta.valorSuma}',
      width: cardW,
      height: cardH,
    );
    // Árbol estable + AnimatedAlign: si el padre cambia al seleccionar,
    // la animación se reinicia y la carta “teletransporta”.
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: seleccionada
            ? colorSeleccionCartaEspanola.withValues(alpha: 0.25)
            : Colors.transparent,
        highlightColor: seleccionada
            ? colorSeleccionCartaEspanola.withValues(alpha: 0.18)
            : Colors.transparent,
        hoverColor: seleccionada
            ? colorSeleccionCartaEspanola.withValues(alpha: 0.22)
            : Colors.transparent,
        child: SizedBox(
          width: cardW,
          height: cardH + _deslizamiento,
          child: AnimatedAlign(
            duration: animaciones
                ? const Duration(milliseconds: 380)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            alignment:
                seleccionada ? Alignment.topCenter : Alignment.bottomCenter,
            child: skin,
          ),
        ),
      ),
    );
  }
}

PaloEspanolVisual paloEspanolDeEscoba(PaloEscoba palo) => switch (palo) {
      PaloEscoba.oro => PaloEspanolVisual.oro,
      PaloEscoba.copa => PaloEspanolVisual.copa,
      PaloEscoba.espada => PaloEspanolVisual.espada,
      PaloEscoba.basto => PaloEspanolVisual.basto,
    };

class _ForzarCartasResult {
  const _ForzarCartasResult({
    required this.mesa,
    required this.mano,
  });

  final List<CartaEscoba> mesa;
  final List<CartaEscoba> mano;
}

enum _ModoForzarCartas { mesa, mano }

class _DialogoForzarCartasEscoba extends StatefulWidget {
  const _DialogoForzarCartasEscoba({
    required this.mesaInicial,
    required this.manoInicial,
    required this.cupoMesa,
    required this.cupoMano,
    this.excluidas = const {},
  });

  final List<CartaEscoba> mesaInicial;
  final List<CartaEscoba> manoInicial;
  final int cupoMesa;
  final int cupoMano;
  /// Cartas ya capturadas (fuera de juego): no se pueden volver a elegir.
  final Set<CartaEscoba> excluidas;

  @override
  State<_DialogoForzarCartasEscoba> createState() =>
      _DialogoForzarCartasEscobaState();
}

class _DialogoForzarCartasEscobaState extends State<_DialogoForzarCartasEscoba> {
  late final List<CartaEscoba> _todas;
  late List<CartaEscoba> _mesa;
  late List<CartaEscoba> _mano;
  late _ModoForzarCartas _modo;

  int get _cupoMesa => widget.cupoMesa;
  int get _cupoMano => widget.cupoMano;

  @override
  void initState() {
    super.initState();
    _todas = [
      for (final c in crearMazoEscoba())
        if (!widget.excluidas.contains(c)) c,
    ]..sort((a, b) {
        final p = a.palo.index.compareTo(b.palo.index);
        if (p != 0) return p;
        return a.numero.compareTo(b.numero);
      });
    _mesa = [
      for (final c in widget.mesaInicial.take(_cupoMesa))
        if (!widget.excluidas.contains(c)) c,
    ];
    _mano = [
      for (final c in widget.manoInicial.take(_cupoMano))
        if (!widget.excluidas.contains(c)) c,
    ];
    _modo = _cupoMesa > 0
        ? _ModoForzarCartas.mesa
        : _ModoForzarCartas.mano;
  }

  bool _enMesa(CartaEscoba c) => _mesa.contains(c);
  bool _enMano(CartaEscoba c) => _mano.contains(c);

  void _toggle(CartaEscoba c) {
    setState(() {
      // Si ya está elegida (mesa o mano), solo deseleccionar.
      // No moverla a la otra categoría aunque haya cupo libre.
      if (_enMesa(c)) {
        _mesa.remove(c);
        return;
      }
      if (_enMano(c)) {
        _mano.remove(c);
        return;
      }
      // Carta libre → agregar a la categoría activa si hay lugar.
      if (_modo == _ModoForzarCartas.mesa) {
        if (_cupoMesa <= 0 || _mesa.length >= _cupoMesa) return;
        _mesa.add(c);
      } else {
        if (_cupoMano <= 0 || _mano.length >= _cupoMano) return;
        _mano.add(c);
      }
    });
  }

  Color _colorPalo(PaloEscoba palo) =>
      colorPaloEspanol(paloEspanolDeEscoba(palo));

  String _tituloPalo(PaloEscoba palo) => switch (palo) {
        PaloEscoba.oro => 'Oros',
        PaloEscoba.copa => 'Copas',
        PaloEscoba.espada => 'Espadas',
        PaloEscoba.basto => 'Bastos',
      };

  Widget _celdaCarta(CartaEscoba c) {
    final sel = _enMesa(c) || _enMano(c);
    final zona = _enMesa(c)
        ? 'MESA'
        : (_enMano(c) ? 'MANO' : null);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggle(c),
        borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            CartaEspanolaSkin(
              numero: c.numero,
              etiqueta: c.etiqueta,
              palo: paloEspanolDeEscoba(c.palo),
              seleccionada: sel,
              subtitulo: 'vale ${c.valorSuma}',
              width: 64,
              height: 100,
            ),
            if (zona != null) ...[
              const SizedBox(height: 2),
              Text(
                zona,
                style: TextStyle(
                  color: _enMesa(c) ? AppColors.azul : AppColors.mint,
                  fontWeight: FontWeight.w900,
                  fontSize: 9,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _contenedorPalo(PaloEscoba palo, List<CartaEscoba> cartas) {
    final color = _colorPalo(palo);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.65), width: 1.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _tituloPalo(palo),
            style: TextStyle(
              color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
              letterSpacing: 0.6,
                ),
              ),
          const SizedBox(height: 8),
          if (cartas.isEmpty)
              Text(
              'Sin cartas disponibles',
                style: TextStyle(
                color: AppColors.textoSuave.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 78,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.55,
              ),
              itemCount: cartas.length,
              itemBuilder: (context, i) => _celdaCarta(cartas[i]),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    final porPalo = <PaloEscoba, List<CartaEscoba>>{
      for (final palo in PaloEscoba.values)
        palo: [for (final c in _todas) if (c.palo == palo) c],
    };

    return Dialog(
      backgroundColor: AppColors.carta,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 720, maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            children: [
              const Text(
                '🎯 Forzar cartas',
                      style: TextStyle(
                  color: AppColors.acento,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
              const SizedBox(height: 4),
              Text(
                _modo == _ModoForzarCartas.mesa
                    ? 'Modo mesa: elegí hasta $_cupoMesa '
                        '(si faltan, se completan al azar)'
                    : 'Modo mano: elegí hasta $_cupoMano '
                        '(si faltan, se completan al azar)',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(right: 4),
                        children: [
                          for (final palo in PaloEscoba.values)
                            _contenedorPalo(palo, porPalo[palo]!),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 132,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_cupoMesa > 0) ...[
                            _BotonModoForzar(
                              label: 'Tirar en\nla mesa',
                              sublabel: '${_mesa.length}/$_cupoMesa',
                              color: AppColors.azul,
                              activo: _modo == _ModoForzarCartas.mesa,
                              onTap: () => setState(
                                () => _modo = _ModoForzarCartas.mesa,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (_cupoMano > 0)
                            _BotonModoForzar(
                              label: 'Mano',
                              sublabel: '${_mano.length}/$_cupoMano',
                              color: AppColors.mint,
                              activo: _modo == _ModoForzarCartas.mano,
                              onTap: () => setState(
                                () => _modo = _ModoForzarCartas.mano,
                              ),
                            ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop(
                                _ForzarCartasResult(
                                  mesa: List.of(_mesa),
                                  mano: List.of(_mano),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.acento,
                              foregroundColor: const Color(0xFF1A0A00),
                              minimumSize: const Size.fromHeight(48),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Aplicar',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.peligro,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                      ),
                ),
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

class _BotonModoForzar extends StatelessWidget {
  const _BotonModoForzar({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.activo,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final Color color;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: activo
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Material(
        color: activo
            ? color.withValues(alpha: 0.22)
            : Colors.black.withValues(alpha: 0.25),
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: activo ? color : color.withValues(alpha: 0.45),
                width: activo ? 2.2 : 1.3,
              ),
            ),
            child: Column(
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sublabel,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
