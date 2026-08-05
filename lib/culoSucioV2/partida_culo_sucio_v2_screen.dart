import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/culoSucioV2/motor_culo_sucio_v2.dart';
import 'package:app_juegos_mesa/culoSucioV2/standby_store.dart';
import 'package:app_juegos_mesa/culoSucioV2/textos.dart';
import 'package:app_juegos_mesa/culoSucioV2/victoria_culo_sucio_v2_overlay.dart';
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
      _partida.jugadorActual.nombre == TextosCuloSucioV2.vsPcNombre;

  bool get _debeMostrarVictoria =>
      _partida.ganador != null &&
      _partida.perdedor != null &&
      _partida.ganador != TextosCuloSucioV2.vsPcNombre;

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
    if (_partida.terminada || _robando || !_esTurnoHumano) return;
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

  void _reiniciar() {
    _pcToken++;
    CuloSucioV2StandByStore.limpiar();
    setState(() {
      _partida = nuevaPartidaCuloSucioV2(
        nombres: widget.nombres,
        contraPc: widget.contraPc,
      );
      _robando = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezTurnoPc());
  }

  Color _colorPalo(PaloCuloSucioV2 palo) => switch (palo) {
        PaloCuloSucioV2.oro => const Color(0xFFFFC107),
        PaloCuloSucioV2.copa => const Color(0xFFFF5252),
        PaloCuloSucioV2.espada => const Color(0xFF40C4FF),
        PaloCuloSucioV2.basto => const Color(0xFF69F0AE),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      TextosCuloSucioV2.reglaCorta,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textoSuave,
                        fontSize: 12,
                        height: 1.3,
                      ),
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
                    _esTurnoPc
                        ? TextosCuloSucioV2.esperandoPc
                        : (_esTurnoHumano
                            ? TextosCuloSucioV2.robaUna
                            : 'Turno de ${_partida.jugadorActual.nombre}'),
                    style: TextStyle(
                      color: _esTurnoHumano
                          ? AppColors.acento
                          : AppColors.textoSuave,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${TextosCuloSucioV2.manoRival}: ${manoArriba.nombre}',
                    style: const TextStyle(
                      color: AppColors.textoSuave,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 96,
                    child: _FilaCartas(
                      cartas: manoArriba.mano,
                      bocaArriba: _modoDiosActivo,
                      colorPalo: _colorPalo,
                      onTapIndex: (_esTurnoHumano &&
                              !_robando &&
                              identical(manoArriba, rivalParaRobar))
                          ? _robarDeRival
                          : null,
                    ),
                  ),
                  if (_partida.ultimaRobada != null ||
                      _partida.ultimoPar != null) ...[
                    const SizedBox(height: 8),
                    _AvisoJugada(
                      robada: _partida.ultimaRobada,
                      par: _partida.ultimoPar,
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '${TextosCuloSucioV2.paresDescartados} (${yoTurno.descartes.length ~/ 2})',
                    style: const TextStyle(
                      color: AppColors.textoSuave,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 52,
                    child: _FilaCartas(
                      cartas: yoTurno.descartes,
                      bocaArriba: true,
                      compacta: true,
                      colorPalo: _colorPalo,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${TextosCuloSucioV2.tuMano}: ${manoAbajo.nombre}',
                    style: const TextStyle(
                      color: AppColors.mint,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 110,
                    child: _FilaCartas(
                      cartas: manoAbajo.mano,
                      bocaArriba: true,
                      colorPalo: _colorPalo,
                    ),
                  ),
                  const SizedBox(height: 16),
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

class _FilaCartas extends StatelessWidget {
  const _FilaCartas({
    required this.cartas,
    required this.bocaArriba,
    required this.colorPalo,
    this.onTapIndex,
    this.compacta = false,
  });

  final List<CartaCuloSucioV2> cartas;
  final bool bocaArriba;
  final Color Function(PaloCuloSucioV2) colorPalo;
  final Future<void> Function(int index)? onTapIndex;
  final bool compacta;

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
    final w = compacta ? 36.0 : 58.0;
    final h = compacta ? 50.0 : 88.0;
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: cartas.length,
      separatorBuilder: (_, __) => const SizedBox(width: 6),
      itemBuilder: (context, index) {
        final c = cartas[index];
        final color = colorPalo(c.palo);
        final child = Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: bocaArriba
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.carta,
                      Color.lerp(AppColors.carta, color, 0.35)!,
                    ],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF3B1D6E), Color(0xFF1A0A33)],
                  ),
            border: Border.all(
              color: c.esCuloSucio && bocaArriba
                  ? AppColors.peligro
                  : (bocaArriba ? color : AppColors.acento),
              width: c.esCuloSucio && bocaArriba ? 2 : 1.4,
            ),
          ),
          child: bocaArriba
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${c.numero}',
                      style: TextStyle(
                        color: c.esCuloSucio ? AppColors.peligro : color,
                        fontWeight: FontWeight.w900,
                        fontSize: compacta ? 12 : 18,
                      ),
                    ),
                    if (!compacta)
                      Text(
                        c.nombrePalo,
                        style: const TextStyle(
                          color: AppColors.textoSuave,
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                        ),
                      ),
                  ],
                )
              : Center(
                  child: Text(
                    '?',
                    style: TextStyle(
                      color: AppColors.acento,
                      fontWeight: FontWeight.w900,
                      fontSize: compacta ? 16 : 28,
                    ),
                  ),
                ),
        );
        if (onTapIndex == null) return child;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onTapIndex!(index),
            child: child,
          ),
        );
      },
    );
  }
}
