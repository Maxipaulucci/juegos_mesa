import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/guerraDeCartas/menu_partida_guerra.dart';
import 'package:app_juegos_mesa/guerraDeCartas/motor_guerra.dart';
import 'package:app_juegos_mesa/guerraDeCartas/standby_store.dart';
import 'package:app_juegos_mesa/guerraDeCartas/textos.dart';
import 'package:app_juegos_mesa/guerraDeCartas/victoria_guerra_overlay.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/cartas/carta_inglesa_skin.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/partida_ui/epic_backdrop.dart';
import 'package:app_juegos_mesa/shared/partida_ui/reiniciar_partida_pc.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Partida local / vs PC de Guerra de cartas.
class PartidaGuerraScreen extends StatefulWidget {
  const PartidaGuerraScreen({
    super.key,
    required this.nombres,
    this.contraPc = false,
    this.modoDios = false,
    this.resume,
  });

  final List<String> nombres;
  final bool contraPc;
  final bool modoDios;
  final PartidaGuerraResume? resume;

  @override
  State<PartidaGuerraScreen> createState() => _PartidaGuerraScreenState();
}

class _PartidaGuerraScreenState extends State<PartidaGuerraScreen> {
  late PartidaGuerra _partida;
  late List<String> _nombres;
  AjustesEstado _ajustes = const AjustesEstado();
  bool _mostrarMenu = false;
  bool _mostrarAjustes = false;
  bool _confirmarRendicion = false;
  bool _jugando = false;

  bool get _esLocalHotSeat => !widget.contraPc;
  bool get _modoDiosActivo => widget.modoDios && widget.contraPc;

  JugadorGuerra get _humanoPrincipal {
    if (widget.contraPc) {
      return _partida.jugadores.firstWhere(
        (j) => !esNombrePc(j.nombre),
        orElse: () => _partida.jugadores.first,
      );
    }
    return _partida.jugadores.first;
  }

  bool get _puedeJugarRonda {
    if (_partida.terminada || _jugando) return false;
    return _partida.conCartas.length >= 2;
  }

  String get _textoEstado {
    if (_partida.terminada) return '';
    final ur = _partida.ultimaRonda;
    if (ur != null) {
      if (ur.huboGuerra) {
        return ur.mensaje ??
            '¡Guerra! Ganó ${ur.ganadorNombre} (${ur.pozoMesa.length} cartas)';
      }
      return '${ur.ganadorNombre} se lleva ${ur.pozoMesa.length} carta(s)';
    }
    return 'Tocá “${TextosGuerra.jugar}” para voltear las cimas';
  }

  @override
  void initState() {
    super.initState();
    final resume = widget.resume;
    _nombres = List.of(resume?.nombres ?? widget.nombres);
    if (resume != null) {
      _partida = resume.partida;
      _nombres = List.of(resume.nombres);
    } else {
      _partida = nuevaPartidaGuerra(
        nombres: _nombres,
        contraPc: widget.contraPc,
      );
      _nombres = [for (final j in _partida.jugadores) j.nombre];
    }
  }

  void _guardarResumeSiCorresponde() {
    if (!widget.contraPc) return;
    if (_partida.terminada) {
      GuerraStandByStore.limpiar();
      return;
    }
    GuerraStandByStore.guardar(
      PartidaGuerraResume(
        partida: _partida,
        nombres: _nombres,
        modoDios: widget.modoDios,
      ),
    );
  }

  void _salirAlMenu({required bool guardar}) {
    if (guardar) {
      _guardarResumeSiCorresponde();
    } else {
      GuerraStandByStore.limpiar();
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _mostrarReglas() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.carta,
        title: const Text(
          'Reglas',
          style: TextStyle(
            color: AppColors.azul,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            TextosGuerra.reglas(),
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

  void _rendirse() {
    if (_partida.terminada) return;
    final yo = _humanoPrincipal.nombre;
    setState(() {
      _mostrarMenu = false;
      _confirmarRendicion = false;
      rendirseGuerra(_partida, yo);
    });
  }

  Future<void> _jugarRonda() async {
    if (!_puedeJugarRonda) return;
    setState(() => _jugando = true);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    final err = jugarRondaGuerra(_partida);
    setState(() {
      _jugando = false;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
    });
  }

  void _reiniciar() {
    GuerraStandByStore.limpiar();
    setState(() {
      if (widget.contraPc) {
        final pcs = cantidadPcElegidaEnMenu(
              MenuJuegoScreen.juegoIdGuerraDeCartas,
            ) ??
            cantidadPcEnNombres(_nombres);
        _nombres = reconstruirNombresVsPc(
          actuales: _nombres,
          cantidadPc: pcs.clamp(1, 3),
        );
      }
      _partida = nuevaPartidaGuerra(
        nombres: _nombres,
        contraPc: widget.contraPc,
      );
      _nombres = [for (final j in _partida.jugadores) j.nombre];
      _mostrarMenu = false;
      _mostrarAjustes = false;
      _confirmarRendicion = false;
      _jugando = false;
    });
  }

  Future<void> _pedirReiniciarVsPc() async {
    if (!widget.contraPc) return;
    final ok = await confirmarReiniciarPartidaPc(context);
    if (!ok || !mounted) return;
    _reiniciar();
  }

  PaloInglesVisual _paloVisual(PaloGuerra p) => switch (p) {
        PaloGuerra.corazones => PaloInglesVisual.corazones,
        PaloGuerra.diamantes => PaloInglesVisual.diamantes,
        PaloGuerra.treboles => PaloInglesVisual.treboles,
        PaloGuerra.picas => PaloInglesVisual.picas,
      };

  String _etiquetaValor(CartaGuerra c) => switch (c.valor) {
        1 => 'A',
        11 => 'J',
        12 => 'Q',
        13 => 'K',
        _ => '${c.valor}',
      };

  Widget _cartaMini(CartaGuerra? c, {required bool bocaArriba}) {
    if (c == null) {
      return Container(
        width: 68,
        height: 102,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1A0A33),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cartaBorde),
        ),
        child: const Text('—', style: TextStyle(color: AppColors.textoSuave)),
      );
    }
    return CartaInglesaSkin(
      etiquetaValor: _etiquetaValor(c),
      palo: _paloVisual(c.palo),
      bocaArriba: bocaArriba,
    );
  }

  Widget _pilaJugador(JugadorGuerra j, {required bool esHumano}) {
    final cimaMazo = j.mazo.isEmpty ? null : j.mazo.last;
    final cimaPozo = j.pozo.isEmpty ? null : j.pozo.last;
    final verCima =
        esHumano ? false : (_modoDiosActivo && esNombrePc(j.nombre));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          j.rendido ? '${j.nombre} (fuera)' : j.nombre,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: esHumano ? AppColors.mint : AppColors.textoSuave,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            decoration: j.rendido ? TextDecoration.lineThrough : null,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              children: [
                const Text(
                  'Mazo',
                  style: TextStyle(
                    color: AppColors.textoSuave,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${j.mazo.length}',
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                _cartaMini(
                  j.mazo.isEmpty ? null : cimaMazo,
                  bocaArriba: verCima && cimaMazo != null,
                ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              children: [
                const Text(
                  'Pozo',
                  style: TextStyle(
                    color: AppColors.textoSuave,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${j.pozo.length}',
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                _cartaMini(
                  j.pozo.isEmpty ? null : cimaPozo,
                  bocaArriba: true,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Total ${j.totalCartas}',
          style: const TextStyle(
            color: AppColors.acento,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ur = _partida.ultimaRonda;
    final humano = _humanoPrincipal;
    final rivales = [
      for (final j in _partida.jugadores)
        if (j.nombre != humano.nombre) j,
    ];

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
            const Positioned.fill(
              child: EpicBackdrop(centerY: 0.42, fadeRayosAlCentro: true),
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
                            _mostrarAjustes = false;
                          }),
                          icon: const Icon(Icons.menu, color: AppColors.texto),
                        ),
                        const Expanded(
                          child: Text(
                            TextosGuerra.titulo,
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
                  if (_textoEstado.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _textoEstado,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.acento,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          if (rivales.isNotEmpty)
                            Expanded(
                              flex: 2,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final o in rivales) ...[
                                      _pilaJugador(o, esHumano: false),
                                      const SizedBox(width: 16),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: ur == null
                                  ? Text(
                                      'Mesa vacía',
                                      style: TextStyle(
                                        color: AppColors.textoSuave
                                            .withValues(alpha: 0.7),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          ur.huboGuerra ? '¡GUERRA!' : 'Mesa',
                                          style: TextStyle(
                                            color: ur.huboGuerra
                                                ? AppColors.peligro
                                                : AppColors.textoSuave,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          height: 120,
                                          child: ListView(
                                            scrollDirection: Axis.horizontal,
                                            shrinkWrap: true,
                                            children: [
                                              for (final e
                                                  in ur.cartasJugadas.entries)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    right: 10,
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      Text(
                                                        e.key,
                                                        style: const TextStyle(
                                                          color: AppColors
                                                              .textoSuave,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      _cartaMini(
                                                        e.value,
                                                        bocaArriba: true,
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
                          _pilaJugador(humano, esHumano: true),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.azul,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.carta.withValues(alpha: 0.5),
                        ),
                        onPressed: _puedeJugarRonda ? _jugarRonda : null,
                        child: Text(
                          _jugando ? '…' : TextosGuerra.jugar,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ),
                  ),
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
                child: MenuPartidaGuerra(
                  jugador: humano.nombre,
                  partidaTerminada: _partida.terminada,
                  permitirRendirse: true,
                  confirmarRendicion: _confirmarRendicion,
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
                  onSalirORendirse: _partida.terminada
                      ? () => _salirAlMenu(guardar: false)
                      : () => setState(() => _confirmarRendicion = true),
                  onConfirmarRendicion: _rendirse,
                  onCancelarRendicion: () =>
                      setState(() => _confirmarRendicion = false),
                ),
              ),
            if (_partida.terminada)
              Positioned.fill(
                child: VictoriaGuerraOverlay(
                  partida: _partida,
                  gane: widget.contraPc
                      ? _partida.ganador == humano.nombre
                      : (_partida.ganador == humano.nombre ||
                          (_esLocalHotSeat && _partida.ganador != null)),
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
