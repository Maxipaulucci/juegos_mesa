import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/desconfio/ia_desconfio.dart';
import 'package:app_juegos_mesa/desconfio/menu_partida_desconfio.dart';
import 'package:app_juegos_mesa/desconfio/motor_desconfio.dart';
import 'package:app_juegos_mesa/desconfio/standby_store.dart';
import 'package:app_juegos_mesa/desconfio/textos.dart';
import 'package:app_juegos_mesa/desconfio/victoria_desconfio_overlay.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/cartas/carta_espanola_skin.dart';
import 'package:app_juegos_mesa/shared/cartas/reordenar_carta_mano.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/partida_ui/epic_backdrop.dart';
import 'package:app_juegos_mesa/shared/partida_ui/reiniciar_partida_pc.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Partida local / vs PC de Desconfío.
class PartidaDesconfioScreen extends StatefulWidget {
  const PartidaDesconfioScreen({
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
  final PartidaDesconfioResume? resume;

  @override
  State<PartidaDesconfioScreen> createState() => _PartidaDesconfioScreenState();
}

class _PartidaDesconfioScreenState extends State<PartidaDesconfioScreen> {
  static const double _cartaW = 64;
  static const double _cartaH = 96;

  late PartidaDesconfio _partida;
  late List<String> _nombres;
  late bool _modoDios;
  late DificultadPc _dificultad;
  AjustesEstado _ajustes = const AjustesEstado();
  bool _mostrarMenu = false;
  bool _mostrarAjustes = false;
  bool _confirmarRendicion = false;
  int? _seleccionMano;
  bool _pcPensando = false;

  bool get _esLocalHotSeat => !widget.contraPc;
  bool get _modoDiosActivo => _modoDios && widget.contraPc;

  JugadorDesconfio get _humanoPrincipal {
    if (widget.contraPc) {
      return _partida.jugadores.firstWhere(
        (j) => !esNombrePc(j.nombre),
        orElse: () => _partida.jugadores.first,
      );
    }
    return _partida.jugadorActual;
  }

  JugadorDesconfio get _vistaLocal {
    if (widget.contraPc) return _humanoPrincipal;
    // En reacción local: ve el que puede desconfiar / seguir (no el que tiró).
    if (_partida.fase == FaseDesconfio.esperandoReaccion) {
      final d = _desafianteActual;
      if (d != null) {
        for (final j in _partida.jugadores) {
          if (j.nombre == d) return j;
        }
      }
    }
    return _partida.jugadorActual;
  }

  @override
  void initState() {
    super.initState();
    _modoDios = widget.modoDios;
    _dificultad = widget.dificultad;
    final resume = widget.resume;
    if (resume != null) {
      _partida = resume.partida;
      _nombres = List.of(resume.nombres);
      // Seguir con el modo dios de la partida guardada; el del menú
      // solo se aplica al reiniciar / actualizar partida.
      _modoDios = resume.modoDios;
    } else {
      _nombres = List.of(widget.nombres);
      _partida = nuevaPartidaDesconfio(
        nombres: _nombres,
        contraPc: widget.contraPc,
      );
      _nombres = [for (final j in _partida.jugadores) j.nombre];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezPc());
  }

  PaloEspanolVisual _paloVisual(PaloDesconfio p) => switch (p) {
        PaloDesconfio.oro => PaloEspanolVisual.oro,
        PaloDesconfio.copa => PaloEspanolVisual.copa,
        PaloDesconfio.espada => PaloEspanolVisual.espada,
        PaloDesconfio.basto => PaloEspanolVisual.basto,
      };

  Widget _carta(CartaDesconfio c, {required bool bocaArriba, bool sel = false}) {
    return CartaEspanolaSkin(
      numero: c.numero,
      etiqueta: c.etiqueta,
      palo: _paloVisual(c.palo),
      bocaArriba: bocaArriba,
      seleccionada: sel,
      width: _cartaW,
      height: _cartaH,
    );
  }

  void _snack(String? err) {
    if (err == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
  }

  void _guardarResumeSiCorresponde() {
    if (!widget.contraPc) return;
    if (_partida.terminada) {
      DesconfioStandByStore.limpiar();
      return;
    }
    DesconfioStandByStore.guardar(
      PartidaDesconfioResume(
        partida: _partida,
        nombres: _nombres,
        modoDios: _modoDios,
      ),
    );
  }

  void _salirAlMenu({required bool guardar}) {
    if (guardar) {
      _guardarResumeSiCorresponde();
    } else {
      DesconfioStandByStore.limpiar();
    }
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  void _reiniciar() {
    DesconfioStandByStore.limpiar();
    setState(() {
      _modoDios = modoDiosElegidoEnMenu(
        MenuJuegoScreen.juegoIdDesconfio,
        fallback: widget.modoDios,
      );
      if (widget.contraPc) {
        final pcs = cantidadPcElegidaEnMenu(
              MenuJuegoScreen.juegoIdDesconfio,
            ) ??
            cantidadPcEnNombres(_nombres);
        _nombres = reconstruirNombresVsPc(
          actuales: _nombres,
          cantidadPc: pcs.clamp(1, 3),
        );
      }
      _partida = nuevaPartidaDesconfio(
        nombres: _nombres,
        contraPc: widget.contraPc,
      );
      _nombres = [for (final j in _partida.jugadores) j.nombre];
      _seleccionMano = null;
      _mostrarMenu = false;
      _mostrarAjustes = false;
      _confirmarRendicion = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezPc());
  }

  Future<void> _pedirReiniciarVsPc() async {
    if (!widget.contraPc) return;
    final ok = await confirmarReiniciarPartidaPc(context);
    if (!ok || !mounted) return;
    _reiniciar();
  }

  void _mostrarReglas() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.carta,
        title: const Text(
          'Reglas',
          style: TextStyle(
            color: AppColors.azulSuave,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            reglasDesconfio(),
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

  void _elegirPalo(PaloDesconfio palo) {
    final err = elegirPaloDesconfio(_partida, palo);
    setState(() => _seleccionMano = null);
    _snack(err);
    _talVezPc();
  }

  void _tirarSeleccionada() {
    final i = _seleccionMano;
    if (i == null) {
      _snack('Elegí una carta de tu mano');
      return;
    }
    final err = tirarCartaDesconfio(_partida, i);
    setState(() => _seleccionMano = null);
    _snack(err);
    if (err == null && widget.contraPc) {
      _talVezReaccionPc();
    }
  }

  /// Segundo toque a la misma carta, o toque al pozo con carta seleccionada.
  void _tirarSeleccionSiCorresponde() {
    if (_seleccionMano == null || !_puedeElegirCartaParaTirar) return;
    if (_partida.fase == FaseDesconfio.jugando) {
      _tirarSeleccionada();
      return;
    }
    if (_partida.fase == FaseDesconfio.esperandoReaccion) {
      _tirarSinDesconfiar();
    }
  }

  void _alTocarCartaMano(int i) {
    if (!_puedeElegirCartaParaTirar) return;
    if (_seleccionMano == i) {
      _tirarSeleccionSiCorresponde();
      return;
    }
    setState(() => _seleccionMano = i);
  }

  void _reordenarMano(int desde, int hacia) {
    if (_partida.terminada) return;
    final mano = _vistaLocal.mano;
    if (desde < 0 ||
        hacia < 0 ||
        desde >= mano.length ||
        hacia >= mano.length) {
      return;
    }
    if (desde == hacia) return;
    final carta = mano.removeAt(desde);
    mano.insert(hacia, carta);
    setState(() {
      final sel = _seleccionMano;
      if (sel == null) return;
      if (sel == desde) {
        _seleccionMano = hacia;
      } else if (desde < hacia && sel > desde && sel <= hacia) {
        _seleccionMano = sel - 1;
      } else if (hacia < desde && sel >= hacia && sel < desde) {
        _seleccionMano = sel + 1;
      }
    });
  }

  /// No desconfío: paso el turno y tiro la carta elegida al pozo.
  void _tirarSinDesconfiar() {
    final i = _seleccionMano;
    if (i == null) {
      _snack('Elegí una carta de tu mano');
      return;
    }
    // Guardamos la carta por valor: tras seguir el índice sigue valiendo
    // en la misma mano del humano.
    final errSeguir = seguirTrasTiradaDesconfio(_partida);
    if (errSeguir != null) {
      _snack(errSeguir);
      setState(() {});
      return;
    }
    if (_partida.terminada) {
      setState(() => _seleccionMano = null);
      return;
    }
    final yo = widget.contraPc ? _humanoPrincipal : _partida.jugadorActual;
    if (_partida.jugadorActual.nombre != yo.nombre) {
      setState(() => _seleccionMano = null);
      _talVezPc();
      return;
    }
    if (i < 0 || i >= yo.mano.length) {
      setState(() => _seleccionMano = null);
      _snack('Elegí una carta de tu mano');
      return;
    }
    final errTirar = tirarCartaDesconfio(_partida, i);
    setState(() => _seleccionMano = null);
    _snack(errTirar);
    if (errTirar == null && widget.contraPc) {
      _talVezReaccionPc();
    }
  }

  void _desconfiar(String nombre) {
    if (_partida.pozo.isEmpty) {
      _snack('No hay carta en el pozo para desconfiar.');
      return;
    }
    final tirador = _partida.ultimaDelPozo?.jugador;
    if (tirador != null && tirador == _vistaLocal.nombre) {
      _snack('No podés desconfiar de tu propia carta.');
      return;
    }
    final err = desconfiarDesconfio(_partida, nombre);
    setState(() => _seleccionMano = null);
    _snack(err);
  }

  void _continuarRevelacion() {
    final err = continuarTrasRevelacionDesconfio(_partida);
    setState(() {});
    _snack(err);
    _talVezPc();
  }

  /// Tras el tiro de la PC: puedo elegir carta y tocar Tirar / Desconfío.
  bool get _puedeElegirCartaParaTirar {
    if (_partida.terminada || _pcPensando) return false;
    if (_partida.fase == FaseDesconfio.jugando) {
      if (_turnoDePc) return false;
      return _partida.jugadorActual.nombre == _vistaLocal.nombre;
    }
    if (_partida.fase == FaseDesconfio.esperandoReaccion) {
      final tirador = _partida.ultimaDelPozo?.jugador;
      if (tirador == null) return false;
      // Solo si tiró la PC (o un rival), no si tiré yo.
      // Nota: jugadorActual sigue siendo el tirador (PC), pero igual
      // el humano debe poder elegir carta para Tirar.
      if (widget.contraPc) {
        return esNombrePc(tirador);
      }
      return tirador != _vistaLocal.nombre;
    }
    return false;
  }

  bool get _turnoDePc {
    if (!widget.contraPc || _partida.terminada) return false;
    return esNombrePc(_partida.jugadorActual.nombre);
  }

  /// Tras una tirada humana (u otra): la PC decide desconfiar o seguir.
  Future<void> _talVezReaccionPc() async {
    if (!widget.contraPc || !mounted || _partida.terminada) return;
    if (_partida.fase != FaseDesconfio.esperandoReaccion) return;
    final ultima = _partida.ultimaDelPozo;
    if (ultima == null) return;
    // Solo reacciona la PC si quien tiró no es PC (o hay otra PC rival).
    // Si tiró un humano, decide la PC. Si tiró una PC, espera al humano.
    if (esNombrePc(ultima.jugador)) return;
    if (_pcPensando) return;
    _pcPensando = true;
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted || _partida.fase != FaseDesconfio.esperandoReaccion) {
      _pcPensando = false;
      return;
    }

    final quien = pcQueDesconfia(
      partida: _partida,
      dificultad: _dificultad,
    );
    if (!mounted) {
      _pcPensando = false;
      return;
    }
    if (quien != null) {
      setState(() {
        desconfiarDesconfio(_partida, quien.nombre);
        _pcPensando = false;
      });
    } else {
      setState(() {
        seguirTrasTiradaDesconfio(_partida);
        _pcPensando = false;
      });
      _talVezPc();
    }
  }

  Future<void> _talVezPc() async {
    if (!_turnoDePc || !mounted || _pcPensando) return;
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted || !_turnoDePc) return;

    final j = _partida.jugadorActual;
    if (_partida.fase == FaseDesconfio.elegirPalo) {
      // Elige el palo del que más cartas tiene.
      final counts = <PaloDesconfio, int>{
        for (final p in PaloDesconfio.values) p: 0,
      };
      for (final c in j.mano) {
        counts[c.palo] = (counts[c.palo] ?? 0) + 1;
      }
      var mejor = PaloDesconfio.oro;
      var maxN = -1;
      for (final e in counts.entries) {
        if (e.value > maxN) {
          maxN = e.value;
          mejor = e.key;
        }
      }
      setState(() => elegirPaloDesconfio(_partida, mejor));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    if (!mounted || !_turnoDePc) return;
    if (_partida.fase == FaseDesconfio.jugando && j.mano.isNotEmpty) {
      final palo = _partida.paloDeclarado;
      var idx = 0;
      if (palo != null) {
        final delPalo = [
          for (var i = 0; i < j.mano.length; i++)
            if (j.mano[i].palo == palo) i,
        ];
        final otras = [
          for (var i = 0; i < j.mano.length; i++)
            if (j.mano[i].palo != palo) i,
        ];
        final rng = math.Random();
        final chanceMentir = switch (_dificultad) {
          DificultadPc.facil => 0.12,
          DificultadPc.medio => 0.28,
          DificultadPc.dificil => 0.42,
        };
        final quiereMentir =
            otras.isNotEmpty && rng.nextDouble() < chanceMentir;
        if (delPalo.isNotEmpty && !quiereMentir) {
          idx = delPalo.first;
        } else if (otras.isNotEmpty) {
          idx = otras[rng.nextInt(otras.length)];
        } else {
          idx = 0;
        }
      }
      setState(() => tirarCartaDesconfio(_partida, idx));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    if (!mounted) return;
    // Tras tirar la PC, el humano decide (no auto-seguir).
    // Si no hay humano (solo PCs), otra PC puede reaccionar.
    if (_partida.fase == FaseDesconfio.esperandoReaccion) {
      final hayHumano = _partida.jugadores.any((x) => !esNombrePc(x.nombre));
      if (!hayHumano) {
        final quien = pcQueDesconfia(
          partida: _partida,
          dificultad: _dificultad,
        );
        if (quien != null) {
          setState(() => desconfiarDesconfio(_partida, quien.nombre));
        } else {
          setState(() => seguirTrasTiradaDesconfio(_partida));
          _talVezPc();
        }
      }
    }

    if (!mounted) return;
    if (_partida.fase == FaseDesconfio.revelando) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => continuarTrasRevelacionDesconfio(_partida));
      _talVezPc();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vista = _vistaLocal;
    final ur = _partida.ultimoResultado;

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
                          }),
                          icon: const Icon(Icons.menu, color: AppColors.texto),
                        ),
                        const Expanded(
                          child: Text(
                            TextosDesconfio.titulo,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.texto,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
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
                  if (_partida.ultimoMensaje != null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _partida.ultimoMensaje!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.acento,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Column(
                        children: [
                          // Rivales
                          SizedBox(
                            height: 72,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                for (final j in _partida.jugadores)
                                  if (j.nombre != vista.nombre)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: _chipRival(j),
                                    ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Pozo
                          Expanded(child: Center(child: _pozoWidget())),
                          const SizedBox(height: 8),
                          // Mano
                          Center(
                            child: Text(
                              '${_esLocalHotSeat ? 'Mano de ${vista.nombre}' : TextosDesconfio.tuMano} - ${vista.mano.length} carta${vista.mano.length == 1 ? '' : 's'}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textoSuave,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: _cartaH + 28,
                            child: _ManoConFlechas(
                              cartas: vista.mano,
                              seleccion: _seleccionMano,
                              puedeElegir: _puedeElegirCartaParaTirar,
                              cartaW: _cartaW,
                              cartaH: _cartaH,
                              animaciones: _ajustes.animaciones,
                              onTapIndex: _alTocarCartaMano,
                              onReordenar: _partida.terminada
                                  ? null
                                  : _reordenarMano,
                              buildCarta: (c, {required sel}) => _carta(
                                c,
                                bocaArriba: true,
                                sel: sel,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Desconfío / Tirar: siempre debajo de la mano (también
                          // al elegir palo); se habilitan según la fase.
                          _botonesDesconfioYTirar(vista),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_partida.fase == FaseDesconfio.elegirPalo &&
                _partida.jugadorActual.nombre == vista.nombre &&
                !_turnoDePc) ...[
              Positioned.fill(
                child: _overlayElegirPalo(),
              ),
              // Solo menú y ajustes por encima del oscuro (no reiniciar).
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
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
            ],
            if (_partida.fase == FaseDesconfio.revelando && ur != null)
              Positioned.fill(
                child: _overlayRevelacion(ur),
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
                child: MenuPartidaDesconfio(
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
                    if (_esLocalHotSeat) {
                      setState(() => _confirmarRendicion = true);
                    } else {
                      _salirAlMenu(guardar: true);
                    }
                  },
                  onConfirmarRendicion: () {
                    if (_esLocalHotSeat) {
                      setState(() {
                        _mostrarMenu = false;
                        _confirmarRendicion = false;
                        rendirseDesconfio(_partida, vista.nombre);
                      });
                    } else {
                      _salirAlMenu(guardar: true);
                    }
                  },
                  onCancelarRendicion: () =>
                      setState(() => _confirmarRendicion = false),
                ),
              ),
            if (_partida.terminada)
              Positioned.fill(
                child: VictoriaDesconfioOverlay(
                  partida: _partida,
                  gane: !widget.contraPc ||
                      _partida.ganador == _humanoPrincipal.nombre,
                  animaciones: _ajustes.animaciones,
                  onVolverAJugar: _reiniciar,
                  onVolver: () => _salirAlMenu(guardar: false),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chipRival(JugadorDesconfio j) {
    final turno = _partida.jugadorActual.nombre == j.nombre;
    final verCartas = _modoDiosActivo && esNombrePc(j.nombre);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.carta.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: turno ? AppColors.acento : AppColors.cartaBorde,
          width: turno ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            j.nombre,
            style: TextStyle(
              color: turno ? AppColors.acento : AppColors.texto,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          Text(
            verCartas && j.mano.isNotEmpty
                ? j.mano.map((c) => c.etiqueta).take(3).join(' · ')
                : '${j.cartasEnMano} carta(s)',
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pozoWidget() {
    final n = _partida.pozo.length;
    final palo = _partida.paloDeclarado;
    bool verCartaPozo(CartaEnPozoDesconfio c) =>
        _modoDiosActivo && esNombrePc(c.jugador);
    final puedeTirarAlPozo =
        _seleccionMano != null && _puedeElegirCartaParaTirar;

    Widget pila;
    if (n == 0) {
      pila = Container(
        width: _cartaW,
        height: _cartaH,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: puedeTirarAlPozo
                ? colorSeleccionCartaEspanola
                : AppColors.cartaBorde,
            width: puedeTirarAlPozo ? 2.2 : 1,
          ),
          color: const Color(0xFF1A0A33),
        ),
        child: const Text(
          '—',
          style: TextStyle(color: AppColors.textoSuave),
        ),
      );
    } else {
      pila = SizedBox(
        width: _cartaW + 16,
        height: _cartaH + 10,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < (n - 1).clamp(0, 3); i++)
              Transform.translate(
                offset: Offset(i * 3.0, i * 2.0),
                child: _carta(
                  _partida.pozo[i].carta,
                  bocaArriba: verCartaPozo(_partida.pozo[i]),
                ),
              ),
            Transform.translate(
              offset: Offset(
                (n - 1).clamp(0, 3) * 3.0,
                (n - 1).clamp(0, 3) * 2.0,
              ),
              child: _carta(
                _partida.pozo.last.carta,
                bocaArriba: verCartaPozo(_partida.pozo.last),
                sel: puedeTirarAlPozo,
              ),
            ),
          ],
        ),
      );
    }

    if (puedeTirarAlPozo) {
      pila = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _tirarSeleccionSiCorresponde,
          borderRadius: BorderRadius.circular(14),
          child: pila,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          TextosDesconfio.pozo,
          style: TextStyle(
            color: puedeTirarAlPozo
                ? colorSeleccionCartaEspanola
                : AppColors.textoSuave,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (palo != null) ...[
          const SizedBox(height: 6),
          _cartaPaloIndicador(palo),
        ],
        const SizedBox(height: 8),
        pila,
        if (n > 0) ...[
          const SizedBox(height: 6),
          Text(
            puedeTirarAlPozo ? 'Tocá para tirar' : '$n en el pozo',
            style: TextStyle(
              color: puedeTirarAlPozo
                  ? colorSeleccionCartaEspanola
                  : AppColors.textoSuave,
              fontSize: 12,
              fontWeight:
                  puedeTirarAlPozo ? FontWeight.w800 : FontWeight.w400,
            ),
          ),
        ] else if (puedeTirarAlPozo) ...[
          const SizedBox(height: 6),
          Text(
            'Tocá para tirar',
            style: TextStyle(
              color: colorSeleccionCartaEspanola,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }

  /// Misma carta de palo que en la elección, solo como indicador (sin tap).
  Widget _cartaPaloIndicador(PaloDesconfio palo) {
    return CartaEspanolaSkin(
      numero: 0,
      etiqueta: nombrePaloDesconfio(palo),
      palo: _paloVisual(palo),
      width: 56,
      height: 84,
    );
  }

  /// Nombre de quien puede decir «¡Desconfío!» en la fase de reacción, o null.
  String? get _desafianteActual {
    if (_partida.fase != FaseDesconfio.esperandoReaccion) return null;
    final tirador = _partida.ultimaDelPozo?.jugador;
    if (tirador == null) return null;
    if (widget.contraPc) {
      // Tras mi tiro la PC decide sola.
      if (!esNombrePc(tirador)) return null;
      return _humanoPrincipal.nombre;
    }
    final otros = [
      for (final j in _partida.jugadores)
        if (!j.rendido && j.nombre != tirador) j.nombre,
    ];
    return otros.isEmpty ? null : otros.first;
  }

  /// Fila fija ¡Desconfío! / Tirar debajo de la mano (visible desde elegir palo).
  Widget _botonesDesconfioYTirar(JugadorDesconfio vista) {
    if (_partida.terminada) return const SizedBox.shrink();

    VoidCallback? onDesconfio;
    VoidCallback? onTirar;
    String? aviso;

    if (_partida.fase == FaseDesconfio.esperandoReaccion) {
      final tirador = _partida.ultimaDelPozo?.jugador;
      if (widget.contraPc &&
          tirador != null &&
          !esNombrePc(tirador)) {
        aviso = _pcPensando ? 'La PC está pensando…' : 'La PC decide…';
      } else {
        final desafiante = _desafianteActual;
        // Sin cartas en el pozo (p. ej. antes de la 1ª tirada) no se puede
        // desconfiar; tampoco quien acaba de tirar.
        final puedeDesconfiar = desafiante != null &&
            !_pcPensando &&
            _partida.pozo.isNotEmpty &&
            vista.nombre == desafiante &&
            vista.nombre != tirador;
        if (puedeDesconfiar) {
          onDesconfio = () => _desconfiar(desafiante);
          onTirar =
              _seleccionMano == null ? null : _tirarSinDesconfiar;
        }
      }
    } else if (_partida.fase == FaseDesconfio.jugando) {
      if (_turnoDePc || _pcPensando) {
        aviso =
            _pcPensando ? 'La PC está pensando…' : 'La PC está jugando…';
      } else if (_partida.jugadorActual.nombre == vista.nombre) {
        // Primera carta (u otra) con pozo vacío: solo Tirar, nunca Desconfío.
        onTirar =
            _seleccionMano == null ? null : _tirarSeleccionada;
      }
    } else if (_turnoDePc || _pcPensando) {
      aviso = _pcPensando ? 'La PC está pensando…' : 'La PC está jugando…';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (aviso != null) ...[
          Text(
            aviso,
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.peligro,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.peligro.withValues(alpha: 0.35),
                      disabledForegroundColor:
                          Colors.white.withValues(alpha: 0.55),
                      minimumSize: const Size.fromHeight(52),
                      maximumSize: const Size.fromHeight(52),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onDesconfio,
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        TextosDesconfio.desconfio,
                        maxLines: 1,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.azul,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.azul.withValues(alpha: 0.35),
                      disabledForegroundColor:
                          Colors.white.withValues(alpha: 0.55),
                      minimumSize: const Size.fromHeight(52),
                      maximumSize: const Size.fromHeight(52),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onTirar,
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        TextosDesconfio.tirar,
                        maxLines: 1,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _overlayElegirPalo() {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
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
              const Text(
                TextosDesconfio.elegirPalo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.acento,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 6),
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
                    for (final p in PaloDesconfio.values) ...[
                      if (p != PaloDesconfio.values.first)
                        const SizedBox(width: 10),
                      _cartaPaloElegible(p),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cartaPaloElegible(PaloDesconfio palo) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _elegirPalo(palo),
        borderRadius: BorderRadius.circular(14),
        child: CartaEspanolaSkin(
          numero: 0,
          etiqueta: nombrePaloDesconfio(palo),
          palo: _paloVisual(palo),
          width: 78,
          height: 118,
        ),
      ),
    );
  }

  Widget _overlayRevelacion(ResultadoDesconfio ur) {
    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.carta,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ur.eraDelPalo ? AppColors.mint : AppColors.peligro,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${ur.desconfiador} desconfió',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ur.eraDelPalo ? '¡Era verdad!' : '¡Mentira!',
                style: TextStyle(
                  color: ur.eraDelPalo ? AppColors.mint : AppColors.peligro,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 12),
              _carta(ur.carta, bocaArriba: true),
              const SizedBox(height: 12),
              Text(
                _partida.ultimoMensaje ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.texto, height: 1.35),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _continuarRevelacion,
                child: const Text(TextosDesconfio.continuar),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mano horizontal con contenedor, flechas y reorden por arrastre.
class _ManoConFlechas extends StatefulWidget {
  const _ManoConFlechas({
    required this.cartas,
    required this.seleccion,
    required this.puedeElegir,
    required this.onTapIndex,
    required this.buildCarta,
    required this.cartaW,
    required this.cartaH,
    required this.animaciones,
    this.onReordenar,
  });

  final List<CartaDesconfio> cartas;
  final int? seleccion;
  final bool puedeElegir;
  final ValueChanged<int> onTapIndex;
  final Widget Function(CartaDesconfio c, {required bool sel}) buildCarta;
  final double cartaW;
  final double cartaH;
  final bool animaciones;
  final void Function(int desde, int hacia)? onReordenar;

  @override
  State<_ManoConFlechas> createState() => _ManoConFlechasState();
}

class _ManoConFlechasState extends State<_ManoConFlechas> {
  static const double _gap = 6;
  static const double _pasoScroll = 160;

  final _scroll = ScrollController();
  final _rowKey = GlobalKey();
  final _reorden = ReordenarCartaManoDrag();
  bool _hayIzquierda = false;
  bool _hayDerecha = false;
  bool _priorizarReorden = false;

  bool get _arrastrando => _reorden.arrastrando;
  bool get _puedeReordenar => widget.onReordenar != null;
  bool get _bloquearScroll => _arrastrando || _priorizarReorden;
  double get _paso => widget.cartaW + _gap;

  void _setPriorizarReorden(bool v) {
    if (!mounted) return;
    if (!v && _arrastrando) return;
    if (_priorizarReorden == v) return;
    setState(() => _priorizarReorden = v);
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_actualizarFlechas);
    WidgetsBinding.instance.addPostFrameCallback((_) => _actualizarFlechas());
  }

  @override
  void didUpdateWidget(covariant _ManoConFlechas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cartas.length != widget.cartas.length ||
        oldWidget.cartaW != widget.cartaW) {
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
    final izq = pos.maxScrollExtent > 0.5 && pos.pixels > 1;
    final der =
        pos.maxScrollExtent > 0.5 && pos.pixels < pos.maxScrollExtent - 1;
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

  int _indiceInsercionDesdeGlobal(double globalX) {
    return indiceInsercionDesdeGlobalReorden(
      rowKey: _rowKey,
      drag: _reorden,
      globalX: globalX,
      cantidad: widget.cartas.length,
      anchoCarta: widget.cartaW,
      gap: _gap,
    );
  }

  void _iniciarDrag(int index, Offset localPosition) {
    setState(() {
      _reorden.iniciar(
        index: index,
        localPosition: localPosition,
        anchoCarta: widget.cartaW,
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

  Widget _flecha({required bool izquierda, required bool visible}) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 160),
        child: Material(
          color: AppColors.carta.withValues(alpha: 0.92),
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: visible
                ? () => _desplazar(izquierda ? -_pasoScroll : _pasoScroll)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                izquierda
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: AppColors.acento,
                size: 28,
              ),
            ),
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

    final altoSlot = widget.cartaH + kDeslizamientoSeleccionCarta;

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
        children: [
          NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              _actualizarFlechas();
              return false;
            },
            child: Listener(
              onPointerSignal: (signal) {
                if (signal is! PointerScrollEvent) return;
                if (!_scroll.hasClients || _bloquearScroll) {
                  return;
                }
                final delta =
                    signal.scrollDelta.dx.abs() > signal.scrollDelta.dy.abs()
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
                behavior: const _ManoScrollBehavior(),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final minW = math.max(0.0, constraints.maxWidth - 68);
                    final n = widget.cartas.length;
                    final contentW =
                        n == 0 ? 0.0 : n * widget.cartaW + (n - 1) * _gap;
                    final filaW = math.max(minW, contentW);
                    return SingleChildScrollView(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      // Solo bloquea scroll al tocar/arrastrar la seleccionada.
                      physics: physicsScrollManoReorden(
                        bloquearPorReorden: _bloquearScroll,
                        cuandoLibre: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 34,
                        vertical: 4,
                      ),
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
                                for (var i = 0;
                                    i < widget.cartas.length;
                                    i++) ...[
                                  if (i > 0) const SizedBox(width: _gap),
                                  Builder(
                                    builder: (context) {
                                      final c = widget.cartas[i];
                                      final sel = widget.seleccion == i;
                                      final esLaQueArrastro =
                                          _reorden.dragIndex == i;
                                      final atenuar =
                                          _arrastrando && !esLaQueArrastro;
                                      final skin =
                                          widget.buildCarta(c, sel: sel);

                                      Widget child = CartaOpacidadReorden(
                                        esLaQueArrastro: esLaQueArrastro,
                                        atenuar: atenuar,
                                        child: CartaSlotSeleccion(
                                          seleccionada: sel,
                                          animaciones: widget.animaciones,
                                          width: widget.cartaW,
                                          height: widget.cartaH,
                                          child: skin,
                                        ),
                                      );

                                      child = CartaConHuecoReorden(
                                        arrastrandoMano: _arrastrando,
                                        esLaQueArrastro: esLaQueArrastro,
                                        shiftX: _reorden.shiftX(i, _paso),
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
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        child: child,
                                      );

                                      if (_puedeReordenar && sel) {
                                        return PriorizarReordenSobreScroll(
                                          onCambiar: _setPriorizarReorden,
                                          child: DetectorArrastreReorden(
                                            onTap: widget.puedeElegir
                                                ? () => widget.onTapIndex(i)
                                                : null,
                                            onPanStart: (details) =>
                                                _iniciarDrag(
                                              i,
                                              details.localPosition,
                                            ),
                                            onPanUpdate: _actualizarDrag,
                                            onPanEnd: _soltarDrag,
                                            onPanCancel: _cancelarDrag,
                                            child: child,
                                          ),
                                        );
                                      }

                                      if (!widget.puedeElegir) return child;

                                      return Material(
                                        color: Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        child: InkWell(
                                          onTap: () => widget.onTapIndex(i),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          splashColor: sel
                                              ? colorSeleccionCartaEspanola
                                                  .withValues(alpha: 0.25)
                                              : Colors.transparent,
                                          highlightColor: sel
                                              ? colorSeleccionCartaEspanola
                                                  .withValues(alpha: 0.18)
                                              : Colors.transparent,
                                          hoverColor: sel
                                              ? colorSeleccionCartaEspanola
                                                  .withValues(alpha: 0.22)
                                              : Colors.transparent,
                                          child: child,
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
                                anchoCarta: widget.cartaW,
                                gap: _gap,
                                dragDx: _reorden.dragDx,
                                dragDy: _reorden.dragDy,
                                borderRadius: BorderRadius.circular(14),
                                child: CartaSlotSeleccion(
                                  seleccionada: true,
                                  animaciones: false,
                                  width: widget.cartaW,
                                  height: widget.cartaH,
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
  }
}

/// Permite arrastrar la mano con dedo, mouse, stylus y trackpad.
class _ManoScrollBehavior extends MaterialScrollBehavior {
  const _ManoScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}
