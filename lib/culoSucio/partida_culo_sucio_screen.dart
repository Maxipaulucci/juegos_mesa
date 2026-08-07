import 'dart:async';

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/culoSucio/culo_sucio_online_codec.dart';
import 'package:app_juegos_mesa/culoSucio/historial_culo_sucio.dart';
import 'package:app_juegos_mesa/culoSucio/menu_partida_culo_sucio.dart';
import 'package:app_juegos_mesa/culoSucio/modo_dios_culo_sucio.dart';
import 'package:app_juegos_mesa/culoSucio/motor_culo_sucio.dart';
import 'package:app_juegos_mesa/culoSucio/opciones_culo_sucio.dart';
import 'package:app_juegos_mesa/culoSucio/standby_store.dart';
import 'package:app_juegos_mesa/culoSucio/textos.dart';
import 'package:app_juegos_mesa/culoSucio/victoria_culo_sucio_overlay.dart';
import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/cartas/icono_espada.dart';
import 'package:app_juegos_mesa/shared/partida_ui/epic_backdrop.dart';
import 'package:app_juegos_mesa/shared/partida_ui/nombre_jugador_editable.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/theme/victoria_celebration.dart';

/// Partida de Culo sucio v1 (local, vs PC u online).
class PartidaCuloSucioScreen extends StatefulWidget {
  const PartidaCuloSucioScreen({
    super.key,
    required this.nombres,
    this.contraPc = false,
    this.modoDios = false,
    this.opciones = const OpcionesCuloSucio(),
    this.resume,
    this.salaCodigo,
    this.miNombre,
  });

  final List<String> nombres;
  final bool contraPc;
  final bool modoDios;
  final OpcionesCuloSucio opciones;
  final PartidaCuloSucioResume? resume;
  final String? salaCodigo;
  final String? miNombre;

  @override
  State<PartidaCuloSucioScreen> createState() => _PartidaCuloSucioScreenState();
}

class _PartidaCuloSucioScreenState extends State<PartidaCuloSucioScreen> {
  late PartidaCuloSucio _partida;
  late List<String> _nombres;
  late OpcionesCuloSucio _opciones;
  bool _sacando = false;
  bool _editandoMazo = false;
  int _pcToken = 0;
  bool _mostrarMenu = false;
  bool _mostrarAjustes = false;
  bool _confirmarRendicion = false;
  AjustesEstado _ajustes = const AjustesEstado();

  StreamSubscription<Sala>? _onlineSub;
  int _onlineVersion = 0;
  bool _publicandoOnline = false;
  bool _esperandoMazoOnline = false;
  bool _mazoPublicado = false;

  bool get _esOnline =>
      widget.salaCodigo != null &&
      widget.salaCodigo!.isNotEmpty &&
      widget.miNombre != null &&
      widget.miNombre!.isNotEmpty;

  bool get _soyAnfitrionOnline =>
      _esOnline &&
      widget.miNombre != null &&
      (_nombres.isNotEmpty
          ? _nombres.first == widget.miNombre
          : (_partida.nombres.isNotEmpty &&
              _partida.nombres.first == widget.miNombre));

  bool get _esMiTurno =>
      !_esOnline || _partida.jugadorActual == widget.miNombre;

  bool get _bloquearHumano =>
      _sacando ||
      _editandoMazo ||
      (_esOnline && (_esperandoMazoOnline || !_esMiTurno));

  bool get _modoDiosActivo =>
      widget.modoDios && widget.contraPc && !_esOnline;

  @override
  void initState() {
    super.initState();
    _opciones = widget.opciones;
    final resume = widget.resume;
    _nombres = List.of(resume?.nombres ?? widget.nombres);
    if (_esOnline) {
      _partida = PartidaCuloSucio(
        nombres: List.of(_nombres),
        mazo: [],
      );
      _esperandoMazoOnline = true;
      _iniciarSincronizacionOnline();
    } else if (resume != null) {
      _partida = resume.partida;
      _opciones = resume.opciones;
      _nombres = List.of(resume.nombres);
      WidgetsBinding.instance.addPostFrameCallback((_) => _talVezTurnoPc());
    } else {
      _partida = nuevaPartidaCuloSucio(
        nombres: _nombres,
        contraPc: widget.contraPc,
        incluirComodines: _opciones.comodines,
      );
      _nombres = List.of(_partida.nombres);
      WidgetsBinding.instance.addPostFrameCallback((_) => _talVezTurnoPc());
    }
  }

  @override
  void dispose() {
    _onlineSub?.cancel();
    super.dispose();
  }

  bool get _esLocalHotSeat => !_esOnline && !widget.contraPc;

  bool get _esTurnoPc =>
      !_esOnline &&
      _partida.contraPc &&
      !_partida.terminada &&
      _partida.jugadorActual == TextosCuloSucio.vsPcNombre;

  /// Victoria con confeti: ganador local / vs PC, o yo gané online.
  bool get _debeMostrarVictoria {
    if (_partida.ganador == null || _partida.perdedor == null) return false;
    if (_esOnline) return widget.miNombre == _partida.ganador;
    if (_esLocalHotSeat) return true;
    return _partida.ganador != TextosCuloSucio.vsPcNombre;
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
    if (juego != 'culoSucioV1') {
      if (_soyAnfitrionOnline && !_mazoPublicado) {
        unawaited(_publicarMazoInicialOnline());
      }
      return;
    }

    final version = (gameState['version'] as num?)?.toInt() ?? 0;
    if (version < _onlineVersion) return;
    if (_publicandoOnline && version <= _onlineVersion) return;

    final tiene = culoSucioPartidaGenerada(gameState);
    if (!tiene) {
      if (_soyAnfitrionOnline && !_mazoPublicado) {
        unawaited(_publicarMazoInicialOnline());
      }
      return;
    }

    if (version <= _onlineVersion && !_esperandoMazoOnline) return;

    final comodines = gameState['comodines'] == true;
    setState(() {
      applyCuloSucioGameState(_partida, gameState);
      _opciones = _opciones.copyWith(comodines: comodines);
      _onlineVersion = version;
      _esperandoMazoOnline = false;
      _mazoPublicado = true;
    });
  }

  Future<void> _publicarMazoInicialOnline() async {
    if (!_esOnline || _mazoPublicado || _publicandoOnline) return;
    final generada = nuevaPartidaCuloSucio(
      nombres: _nombres,
      incluirComodines: _opciones.comodines,
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
        final gameState = encodeCuloSucioGameState(
          partida: _partida,
          version: _onlineVersion,
          comodines: _opciones.comodines,
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
      CuloSucioStandByStore.limpiar();
      return;
    }
    CuloSucioStandByStore.guardar(
      PartidaCuloSucioResume(
        partida: _partida,
        nombres: _nombres,
        opciones: _opciones,
        modoDios: widget.modoDios,
      ),
    );
  }

  void _salirAlMenu({required bool guardar}) {
    _pcToken++;
    if (guardar) {
      _guardarResumeSiCorresponde();
    } else {
      CuloSucioStandByStore.limpiar();
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  static const int _maxNombre = 15;

  bool _esPcNombre(String nombre) =>
      nombre == TextosCuloSucio.vsPcNombre ||
      (nombre.startsWith('PC ') && nombre.length > 3);

  bool _puedeRenombrar(int index) {
    if (_esOnline) return false;
    if (_partida.terminada) return false;
    if (index < 0 || index >= _partida.nombres.length) return false;
    if (_partida.estaRendido(index)) return false;
    return !_esPcNombre(_partida.nombres[index]);
  }

  void _rendirse() {
    if (_partida.terminada || !_esLocalHotSeat) return;
    final yo = _partida.jugadorActual;
    if (yo.isEmpty) return;
    final idx = _partida.nombres.indexOf(yo);
    if (idx < 0 || _partida.estaRendido(idx)) return;

    setState(() {
      _mostrarMenu = false;
      _confirmarRendicion = false;
      rendirseCuloSucio(_partida, yo);
    });
  }

  String? _validarNombre(String nombre, int index) {
    if (nombre.isEmpty) return 'El nombre no puede estar vacío.';
    if (nombre.length > _maxNombre) {
      return 'Máximo $_maxNombre caracteres.';
    }
    if (_esPcNombre(nombre)) {
      return 'Ese nombre está reservado para la PC.';
    }
    final ocupado = _partida.nombres.asMap().entries.any(
          (e) => e.key != index && e.value == nombre,
        );
    if (ocupado) return 'Ese nombre ya está en uso.';
    return null;
  }

  Future<void> _renombrarJugador(int index) async {
    if (!_puedeRenombrar(index)) return;
    final actual = _partida.nombres[index];
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
      _partida.nombres[index] = nuevo;
      if (index < _nombres.length) _nombres[index] = nuevo;
      if (_partida.perdedor == actual) _partida.perdedor = nuevo;
      if (_partida.ganador == actual) _partida.ganador = nuevo;
      for (final j in _partida.historial) {
        if (j.jugador == actual) j.jugador = nuevo;
      }
      final msg = _partida.mensajeFin;
      if (msg != null && msg.contains(actual)) {
        _partida.mensajeFin = msg.replaceAll(actual, nuevo);
      }
    });
  }

  String get _nombreMenu {
    if (_esOnline) return widget.miNombre ?? _partida.jugadorActual;
    if (widget.contraPc) {
      return _partida.nombres.firstWhere(
        (n) => n != TextosCuloSucio.vsPcNombre,
        orElse: () => _partida.jugadorActual,
      );
    }
    return _partida.jugadorActual;
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
            reglasCuloSucio(comodines: _opciones.comodines),
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

  Future<void> _talVezTurnoPc() async {
    if (_esOnline) return;
    if (!_esTurnoPc || _sacando || _editandoMazo) return;
    final token = ++_pcToken;
    final espera = _modoDiosActivo ? 2200 : 700;
    await Future<void>.delayed(Duration(milliseconds: espera));
    if (!mounted || token != _pcToken) return;
    if (!_esTurnoPc || _sacando || _editandoMazo) return;
    await _sacar();
  }

  Future<void> _sacar() async {
    if (_partida.terminada || _sacando || _editandoMazo) return;
    if (_esOnline && !_esMiTurno) return;
    if (_esOnline && _esperandoMazoOnline) return;
    setState(() => _sacando = true);
    sacarCartaCuloSucio(_partida);
    if (!mounted) return;
    setState(() => _sacando = false);
    if (_esOnline) {
      unawaited(_publicarEstadoOnline(forzar: _partida.terminada));
      return;
    }
    if (!_partida.terminada) {
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (mounted) _talVezTurnoPc();
    }
  }

  Future<void> _abrirEditarMazo() async {
    if (!_modoDiosActivo || _partida.terminada || _partida.mazo.isEmpty) {
      return;
    }
    _pcToken++;
    setState(() => _editandoMazo = true);
    final nuevo = await mostrarEditarMazoCuloSucio(
      context: context,
      ordenDesdeProxima: ordenSalidaMazoCuloSucio(_partida),
    );
    if (!mounted) return;
    setState(() {
      _editandoMazo = false;
      if (nuevo != null) {
        forzarMazoCuloSucio(_partida, nuevo);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezTurnoPc());
  }

  void _reiniciar() {
    if (_esOnline) return;
    _pcToken++;
    CuloSucioStandByStore.limpiar();
    setState(() {
      _partida = nuevaPartidaCuloSucio(
        nombres: _nombres,
        contraPc: widget.contraPc,
        incluirComodines: _opciones.comodines,
      );
      _sacando = false;
      _editandoMazo = false;
      _mostrarMenu = false;
      _confirmarRendicion = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezTurnoPc());
  }

  Color _colorPalo(PaloCuloSucio? palo) {
    return switch (palo) {
      PaloCuloSucio.oro => const Color(0xFFFFC107),
      PaloCuloSucio.copa => const Color(0xFFFF5252),
      PaloCuloSucio.espada => const Color(0xFF40C4FF),
      PaloCuloSucio.basto => const Color(0xFF69F0AE),
      null => AppColors.violeta,
    };
  }

  IconData _iconoPalo(PaloCuloSucio? palo, {required bool comodin}) {
    if (comodin) return Icons.star_rounded;
    return switch (palo) {
      PaloCuloSucio.oro => Icons.monetization_on_outlined,
      PaloCuloSucio.copa => Icons.wine_bar_outlined,
      PaloCuloSucio.espada => Icons.bolt_outlined,
      PaloCuloSucio.basto => Icons.park_outlined,
      null => Icons.style_outlined,
    };
  }

  Widget _widgetIconoPalo(
    PaloCuloSucio? palo, {
    required bool comodin,
    required double size,
    required Color color,
  }) {
    if (comodin) {
      return Icon(Icons.star_rounded, size: size, color: color);
    }
    if (palo == PaloCuloSucio.espada) {
      return IconoEspadaOutlined(size: size, color: color);
    }
    return Icon(_iconoPalo(palo, comodin: false), size: size, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final carta = _partida.ultimaCarta;
    final proxima =
        _modoDiosActivo ? proximaCartaCuloSucio(_partida) : null;
    final puedeSacar = !_partida.terminada &&
        !_esTurnoPc &&
        !_bloquearHumano &&
        !_esperandoMazoOnline;

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
          const Positioned.fill(child: EpicBackdrop(centerY: 0.52)),
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
                          TextosCuloSucio.titulo,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.texto,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    TextosCuloSucio.reglaConOpciones(
                      comodines: _opciones.comodines,
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textoSuave,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      for (var i = 0; i < _partida.nombres.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: _ChipJugador(
                            nombre: _partida.estaRendido(i)
                                ? '${_partida.nombres[i]} (fuera)'
                                : _partida.nombres[i],
                            activo: !_partida.terminada &&
                                !_partida.estaRendido(i) &&
                                _partida.indiceTurno == i,
                            perdido: _partida.perdedor == _partida.nombres[i],
                            ganado: _partida.ganador == _partida.nombres[i],
                            rendido: _partida.estaRendido(i),
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
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${TextosCuloSucio.cartasRestantes}: ${_partida.cartasRestantes}',
                      style: const TextStyle(
                        color: AppColors.textoSuave,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_modoDiosActivo && proxima != null) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.carta.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: proxima.esCuloSucio
                                ? AppColors.peligro
                                : AppColors.acento,
                          ),
                        ),
                        child: Text(
                          'Próxima: ${proxima.etiqueta}',
                          style: TextStyle(
                            color: proxima.esCuloSucio
                                ? AppColors.peligro
                                : AppColors.acento,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Compensa el botón a la derecha para que el mazo quede centrado.
                    SizedBox(width: _modoDiosActivo ? 52 : 0),
                    if (carta == null)
                      const _CartaTapada()
                    else
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (carta.esComodin) ...[
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Esto no deberia estar aqui.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.acento,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                          _CartaVista(
                            etiqueta: carta.etiqueta,
                            esCuloSucio: carta.esCuloSucio,
                            color: _colorPalo(carta.palo),
                            icono: _widgetIconoPalo(
                              carta.palo,
                              comodin: carta.esComodin,
                              size: 56,
                              color: _colorPalo(carta.palo),
                            ),
                          ),
                        ],
                      ),
                    if (_modoDiosActivo) ...[
                      const SizedBox(width: 12),
                      Material(
                        color: AppColors.carta,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: (_partida.terminada ||
                                  _partida.mazo.isEmpty ||
                                  _sacando)
                              ? null
                              : _abrirEditarMazo,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.textoSuave
                                    .withValues(alpha: 0.5),
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
                    ],
                  ],
                ),
                const Spacer(),
                if (!_partida.terminada) ...[
                  Text(
                    _esperandoMazoOnline
                        ? 'Esperando mazo del anfitrión…'
                        : (_esOnline && !_esMiTurno)
                            ? 'Turno de ${_partida.jugadorActual}'
                            : '${TextosCuloSucio.turnoDe} ${_partida.jugadorActual}',
                    style: TextStyle(
                      color: (_esTurnoPc || (_esOnline && !_esMiTurno))
                          ? AppColors.textoSuave
                          : AppColors.acento,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: puedeSacar ? _sacar : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.peligro,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.carta.withValues(alpha: 0.7),
                        ),
                        child: Text(
                          _esperandoMazoOnline
                              ? 'Preparando mazo…'
                              : _esTurnoPc
                                  ? (_modoDiosActivo
                                      ? 'La PC saca pronto…'
                                      : 'La PC está sacando…')
                                  : (_esOnline && !_esMiTurno)
                                      ? 'Esperando al rival…'
                                      : TextosCuloSucio.sacarCarta,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
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
              child: MenuPartidaCuloSucio(
                jugador: _nombreMenu,
                partidaTerminada: _partida.terminada,
                permitirRendirse: _esLocalHotSeat,
                confirmarRendicion:
                    _confirmarRendicion && _esLocalHotSeat,
                onCerrar: () => setState(() {
                  _mostrarMenu = false;
                  _confirmarRendicion = false;
                }),
                onReglas: () {
                  setState(() {
                    _mostrarMenu = false;
                    _confirmarRendicion = false;
                  });
                  _mostrarReglas();
                },
                onSalirORendirse: _partida.terminada || !_esLocalHotSeat
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
                  ? VictoriaCuloSucioOverlay(
                      partida: _partida,
                      mostrarVolverAJugar: !_esOnline,
                      onVolverAJugar: _reiniciar,
                      onVolver: () => _salirAlMenu(guardar: false),
                    )
                  : _OverlayFin(
                      partida: _partida,
                      mensaje: _partida.mensajeFin ?? '',
                      esCuloSucio: _partida.perdedor != null,
                      perdedor: _partida.perdedor,
                      ganador: _partida.ganador,
                      mostrarOtraVez: !_esOnline,
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
    required this.activo,
    required this.perdido,
    required this.ganado,
    this.rendido = false,
    this.puedeRenombrar = false,
    this.onRenombrar,
  });

  final String nombre;
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.carta.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borde,
          width: activo || perdido || ganado ? 2 : 1,
        ),
      ),
      child: NombreJugadorEditable(
        nombre: nombre,
        puedeRenombrar: puedeRenombrar,
        onRenombrar: onRenombrar,
        fontSize: 14,
        tachado: rendido,
        colorTexto: perdido
            ? AppColors.peligro
            : ganado
                ? AppColors.mint
                : rendido
                    ? AppColors.textoSuave
                    : AppColors.texto,
      ),
    );
  }
}

class _CartaTapada extends StatelessWidget {
  const _CartaTapada();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B1D6E),
            Color(0xFF1A0A33),
            Color(0xFF2A1050),
          ],
        ),
        border: Border.all(color: AppColors.acento, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.acento.withValues(alpha: 0.35),
            blurRadius: 22,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Patrón sutil de dorso.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.violeta.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const Center(
            child: Text(
              '?',
              style: TextStyle(
                color: AppColors.acento,
                fontSize: 92,
                fontWeight: FontWeight.w900,
                height: 1,
                shadows: [
                  Shadow(
                    color: Color(0xAAFFC107),
                    blurRadius: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaVista extends StatelessWidget {
  const _CartaVista({
    required this.etiqueta,
    required this.esCuloSucio,
    required this.color,
    required this.icono,
  });

  final String etiqueta;
  final bool esCuloSucio;
  final Color color;
  final Widget icono;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 168,
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.carta,
            Color.lerp(AppColors.carta, color, 0.35)!,
          ],
        ),
        border: Border.all(
          color: esCuloSucio ? AppColors.peligro : color,
          width: esCuloSucio ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (esCuloSucio ? AppColors.peligro : color)
                .withValues(alpha: 0.45),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icono,
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              etiqueta,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: esCuloSucio ? AppColors.peligro : AppColors.texto,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
          ),
          if (esCuloSucio) ...[
            const SizedBox(height: 10),
            const Text(
              TextosCuloSucio.culoSucio,
              style: TextStyle(
                color: AppColors.peligro,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OverlayFin extends StatefulWidget {
  const _OverlayFin({
    required this.partida,
    required this.mensaje,
    required this.esCuloSucio,
    required this.perdedor,
    required this.ganador,
    required this.onOtraVez,
    required this.onVolver,
    this.mostrarOtraVez = true,
  });

  final PartidaCuloSucio partida;
  final String mensaje;
  final bool esCuloSucio;
  final String? perdedor;
  final String? ganador;
  final VoidCallback onOtraVez;
  final VoidCallback onVolver;
  final bool mostrarOtraVez;

  @override
  State<_OverlayFin> createState() => _OverlayFinState();
}

class _OverlayFinState extends State<_OverlayFin> {
  bool _cartelVisible = true;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IgnorePointer(
          ignoring: !_cartelVisible,
          child: Material(
            color: _cartelVisible
                ? Colors.black.withValues(alpha: 0.72)
                : Colors.transparent,
            child: _cartelVisible
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Material(
                        color: AppColors.carta,
                        borderRadius: BorderRadius.circular(22),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.esCuloSucio
                                    ? Icons.sentiment_very_dissatisfied_rounded
                                    : Icons.handshake_outlined,
                                size: 52,
                                color: widget.esCuloSucio
                                    ? AppColors.peligro
                                    : AppColors.acento,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.esCuloSucio
                                    ? TextosCuloSucio.culoSucio
                                    : 'Fin',
                                style: TextStyle(
                                  color: widget.esCuloSucio
                                      ? AppColors.peligro
                                      : AppColors.texto,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.mensaje,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.texto,
                                  fontSize: 15,
                                  height: 1.35,
                                ),
                              ),
                              if (widget.ganador != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Gana ${widget.ganador}',
                                  style: const TextStyle(
                                    color: AppColors.mint,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                              if (widget.partida.cartasSacadas > 0) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Cartas sacadas: ${widget.partida.cartasSacadas}',
                                  style: const TextStyle(
                                    color: AppColors.textoSuave,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 22),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => mostrarHistorialCuloSucio(
                                    context: context,
                                    partida: widget.partida,
                                  ),
                                  icon: const Icon(Icons.history_rounded),
                                  label: const Text('Historial'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.azul,
                                    side: const BorderSide(
                                      color: AppColors.azul,
                                      width: 1.6,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (widget.mostrarOtraVez) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: widget.onOtraVez,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.peligro,
                                      foregroundColor: Colors.white,
                                    ),
                                    child:
                                        const Text(TextosCuloSucio.reiniciar),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: widget.onVolver,
                                  child:
                                      const Text(TextosCuloSucio.volverMenu),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.expand(),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: BotonOjoVictoria(
                cartelVisible: _cartelVisible,
                onTap: () =>
                    setState(() => _cartelVisible = !_cartelVisible),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
