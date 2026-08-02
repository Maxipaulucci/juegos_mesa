import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/theme/victoria_celebration.dart';
import 'package:app_juegos_mesa/tutiFruti/motor_tuti_fruti.dart';

/// Cartel de victoria de Tutti Frutti (confeti + fuegos artificiales).
class VictoriaTutiFrutiOverlay extends StatefulWidget {
  const VictoriaTutiFrutiOverlay({
    super.key,
    required this.partida,
    required this.onVolver,
    this.animaciones = true,
    this.subtitulo,
  });

  final PartidaTuti partida;
  final VoidCallback onVolver;
  final bool animaciones;
  /// Si se setea, reemplaza el subtítulo por puntos (p.ej. abandono).
  final String? subtitulo;

  @override
  State<VictoriaTutiFrutiOverlay> createState() =>
      _VictoriaTutiFrutiOverlayState();
}

class _VictoriaTutiFrutiOverlayState extends State<VictoriaTutiFrutiOverlay>
    with TickerProviderStateMixin {
  static const int _cicloConfetiSegundos = 3600;

  late final AnimationController _entrada;
  late final AnimationController _pulso;
  late final AnimationController _confeti;
  late final Animation<double> _escala;
  late final Animation<double> _opacidad;

  bool _mostrarSelectorTablero = false;
  String? _jugadorTablero;
  bool _cartelVisible = true;

  List<MapEntry<String, int>> get _ranking => rankingTuti(widget.partida);

  List<String> get _ganadores {
    if (widget.partida.victoriaPorAbandono) {
      final g = widget.partida.ganadorAbandono;
      if (g != null && g.isNotEmpty) return [g];
      return widget.partida.nombresActivos;
    }
    final r = _ranking;
    if (r.isEmpty) return const [];
    final top = r.first.value;
    return r.where((e) => e.value == top).map((e) => e.key).toList();
  }

  bool get _empate =>
      !widget.partida.victoriaPorAbandono && _ganadores.length > 1;

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
    if (_jugadorTablero != null) {
      return _TableroJugadorPanel(
        partida: widget.partida,
        nombre: _jugadorTablero!,
        esGanador: _ganadores.contains(_jugadorTablero),
        onCerrar: () => setState(() => _jugadorTablero = null),
      );
    }

    if (_mostrarSelectorTablero) {
      return _SelectorJugadoresPanel(
        nombres: widget.partida.nombres,
        ganadores: _ganadores.toSet(),
        totales: widget.partida.totales,
        onSeleccionar: (n) => setState(() => _jugadorTablero = n),
        onCerrar: () => setState(() => _mostrarSelectorTablero = false),
      );
    }

    final pts = _ranking.isEmpty ? 0 : _ranking.first.value;
    final nombres = _ganadores.isEmpty
        ? '—'
        : _ganadores.map((n) => n.toUpperCase()).join('\n');
    final sub = widget.subtitulo ??
        (widget.partida.victoriaPorAbandono
            ? 'Has ganado por abandono'
            : (_empate
                ? '$pts PTS · ¡Quedaron a la par!'
                : '$pts PTS · ¡Más puntos y se lleva la partida!'));

    return _WinnerCardTuti(
      titulo: _empate ? '¡EMPATE!' : '¡GANADOR!',
      nombres: nombres,
      pulso: _pulso,
      animaciones: widget.animaciones,
      subtitulo: sub,
      onVerTablero: () => setState(() {
        _mostrarSelectorTablero = true;
        _jugadorTablero = null;
      }),
      onVolver: widget.onVolver,
    );
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
                // Fuegos por encima del cartel (siguen spawneando en los bordes).
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

class _WinnerCardTuti extends StatelessWidget {
  const _WinnerCardTuti({
    required this.titulo,
    required this.nombres,
    required this.pulso,
    required this.subtitulo,
    required this.onVerTablero,
    required this.onVolver,
    this.animaciones = true,
  });

  final String titulo;
  final String nombres;
  final AnimationController pulso;
  final String subtitulo;
  final VoidCallback onVerTablero;
  final VoidCallback onVolver;
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
            const SizedBox(height: 10),
            Text(
              nombres,
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
            GlowButtonVictoria(
              label: 'VER TABLERO',
              icon: Icons.grid_view_rounded,
              color: AppColors.azul,
              onPressed: onVerTablero,
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

class _SelectorJugadoresPanel extends StatelessWidget {
  const _SelectorJugadoresPanel({
    required this.nombres,
    required this.ganadores,
    required this.totales,
    required this.onSeleccionar,
    required this.onCerrar,
  });

  final List<String> nombres;
  final Set<String> ganadores;
  final Map<String, int> totales;
  final ValueChanged<String> onSeleccionar;
  final VoidCallback onCerrar;

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
              IconButton(
                onPressed: onCerrar,
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back, color: AppColors.texto),
              ),
              const Expanded(
                child: Text(
                  'VER TABLERO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: AppColors.acento,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const Text(
            'Elegí un jugador',
            style: TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: nombres.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final n = nombres[i];
                final esGanador = ganadores.contains(n);
                final pts = totales[n] ?? 0;
                return GlowButtonVictoria(
                  label: '${n.toUpperCase()}  ·  $pts PTS',
                  icon: esGanador ? Icons.emoji_events : Icons.person,
                  color: esGanador ? AppColors.acento : AppColors.azul,
                  onPressed: () => onSeleccionar(n),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TableroJugadorPanel extends StatelessWidget {
  const _TableroJugadorPanel({
    required this.partida,
    required this.nombre,
    required this.esGanador,
    required this.onCerrar,
  });

  final PartidaTuti partida;
  final String nombre;
  final bool esGanador;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final historial = [...partida.historial]
      ..sort((a, b) => a.ronda.compareTo(b.ronda));
    final total = partida.totales[nombre] ?? 0;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1450), Color(0xFF12081F)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.acento, width: 2),
        boxShadow: neonGlow(AppColors.acento, blur: 18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onCerrar,
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back, color: AppColors.texto),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      nombre.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.acento,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (esGanador)
                      const Text(
                        'GANADOR',
                        style: TextStyle(
                          color: AppColors.mint,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          Text(
            'TOTAL: $total PTS',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: historial.isEmpty
                ? const Center(
                    child: Text(
                      'Sin rondas registradas',
                      style: TextStyle(color: AppColors.textoSuave),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(right: 4, bottom: 4),
                    itemCount: historial.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final r = historial[i];
                      final respuestas =
                          r.respuestas[nombre] ?? const <String>[];
                      final puntajes = r.puntajes[nombre] ?? const <int>[];
                      final ptsRonda = r.puntosRonda[nombre] ?? 0;
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.azul.withValues(alpha: 0.55),
                          ),
                          color: AppColors.carta.withValues(alpha: 0.35),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'RONDA ${r.ronda} · Letra ${r.letra}',
                                      style: const TextStyle(
                                        color: AppColors.rosa,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '+$ptsRonda',
                                    style: const TextStyle(
                                      color: AppColors.mint,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              for (var c = 0;
                                  c < partida.categorias.length;
                                  c++) ...[
                                if (c > 0) const SizedBox(height: 8),
                                _FilaCategoriaTablero(
                                  categoria: partida.categorias[c],
                                  respuesta: c < respuestas.length
                                      ? respuestas[c]
                                      : '',
                                  puntos: c < puntajes.length
                                      ? puntajes[c]
                                      : 0,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilaCategoriaTablero extends StatelessWidget {
  const _FilaCategoriaTablero({
    required this.categoria,
    required this.respuesta,
    required this.puntos,
  });

  final String categoria;
  final String respuesta;
  final int puntos;

  @override
  Widget build(BuildContext context) {
    final vacia = respuesta.trim().isEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                categoria,
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                vacia ? '(vacío)' : respuesta,
                style: TextStyle(
                  color: vacia ? AppColors.textoSuave : AppColors.texto,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  fontStyle: vacia ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$puntos',
          style: TextStyle(
            color: puntos > 0 ? AppColors.acento : AppColors.peligro,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}
