import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/laPapa/motor_la_papa.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/theme/victoria_celebration.dart';

/// Cartel de victoria / fin de La Papa (mismo estilo que Generala / Diez Mil).
class VictoriaLaPapaOverlay extends StatefulWidget {
  const VictoriaLaPapaOverlay({
    super.key,
    required this.partida,
    required this.onVolverAJugar,
    required this.onVolver,
    this.ganador,
    this.subtitulo,
    this.animaciones = true,
    this.esSolo = false,
  });

  final PartidaPapa partida;
  final String? ganador;
  final String? subtitulo;
  final VoidCallback onVolverAJugar;
  final VoidCallback onVolver;
  final bool animaciones;
  /// Modo un solo jugador: cartel de fin distinto al de victoria multi.
  final bool esSolo;

  @override
  State<VictoriaLaPapaOverlay> createState() => _VictoriaLaPapaOverlayState();
}

class _VictoriaLaPapaOverlayState extends State<VictoriaLaPapaOverlay>
    with TickerProviderStateMixin {
  static const int _cicloConfetiSegundos = 3600;

  late final AnimationController _entrada;
  late final AnimationController _pulso;
  late final AnimationController _confeti;
  late final Animation<double> _escala;
  late final Animation<double> _opacidad;

  bool _mostrarStats = false;
  String? _statsJugador;
  bool _cartelVisible = true;

  @override
  void initState() {
    super.initState();
    final conAnim = widget.animaciones;

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

  Widget _construirContenido() {
    if (!_mostrarStats) {
      final maxN = widget.partida.maxNumero;
      final completo = widget.partida.fase == FasePapa.ganado;
      // Último número alcanzado (en derrota: el de origen del intento fallido).
      final hasta = completo ? maxN : widget.partida.siguienteConectar;

      final String titulo;
      final String? nombre;
      final String subtitulo;

      if (widget.esSolo) {
        if (completo) {
          titulo = '¡GANADOR!';
          nombre = _ganadorMostrado;
          subtitulo = '¡Felicidades! Completaste los $maxN números.';
        } else {
          titulo = 'Fin';
          nombre = null;
          subtitulo =
              'Felicidades, llegaste hasta el número $hasta de $maxN.';
        }
      } else {
        titulo = '¡GANADOR!';
        nombre = _ganadorMostrado;
        subtitulo = widget.subtitulo ??
            'Completó la hoja y se lleva la partida';
      }

      return _WinnerCardPapa(
        titulo: titulo,
        ganador: nombre,
        pulso: _pulso,
        animaciones: widget.animaciones,
        subtitulo: subtitulo,
        onEstadisticas: () => setState(() {
          _mostrarStats = true;
          _statsJugador = null;
        }),
        onVolverAJugar: widget.onVolverAJugar,
        onVolver: widget.onVolver,
      );
    }

    if (_statsJugador == null) {
      return _StatsSelectorPapa(
        jugadores: widget.partida.nombres,
        ganador: widget.ganador ?? _ganadorMostrado,
        onSeleccionar: (nombre) => setState(() => _statsJugador = nombre),
        onCerrar: () => setState(() => _mostrarStats = false),
        onVolver: widget.onVolver,
      );
    }

    return _StatsBoardPanel(
      partida: widget.partida,
      jugador: _statsJugador!,
      ganador: widget.ganador ?? _ganadorMostrado,
      onCerrar: () => setState(() => _statsJugador = null),
      onVolver: widget.onVolver,
    );
  }

  /// Nombre a mostrar en el cartel (siempre hay un ganador en multi).
  String get _ganadorMostrado {
    final g = widget.ganador?.trim();
    if (g != null && g.isNotEmpty) return g;
    final nombres = widget.partida.nombres;
    if (nombres.length == 1) return nombres.first;
    return nombres.isNotEmpty ? nombres.first : 'Jugador';
  }

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
                              child: _construirContenido(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
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
                onTap: () => setState(
                  () => _cartelVisible = !_cartelVisible,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WinnerCardPapa extends StatelessWidget {
  const _WinnerCardPapa({
    required this.titulo,
    required this.pulso,
    required this.onEstadisticas,
    required this.onVolverAJugar,
    required this.onVolver,
    required this.subtitulo,
    this.ganador,
    this.animaciones = true,
  });

  final String titulo;
  final String? ganador;
  final AnimationController pulso;
  final VoidCallback onEstadisticas;
  final VoidCallback onVolverAJugar;
  final VoidCallback onVolver;
  final String subtitulo;
  final bool animaciones;

  @override
  Widget build(BuildContext context) {
    final esFin = titulo == 'Fin';

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
          border: Border.all(
            color: esFin ? AppColors.mint : AppColors.acento,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (esFin ? AppColors.mint : AppColors.acento)
                  .withValues(alpha: 0.55),
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
            Text(esFin ? '🏁' : '🏆', style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 8),
            ShaderMask(
              shaderCallback: (b) => LinearGradient(
                colors: esFin
                    ? const [Colors.white, AppColors.mint, AppColors.azul]
                    : const [Colors.white, AppColors.acento, AppColors.rosa],
              ).createShader(b),
              child: Text(
                titulo,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            if (ganador != null && ganador!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                ganador!.toUpperCase(),
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
            ],
            const SizedBox(height: 10),
            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textoSuave,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            GlowButtonVictoria(
              label: 'ESTADÍSTICAS',
              icon: Icons.bar_chart_rounded,
              color: AppColors.azul,
              onPressed: onEstadisticas,
            ),
            const SizedBox(height: 10),
            GlowButtonVictoria(
              label: 'VOLVER A JUGAR',
              icon: Icons.replay_rounded,
              color: AppColors.mint,
              onPressed: onVolverAJugar,
            ),
            const SizedBox(height: 10),
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

class _StatsSelectorPapa extends StatelessWidget {
  const _StatsSelectorPapa({
    required this.jugadores,
    required this.ganador,
    required this.onSeleccionar,
    required this.onCerrar,
    required this.onVolver,
  });

  final List<String> jugadores;
  final String? ganador;
  final ValueChanged<String> onSeleccionar;
  final VoidCallback onCerrar;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1450), Color(0xFF12081F)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.azul, width: 2),
        boxShadow: neonGlow(AppColors.azul, blur: 18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ESTADÍSTICAS',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: AppColors.acento,
                  ),
                ),
              ),
              IconButton(
                onPressed: onCerrar,
                icon: const Icon(Icons.close, color: AppColors.texto),
              ),
            ],
          ),
          const Text(
            'Elegí un jugador',
            style: TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < jugadores.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    GlowButtonVictoria(
                      label: jugadores[i].toUpperCase(),
                      icon: jugadores[i] == ganador
                          ? Icons.emoji_events
                          : Icons.person,
                      color: jugadores[i] == ganador
                          ? AppColors.acento
                          : AppColors.azul,
                      onPressed: () => onSeleccionar(jugadores[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
}

class _StatsBoardPanel extends StatelessWidget {
  const _StatsBoardPanel({
    required this.partida,
    required this.jugador,
    required this.ganador,
    required this.onCerrar,
    required this.onVolver,
  });

  final PartidaPapa partida;
  final String jugador;
  final String? ganador;
  final VoidCallback onCerrar;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    final esGanador = jugador == ganador;
    final accent = esGanador ? AppColors.acento : AppColors.azul;
    final numeros = numerosConectadosPorPapa(partida, jugador);
    final trazos = trazosDeJugadorPapa(partida, jugador);
    final conexiones = trazos.length;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1450), Color(0xFF12081F)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent, width: 2),
        boxShadow: neonGlow(accent, blur: 18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onCerrar,
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back, color: AppColors.texto),
              ),
              Expanded(
                child: Text(
                  jugador.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          Text(
            esGanador ? '★ Ganador ★' : 'Números que conectó',
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$conexiones ${conexiones == 1 ? 'conexión' : 'conexiones'} · '
            '${numeros.length} número${numeros.length == 1 ? '' : 's'}',
            style: TextStyle(
              color: accent.withValues(alpha: 0.95),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: Center(
              child: AspectRatio(
                aspectRatio: columnasPapa / filasPapa,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.mint, width: 2),
                    boxShadow: neonGlow(AppColors.mint, blur: 12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CustomPaint(
                      painter: _HojaStatsPapaPainter(
                        partida: partida,
                        numerosVisibles: numeros,
                        trazos: trazos,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
}

/// Mini hoja: grilla + números del jugador y conexiones entre centros de casilla.
class _HojaStatsPapaPainter extends CustomPainter {
  _HojaStatsPapaPainter({
    required this.partida,
    required this.numerosVisibles,
    required this.trazos,
  });

  final PartidaPapa partida;
  final Set<int> numerosVisibles;
  final List<TrazoPapa> trazos;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / columnasPapa;
    final cellH = size.height / filasPapa;

    final gridPaint = Paint()
      ..color = const Color(0xFF2A1450).withValues(alpha: 0.55)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var c = 0; c <= columnasPapa; c++) {
      final x = c * cellW;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var r = 0; r <= filasPapa; r++) {
      final y = r * cellH;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final strokePaint = Paint()
      ..color = const Color(0xFF1A0A33)
      ..strokeWidth = math.max(2.2, math.min(cellW, cellH) * 0.09)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final t in trazos) {
      final iDe = partida.indiceDeNumero(t.de);
      final iA = partida.indiceDeNumero(t.a);
      if (iDe == null || iA == null) continue;
      final desde = centroCasillaPapa(iDe, size);
      final hasta = centroCasillaPapa(iA, size);
      final pts = _trazoAlineadoACentros(t.puntos, desde, hasta);
      _dibujarPolyline(canvas, pts, strokePaint);
    }

    for (var i = 0; i < partida.casillas.length; i++) {
      final n = partida.casillas[i];
      if (n == null || !numerosVisibles.contains(n)) continue;
      final c = centroCasillaPapa(i, size);
      final fontSize = math.min(cellW, cellH) * 0.24;
      final tp = TextPainter(
        text: TextSpan(
          text: '$n',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final padX = math.max(4.0, fontSize * 0.35);
      final padY = math.max(2.5, fontSize * 0.2);
      final chip = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c,
          width: tp.width + padX * 2,
          height: tp.height + padY * 2,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(
        chip,
        Paint()
          ..color = const Color(0xFF0A0614)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        chip,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  /// Adapta el trazo libre para que empiece en [desde] y termine en [hasta].
  List<Offset> _trazoAlineadoACentros(
    List<Offset> originales,
    Offset desde,
    Offset hasta,
  ) {
    if (originales.length < 2) return [desde, hasta];

    final o0 = originales.first;
    final o1 = originales.last;
    final ox = o1.dx - o0.dx;
    final oy = o1.dy - o0.dy;
    final nx = hasta.dx - desde.dx;
    final ny = hasta.dy - desde.dy;
    final olen2 = ox * ox + oy * oy;
    if (olen2 < 1e-6) return [desde, hasta];

    final oLen = math.sqrt(olen2);
    final nLen = math.sqrt(nx * nx + ny * ny);
    if (nLen < 1e-6) return [desde, hasta];

    final scale = nLen / oLen;
    final rot = math.atan2(ny, nx) - math.atan2(oy, ox);
    final cosR = math.cos(rot);
    final sinR = math.sin(rot);

    final out = <Offset>[];
    for (final p in originales) {
      final dx = p.dx - o0.dx;
      final dy = p.dy - o0.dy;
      final rx = (dx * cosR - dy * sinR) * scale;
      final ry = (dx * sinR + dy * cosR) * scale;
      out.add(Offset(desde.dx + rx, desde.dy + ry));
    }
    return out;
  }

  void _dibujarPolyline(Canvas canvas, List<Offset> pts, Paint paint) {
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HojaStatsPapaPainter oldDelegate) => true;
}

