import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
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
  /// Tras ganar: muestra el tablero con el orden real de eliminación.
  bool _verOrdenFinal = false;

  bool get _modoDiosActivo =>
      widget.modoDios &&
      (widget.solo || _partida.solo) &&
      !_esOnline &&
      _guiaDios != null &&
      !_verOrdenFinal;

  bool get _modoPracticaActivo =>
      _opciones.modoPractica && !_esOnline;

  bool get _puedeDeshacer =>
      _modoPracticaActivo && _historial.isNotEmpty;

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
    _opciones = resume?.opciones ?? widget.opciones;
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
      applyUnoSoloGameState(_partida, gameState);
      _nombres = List.of(_partida.nombres);
      _onlineVersion = version;
      _esperandoTableroOnline = false;
      _tableroPublicado = true;
      if (!_esMiTurno) _seleccion = null;
    });
  }

  Future<void> _publicarTableroInicialOnline() async {
    if (!_esOnline || _tableroPublicado || _publicandoOnline) return;
    final generada = nuevaPartidaUnoSolo(nombres: _nombres, solo: false);
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
        final gameState = encodeUnoSoloGameState(
          partida: _partida,
          version: _onlineVersion,
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
      }
    });
    if (err != null) {
      _mostrarAviso(err);
    } else {
      _ocultarAviso();
      unawaited(_publicarEstadoOnline());
    }
  }

  void _deshacer() {
    if (!_puedeDeshacer) {
      _mostrarAviso('Ya estás al inicio de la partida.');
      return;
    }
    final err = deshacerUltimoUnoSolo(_partida, _historial);
    setState(() {
      _seleccion = null;
      _verOrdenFinal = false;
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
      _seleccion = null;
      _aviso = null;
      _verOrdenFinal = false;
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
        _partida.mensajeFin = '$yo se rindió.';
      } else if (otros.length == 1 || _partida.nombres.length <= 2) {
        _partida.fase = FaseUnoSolo.ganado;
        _partida.ganador = otros.first;
        _partida.mensajeFin = '$yo se rindió. ¡${otros.first} gana!';
      } else {
        // Varios: sacar al rendido del turno y seguir (simplificado: gana el siguiente).
        // Mantener simple: el siguiente activo gana solo si queda uno; si no, removemos del ciclo.
        _partida.fase = FaseUnoSolo.ganado;
        _partida.ganador = otros.first;
        _partida.mensajeFin = '$yo se rindió. ¡${otros.first} gana!';
      }
    });
    unawaited(_publicarEstadoOnline(forzar: true));
    if (_esOnline && !_partida.terminada && mounted) {
      Navigator.of(context).pop();
    }
  }

  Set<int> get _destinosResaltados {
    final sel = _seleccion;
    if (sel == null) return {};
    return {
      for (final m in movimientosDesdeUnoSolo(_partida, sel)) m.hasta,
    };
  }

  Set<int> get _mediosResaltados {
    final sel = _seleccion;
    if (sel == null) return {};
    return {
      for (final m in movimientosDesdeUnoSolo(_partida, sel)) m.medio,
    };
  }

  String get _textoEstado {
    if (_esperandoTableroOnline) {
      return _soyAnfitrionOnline
          ? 'Preparando tablero compartido…'
          : 'Esperando el tablero del anfitrión…';
    }
    if (_partida.terminada) {
      if (_verOrdenFinal) {
        return 'Orden de eliminación · tocá “Volver al resultado”';
      }
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
        return 'Modo Dios · números = orden de eliminación';
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
                        child: Text(
                          'Uno solo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFFFB74D),
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 0.6,
                          ),
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
                        '← o Espacio: deshacer un movimiento',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.acento.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: _puedeDeshacer ? _deshacer : null,
                        icon: const Icon(Icons.undo_rounded, size: 18),
                        label: const Text(
                          'Deshacer',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.acento,
                          disabledForegroundColor:
                              AppColors.textoSuave.withValues(alpha: 0.4),
                          side: BorderSide(
                            color: _puedeDeshacer
                                ? AppColors.acento
                                : AppColors.textoSuave.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                          backgroundColor: AppColors.carta,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_verOrdenFinal) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: () =>
                            setState(() => _verOrdenFinal = false),
                        icon: const Icon(Icons.emoji_events_rounded),
                        label: const Text('Volver al resultado'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.acento,
                        ),
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
                            final ordenReview = _verOrdenFinal
                                ? ordenEliminacionDesdeHistorial(_historial)
                                : null;
                            return SizedBox(
                              width: side,
                              height: side,
                              child: TableroUnoSolo(
                                partida: _partida,
                                seleccion: _seleccion,
                                destinos: _destinosResaltados,
                                medios: _mediosResaltados,
                                ordenEliminacion: ordenReview ??
                                    (_modoDiosActivo
                                        ? _guiaDios!.ordenEliminacion
                                        : null),
                                mostrarOrdenEnVacias: ordenReview != null,
                                proximoDesde: _modoDiosActivo
                                    ? _guiaDios!
                                        .proximoLegal(_partida)
                                        ?.desde
                                    : null,
                                onTap: _bloquearHumano || _verOrdenFinal
                                    ? null
                                    : _onTapCelda,
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
          if (_partida.terminada && !_verOrdenFinal)
            Positioned.fill(
              child: VictoriaUnoSoloOverlay(
                partida: _partida,
                mostrarVolverAJugar: !_esOnline,
                onVolverAJugar: _volverAJugar,
                onVerOrden: _historial.isEmpty
                    ? null
                    : () => setState(() => _verOrdenFinal = true),
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
      color: Colors.black.withValues(alpha: 0.7),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: BoxDecoration(
                color: AppColors.carta,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.mint, width: 2),
                boxShadow: neonGlow(AppColors.mint, blur: 16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          partidaTerminada ? 'Menú' : 'Turno de $jugador',
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onCerrar,
                        icon: const Icon(Icons.close, color: AppColors.texto),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: onReglas,
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text('REGLAS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.azul,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (partidaTerminada || esSolo)
                    ElevatedButton.icon(
                      onPressed: onSalirORendirse,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('SALIR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.peligro,
                        foregroundColor: Colors.white,
                      ),
                    )
                  else if (!confirmarRendicion)
                    ElevatedButton.icon(
                      onPressed: onSalirORendirse,
                      icon: const Icon(Icons.flag_rounded),
                      label: const Text('RENDIRSE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.peligro,
                        foregroundColor: Colors.white,
                      ),
                    )
                  else ...[
                    const Text(
                      '¿Confirmás tu derrota?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.peligro,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: onConfirmarRendicion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.peligro,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('CONFIRMAR RENDICIÓN'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: onCancelarRendicion,
                      child: const Text('Cancelar'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
