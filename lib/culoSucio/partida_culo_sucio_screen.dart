import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/culoSucio/motor_culo_sucio.dart';
import 'package:app_juegos_mesa/culoSucio/textos.dart';
import 'package:app_juegos_mesa/shared/partida_ui/epic_backdrop.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Partida local de Culo sucio v1.
class PartidaCuloSucioScreen extends StatefulWidget {
  const PartidaCuloSucioScreen({
    super.key,
    required this.nombres,
    this.contraPc = false,
  });

  final List<String> nombres;
  final bool contraPc;

  @override
  State<PartidaCuloSucioScreen> createState() => _PartidaCuloSucioScreenState();
}

class _PartidaCuloSucioScreenState extends State<PartidaCuloSucioScreen> {
  late PartidaCuloSucio _partida;
  bool _sacando = false;

  @override
  void initState() {
    super.initState();
    _partida = nuevaPartidaCuloSucio(
      nombres: widget.nombres,
      contraPc: widget.contraPc,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _talVezTurnoPc());
  }

  bool get _esTurnoPc =>
      _partida.contraPc &&
      !_partida.terminada &&
      _partida.jugadorActual == TextosCuloSucio.vsPcNombre;

  Future<void> _talVezTurnoPc() async {
    if (!_esTurnoPc || _sacando) return;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted || !_esTurnoPc) return;
    await _sacar();
  }

  Future<void> _sacar() async {
    if (_partida.terminada || _sacando) return;
    setState(() => _sacando = true);
    sacarCartaCuloSucio(_partida);
    if (!mounted) return;
    setState(() => _sacando = false);
    if (!_partida.terminada) {
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (mounted) _talVezTurnoPc();
    }
  }

  void _reiniciar() {
    setState(() {
      _partida = nuevaPartidaCuloSucio(
        nombres: widget.nombres,
        contraPc: widget.contraPc,
      );
      _sacando = false;
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
    final puedeSacar =
        !_partida.terminada && !_esTurnoPc && !_sacando;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Stack(
        children: [
          const Positioned.fill(child: EpicBackdrop()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: AppColors.texto,
                      ),
                      Expanded(
                        child: const Text(
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
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    TextosCuloSucio.reglaCorta,
                    textAlign: TextAlign.center,
                    style: TextStyle(
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
                Text(
                  '${TextosCuloSucio.cartasRestantes}: ${_partida.cartasRestantes}',
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (carta == null)
                  const Text(
                    'Tocá “Sacar carta” para empezar',
                    style: TextStyle(
                      color: AppColors.textoSuave,
                      fontSize: 15,
                    ),
                  )
                else
                  _CartaVista(
                    etiqueta: carta.etiqueta,
                    esCuloSucio: carta.esCuloSucio,
                    color: _colorPalo(carta.palo),
                    icono: _iconoPalo(
                      carta.palo,
                      comodin: carta.esComodin,
                    ),
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
                              ? 'La PC está sacando…'
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
              child: _OverlayFin(
                mensaje: _partida.mensajeFin ?? '',
                esCuloSucio: _partida.perdedor != null,
                perdedor: _partida.perdedor,
                ganador: _partida.ganador,
                onOtraVez: _reiniciar,
                onVolver: () => Navigator.of(context).maybePop(),
              ),
            ),
        ],
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
        border: Border.all(color: borde, width: activo || perdido || ganado ? 2 : 1),
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

class _OverlayFin extends StatelessWidget {
  const _OverlayFin({
    required this.mensaje,
    required this.esCuloSucio,
    required this.perdedor,
    required this.ganador,
    required this.onOtraVez,
    required this.onVolver,
  });

  final String mensaje;
  final bool esCuloSucio;
  final String? perdedor;
  final String? ganador;
  final VoidCallback onOtraVez;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
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
                    esCuloSucio
                        ? Icons.sentiment_very_dissatisfied_rounded
                        : Icons.handshake_outlined,
                    size: 52,
                    color: esCuloSucio ? AppColors.peligro : AppColors.acento,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    esCuloSucio ? TextosCuloSucio.culoSucio : 'Fin',
                    style: TextStyle(
                      color:
                          esCuloSucio ? AppColors.peligro : AppColors.texto,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    mensaje,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  if (ganador != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Gana $ganador',
                      style: const TextStyle(
                        color: AppColors.mint,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onOtraVez,
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
                      onPressed: onVolver,
                      child: const Text(TextosCuloSucio.volverMenu),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
