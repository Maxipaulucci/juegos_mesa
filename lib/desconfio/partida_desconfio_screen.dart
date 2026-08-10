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

  JugadorDesconfio get _vistaLocal =>
      _esLocalHotSeat ? _partida.jugadorActual : _humanoPrincipal;

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
                          // Acciones de fase
                          _accionesFase(vista),
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
                            height: _cartaH + 22,
                            child: _ManoConFlechas(
                              cartas: vista.mano,
                              seleccion: _seleccionMano,
                              puedeElegir: _puedeElegirCartaParaTirar,
                              cartaW: _cartaW,
                              cartaH: _cartaH,
                              onTapIndex: (i) => setState(
                                () => _seleccionMano =
                                    _seleccionMano == i ? null : i,
                              ),
                              buildCarta: (c, {required sel}) => _carta(
                                c,
                                bocaArriba: true,
                                sel: sel,
                              ),
                            ),
                          ),
                          if (_partida.fase == FaseDesconfio.jugando &&
                              _partida.jugadorActual.nombre == vista.nombre &&
                              !_turnoDePc) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.azul,
                                ),
                                onPressed: _seleccionMano == null
                                    ? null
                                    : _tirarSeleccionada,
                                child: const Text(
                                  TextosDesconfio.tirar,
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ],
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
                !_turnoDePc)
              Positioned.fill(
                child: _overlayElegirPalo(),
              ),
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          TextosDesconfio.pozo,
          style: TextStyle(
            color: AppColors.textoSuave,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (palo != null) ...[
          const SizedBox(height: 6),
          _cartaPaloIndicador(palo),
        ],
        const SizedBox(height: 8),
        if (n == 0)
          Container(
            width: _cartaW,
            height: _cartaH,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cartaBorde),
              color: const Color(0xFF1A0A33),
            ),
            child: const Text(
              '—',
              style: TextStyle(color: AppColors.textoSuave),
            ),
          )
        else
          SizedBox(
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
                  ),
                ),
              ],
            ),
          ),
        if (n > 0) ...[
          const SizedBox(height: 6),
          Text(
            '$n en el pozo',
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontSize: 12,
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

  Widget _accionesFase(JugadorDesconfio vista) {
    if (_partida.terminada) return const SizedBox.shrink();

    if (_partida.fase == FaseDesconfio.elegirPalo &&
        _partida.jugadorActual.nombre == vista.nombre &&
        !_turnoDePc) {
      // El cartel de elección se muestra como overlay.
      return const SizedBox.shrink();
    }

    if (_partida.fase == FaseDesconfio.esperandoReaccion) {
      final tirador = _partida.ultimaDelPozo?.jugador;
      // Vs PC: si tiró el humano, la PC decide sola (desconfiar o seguir).
      if (widget.contraPc &&
          tirador != null &&
          !esNombrePc(tirador)) {
        return Text(
          _pcPensando ? 'La PC está pensando…' : 'La PC decide…',
          style: const TextStyle(
            color: AppColors.textoSuave,
            fontWeight: FontWeight.w700,
          ),
        );
      }

      // Reacción del humano (tras tiro de la PC) o hot-seat local.
      final String desafiante;
      if (widget.contraPc) {
        desafiante = _humanoPrincipal.nombre;
        // Tras mi tiro la PC decide sola: no muestro botones.
        if (tirador == desafiante) {
          return const SizedBox.shrink();
        }
      } else {
        // Local: desconfía el siguiente jugador que no tiró.
        final otros = [
          for (final j in _partida.jugadores)
            if (!j.rendido && j.nombre != tirador) j.nombre,
        ];
        if (otros.isEmpty) return const SizedBox.shrink();
        desafiante = otros.first;
      }

      return Padding(
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
                    minimumSize: const Size.fromHeight(52),
                    maximumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _desconfiar(desafiante),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      TextosDesconfio.desconfio,
                      maxLines: 1,
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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
                    minimumSize: const Size.fromHeight(52),
                    maximumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed:
                      _seleccionMano == null ? null : _tirarSinDesconfiar,
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      TextosDesconfio.tirar,
                      maxLines: 1,
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_turnoDePc || _pcPensando) {
      return Text(
        _pcPensando ? 'La PC está pensando…' : 'La PC está jugando…',
        style: const TextStyle(
          color: AppColors.textoSuave,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return const SizedBox.shrink();
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

/// Mano horizontal con contenedor y flechas laterales para recorrer cartas.
class _ManoConFlechas extends StatefulWidget {
  const _ManoConFlechas({
    required this.cartas,
    required this.seleccion,
    required this.puedeElegir,
    required this.onTapIndex,
    required this.buildCarta,
    required this.cartaW,
    required this.cartaH,
  });

  final List<CartaDesconfio> cartas;
  final int? seleccion;
  final bool puedeElegir;
  final ValueChanged<int> onTapIndex;
  final Widget Function(CartaDesconfio c, {required bool sel}) buildCarta;
  final double cartaW;
  final double cartaH;

  @override
  State<_ManoConFlechas> createState() => _ManoConFlechasState();
}

class _ManoConFlechasState extends State<_ManoConFlechas> {
  static const double _gap = 6;
  static const double _pasoScroll = 160;
  static const double _deslizamiento = 14;

  final _scroll = ScrollController();
  bool _hayIzquierda = false;
  bool _hayDerecha = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_actualizarFlechas);
    WidgetsBinding.instance.addPostFrameCallback((_) => _actualizarFlechas());
  }

  @override
  void didUpdateWidget(covariant _ManoConFlechas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cartas.length != widget.cartas.length) {
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
                if (!_scroll.hasClients) return;
                // Rueda vertical del mouse → desplazamiento horizontal de la mano.
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
                child: ListView.separated(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 34,
                    vertical: 4,
                  ),
                  itemCount: widget.cartas.length,
                  separatorBuilder: (_, __) => const SizedBox(width: _gap),
                  itemBuilder: (context, i) {
                    final c = widget.cartas[i];
                    final sel = widget.seleccion == i;
                    final skin = widget.buildCarta(c, sel: sel);
                    // Slot fijo: al seleccionar, la carta sube (como Chancho va).
                    final tarjeta = SizedBox(
                      width: widget.cartaW,
                      height: widget.cartaH + _deslizamiento,
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        alignment: sel
                            ? Alignment.topCenter
                            : Alignment.bottomCenter,
                        child: skin,
                      ),
                    );
                    if (!widget.puedeElegir) return tarjeta;
                    // Sin hover si no está seleccionada.
                    // Con selección, el InkWell pinta la sombra en el hueco de abajo.
                    if (!sel) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onTapIndex(i),
                        child: tarjeta,
                      );
                    }
                    return Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => widget.onTapIndex(i),
                        borderRadius: BorderRadius.circular(14),
                        splashColor: colorSeleccionCartaEspanola.withValues(
                          alpha: 0.25,
                        ),
                        highlightColor: colorSeleccionCartaEspanola.withValues(
                          alpha: 0.18,
                        ),
                        hoverColor: colorSeleccionCartaEspanola.withValues(
                          alpha: 0.22,
                        ),
                        child: tarjeta,
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
