import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/culoSucioV2/motor_culo_sucio_v2.dart';
import 'package:app_juegos_mesa/culoSucioV2/standby_store.dart';
import 'package:app_juegos_mesa/culoSucioV2/textos.dart';
import 'package:app_juegos_mesa/culoSucioV2/victoria_culo_sucio_v2_overlay.dart';
import 'package:app_juegos_mesa/shared/cartas/icono_espada.dart';
import 'package:app_juegos_mesa/shared/partida_ui/epic_backdrop.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Partida local / vs PC de Culo sucio v2.
class PartidaCuloSucioV2Screen extends StatefulWidget {
  const PartidaCuloSucioV2Screen({
    super.key,
    required this.nombres,
    this.contraPc = false,
    this.modoDios = false,
    this.resume,
  });

  final List<String> nombres;
  final bool contraPc;
  final bool modoDios;
  final PartidaCuloSucioV2Resume? resume;

  @override
  State<PartidaCuloSucioV2Screen> createState() =>
      _PartidaCuloSucioV2ScreenState();
}

class _PartidaCuloSucioV2ScreenState extends State<PartidaCuloSucioV2Screen> {
  late PartidaCuloSucioV2 _partida;
  bool _robando = false;
  int _pcToken = 0;
  /// Índices seleccionados en la mano para formar un par inicial.
  final List<int> _seleccionPar = [];

  bool get _modoDiosActivo => widget.modoDios && widget.contraPc;

  /// En vs PC el humano es el que no se llama PC.
  JugadorCuloSucioV2 get _humano {
    if (!widget.contraPc) return _partida.jugadorActual;
    return _partida.jugadores.firstWhere(
      (j) => j.nombre != TextosCuloSucioV2.vsPcNombre,
      orElse: () => _partida.jugadores.first,
    );
  }

  JugadorCuloSucioV2 get _rivalVista {
    if (widget.contraPc) {
      return _partida.jugadores.firstWhere(
        (j) => j.nombre == TextosCuloSucioV2.vsPcNombre,
        orElse: () => _partida.jugadores.last,
      );
    }
    // Partida rápida: el “rival” es el otro respecto al turno actual
    // para la zona de arriba; abajo mostramos la mano del jugador actual.
    return _partida.rivalActual;
  }

  bool get _esTurnoHumano {
    if (_partida.terminada) return false;
    if (!widget.contraPc) return true;
    return _partida.jugadorActual.nombre != TextosCuloSucioV2.vsPcNombre;
  }

  bool get _esTurnoPc =>
      widget.contraPc &&
      !_partida.terminada &&
      _partida.enJuego &&
      _partida.jugadorActual.nombre == TextosCuloSucioV2.vsPcNombre;

  bool get _fasePares => _partida.descartandoPares;

  bool get _puedoDescartarPares =>
      _fasePares && _esTurnoHumano && !_robando;

  bool get _debeMostrarVictoria =>
      _partida.ganador != null &&
      _partida.perdedor != null &&
      _partida.ganador != TextosCuloSucioV2.vsPcNombre;

  String get _textoEstado {
    if (_partida.terminada) return '';
    if (_fasePares) {
      if (!_esTurnoHumano) {
        return TextosCuloSucioV2.esperandoRivalPares;
      }
      return TextosCuloSucioV2.sacandoPares;
    }
    if (_esTurnoPc) return TextosCuloSucioV2.esperandoPc;
    if (_esTurnoHumano) return TextosCuloSucioV2.robaUna;
    return 'Turno de ${_partida.jugadorActual.nombre}';
  }

  @override
  void initState() {
    super.initState();
    final resume = widget.resume;
    if (resume != null) {
      _partida = resume.partida;
    } else {
      _partida = nuevaPartidaCuloSucioV2(
        nombres: widget.nombres,
        contraPc: widget.contraPc,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezTurnoPc());
  }

  void _guardarResumeSiCorresponde() {
    if (!widget.contraPc) return;
    if (_partida.terminada) {
      CuloSucioV2StandByStore.limpiar();
      return;
    }
    CuloSucioV2StandByStore.guardar(
      PartidaCuloSucioV2Resume(
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
      CuloSucioV2StandByStore.limpiar();
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _talVezTurnoPc() async {
    if (!_esTurnoPc || _robando) return;
    final token = ++_pcToken;
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!mounted || token != _pcToken) return;
    if (!_esTurnoPc) return;
    setState(() => _robando = true);
    jugarTurnoPcCuloSucioV2(_partida);
    if (!mounted) return;
    setState(() => _robando = false);
    if (!_partida.terminada) {
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (mounted) _talVezTurnoPc();
    }
  }

  Future<void> _robarDeRival(int indice) async {
    if (!_partida.enJuego || _robando || !_esTurnoHumano) return;
    final hacia = widget.contraPc ? _humano : _partida.jugadorActual;
    final de = widget.contraPc ? _rivalVista : _partida.rivalActual;
    if (hacia.nombre != _partida.jugadorActual.nombre) return;

    setState(() => _robando = true);
    final err = robarCartaCuloSucioV2(
      _partida,
      de: de,
      indiceEnManoDe: indice,
      hacia: hacia,
    );
    if (!mounted) return;
    setState(() => _robando = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (!_partida.terminada) {
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (mounted) _talVezTurnoPc();
    }
  }

  void _tocarCartaManoParaPar(int indice) {
    if (!_puedoDescartarPares) return;
    if (_seleccionPar.contains(indice)) {
      setState(() => _seleccionPar.remove(indice));
      return;
    }
    if (_seleccionPar.isEmpty) {
      setState(() => _seleccionPar.add(indice));
      return;
    }

    final jugador = widget.contraPc ? _humano : _partida.jugadorActual;
    final primero = _seleccionPar.first;
    if (primero < 0 ||
        primero >= jugador.mano.length ||
        indice >= jugador.mano.length) {
      setState(() {
        _seleccionPar
          ..clear()
          ..add(indice);
      });
      return;
    }

    if (jugador.mano[primero].numero != jugador.mano[indice].numero) {
      // Número distinto: la nueva carta queda como única selección.
      setState(() {
        _seleccionPar
          ..clear()
          ..add(indice);
      });
      return;
    }

    final err = descartarParManualCuloSucioV2(
      _partida,
      jugador: jugador,
      indiceA: primero,
      indiceB: indice,
    );
    setState(() => _seleccionPar.clear());
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  void _confirmarParesListos() {
    if (!_puedoDescartarPares) return;
    final err = confirmarParesInicialesListos(_partida);
    setState(() => _seleccionPar.clear());
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (_partida.enJuego) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _talVezTurnoPc());
    }
  }

  void _eliminarParesAutomaticamente() {
    if (!_puedoDescartarPares) return;
    final err = descartarTodosParesInicialesCuloSucioV2(_partida);
    setState(() => _seleccionPar.clear());
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  void _reiniciar() {
    _pcToken++;
    CuloSucioV2StandByStore.limpiar();
    setState(() {
      _partida = nuevaPartidaCuloSucioV2(
        nombres: widget.nombres,
        contraPc: widget.contraPc,
      );
      _robando = false;
      _seleccionPar.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezTurnoPc());
  }

  Color _colorPalo(PaloCuloSucioV2 palo) => switch (palo) {
        PaloCuloSucioV2.oro => const Color(0xFFFFC107),
        PaloCuloSucioV2.copa => const Color(0xFFFF5252),
        PaloCuloSucioV2.espada => const Color(0xFF40C4FF),
        PaloCuloSucioV2.basto => const Color(0xFF69F0AE),
      };

  IconData _iconoPalo(PaloCuloSucioV2 palo) => switch (palo) {
        PaloCuloSucioV2.oro => Icons.monetization_on_outlined,
        PaloCuloSucioV2.copa => Icons.wine_bar_outlined,
        PaloCuloSucioV2.espada => Icons.bolt_outlined,
        PaloCuloSucioV2.basto => Icons.park_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final manoAbajo = widget.contraPc ? _humano : _partida.jugadorActual;
    final manoArriba = widget.contraPc ? _rivalVista : _partida.rivalActual;
    final rivalParaRobar = manoArriba;
    final yoTurno = manoAbajo;

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
            const Positioned.fill(child: EpicBackdrop(centerY: 0.45)),
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
                            TextosCuloSucioV2.titulo,
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
                  const SizedBox(height: 10),
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
                              cartas: _partida.jugadores[i].mano.length,
                              activo: !_partida.terminada &&
                                  _partida.indiceTurno == i,
                              perdido: _partida.perdedor ==
                                  _partida.jugadores[i].nombre,
                              ganado: _partida.ganador ==
                                  _partida.jugadores[i].nombre,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _textoEstado,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _esTurnoHumano
                          ? AppColors.acento
                          : AppColors.textoSuave,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  if (!_fasePares) ...[
                    const Spacer(flex: 3),
                    Text(
                      '${TextosCuloSucioV2.manoRival}: ${manoArriba.nombre}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textoSuave,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 112,
                      width: double.infinity,
                      child: _FilaCartas(
                        cartas: manoArriba.mano,
                        bocaArriba: _modoDiosActivo,
                        colorPalo: _colorPalo,
                        iconoPalo: _iconoPalo,
                        onTapIndex: (_esTurnoHumano &&
                                !_robando &&
                                identical(manoArriba, rivalParaRobar))
                            ? _robarDeRival
                            : null,
                      ),
                    ),
                    if (_partida.ultimaRobada != null ||
                        _partida.ultimoPar != null) ...[
                      const SizedBox(height: 10),
                      Center(
                        child: _AvisoJugada(
                          robada: _partida.ultimaRobada,
                          par: _partida.ultimoPar,
                        ),
                      ),
                    ],
                    const Spacer(flex: 1),
                    Text(
                      '${TextosCuloSucioV2.paresDescartados} (${yoTurno.descartes.length ~/ 2})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textoSuave,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: _FilaCartas(
                        cartas: yoTurno.descartes,
                        bocaArriba: true,
                        compacta: true,
                        colorPalo: _colorPalo,
                        iconoPalo: _iconoPalo,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${TextosCuloSucioV2.tuMano}: ${manoAbajo.nombre}',
                      textAlign: TextAlign.center,
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
                        colorPalo: _colorPalo,
                        iconoPalo: _iconoPalo,
                      ),
                    ),
                    const Spacer(flex: 1),
                  ] else ...[
                    Expanded(
                      child: _ZonaParesDescartados(
                        descartes: yoTurno.descartes,
                        ultimoPar: _partida.ultimoPar,
                        colorPalo: _colorPalo,
                        iconoPalo: _iconoPalo,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A0A33),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.violeta,
                            width: 1.6,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${TextosCuloSucioV2.tuMano}: ${manoAbajo.nombre}',
                                    style: const TextStyle(
                                      color: AppColors.mint,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (_puedoDescartarPares)
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: manoTieneParCuloSucioV2(
                                              manoAbajo.mano)
                                          ? _eliminarParesAutomaticamente
                                          : null,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2A1050),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: manoTieneParCuloSucioV2(
                                                    manoAbajo.mano)
                                                ? AppColors.acento
                                                : AppColors.cartaBorde,
                                            width: 1.4,
                                          ),
                                        ),
                                        child: Text(
                                          TextosCuloSucioV2.eliminarParesAuto,
                                          style: TextStyle(
                                            color: manoTieneParCuloSucioV2(
                                                    manoAbajo.mano)
                                                ? AppColors.acento
                                                : AppColors.textoSuave,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _ManoDosFilas(
                              cartas: manoAbajo.mano,
                              colorPalo: _colorPalo,
                              iconoPalo: _iconoPalo,
                              seleccionados: _puedoDescartarPares
                                  ? _seleccionPar
                                  : const [],
                              onTapIndex: _puedoDescartarPares
                                  ? (i) async => _tocarCartaManoParaPar(i)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_puedoDescartarPares)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: manoTieneParCuloSucioV2(manoAbajo.mano)
                                ? null
                                : _confirmarParesListos,
                            child: const Text(TextosCuloSucioV2.listoPares),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (_partida.terminada)
              Positioned.fill(
                child: _debeMostrarVictoria
                    ? VictoriaCuloSucioV2Overlay(
                        partida: _partida,
                        onVolverAJugar: _reiniciar,
                        onVolver: () => _salirAlMenu(guardar: false),
                      )
                    : DerrotaCuloSucioV2Overlay(
                        partida: _partida,
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
    required this.cartas,
    required this.activo,
    required this.perdido,
    required this.ganado,
  });

  final String nombre;
  final int cartas;
  final bool activo;
  final bool perdido;
  final bool ganado;

  @override
  Widget build(BuildContext context) {
    final borde = perdido
        ? AppColors.peligro
        : ganado
            ? AppColors.mint
            : activo
                ? AppColors.acento
                : AppColors.cartaBorde;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.carta.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borde,
          width: activo || perdido || ganado ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: perdido
                  ? AppColors.peligro
                  : ganado
                      ? AppColors.mint
                      : AppColors.texto,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(
            '$cartas carta${cartas == 1 ? '' : 's'}',
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

class _ZonaParesDescartados extends StatelessWidget {
  const _ZonaParesDescartados({
    required this.descartes,
    required this.ultimoPar,
    required this.colorPalo,
    required this.iconoPalo,
  });

  final List<CartaCuloSucioV2> descartes;
  final List<CartaCuloSucioV2>? ultimoPar;
  final Color Function(PaloCuloSucioV2) colorPalo;
  final IconData Function(PaloCuloSucioV2) iconoPalo;

  @override
  Widget build(BuildContext context) {
    final pares = descartes.length ~/ 2;
    final destacado = ultimoPar != null && ultimoPar!.length >= 2
        ? ultimoPar!
        : (descartes.length >= 2
            ? descartes.sublist(descartes.length - 2)
            : const <CartaCuloSucioV2>[]);
    final vacio = destacado.length < 2;
    final mostrarHistorial = pares > 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        children: [
          Text(
            '$pares par${pares == 1 ? '' : 'es'} descartado${pares == 1 ? '' : 's'}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: vacio
                ? const Center(
                    child: Text(
                      'Acá se van a ver los pares que saques',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textoSuave,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final historialH = mostrarHistorial ? 72.0 : 0.0;
                      final tituloParH =
                          (ultimoPar != null && ultimoPar!.length >= 2)
                              ? 28.0
                              : 0.0;
                      final disponible = (constraints.maxHeight -
                              historialH -
                              tituloParH)
                          .clamp(56.0, 160.0);
                      final cardH = disponible;
                      final cardW = cardH * (92 / 136);

                      return Column(
                        children: [
                          if (ultimoPar != null && ultimoPar!.length >= 2)
                            const Text(
                              '¡Par!',
                              style: TextStyle(
                                color: AppColors.mint,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: 1,
                              ),
                            ),
                          Expanded(
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _CartaSkinV2(
                                      carta: destacado[0],
                                      bocaArriba: true,
                                      compacta: false,
                                      seleccionada: false,
                                      color: colorPalo(destacado[0].palo),
                                      icono: iconoPalo(destacado[0].palo),
                                      width: cardW,
                                      height: cardH,
                                    ),
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 12),
                                      child: Text(
                                        '+',
                                        style: TextStyle(
                                          color: AppColors.mint,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 28,
                                        ),
                                      ),
                                    ),
                                    _CartaSkinV2(
                                      carta: destacado[1],
                                      bocaArriba: true,
                                      compacta: false,
                                      seleccionada: false,
                                      color: colorPalo(destacado[1].palo),
                                      icono: iconoPalo(destacado[1].palo),
                                      width: cardW,
                                      height: cardH,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (mostrarHistorial) ...[
                            const Text(
                              TextosCuloSucioV2.paresDescartados,
                              style: TextStyle(
                                color: AppColors.textoSuave,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 56,
                              width: double.infinity,
                              child: _FilaCartas(
                                cartas: descartes,
                                bocaArriba: true,
                                compacta: true,
                                colorPalo: colorPalo,
                                iconoPalo: iconoPalo,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AvisoJugada extends StatelessWidget {
  const _AvisoJugada({
    required this.robada,
    required this.par,
  });

  final CartaCuloSucioV2? robada;
  final List<CartaCuloSucioV2>? par;

  @override
  Widget build(BuildContext context) {
    final texto = par != null && par!.length >= 2
        ? '¡Par! ${par![0].etiqueta} + ${par![1].etiqueta}'
        : (robada == null
            ? ''
            : 'Robó: ${robada!.etiqueta}');
    if (texto.isEmpty) return const SizedBox.shrink();
    final color = par != null
        ? AppColors.mint
        : (robada?.esCuloSucio == true
            ? AppColors.peligro
            : AppColors.acento);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.carta.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ManoDosFilas extends StatelessWidget {
  const _ManoDosFilas({
    required this.cartas,
    required this.colorPalo,
    required this.iconoPalo,
    this.onTapIndex,
    this.seleccionados = const [],
  });

  final List<CartaCuloSucioV2> cartas;
  final Color Function(PaloCuloSucioV2) colorPalo;
  final IconData Function(PaloCuloSucioV2) iconoPalo;
  final Future<void> Function(int index)? onTapIndex;
  final List<int> seleccionados;

  @override
  Widget build(BuildContext context) {
    if (cartas.isEmpty) {
      return const Center(
        child: Text('—', style: TextStyle(color: AppColors.textoSuave)),
      );
    }
    final mitad = (cartas.length + 1) ~/ 2;
    final fila1 = cartas.sublist(0, mitad);
    final fila2 = cartas.sublist(mitad);
    Widget fila({
      required List<CartaCuloSucioV2> cards,
      required int base,
    }) {
      return _FilaCartas(
        cartas: cards,
        bocaArriba: true,
        colorPalo: colorPalo,
        iconoPalo: iconoPalo,
        seleccionados: seleccionados,
        indiceBase: base,
        onTapIndex: onTapIndex,
      );
    }

    if (fila2.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          height: 110,
          child: fila(cards: fila1, base: 0),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 110, child: fila(cards: fila1, base: 0)),
          const SizedBox(height: 8),
          SizedBox(height: 110, child: fila(cards: fila2, base: mitad)),
        ],
      ),
    );
  }
}

class _FilaCartas extends StatelessWidget {
  const _FilaCartas({
    required this.cartas,
    required this.bocaArriba,
    required this.colorPalo,
    required this.iconoPalo,
    this.onTapIndex,
    this.compacta = false,
    this.seleccionados = const [],
    this.indiceBase = 0,
  });

  final List<CartaCuloSucioV2> cartas;
  final bool bocaArriba;
  final Color Function(PaloCuloSucioV2) colorPalo;
  final IconData Function(PaloCuloSucioV2) iconoPalo;
  final Future<void> Function(int index)? onTapIndex;
  final bool compacta;
  final List<int> seleccionados;
  /// Índice real de la primera carta de esta fila (para manos partidas).
  final int indiceBase;

  @override
  Widget build(BuildContext context) {
    if (cartas.isEmpty) {
      return const Center(
        child: Text(
          '—',
          style: TextStyle(color: AppColors.textoSuave),
        ),
      );
    }
    final w = compacta ? 40.0 : 68.0;
    final h = compacta ? 56.0 : 102.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < cartas.length; index++) ...[
                  if (index > 0) SizedBox(width: compacta ? 4 : 6),
                  Builder(
                    builder: (context) {
                      final c = cartas[index];
                      final indiceReal = indiceBase + index;
                      final color = colorPalo(c.palo);
                      final seleccionada = seleccionados.contains(indiceReal);
                      final card = _CartaSkinV2(
                        carta: c,
                        bocaArriba: bocaArriba,
                        compacta: compacta,
                        seleccionada: seleccionada,
                        color: color,
                        icono: iconoPalo(c.palo),
                        width: w,
                        height: h,
                      );
                      final child = AnimatedPadding(
                        duration: const Duration(milliseconds: 120),
                        padding: EdgeInsets.only(bottom: seleccionada ? 8 : 0),
                        child: card,
                      );
                      if (onTapIndex == null) return child;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(compacta ? 10 : 14),
                          onTap: () => onTapIndex!(indiceReal),
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

/// Misma skin visual que Culo sucio v1 (ícono, brillo, dorso).
class _CartaSkinV2 extends StatelessWidget {
  const _CartaSkinV2({
    required this.carta,
    required this.bocaArriba,
    required this.compacta,
    required this.seleccionada,
    required this.color,
    required this.icono,
    required this.width,
    required this.height,
  });

  final CartaCuloSucioV2 carta;
  final bool bocaArriba;
  final bool compacta;
  final bool seleccionada;
  final Color color;
  final IconData icono;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radio = compacta ? 10.0 : 14.0;
    if (!bocaArriba) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radio),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3B1D6E),
              Color(0xFF1A0A33),
              Color(0xFF2A1050),
            ],
          ),
          border: Border.all(
            color: seleccionada ? AppColors.mint : AppColors.acento,
            width: seleccionada ? 2.4 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (seleccionada ? AppColors.mint : AppColors.acento)
                  .withValues(alpha: 0.35),
              blurRadius: compacta ? 8 : 14,
              spreadRadius: 0.5,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(compacta ? 4 : 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radio - 4),
                    border: Border.all(
                      color: AppColors.violeta.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                '?',
                style: TextStyle(
                  color: AppColors.acento,
                  fontSize: compacta ? 18 : 36,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  shadows: const [
                    Shadow(color: Color(0xAAFFC107), blurRadius: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final borde = seleccionada
        ? AppColors.mint
        : (carta.esCuloSucio ? AppColors.peligro : color);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radio),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.carta,
            Color.lerp(AppColors.carta, color, 0.35)!,
          ],
        ),
        border: Border.all(
          color: borde,
          width: seleccionada || carta.esCuloSucio ? 2.4 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: borde.withValues(alpha: 0.45),
            blurRadius: compacta ? 8 : 14,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compacta ? 2 : 4,
          vertical: compacta ? 2 : 6,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            carta.palo == PaloCuloSucioV2.espada
                ? IconoEspadaOutlined(
                    size: compacta ? 14 : 26,
                    color: color,
                  )
                : Icon(
                    icono,
                    size: compacta ? 14 : 26,
                    color: color,
                  ),
            SizedBox(height: compacta ? 2 : 6),
            Text(
              compacta ? '${carta.numero}' : carta.etiqueta,
              textAlign: TextAlign.center,
              maxLines: compacta ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: carta.esCuloSucio ? AppColors.peligro : AppColors.texto,
                fontSize: compacta ? 11 : 11,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            if (carta.esCuloSucio && !compacta) ...[
              const SizedBox(height: 4),
              const Text(
                TextosCuloSucioV2.culoSucio,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.peligro,
                  fontWeight: FontWeight.w900,
                  fontSize: 7,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
