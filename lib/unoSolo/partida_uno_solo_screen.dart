import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/partida_ui/epic_backdrop.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/unoSolo/guia_modo_dios_uno_solo.dart';
import 'package:app_juegos_mesa/unoSolo/motor_uno_solo.dart';
import 'package:app_juegos_mesa/unoSolo/opciones_uno_solo.dart';
import 'package:app_juegos_mesa/unoSolo/standby_store.dart';
import 'package:app_juegos_mesa/unoSolo/textos.dart';
import 'package:app_juegos_mesa/unoSolo/tablero_uno_solo.dart';
import 'package:app_juegos_mesa/unoSolo/uno_solo_online_codec.dart';
import 'package:app_juegos_mesa/unoSolo/victoria_uno_solo_overlay.dart';

class PartidaUnoSoloScreen extends StatefulWidget {
  const PartidaUnoSoloScreen({
    super.key,
    required this.nombres,
    this.solo = false,
    this.modoDios = false,
    this.opciones = const OpcionesUnoSolo(),
    this.salaCodigo,
    this.miNombre,
    this.ajustesIniciales,
    this.resume,
  });

  final List<String> nombres;
  final bool solo;
  /// Tutorial: números de orden de eliminación (solo en Jugar solo).
  final bool modoDios;
  final OpcionesUnoSolo opciones;
  final String? salaCodigo;
  final String? miNombre;
  final AjustesEstado? ajustesIniciales;
  final PartidaUnoSoloResume? resume;

  @override
  State<PartidaUnoSoloScreen> createState() => _PartidaUnoSoloScreenState();
}

class _PartidaUnoSoloScreenState extends State<PartidaUnoSoloScreen> {
  static const int _maxNombre = 15;

  late PartidaUnoSolo _partida;
  late List<String> _nombres;
  late OpcionesUnoSolo _opciones;
  AjustesEstado _ajustes = const AjustesEstado();
  bool _mostrarMenu = false;
  bool _mostrarAjustes = false;
  bool _confirmarRendicion = false;
  int? _seleccion;
  String? _aviso;
  Timer? _avisoTimer;
  late final GuiaModoDiosUnoSolo? _guiaDios;
  final List<MovimientoUnoSolo> _historial = [];
  /// Movimientos deshechos que se pueden rehacer (modo práctica).
  final List<MovimientoUnoSolo> _rehacer = [];

  bool get _modoDiosActivo =>
      widget.modoDios &&
      (widget.solo || _partida.solo) &&
      !_esOnline &&
      _guiaDios != null;

  bool get _modoPracticaActivo =>
      _opciones.modoPractica && !_esOnline;

  bool get _puedeDeshacer =>
      _modoPracticaActivo && _historial.isNotEmpty;

  bool get _puedeRehacer =>
      _modoPracticaActivo && _rehacer.isNotEmpty;

  bool get _esCelular {
    final p = Theme.of(context).platform;
    return p == TargetPlatform.android || p == TargetPlatform.iOS;
  }

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

  bool get _esMiTurno =>
      !_esOnline || _partida.jugadorActual == widget.miNombre;

  bool get _soyAnfitrionOnline =>
      _esOnline &&
      _partida.nombres.isNotEmpty &&
      _partida.nombres.first == widget.miNombre;

  bool get _bloquearHumano =>
      _partida.terminada ||
      (_esOnline && (_esperandoTableroOnline || !_esMiTurno));

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onTeclaDeshacer);
    final resume = widget.resume;
    final quiereGuia = widget.modoDios || (resume?.modoDios ?? false);
    _guiaDios = quiereGuia ? GuiaModoDiosUnoSolo.estandar() : null;
    _opciones = widget.opciones;
    if (resume != null) {
      _nombres = List.of(resume.nombres);
      _ajustes = resume.ajustesIniciales;
      _partida = resume.partida;
      _historial
        ..clear()
        ..addAll(resume.historial);
      return;
    }
    _nombres = List.of(widget.nombres);
    _ajustes = widget.ajustesIniciales ?? const AjustesEstado();
    if (_esOnline) {
      _esperandoTableroOnline = true;
      _partida = nuevaPartidaUnoSolo(nombres: _nombres, solo: false);
      // Vaciar hasta sync (evita tableros distintos).
      for (var i = 0; i < _partida.celdas.length; i++) {
        if (_partida.celdas[i] != CeldaUnoSolo.invalida) {
          _partida.celdas[i] = CeldaUnoSolo.vacia;
        }
      }
      _iniciarSincronizacionOnline();
      return;
    }
    _partida = nuevaPartidaUnoSolo(
      nombres: _nombres,
      solo: widget.solo || _nombres.length == 1,
    );
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onTeclaDeshacer);
    _avisoTimer?.cancel();
    _onlineSub?.cancel();
    super.dispose();
  }

  bool _onTeclaDeshacer(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!_modoPracticaActivo) return false;
    if (_mostrarMenu || _mostrarAjustes) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight) {
      if (!mounted) return false;
      _rehacerMovimiento();
      return true;
    }
    if (key != LogicalKeyboardKey.arrowLeft &&
        key != LogicalKeyboardKey.space) {
      return false;
    }
    if (!mounted) return false;
    _deshacer();
    return true;
  }

  void _mostrarAviso(String mensaje) {
    _avisoTimer?.cancel();
    setState(() => _aviso = mensaje);
    _avisoTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      setState(() => _aviso = null);
    });
  }

  void _ocultarAviso() {
    _avisoTimer?.cancel();
    if (_aviso != null) setState(() => _aviso = null);
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
    if (juego != 'unoSolo') {
      if (_soyAnfitrionOnline && !_tableroPublicado) {
        unawaited(_publicarTableroInicialOnline());
      }
      return;
    }

    final version = (gameState['version'] as num?)?.toInt() ?? 0;
    if (version < _onlineVersion) return;
    if (_publicandoOnline && version <= _onlineVersion) return;

    final tiene = unoSoloPartidaGenerada(gameState);
    if (!tiene) {
      if (_soyAnfitrionOnline && !_tableroPublicado) {
        unawaited(_publicarTableroInicialOnline());
      }
      return;
    }

    if (version <= _onlineVersion && !_esperandoTableroOnline) return;

    setState(() {
      applyUnoSoloGameState(
        _partida,
        gameState,
        historialOut: _historial,
      );
      _nombres = List.of(_partida.nombres);
      _onlineVersion = version;
      _esperandoTableroOnline = false;
      _tableroPublicado = true;
      _rehacer.clear();
      if (!_esMiTurno) _seleccion = null;
    });
  }

  Future<void> _publicarTableroInicialOnline() async {
    if (!_esOnline || _tableroPublicado || _publicandoOnline) return;
    final generada = nuevaPartidaUnoSolo(nombres: _nombres, solo: false);
    setState(() {
      _partida = generada;
      _historial.clear();
      _rehacer.clear();
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
        final gameState = encodeUnoSoloGameState(
          partida: _partida,
          version: _onlineVersion,
          historial: _historial,
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

  void _onTapCelda(int index) {
    if (_bloquearHumano) return;
    if (_partida.celdas[index] == CeldaUnoSolo.invalida) return;

    final celda = _partida.celdas[index];
    final sel = _seleccion;

    if (sel == null) {
      if (celda != CeldaUnoSolo.ocupada) {
        _mostrarAviso('Elegí una ficha para saltar.');
        return;
      }
      final movs = movimientosDesdeUnoSolo(_partida, index);
      if (movs.isEmpty) {
        setState(() => _seleccion = null);
        _mostrarAviso('Esa ficha no tiene saltos posibles.');
        return;
      }
      setState(() => _seleccion = index);
      _ocultarAviso();
      return;
    }

    if (sel == index) {
      setState(() => _seleccion = null);
      _ocultarAviso();
      return;
    }

    if (celda == CeldaUnoSolo.ocupada) {
      final movs = movimientosDesdeUnoSolo(_partida, index);
      setState(() => _seleccion = movs.isEmpty ? null : index);
      if (movs.isEmpty) {
        _mostrarAviso('Esa ficha no tiene saltos posibles.');
      } else {
        _ocultarAviso();
      }
      return;
    }

    // Destino vacío: intentar salto.
    final mov = buscarSaltoUnoSolo(_partida, sel, index);
    final err = mov == null
        ? 'Ese salto no es válido.'
        : jugarMovimientoUnoSolo(_partida, mov);
    setState(() {
      _seleccion = null;
      if (err == null && mov != null) {
        _historial.add(mov);
        _rehacer.clear();
      }
    });
    if (err != null) {
      _mostrarAviso(err);
    } else {
      _ocultarAviso();
      unawaited(_publicarEstadoOnline(forzar: _partida.terminada));
    }
  }

  void _deshacer() {
    if (!_puedeDeshacer) {
      _mostrarAviso('Ya estás al inicio de la partida.');
      return;
    }
    final mov = _historial.last;
    final err = deshacerUltimoUnoSolo(_partida, _historial);
    setState(() {
      _seleccion = null;
      if (err == null) {
        _rehacer.add(mov);
      }
    });
    if (err != null) {
      _mostrarAviso(err);
    } else {
      _ocultarAviso();
    }
  }

  void _rehacerMovimiento() {
    if (!_puedeRehacer) {
      _mostrarAviso('No hay movimiento para rehacer.');
      return;
    }
    final mov = _rehacer.removeLast();
    final err = jugarMovimientoUnoSolo(_partida, mov);
    setState(() {
      _seleccion = null;
      if (err == null) {
        _historial.add(mov);
      } else {
        _rehacer.add(mov);
      }
    });
    if (err != null) {
      _mostrarAviso(err);
    } else {
      _ocultarAviso();
    }
  }

  void _volverAJugar() {
    if (_esOnline) return;
    UnoSoloStandByStore.limpiar();
    _avisoTimer?.cancel();
    setState(() {
      _partida = nuevaPartidaUnoSolo(
        nombres: _nombres,
        solo: widget.solo || _nombres.length == 1,
      );
      _historial.clear();
      _rehacer.clear();
      _seleccion = null;
      _aviso = null;
      _mostrarMenu = false;
      _mostrarAjustes = false;
      _confirmarRendicion = false;
    });
  }

  void _salirAlMenu() {
    Navigator.of(context).pop();
  }

  void _salirGuardandoResume() {
    if (!widget.solo || _esOnline) {
      _salirAlMenu();
      return;
    }
    UnoSoloStandByStore.guardar(
      PartidaUnoSoloResume(
        partida: _partida,
        nombres: _nombres,
        ajustesIniciales: _ajustes,
        modoDios: widget.modoDios,
        opciones: _opciones,
        historial: List.of(_historial),
      ),
    );
    _salirAlMenu();
  }

  void _rendirse() {
    if (_partida.terminada) return;
    if (widget.solo && !_esOnline) {
      _salirGuardandoResume();
      return;
    }
    final yo = _esOnline
        ? (widget.miNombre ?? _partida.jugadorActual)
        : _partida.jugadorActual;
    final otros = [
      for (final n in _partida.nombres)
        if (n != yo) n,
    ];
    setState(() {
      _mostrarMenu = false;
      _confirmarRendicion = false;
      _seleccion = null;
      if (otros.isEmpty) {
        _partida.fase = FaseUnoSolo.perdido;
        _partida.ganador = null;
        _partida.calificacion = null;
        _partida.mensajeFin = '$yo se rindió.';
      } else {
        // Multijugador: gana el rival (victoria por abandono).
        _partida.fase = FaseUnoSolo.ganado;
        _partida.ganador = otros.first;
        _partida.calificacion = '¡Victoria!';
        _partida.mensajeFin =
            '$yo se rindió. ¡${otros.first} gana por abandono!';
      }
    });
    unawaited(_publicarEstadoOnline(forzar: true));
    if (_esOnline && !_partida.terminada && mounted) {
      Navigator.of(context).pop();
    }
  }

  Set<int> get _destinosResaltados {
    final sel = _seleccion;
    if (sel != null) {
      return {
        for (final m in movimientosDesdeUnoSolo(_partida, sel)) m.hasta,
      };
    }
    if (_modoDiosActivo) {
      final prox = _guiaDios!.proximoLegal(_partida);
      if (prox != null) return {prox.hasta};
    }
    return {};
  }

  Set<int> get _mediosResaltados {
    final sel = _seleccion;
    if (sel != null) {
      return {
        for (final m in movimientosDesdeUnoSolo(_partida, sel)) m.medio,
      };
    }
    if (_modoDiosActivo) {
      final prox = _guiaDios!.proximoLegal(_partida);
      if (prox != null) return {prox.medio};
    }
    return {};
  }

  String get _nombreHeader {
    if (_esOnline) {
      return widget.miNombre ?? _partida.jugadorActual;
    }
    return _partida.jugadorActual;
  }

  int? get _indiceRenombrable {
    if (_partida.terminada || _nombres.isEmpty) return null;
    if (_esOnline) {
      final i = _nombres.indexWhere((n) => n == widget.miNombre);
      return i >= 0 ? i : null;
    }
    return _partida.indiceTurno % _nombres.length;
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

  Future<void> _renombrarDesdeHeader() async {
    final index = _indiceRenombrable;
    if (index == null) return;
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
    });
    unawaited(_publicarEstadoOnline(forzar: true));
  }

  Widget _chipNombre() {
    final nombre = _nombreHeader;
    final puedeRenombrar = _indiceRenombrable != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: puedeRenombrar ? _renombrarDesdeHeader : null,
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

  String get _textoEstado {
    if (_esperandoTableroOnline) {
      return _soyAnfitrionOnline
          ? 'Preparando tablero compartido…'
          : 'Esperando el tablero del anfitrión…';
    }
    if (_partida.terminada) {
      return _partida.mensajeFin ?? 'Fin';
    }
    if (_esOnline && !_esMiTurno) {
      return 'Turno de ${_partida.jugadorActual}…';
    }
    if (_seleccion != null) {
      return 'Tocá el hueco vacío donde querés saltar';
    }
    if (_partida.solo) {
      if (_modoDiosActivo) {
        return 'Modo Dios · flecha = ficha a comer (hacia el centro)';
      }
      if (_modoPracticaActivo) {
        return 'Modo práctica · ${_partida.fichasRestantes} fichas';
      }
      return 'Dejá una ficha en el centro · ${_partida.fichasRestantes} fichas';
    }
    return 'Turno de ${_partida.jugadorActual} · ${_partida.fichasRestantes} fichas';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Stack(
        children: [
          const Positioned.fill(child: EpicBackdrop()),
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
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Flexible(
                              child: Text(
                                'Uno solo · ',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Color(0xFFFFB74D),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            Flexible(child: _chipNombre()),
                          ],
                        ),
                      ),
                      if ((widget.solo || _partida.solo) && !_esOnline)
                        IconButton(
                          tooltip: 'Reiniciar tablero',
                          onPressed: _volverAJugar,
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: AppColors.textoSuave,
                          ),
                        ),
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
                  Text(
                    _textoEstado,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _esOnline && !_esMiTurno
                          ? AppColors.rosa
                          : AppColors.textoSuave,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (_modoPracticaActivo) ...[
                    if (!_esCelular) ...[
                      const SizedBox(height: 6),
                      Text(
                        '← / Espacio: deshacer · →: rehacer',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.acento.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _BotonCircularPractica(
                            icon: Icons.undo_rounded,
                            activo: _puedeDeshacer,
                            onTap: _puedeDeshacer ? _deshacer : null,
                          ),
                          const SizedBox(width: 10),
                          _BotonCircularPractica(
                            icon: Icons.redo_rounded,
                            activo: _puedeRehacer,
                            onTap: _puedeRehacer ? _rehacerMovimiento : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final side = math.min(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            final ordenDios = _modoDiosActivo
                                ? {
                                    for (final e
                                        in _guiaDios!.ordenEliminacion.entries)
                                      e.key: '${e.value}',
                                  }
                                : null;
                            final proxDios = _modoDiosActivo
                                ? _guiaDios!.proximoLegal(_partida)
                                : null;
                            return SizedBox(
                              width: side,
                              height: side,
                              child: TableroUnoSolo(
                                partida: _partida,
                                seleccion: _seleccion,
                                destinos: _destinosResaltados,
                                medios: _mediosResaltados,
                                ordenEliminacion: ordenDios,
                                mostrarOrdenEnVacias: false,
                                proximoDesde: proxDios?.desde,
                                proximoMedio: proxDios?.medio,
                                onTap: _bloquearHumano ? null : _onTapCelda,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Notificación superior (avisos de jugada inválida).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: IgnorePointer(
                ignoring: _aviso == null,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  offset: _aviso == null ? const Offset(0, -1.2) : Offset.zero,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _aviso == null ? 0 : 1,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                      child: Material(
                        color: Colors.transparent,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.carta,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.acento,
                              width: 1.8,
                            ),
                            boxShadow: [
                              ...neonGlow(AppColors.acento, blur: 14),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_rounded,
                                  color: AppColors.acento,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _aviso ?? '',
                                    style: const TextStyle(
                                      color: AppColors.texto,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: _ocultarAviso,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: AppColors.textoSuave,
                                    size: 20,
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
              child: _MenuPartidaUnoSolo(
                jugador: _esOnline
                    ? (widget.miNombre ?? _partida.jugadorActual)
                    : _partida.jugadorActual,
                partidaTerminada: _partida.terminada,
                esSolo: widget.solo || _partida.solo,
                confirmarRendicion: _confirmarRendicion &&
                    !widget.solo &&
                    !_partida.solo,
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
                          reglasUnoSolo(),
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
                        UnoSoloStandByStore.limpiar();
                        _salirAlMenu();
                      }
                    : (widget.solo || _partida.solo
                        ? _salirGuardandoResume
                        : () => setState(() => _confirmarRendicion = true)),
                onConfirmarRendicion: _rendirse,
                onCancelarRendicion: () =>
                    setState(() => _confirmarRendicion = false),
              ),
            ),
          if (_partida.terminada &&
              VictoriaUnoSoloOverlay.debeMostrar(_partida))
            Positioned.fill(
              child: VictoriaUnoSoloOverlay(
                partida: _partida,
                animaciones: _ajustes.animaciones,
                mostrarVolverAJugar: !_esOnline,
                ordenEliminacion: _historial.isEmpty
                    ? null
                    : ordenEliminacionDesdeHistorial(_historial),
                onVolverAJugar: _volverAJugar,
                onDeshacer: _puedeDeshacer ? _deshacer : null,
                onVolver: () {
                  UnoSoloStandByStore.limpiar();
                  _salirAlMenu();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuPartidaUnoSolo extends StatelessWidget {
  const _MenuPartidaUnoSolo({
    required this.jugador,
    required this.partidaTerminada,
    required this.esSolo,
    required this.confirmarRendicion,
    required this.onCerrar,
    required this.onReglas,
    required this.onSalirORendirse,
    required this.onConfirmarRendicion,
    required this.onCancelarRendicion,
  });

  final String jugador;
  final bool partidaTerminada;
  final bool esSolo;
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
                              : (esSolo ? 'Juego en curso' : 'Turno actual'),
                          style: TextStyle(
                            color: AppColors.textoSuave.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _ArcadeButtonUnoSolo(
                          label: 'REGLAS',
                          icon: Icons.menu_book_rounded,
                          tono: _BotonTonoUnoSolo.azul,
                          onPressed: onReglas,
                        ),
                        const SizedBox(height: 10),
                        if (partidaTerminada || esSolo)
                          _ArcadeButtonUnoSolo(
                            label: 'SALIR',
                            icon: Icons.logout_rounded,
                            tono: _BotonTonoUnoSolo.rojo,
                            onPressed: onSalirORendirse,
                          )
                        else if (!confirmarRendicion)
                          _ArcadeButtonUnoSolo(
                            label: 'RENDIRSE',
                            icon: Icons.flag_rounded,
                            tono: _BotonTonoUnoSolo.rojo,
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
                          _ArcadeButtonUnoSolo(
                            label: 'CONFIRMAR RENDICIÓN',
                            icon: Icons.check_circle_outline,
                            tono: _BotonTonoUnoSolo.rojo,
                            onPressed: onConfirmarRendicion,
                          ),
                          const SizedBox(height: 10),
                          _ArcadeButtonUnoSolo(
                            label: 'CANCELAR',
                            icon: Icons.close,
                            tono: _BotonTonoUnoSolo.violeta,
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

enum _BotonTonoUnoSolo { violeta, azul, rojo }

class _ArcadeButtonUnoSolo extends StatelessWidget {
  const _ArcadeButtonUnoSolo({
    required this.label,
    required this.icon,
    required this.tono,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final _BotonTonoUnoSolo tono;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    late final List<Color> colors;
    late final Color glow;
    late final Color fg;

    switch (tono) {
      case _BotonTonoUnoSolo.violeta:
        colors = const [
          Color(0xFFCE93D8),
          Color(0xFFAB47BC),
          Color(0xFF6A1B9A),
        ];
        glow = AppColors.rosa;
        fg = Colors.white;
      case _BotonTonoUnoSolo.azul:
        colors = const [
          Color(0xFF81D4FA),
          Color(0xFF29B6F6),
          Color(0xFF0277BD),
        ];
        glow = AppColors.azul;
        fg = Colors.white;
      case _BotonTonoUnoSolo.rojo:
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

class _BotonCircularPractica extends StatelessWidget {
  const _BotonCircularPractica({
    required this.icon,
    required this.activo,
    required this.onTap,
  });

  final IconData icon;
  final bool activo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: activo
          ? AppColors.acento
          : AppColors.carta.withValues(alpha: 0.75),
      shape: const CircleBorder(),
      elevation: activo ? 4 : 0,
      shadowColor: AppColors.acento.withValues(alpha: 0.55),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            size: 26,
            color: activo
                ? const Color(0xFF1A0A00)
                : AppColors.textoSuave.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
