import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/unoSolo/motor_uno_solo.dart';
import 'package:app_juegos_mesa/unoSolo/standby_store.dart';
import 'package:app_juegos_mesa/unoSolo/textos.dart';
import 'package:app_juegos_mesa/unoSolo/uno_solo_online_codec.dart';
import 'package:app_juegos_mesa/unoSolo/victoria_uno_solo_overlay.dart';

class PartidaUnoSoloScreen extends StatefulWidget {
  const PartidaUnoSoloScreen({
    super.key,
    required this.nombres,
    this.solo = false,
    this.salaCodigo,
    this.miNombre,
    this.ajustesIniciales,
    this.resume,
  });

  final List<String> nombres;
  final bool solo;
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
  AjustesEstado _ajustes = const AjustesEstado();
  bool _mostrarMenu = false;
  bool _mostrarAjustes = false;
  bool _confirmarRendicion = false;
  int? _seleccion;
  String? _aviso;

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
    final resume = widget.resume;
    if (resume != null) {
      _nombres = List.of(resume.nombres);
      _ajustes = resume.ajustesIniciales;
      _partida = resume.partida;
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
    _onlineSub?.cancel();
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
        setState(() => _aviso = 'Elegí una ficha para saltar.');
        return;
      }
      final movs = movimientosDesdeUnoSolo(_partida, index);
      if (movs.isEmpty) {
        setState(() {
          _seleccion = null;
          _aviso = 'Esa ficha no tiene saltos posibles.';
        });
        return;
      }
      setState(() {
        _seleccion = index;
        _aviso = null;
      });
      return;
    }

    if (sel == index) {
      setState(() {
        _seleccion = null;
        _aviso = null;
      });
      return;
    }

    if (celda == CeldaUnoSolo.ocupada) {
      final movs = movimientosDesdeUnoSolo(_partida, index);
      setState(() {
        _seleccion = movs.isEmpty ? null : index;
        _aviso = movs.isEmpty ? 'Esa ficha no tiene saltos posibles.' : null;
      });
      return;
    }

    // Destino vacío: intentar salto.
    final err = jugarSaltoUnoSolo(_partida, sel, index);
    setState(() {
      _aviso = err;
      _seleccion = null;
    });
    if (err == null) unawaited(_publicarEstadoOnline());
  }

  void _volverAJugar() {
    if (_esOnline) return;
    UnoSoloStandByStore.limpiar();
    setState(() {
      _partida = nuevaPartidaUnoSolo(
        nombres: _nombres,
        solo: widget.solo || _nombres.length == 1,
      );
      _seleccion = null;
      _aviso = null;
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
    if (_partida.terminada) return _partida.mensajeFin ?? 'Fin';
    if (_esOnline && !_esMiTurno) {
      return 'Turno de ${_partida.jugadorActual}…';
    }
    if (_seleccion != null) {
      return 'Tocá el hueco vacío donde querés saltar';
    }
    if (_partida.solo) {
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
                            color: AppColors.mint,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 0.6,
                          ),
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
                  if (_aviso != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _aviso!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.acento,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
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
                            return SizedBox(
                              width: side,
                              height: side,
                              child: _TableroUnoSolo(
                                partida: _partida,
                                seleccion: _seleccion,
                                destinos: _destinosResaltados,
                                medios: _mediosResaltados,
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
          if (_partida.terminada)
            Positioned.fill(
              child: VictoriaUnoSoloOverlay(
                partida: _partida,
                mostrarVolverAJugar: !_esOnline,
                onVolverAJugar: _volverAJugar,
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

class _TableroUnoSolo extends StatelessWidget {
  const _TableroUnoSolo({
    required this.partida,
    required this.seleccion,
    required this.destinos,
    required this.medios,
    required this.onTap,
  });

  final PartidaUnoSolo partida;
  final int? seleccion;
  final Set<int> destinos;
  final Set<int> medios;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4CAF50),
            Color(0xFF2E7D32),
            Color(0xFF1B5E20),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.mint, width: 2.4),
        boxShadow: neonGlow(AppColors.mint, blur: 16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: CustomPaint(
          painter: _MarcoCruzPainter(),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: PartidaUnoSolo.columnas,
            ),
            itemCount: PartidaUnoSolo.total,
            itemBuilder: (context, i) {
              final celda = partida.celdas[i];
              if (celda == CeldaUnoSolo.invalida) {
                return const SizedBox.shrink();
              }
              final seleccionada = seleccion == i;
              final destino = destinos.contains(i);
              final medio = medios.contains(i);
              return Padding(
                padding: const EdgeInsets.all(3),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onTap == null ? null : () => onTap!(i),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1B5E20).withValues(alpha: 0.55),
                        border: Border.all(
                          color: seleccionada
                              ? AppColors.acento
                              : destino
                                  ? AppColors.mint
                                  : medio
                                      ? AppColors.rosa.withValues(alpha: 0.7)
                                      : Colors.white.withValues(alpha: 0.2),
                          width: seleccionada || destino ? 2.4 : 1.2,
                        ),
                        boxShadow: seleccionada
                            ? neonGlow(AppColors.acento, blur: 10)
                            : destino
                                ? neonGlow(AppColors.mint, blur: 8)
                                : null,
                      ),
                      child: celda == CeldaUnoSolo.ocupada
                          ? Center(
                              child: Container(
                                width: double.infinity,
                                height: double.infinity,
                                margin: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: seleccionada
                                        ? const [
                                            Color(0xFF82B1FF),
                                            Color(0xFF1565C0),
                                          ]
                                        : const [
                                            Color(0xFF5C6BC0),
                                            Color(0xFF1A237E),
                                          ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : destino
                              ? Center(
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.mint.withValues(alpha: 0.85),
                                    ),
                                  ),
                                )
                              : null,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MarcoCruzPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Solo atmósfera: el grid ya dibuja la cruz con celdas vacías.
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
