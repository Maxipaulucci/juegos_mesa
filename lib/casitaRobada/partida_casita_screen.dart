import 'dart:async';

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/casitaRobada/motor_casita.dart';
import 'package:app_juegos_mesa/casitaRobada/standby_store.dart';
import 'package:app_juegos_mesa/casitaRobada/textos.dart';
import 'package:app_juegos_mesa/casitaRobada/victoria_casita_overlay.dart';
import 'package:app_juegos_mesa/shared/cartas/carta_espanola_skin.dart';
import 'package:app_juegos_mesa/shared/partida_ui/epic_backdrop.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Partida local / vs PC de Casita robada.
class PartidaCasitaScreen extends StatefulWidget {
  const PartidaCasitaScreen({
    super.key,
    required this.nombres,
    this.contraPc = false,
    this.modoDios = false,
    this.resume,
  });

  final List<String> nombres;
  final bool contraPc;
  final bool modoDios;
  final PartidaCasitaResume? resume;

  @override
  State<PartidaCasitaScreen> createState() => _PartidaCasitaScreenState();
}

class _PartidaCasitaScreenState extends State<PartidaCasitaScreen> {
  late PartidaCasita _partida;
  int _pcToken = 0;
  int? _cartaSeleccionada;
  bool _jugando = false;

  bool get _modoDiosActivo => widget.modoDios && widget.contraPc;

  JugadorCasita get _yo {
    if (widget.contraPc) {
      return _partida.jugadores.firstWhere(
        (j) => j.nombre != TextosCasita.vsPcNombre,
        orElse: () => _partida.jugadores.first,
      );
    }
    return _partida.jugadorActual;
  }

  JugadorCasita get _rival {
    if (widget.contraPc) {
      return _partida.jugadores.firstWhere(
        (j) => j.nombre == TextosCasita.vsPcNombre,
        orElse: () => _partida.jugadores.last,
      );
    }
    return _partida.rivalActual;
  }

  bool get _esTurnoHumano {
    if (_partida.terminada) return false;
    if (!widget.contraPc) return true;
    return _partida.jugadorActual.nombre != TextosCasita.vsPcNombre;
  }

  bool get _esTurnoPc =>
      widget.contraPc &&
      !_partida.terminada &&
      _partida.jugadorActual.nombre == TextosCasita.vsPcNombre;

  String get _textoEstado {
    if (_partida.terminada) return '';
    if (_esTurnoPc) return TextosCasita.esperandoPc;
    if (_esTurnoHumano) return TextosCasita.juegaUna;
    return 'Turno de ${_partida.jugadorActual.nombre}';
  }

  @override
  void initState() {
    super.initState();
    final resume = widget.resume;
    if (resume != null) {
      _partida = resume.partida;
    } else {
      _partida = nuevaPartidaCasita(
        nombres: widget.nombres,
        contraPc: widget.contraPc,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezTurnoPc());
  }

  void _guardarResumeSiCorresponde() {
    if (!widget.contraPc) return;
    if (_partida.terminada) {
      CasitaStandByStore.limpiar();
      return;
    }
    CasitaStandByStore.guardar(
      PartidaCasitaResume(
        partida: _partida,
        nombres: widget.nombres,
        modoDios: widget.modoDios,
      ),
    );
  }

  void _salirAlMenu({required bool guardar}) {
    _pcToken++;
    if (guardar) {
      _guardarResumeSiCorresponde();
    } else {
      CasitaStandByStore.limpiar();
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _talVezTurnoPc() async {
    if (!_esTurnoPc || _jugando) return;
    final token = ++_pcToken;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted || token != _pcToken || !_esTurnoPc) return;
    setState(() {
      jugarTurnoPcCasita(_partida);
      _cartaSeleccionada = null;
    });
    if (!_partida.terminada) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) _talVezTurnoPc();
    }
  }

  Future<void> _jugarCarta(int indice) async {
    if (!_esTurnoHumano || _jugando || _partida.terminada) return;
    if (!widget.contraPc &&
        _partida.jugadorActual.nombre != _yo.nombre) {
      return;
    }
    setState(() {
      _jugando = true;
      _cartaSeleccionada = indice;
    });
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    final err = jugarCartaCasita(_partida, indiceEnMano: indice);
    setState(() {
      _jugando = false;
      _cartaSeleccionada = null;
    });
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (!_partida.terminada) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (mounted) _talVezTurnoPc();
    }
  }

  void _reiniciar() {
    _pcToken++;
    CasitaStandByStore.limpiar();
    setState(() {
      _partida = nuevaPartidaCasita(
        nombres: widget.nombres,
        contraPc: widget.contraPc,
      );
      _cartaSeleccionada = null;
      _jugando = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezTurnoPc());
  }

  PaloEspanolVisual _paloVisual(PaloCasita p) => switch (p) {
        PaloCasita.oro => PaloEspanolVisual.oro,
        PaloCasita.copa => PaloEspanolVisual.copa,
        PaloCasita.espada => PaloEspanolVisual.espada,
        PaloCasita.basto => PaloEspanolVisual.basto,
      };

  @override
  Widget build(BuildContext context) {
    final manoAbajo = widget.contraPc ? _yo : _partida.jugadorActual;
    final manoArriba = widget.contraPc ? _rival : _partida.rivalActual;
    final pozoAbajo = manoAbajo;
    final pozoArriba = manoArriba;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _salirAlMenu(
          guardar: widget.contraPc && !_partida.terminada,
        );
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
                    padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => _salirAlMenu(
                            guardar:
                                widget.contraPc && !_partida.terminada,
                          ),
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: AppColors.texto,
                        ),
                        const Expanded(
                          child: Text(
                            TextosCasita.titulo,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.texto,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        for (var i = 0;
                            i < _partida.jugadores.length;
                            i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _ChipJugador(
                              nombre: _partida.jugadores[i].nombre,
                              cartasMano:
                                  _partida.jugadores[i].mano.length,
                              cartasPozo:
                                  _partida.jugadores[i].cartasPozo,
                              activo: !_partida.terminada &&
                                  _partida.indiceTurno == i,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_textoEstado.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _textoEstado,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _esTurnoHumano
                            ? AppColors.mint
                            : AppColors.textoSuave,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Rival: mano centrada + casita a la derecha
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          Column(
                            children: [
                              Text(
                                '${TextosCasita.manoRival}: ${manoArriba.nombre}',
                                style: const TextStyle(
                                  color: AppColors.textoSuave,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 100,
                                width: double.infinity,
                                child: _FilaCartas(
                                  cartas: manoArriba.mano,
                                  bocaArriba: _modoDiosActivo,
                                  paloVisual: _paloVisual,
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: _PozoCasita(
                              titulo: TextosCasita.casitaRival,
                              jugador: pozoArriba,
                              paloVisual: _paloVisual,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${TextosCasita.mesa} · mazo ${_partida.mazo.length}',
                    style: const TextStyle(
                      color: AppColors.textoSuave,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 108,
                    width: double.infinity,
                    child: _FilaCartas(
                      cartas: _partida.mesa,
                      bocaArriba: true,
                      paloVisual: _paloVisual,
                    ),
                  ),
                  if (_partida.ultimaJugada != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        _partida.ultimaJugada!.descripcion,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.acento,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Yo: mano centrada + casita a la derecha
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      height: 158,
                      width: double.infinity,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${TextosCasita.tuMano}: ${manoAbajo.nombre}',
                                style: const TextStyle(
                                  color: AppColors.mint,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 118,
                                width: double.infinity,
                                child: _FilaCartas(
                                  cartas: manoAbajo.mano,
                                  bocaArriba: true,
                                  paloVisual: _paloVisual,
                                  seleccionIndex: _cartaSeleccionada,
                                  onTapIndex: _esTurnoHumano && !_jugando
                                      ? _jugarCarta
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: _PozoCasita(
                              titulo: TextosCasita.tuCasita,
                              jugador: pozoAbajo,
                              paloVisual: _paloVisual,
                              resaltar: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            if (_partida.terminada)
              Positioned.fill(
                child: VictoriaCasitaOverlay(
                  partida: _partida,
                  gane: widget.contraPc
                      ? (_partida.ganador == _yo.nombre)
                      : (_partida.ganador != null),
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
    required this.cartasMano,
    required this.cartasPozo,
    required this.activo,
  });

  final String nombre;
  final int cartasMano;
  final int cartasPozo;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.carta.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: activo ? AppColors.mint : AppColors.cartaBorde,
          width: activo ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.texto,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(
            'mano $cartasMano · casita $cartasPozo',
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _PozoCasita extends StatelessWidget {
  const _PozoCasita({
    required this.titulo,
    required this.jugador,
    required this.paloVisual,
    this.resaltar = false,
  });

  final String titulo;
  final JugadorCasita jugador;
  final PaloEspanolVisual Function(PaloCasita) paloVisual;
  final bool resaltar;

  @override
  Widget build(BuildContext context) {
    final cima = jugador.cimaPozo;
    return Column(
      children: [
        Text(
          titulo,
          style: TextStyle(
            color: resaltar ? AppColors.mint : AppColors.textoSuave,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${jugador.cartasPozo}',
          style: const TextStyle(
            color: AppColors.textoSuave,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        if (cima == null)
          Container(
            width: 68,
            height: 102,
            decoration: BoxDecoration(
              color: const Color(0xFF1A0A33),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cartaBorde),
            ),
            child: const Center(
              child: Text(
                '—',
                style: TextStyle(color: AppColors.textoSuave),
              ),
            ),
          )
        else
          CartaEspanolaSkin(
            numero: cima.numero,
            etiqueta: cima.etiqueta,
            palo: paloVisual(cima.palo),
            seleccionada: false,
            width: 68,
            height: 102,
          ),
      ],
    );
  }
}

class _FilaCartas extends StatelessWidget {
  const _FilaCartas({
    required this.cartas,
    required this.bocaArriba,
    required this.paloVisual,
    this.onTapIndex,
    this.seleccionIndex,
  });

  final List<CartaCasita> cartas;
  final bool bocaArriba;
  final PaloEspanolVisual Function(PaloCasita) paloVisual;
  final Future<void> Function(int index)? onTapIndex;
  final int? seleccionIndex;

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
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < cartas.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Builder(
                    builder: (context) {
                      final c = cartas[i];
                      final seleccionada = seleccionIndex == i;
                      Widget card;
                      if (!bocaArriba) {
                        card = Container(
                          width: 68,
                          height: 102,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A0A33),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.acento,
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              '?',
                              style: TextStyle(
                                color: AppColors.acento,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        );
                      } else {
                        card = CartaEspanolaSkin(
                          numero: c.numero,
                          etiqueta: c.etiqueta,
                          palo: paloVisual(c.palo),
                          seleccionada: seleccionada,
                          width: 68,
                          height: 102,
                        );
                      }
                      final child = AnimatedPadding(
                        duration: const Duration(milliseconds: 120),
                        padding: EdgeInsets.only(bottom: seleccionada ? 8 : 0),
                        child: card,
                      );
                      if (onTapIndex == null) return child;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => onTapIndex!(i),
                          child: child,
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
