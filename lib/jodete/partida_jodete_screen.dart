import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/jodete/ia_jodete.dart';
import 'package:app_juegos_mesa/jodete/menu_partida_jodete.dart';
import 'package:app_juegos_mesa/jodete/motor_jodete.dart';
import 'package:app_juegos_mesa/jodete/standby_store.dart';
import 'package:app_juegos_mesa/jodete/textos.dart';
import 'package:app_juegos_mesa/jodete/victoria_jodete_overlay.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/cartas/carta_espanola_skin.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/partida_ui/cambio_jugador_overlay.dart';
import 'package:app_juegos_mesa/shared/partida_ui/epic_backdrop.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

class PartidaJodeteScreen extends StatefulWidget {
  const PartidaJodeteScreen({
    super.key,
    required this.nombres,
    this.contraPc = false,
    this.modoDios = false,
    this.dificultad = DificultadPc.medio,
    this.resume,
  });

  final List<String> nombres;
  final bool contraPc;
  final bool modoDios;
  final DificultadPc dificultad;
  final PartidaJodeteResume? resume;

  @override
  State<PartidaJodeteScreen> createState() => _PartidaJodeteScreenState();
}

class _PartidaJodeteScreenState extends State<PartidaJodeteScreen> {
  late PartidaJodete _partida;
  late bool _modoDios;
  late DificultadPc _dificultad;
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

  bool get _turnoDePc =>
      widget.contraPc &&
      !_partida.terminada &&
      esNombrePc(_partida.jugadorActual.nombre);

  bool get _puedeJugarHumano =>
      !_partida.terminada &&
      !_turnoDePc &&
      !_jugandoPc &&
      !_esperandoCambioJugador &&
      !_eligiendoPalo &&
      _partida.jugadorActual.activo;

  @override
  void initState() {
    super.initState();
    final resume = widget.resume;
    if (resume != null) {
      _partida = resume.partida;
      _modoDios = resume.modoDios;
      _dificultad = resume.dificultad;
      _ajustes = resume.ajustesIniciales ?? const AjustesEstado();
    } else {
      _modoDios = widget.modoDios;
      _dificultad = widget.dificultad;
      _partida = nuevaPartidaJodete(
        nombres: widget.nombres,
        contraPc: widget.contraPc,
        rng: _rng,
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
    setState(() {
      _partida = nuevaPartidaJodete(
        nombres: [for (final j in _partida.jugadores) j.nombre],
        contraPc: widget.contraPc,
        rng: _rng,
      );
      _seleccion = null;
      _mostrarMenu = false;
      _confirmarRendicion = false;
      _eligiendoPalo = false;
      _cartaPendientePalo = null;
      _esperandoCambioJugador = _esLocalHotSeat;
      _jugandoPc = false;
      _limpiarOverlayPc();
    });
    _talVezPc();
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
            reglasJodete(),
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
      setState(() {
        _cartaPendientePalo = carta;
        _eligiendoPalo = true;
      });
      return;
    }
    _aplicarJugada(carta, null);
  }

  void _elegirPalo(PaloJodete palo) {
    final carta = _cartaPendientePalo;
    if (carta == null) return;
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
    setState(() {
      _seleccion = null;
      if (err != null) {
        // noop visual
      }
    });
    if (err == null) {
      _despuesDeJugada(antes);
    }
  }

  void _levantar() {
    if (!_puedeJugarHumano) return;
    final antes = _partida.indiceTurno;
    levantarPorNoJugarJodete(_partida, rng: _rng);
    setState(() => _seleccion = null);
    _despuesDeJugada(antes);
  }

  void _despuesDeJugada(int indiceAntes) {
    if (_partida.terminada) {
      setState(() {});
      return;
    }
    if (_esLocalHotSeat &&
        _partida.indiceTurno != indiceAntes &&
        !esNombrePc(_partida.jugadorActual.nombre)) {
      setState(() => _esperandoCambioJugador = true);
      return;
    }
    setState(() {});
    _talVezPc();
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
    if (!_turnoDePc || _partida.terminada || _jugandoPc) return;
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
        !_partida.terminada) {
      final plan = planificarJugadaPcJodete(
        _partida,
        dificultad: _dificultad,
        rng: _rng,
      );
      final idxAntes = _partida.indiceTurno;
      final nombrePc = _partida.jugadorActual.nombre.toUpperCase();

      if (plan.levantar) {
        final n = _partida.hayPendienteDos ? _partida.pendienteDos : 1;
        await _mostrarOverlayPc(
          titulo: n > 1 ? '$nombrePc LEVANTA $n' : '$nombrePc LEVANTA',
          soloDorso: true,
        );
        if (!mounted || token != _pcToken) break;
        levantarPorNoJugarJodete(_partida, rng: _rng);
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
      if (_partida.terminada) break;
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
    final mano = actual.mano;

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
                        Text(
                          '${TextosJodete.paloVigente}: '
                          '${nombrePaloJodete(_partida.paloVigente)}'
                          '${_partida.sentido == SentidoJodete.horario ? ' · →' : ' · ←'}',
                          style: const TextStyle(
                            color: AppColors.mint,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _mazoWidget(),
                            const SizedBox(width: 18),
                            if (_partida.cimaDescarte != null)
                              _cartaWidget(
                                _partida.cimaDescarte!,
                                seleccionada: false,
                                w: 78,
                                h: 118,
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          _turnoDePc
                              ? '${actual.nombre} está pensando…'
                              : (_partida.hayPendienteDos
                                  ? '¡${actual.nombre}! Tirás un 2 o levantás ${_partida.pendienteDos}'
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
                    onCancelar: () => setState(() {
                      _eligiendoPalo = false;
                      _cartaPendientePalo = null;
                    }),
                  ),
                ),
              if (_esperandoCambioJugador && !_partida.terminada)
                Positioned.fill(
                  child: CambioJugadorOverlay(
                    nombreJugador: actual.nombre,
                    onAceptar: () {
                      setState(() => _esperandoCambioJugador = false);
                      _talVezPc();
                    },
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
                    jugador: actual.nombre,
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
              if (_partida.terminada)
                Positioned.fill(
                  child: VictoriaJodeteOverlay(
                    partida: _partida,
                    gane: !widget.contraPc ||
                        _partida.ganador == _humanoPrincipal.nombre,
                    animaciones: _ajustes.animaciones,
                    onOtraVez: _reiniciar,
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
    final turno = _partida.jugadorActual.nombre == j.nombre;
    final ver = _modoDiosActivo && esNombrePc(j.nombre);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.carta.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: turno ? AppColors.peligro : AppColors.cartaBorde,
          width: turno ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            j.rendido ? '${j.nombre} (X)' : j.nombre,
            style: TextStyle(
              color: j.rendido ? AppColors.textoSuave : AppColors.texto,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          Text(
            '${j.mano.length} cartas',
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontSize: 11,
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
    required this.onCancelar,
  });

  final ValueChanged<PaloJodete> onElegir;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.carta,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.acento, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  TextosJodete.elegirPalo,
                  style: TextStyle(
                    color: AppColors.mint,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final p in PaloJodete.values)
                      FilledButton(
                        onPressed: () => onElegir(p),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorPaloEspanol(switch (p) {
                            PaloJodete.oro => PaloEspanolVisual.oro,
                            PaloJodete.copa => PaloEspanolVisual.copa,
                            PaloJodete.espada => PaloEspanolVisual.espada,
                            PaloJodete.basto => PaloEspanolVisual.basto,
                          }),
                          foregroundColor: Colors.black,
                        ),
                        child: Text(nombrePaloJodete(p)),
                      ),
                  ],
                ),
                TextButton(
                  onPressed: onCancelar,
                  child: const Text('Cancelar'),
                ),
              ],
            ),
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
      return const Center(
        child: Text('—', style: TextStyle(color: AppColors.textoSuave)),
      );
    }
    return LayoutBuilder(
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
    );
  }
}
