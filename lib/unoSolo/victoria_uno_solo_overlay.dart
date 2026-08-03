import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/theme/victoria_celebration.dart';
import 'package:app_juegos_mesa/unoSolo/motor_uno_solo.dart';

/// Fin de Uno solo:
/// · 1 ficha en el centro → victoria con confeti y fuegos.
/// · Rival se rinde (multijugador) → victoria con confeti y fuegos.
/// · 1 ficha fuera del centro → derrota (exige centro).
/// · ≥6 fichas → cartel “Seguí intentando” (sin celebración).
/// · 2–5 fichas → no se muestra (la partida lo oculta).
class VictoriaUnoSoloOverlay extends StatefulWidget {
  const VictoriaUnoSoloOverlay({
    super.key,
    required this.partida,
    required this.onVolverAJugar,
    required this.onVolver,
    this.mostrarVolverAJugar = true,
    this.onVerOrden,
    this.onDeshacer,
    this.animaciones = true,
  });

  final PartidaUnoSolo partida;
  final VoidCallback onVolverAJugar;
  final VoidCallback onVolver;
  final bool mostrarVolverAJugar;
  final VoidCallback? onVerOrden;
  final VoidCallback? onDeshacer;
  final bool animaciones;

  static bool victoriaPorAbandono(PartidaUnoSolo p) {
    if (p.fase != FaseUnoSolo.ganado || p.ganador == null) return false;
    final m = p.mensajeFin ?? '';
    return m.contains('rindió') || m.contains('abandono');
  }

  static bool debeMostrar(PartidaUnoSolo p) {
    if (victoriaPorAbandono(p) || p.fichaUnicaEnCentro) return true;
    final n = p.fichasRestantes;
    return n <= 1 || n >= 6;
  }

  @override
  State<VictoriaUnoSoloOverlay> createState() => _VictoriaUnoSoloOverlayState();
}

class _VictoriaUnoSoloOverlayState extends State<VictoriaUnoSoloOverlay>
    with TickerProviderStateMixin {
  static const int _cicloConfetiSegundos = 3600;

  late final AnimationController _entrada;
  late final AnimationController _pulso;
  late final AnimationController _confeti;
  late final Animation<double> _escala;
  late final Animation<double> _opacidad;
  bool _cartelVisible = true;

  bool get _esVictoria =>
      widget.partida.fichaUnicaEnCentro ||
      VictoriaUnoSoloOverlay.victoriaPorAbandono(widget.partida);

  @override
  void initState() {
    super.initState();
    final conAnim = widget.animaciones && _esVictoria;

    _entrada = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: conAnim ? 700 : 0),
    );
    _pulso = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _confeti = AnimationController.unbounded(vsync: this);

    if (conAnim) {
      _entrada.forward();
      _pulso.repeat(reverse: true);
      _confeti.repeat(
        min: 0,
        max: _cicloConfetiSegundos.toDouble(),
        period: const Duration(seconds: _cicloConfetiSegundos),
      );
    } else {
      _entrada.value = 1;
    }

    _escala = CurvedAnimation(
      parent: _entrada,
      curve: conAnim ? Curves.elasticOut : Curves.linear,
    );
    _opacidad = CurvedAnimation(
      parent: _entrada,
      curve: conAnim ? Curves.easeOut : Curves.linear,
    );
  }

  @override
  void dispose() {
    _entrada.dispose();
    _pulso.dispose();
    _confeti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_esVictoria) {
      return _buildVictoriaConCelebracion();
    }
    return _buildDerrotaOSeguir();
  }

  Widget _buildVictoriaConCelebracion() {
    final porAbandono =
        VictoriaUnoSoloOverlay.victoriaPorAbandono(widget.partida);
    final sub = widget.partida.mensajeFin ??
        (porAbandono
            ? 'Ganaste por abandono del rival'
            : '¡Una sola ficha en el centro!');
    final ganador = widget.partida.ganador?.trim().isNotEmpty == true
        ? widget.partida.ganador!
        : (widget.partida.nombres.isNotEmpty
            ? widget.partida.nombres.first
            : 'Jugador');

    return Stack(
      children: [
        IgnorePointer(
          ignoring: !_cartelVisible,
          child: Material(
            color: _cartelVisible
                ? Colors.black.withValues(alpha: 0.72)
                : Colors.transparent,
            child: Stack(
              children: [
                if (widget.animaciones)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _confeti,
                        builder: (_, __) => CustomPaint(
                          painter: ConfetiPainter(tiempo: _confeti.value),
                        ),
                      ),
                    ),
                  ),
                if (_cartelVisible)
                  SafeArea(
                    child: Center(
                      child: FadeTransition(
                        opacity: _opacidad,
                        child: ScaleTransition(
                          scale: _escala,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: _WinnerCardUnoSolo(
                                ganador: ganador,
                                subtitulo: sub,
                                pulso: _pulso,
                                animaciones: widget.animaciones,
                                onVerOrden: widget.onVerOrden,
                                onDeshacer: widget.onDeshacer,
                                onVolverAJugar: widget.mostrarVolverAJugar
                                    ? widget.onVolverAJugar
                                    : null,
                                onVolver: widget.onVolver,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Fuegos por encima del cartel (igual que Generala / Diez Mil).
                if (widget.animaciones)
                  const Positioned.fill(
                    child: IgnorePointer(child: FuegosArtificialesCapa()),
                  ),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: BotonOjoVictoria(
                cartelVisible: _cartelVisible,
                onTap: () => setState(() => _cartelVisible = !_cartelVisible),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDerrotaOSeguir() {
    final n = widget.partida.fichasRestantes;
    final unaFueraDeCentro = n <= 1 && !widget.partida.fichaUnicaEnCentro;
    final titulo = widget.partida.calificacion ??
        (unaFueraDeCentro ? 'Derrota' : 'Seguí intentando');
    final sub = widget.partida.mensajeFin ??
        (unaFueraDeCentro
            ? 'El juego exige que la última pieza esté en el centro para ganar.'
            : 'No quedan movimientos. Quedaron $n fichas · Seguí intentando');

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _CartelFinUnoSolo(
              titulo: titulo,
              color: AppColors.peligro,
              subtitulo: sub,
              fichas: n,
              onVerOrden: widget.onVerOrden,
              onDeshacer: widget.onDeshacer,
              onVolverAJugar:
                  widget.mostrarVolverAJugar ? widget.onVolverAJugar : null,
              onVolver: widget.onVolver,
            ),
          ),
        ),
      ),
    );
  }
}

/// Cartel de victoria alineado al de Generala / Diez Mil.
class _WinnerCardUnoSolo extends StatelessWidget {
  const _WinnerCardUnoSolo({
    required this.ganador,
    required this.subtitulo,
    required this.pulso,
    required this.onVolver,
    this.onVerOrden,
    this.onDeshacer,
    this.onVolverAJugar,
    this.animaciones = true,
  });

  final String ganador;
  final String subtitulo;
  final AnimationController pulso;
  final VoidCallback onVolver;
  final VoidCallback? onVerOrden;
  final VoidCallback? onDeshacer;
  final VoidCallback? onVolverAJugar;
  final bool animaciones;

  @override
  Widget build(BuildContext context) {
    Widget card(double glow) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
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
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.acento, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.acento.withValues(alpha: 0.55),
              blurRadius: glow,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: AppColors.rosa.withValues(alpha: 0.35),
              blurRadius: glow * 1.2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 8),
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [Colors.white, AppColors.acento, AppColors.rosa],
              ).createShader(b),
              child: const Text(
                '¡GANADOR!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              ganador.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.acento,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: AppColors.acento.withValues(alpha: 0.8),
                    blurRadius: 16,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textoSuave,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            if (onVerOrden != null) ...[
              GlowButtonVictoria(
                label: 'VER ORDEN',
                icon: Icons.format_list_numbered_rounded,
                color: AppColors.acento,
                onPressed: onVerOrden!,
              ),
              const SizedBox(height: 10),
            ],
            if (onDeshacer != null) ...[
              GlowButtonVictoria(
                label: 'DESHACER ÚLTIMO',
                icon: Icons.undo_rounded,
                color: AppColors.rosa,
                onPressed: onDeshacer!,
              ),
              const SizedBox(height: 10),
            ],
            if (onVolverAJugar != null) ...[
              GlowButtonVictoria(
                label: 'VOLVER A JUGAR',
                icon: Icons.replay_rounded,
                color: AppColors.mint,
                onPressed: onVolverAJugar!,
              ),
              const SizedBox(height: 10),
            ],
            GlowButtonVictoria(
              label: 'VOLVER AL MENÚ',
              icon: Icons.home_rounded,
              color: AppColors.violeta,
              onPressed: onVolver,
            ),
          ],
        ),
      );
    }

    if (!animaciones) return card(20);

    return AnimatedBuilder(
      animation: pulso,
      builder: (context, _) => card(14 + pulso.value * 18),
    );
  }
}

class _CartelFinUnoSolo extends StatelessWidget {
  const _CartelFinUnoSolo({
    required this.titulo,
    required this.color,
    required this.subtitulo,
    required this.fichas,
    required this.onVolver,
    this.nombre,
    this.onVerOrden,
    this.onDeshacer,
    this.onVolverAJugar,
    this.pulso,
  });

  final String titulo;
  final Color color;
  final String subtitulo;
  final int fichas;
  final String? nombre;
  final VoidCallback? onVerOrden;
  final VoidCallback? onDeshacer;
  final VoidCallback? onVolverAJugar;
  final VoidCallback onVolver;
  final AnimationController? pulso;

  @override
  Widget build(BuildContext context) {
    Widget card(double glow) {
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3A1A1A),
              Color(0xFF1A0A0A),
              Color(0xFF281414),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.55),
              blurRadius: glow,
              spreadRadius: 2,
            ),
            ...neonGlow(color, blur: 14),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 26,
                letterSpacing: 1.0,
              ),
            ),
            if (nombre != null) ...[
              const SizedBox(height: 10),
              Text(
                nombre!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textoSuave,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Fichas restantes: $fichas',
              style: TextStyle(
                color: color.withValues(alpha: 0.95),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            if (onVerOrden != null) ...[
              GlowButtonVictoria(
                label: 'VER ORDEN',
                icon: Icons.format_list_numbered_rounded,
                color: AppColors.acento,
                onPressed: onVerOrden!,
              ),
              const SizedBox(height: 10),
            ],
            if (onDeshacer != null) ...[
              GlowButtonVictoria(
                label: 'DESHACER ÚLTIMO',
                icon: Icons.undo_rounded,
                color: AppColors.rosa,
                onPressed: onDeshacer!,
              ),
              const SizedBox(height: 10),
            ],
            if (onVolverAJugar != null) ...[
              GlowButtonVictoria(
                label: 'VOLVER A JUGAR',
                icon: Icons.replay_rounded,
                color: AppColors.mint,
                onPressed: onVolverAJugar!,
              ),
              const SizedBox(height: 10),
            ],
            GlowButtonVictoria(
              label: 'VOLVER AL MENÚ',
              icon: Icons.home_rounded,
              color: AppColors.violeta,
              onPressed: onVolver,
            ),
          ],
        ),
      );
    }

    if (pulso == null) return card(18);
    return AnimatedBuilder(
      animation: pulso!,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(pulso!.value);
        return card(14 + t * 10);
      },
    );
  }
}
