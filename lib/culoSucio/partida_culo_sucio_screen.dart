import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/culoSucio/historial_culo_sucio.dart';
import 'package:app_juegos_mesa/culoSucio/modo_dios_culo_sucio.dart';
import 'package:app_juegos_mesa/culoSucio/motor_culo_sucio.dart';
import 'package:app_juegos_mesa/culoSucio/opciones_culo_sucio.dart';
import 'package:app_juegos_mesa/culoSucio/standby_store.dart';
import 'package:app_juegos_mesa/culoSucio/textos.dart';
import 'package:app_juegos_mesa/culoSucio/victoria_culo_sucio_overlay.dart';
import 'package:app_juegos_mesa/shared/partida_ui/epic_backdrop.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/theme/victoria_celebration.dart';

/// Partida local de Culo sucio v1.
class PartidaCuloSucioScreen extends StatefulWidget {
  const PartidaCuloSucioScreen({
    super.key,
    required this.nombres,
    this.contraPc = false,
    this.modoDios = false,
    this.opciones = const OpcionesCuloSucio(),
    this.resume,
  });

  final List<String> nombres;
  final bool contraPc;
  final bool modoDios;
  final OpcionesCuloSucio opciones;
  final PartidaCuloSucioResume? resume;

  @override
  State<PartidaCuloSucioScreen> createState() => _PartidaCuloSucioScreenState();
}

class _PartidaCuloSucioScreenState extends State<PartidaCuloSucioScreen> {
  late PartidaCuloSucio _partida;
  bool _sacando = false;
  bool _editandoMazo = false;
  int _pcToken = 0;

  bool get _modoDiosActivo => widget.modoDios && widget.contraPc;

  @override
  void initState() {
    super.initState();
    final resume = widget.resume;
    if (resume != null) {
      _partida = resume.partida;
    } else {
      _partida = nuevaPartidaCuloSucio(
        nombres: widget.nombres,
        contraPc: widget.contraPc,
        incluirComodines: widget.opciones.comodines,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezTurnoPc());
  }

  bool get _esTurnoPc =>
      _partida.contraPc &&
      !_partida.terminada &&
      _partida.jugadorActual == TextosCuloSucio.vsPcNombre;

  /// Victoria con confeti si alguien ganó y no es la PC (p. ej. la PC sacó el 1 de oro).
  bool get _debeMostrarVictoria =>
      _partida.ganador != null &&
      _partida.perdedor != null &&
      _partida.ganador != TextosCuloSucio.vsPcNombre;

  void _guardarResumeSiCorresponde() {
    if (!widget.contraPc) return;
    if (_partida.terminada) {
      CuloSucioStandByStore.limpiar();
      return;
    }
    CuloSucioStandByStore.guardar(
      PartidaCuloSucioResume(
        partida: _partida,
        nombres: widget.nombres,
        opciones: widget.opciones,
        modoDios: widget.modoDios,
      ),
    );
  }

  void _salirAlMenu({required bool guardar}) {
    _pcToken++;
    if (guardar) {
      _guardarResumeSiCorresponde();
    } else {
      CuloSucioStandByStore.limpiar();
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _talVezTurnoPc() async {
    if (!_esTurnoPc || _sacando || _editandoMazo) return;
    final token = ++_pcToken;
    final espera = _modoDiosActivo ? 2200 : 700;
    await Future<void>.delayed(Duration(milliseconds: espera));
    if (!mounted || token != _pcToken) return;
    if (!_esTurnoPc || _sacando || _editandoMazo) return;
    await _sacar();
  }

  Future<void> _sacar() async {
    if (_partida.terminada || _sacando || _editandoMazo) return;
    setState(() => _sacando = true);
    sacarCartaCuloSucio(_partida);
    if (!mounted) return;
    setState(() => _sacando = false);
    if (!_partida.terminada) {
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (mounted) _talVezTurnoPc();
    }
  }

  Future<void> _abrirEditarMazo() async {
    if (!_modoDiosActivo || _partida.terminada || _partida.mazo.isEmpty) {
      return;
    }
    _pcToken++; // cancela el auto-turno de la PC mientras editás
    setState(() => _editandoMazo = true);
    final nuevo = await mostrarEditarMazoCuloSucio(
      context: context,
      ordenDesdeProxima: ordenSalidaMazoCuloSucio(_partida),
    );
    if (!mounted) return;
    setState(() {
      _editandoMazo = false;
      if (nuevo != null) {
        forzarMazoCuloSucio(_partida, nuevo);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezTurnoPc());
  }

  void _reiniciar() {
    _pcToken++;
    CuloSucioStandByStore.limpiar();
    setState(() {
      _partida = nuevaPartidaCuloSucio(
        nombres: widget.nombres,
        contraPc: widget.contraPc,
        incluirComodines: widget.opciones.comodines,
      );
      _sacando = false;
      _editandoMazo = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezTurnoPc());
  }

  Color _colorPalo(PaloCuloSucio? palo) {
    return switch (palo) {
      PaloCuloSucio.oro => const Color(0xFFFFC107),
      PaloCuloSucio.copa => const Color(0xFFFF5252),
      PaloCuloSucio.espada => const Color(0xFF40C4FF),
      PaloCuloSucio.basto => const Color(0xFF69F0AE),
      null => AppColors.violeta,
    };
  }

  IconData _iconoPalo(PaloCuloSucio? palo, {required bool comodin}) {
    if (comodin) return Icons.star_rounded;
    return switch (palo) {
      PaloCuloSucio.oro => Icons.monetization_on_outlined,
      PaloCuloSucio.copa => Icons.wine_bar_outlined,
      PaloCuloSucio.espada => Icons.bolt_outlined,
      PaloCuloSucio.basto => Icons.park_outlined,
      null => Icons.style_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final carta = _partida.ultimaCarta;
    final proxima =
        _modoDiosActivo ? proximaCartaCuloSucio(_partida) : null;
    final puedeSacar =
        !_partida.terminada && !_esTurnoPc && !_sacando && !_editandoMazo;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Vs PC sin terminar: guarda en memoria. Terminada o local: no resume.
        _salirAlMenu(guardar: widget.contraPc && !_partida.terminada);
      },
      child: Scaffold(
      backgroundColor: AppColors.fondo,
      body: Stack(
        children: [
          const Positioned.fill(child: EpicBackdrop(centerY: 0.52)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _salirAlMenu(
                          guardar: widget.contraPc && !_partida.terminada,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: AppColors.texto,
                      ),
                      const Expanded(
                        child: Text(
                          TextosCuloSucio.titulo,
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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    TextosCuloSucio.reglaConOpciones(
                      comodines: widget.opciones.comodines,
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textoSuave,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      for (var i = 0; i < _partida.nombres.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: _ChipJugador(
                            nombre: _partida.nombres[i],
                            activo: !_partida.terminada &&
                                _partida.indiceTurno == i,
                            perdido: _partida.perdedor == _partida.nombres[i],
                            ganado: _partida.ganador == _partida.nombres[i],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${TextosCuloSucio.cartasRestantes}: ${_partida.cartasRestantes}',
                      style: const TextStyle(
                        color: AppColors.textoSuave,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_modoDiosActivo && proxima != null) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.carta.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: proxima.esCuloSucio
                                ? AppColors.peligro
                                : AppColors.acento,
                          ),
                        ),
                        child: Text(
                          'Próxima: ${proxima.etiqueta}',
                          style: TextStyle(
                            color: proxima.esCuloSucio
                                ? AppColors.peligro
                                : AppColors.acento,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Compensa el botón a la derecha para que el mazo quede centrado.
                    SizedBox(width: _modoDiosActivo ? 52 : 0),
                    if (carta == null)
                      const _CartaTapada()
                    else
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (carta.esComodin) ...[
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Esto no deberia estar aqui.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.acento,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                          _CartaVista(
                            etiqueta: carta.etiqueta,
                            esCuloSucio: carta.esCuloSucio,
                            color: _colorPalo(carta.palo),
                            icono: _iconoPalo(
                              carta.palo,
                              comodin: carta.esComodin,
                            ),
                          ),
                        ],
                      ),
                    if (_modoDiosActivo) ...[
                      const SizedBox(width: 12),
                      Material(
                        color: AppColors.carta,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: (_partida.terminada ||
                                  _partida.mazo.isEmpty ||
                                  _sacando)
                              ? null
                              : _abrirEditarMazo,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.textoSuave
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Icon(
                              Icons.bug_report,
                              size: 20,
                              color: AppColors.textoSuave,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                if (!_partida.terminada) ...[
                  Text(
                    '${TextosCuloSucio.turnoDe} ${_partida.jugadorActual}',
                    style: TextStyle(
                      color: _esTurnoPc
                          ? AppColors.textoSuave
                          : AppColors.acento,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: puedeSacar ? _sacar : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.peligro,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.carta.withValues(alpha: 0.7),
                        ),
                        child: Text(
                          _esTurnoPc
                              ? (_modoDiosActivo
                                  ? 'La PC saca pronto…'
                                  : 'La PC está sacando…')
                              : TextosCuloSucio.sacarCarta,
                        ),
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
                  ? VictoriaCuloSucioOverlay(
                      partida: _partida,
                      onVolverAJugar: _reiniciar,
                      onVolver: () => _salirAlMenu(guardar: false),
                    )
                  : _OverlayFin(
                      partida: _partida,
                      mensaje: _partida.mensajeFin ?? '',
                      esCuloSucio: _partida.perdedor != null,
                      perdedor: _partida.perdedor,
                      ganador: _partida.ganador,
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
    required this.activo,
    required this.perdido,
    required this.ganado,
  });

  final String nombre;
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.carta.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borde,
          width: activo || perdido || ganado ? 2 : 1,
        ),
      ),
      child: Text(
        nombre,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: perdido
              ? AppColors.peligro
              : ganado
                  ? AppColors.mint
                  : AppColors.texto,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _CartaTapada extends StatelessWidget {
  const _CartaTapada();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3B1D6E),
            Color(0xFF1A0A33),
            Color(0xFF2A1050),
          ],
        ),
        border: Border.all(color: AppColors.acento, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.acento.withValues(alpha: 0.35),
            blurRadius: 22,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Patrón sutil de dorso.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.violeta.withValues(alpha: 0.55),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const Center(
            child: Text(
              '?',
              style: TextStyle(
                color: AppColors.acento,
                fontSize: 92,
                fontWeight: FontWeight.w900,
                height: 1,
                shadows: [
                  Shadow(
                    color: Color(0xAAFFC107),
                    blurRadius: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaVista extends StatelessWidget {
  const _CartaVista({
    required this.etiqueta,
    required this.esCuloSucio,
    required this.color,
    required this.icono,
  });

  final String etiqueta;
  final bool esCuloSucio;
  final Color color;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 168,
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.carta,
            Color.lerp(AppColors.carta, color, 0.35)!,
          ],
        ),
        border: Border.all(
          color: esCuloSucio ? AppColors.peligro : color,
          width: esCuloSucio ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (esCuloSucio ? AppColors.peligro : color)
                .withValues(alpha: 0.45),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 56, color: color),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              etiqueta,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: esCuloSucio ? AppColors.peligro : AppColors.texto,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
          ),
          if (esCuloSucio) ...[
            const SizedBox(height: 10),
            const Text(
              TextosCuloSucio.culoSucio,
              style: TextStyle(
                color: AppColors.peligro,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OverlayFin extends StatefulWidget {
  const _OverlayFin({
    required this.partida,
    required this.mensaje,
    required this.esCuloSucio,
    required this.perdedor,
    required this.ganador,
    required this.onOtraVez,
    required this.onVolver,
  });

  final PartidaCuloSucio partida;
  final String mensaje;
  final bool esCuloSucio;
  final String? perdedor;
  final String? ganador;
  final VoidCallback onOtraVez;
  final VoidCallback onVolver;

  @override
  State<_OverlayFin> createState() => _OverlayFinState();
}

class _OverlayFinState extends State<_OverlayFin> {
  bool _cartelVisible = true;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IgnorePointer(
          ignoring: !_cartelVisible,
          child: Material(
            color: _cartelVisible
                ? Colors.black.withValues(alpha: 0.72)
                : Colors.transparent,
            child: _cartelVisible
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Material(
                        color: AppColors.carta,
                        borderRadius: BorderRadius.circular(22),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.esCuloSucio
                                    ? Icons.sentiment_very_dissatisfied_rounded
                                    : Icons.handshake_outlined,
                                size: 52,
                                color: widget.esCuloSucio
                                    ? AppColors.peligro
                                    : AppColors.acento,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.esCuloSucio
                                    ? TextosCuloSucio.culoSucio
                                    : 'Fin',
                                style: TextStyle(
                                  color: widget.esCuloSucio
                                      ? AppColors.peligro
                                      : AppColors.texto,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.mensaje,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.texto,
                                  fontSize: 15,
                                  height: 1.35,
                                ),
                              ),
                              if (widget.ganador != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Gana ${widget.ganador}',
                                  style: const TextStyle(
                                    color: AppColors.mint,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                              if (widget.partida.cartasSacadas > 0) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Cartas sacadas: ${widget.partida.cartasSacadas}',
                                  style: const TextStyle(
                                    color: AppColors.textoSuave,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 22),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => mostrarHistorialCuloSucio(
                                    context: context,
                                    partida: widget.partida,
                                  ),
                                  icon: const Icon(Icons.history_rounded),
                                  label: const Text('Historial'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.azul,
                                    side: const BorderSide(
                                      color: AppColors.azul,
                                      width: 1.6,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: widget.onOtraVez,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.peligro,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text(TextosCuloSucio.reiniciar),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: widget.onVolver,
                                  child:
                                      const Text(TextosCuloSucio.volverMenu),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.expand(),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: BotonOjoVictoria(
                cartelVisible: _cartelVisible,
                onTap: () =>
                    setState(() => _cartelVisible = !_cartelVisible),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
