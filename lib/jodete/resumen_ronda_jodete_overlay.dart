import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/escobaDel15/marcador_palitos.dart';
import 'package:app_juegos_mesa/jodete/motor_jodete.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/theme/victoria_celebration.dart';

/// Cartel de fin de ronda (mismo estilo que Escoba del 15).
class ResumenRondaJodeteOverlay extends StatefulWidget {
  const ResumenRondaJodeteOverlay({
    super.key,
    required this.resultado,
    required this.onContinuar,
    this.esFinPartida = false,
    this.labelContinuar,
    this.objetivo = 30,
  });

  final ResultadoRondaJodete resultado;
  final VoidCallback onContinuar;
  final bool esFinPartida;
  final String? labelContinuar;
  final int objetivo;

  @override
  State<ResumenRondaJodeteOverlay> createState() =>
      _ResumenRondaJodeteOverlayState();
}

class _ResumenRondaJodeteOverlayState extends State<ResumenRondaJodeteOverlay> {
  final Set<int> _expandidos = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _colorJugador(int i) => switch (i % 4) {
        0 => AppColors.mint,
        1 => AppColors.azul,
        2 => AppColors.rosa,
        _ => AppColors.acento,
      };

  String _ordinal(int puesto) => switch (puesto) {
        1 => '1º',
        2 => '2º',
        3 => '3º',
        4 => '4º',
        _ => '$puestoº',
      };

  List<String> _premiosDeLaRonda() {
    return [
      for (final d in widget.resultado.detalles)
        if (d.puntosGanados > 0 || d.puesto == 1)
          '${_ordinal(d.puesto)} ${d.nombre}: '
              '${d.puntosGanados > 0 ? '+${d.puntosGanados}' : '0'}'
              '${d.detallePuntos != null ? ' (${d.detallePuntos})' : ''}'
        else
          '${_ordinal(d.puesto)} ${d.nombre}: 0',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    final resultado = widget.resultado;

    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 440, maxHeight: maxH),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2E1A5C),
                    Color(0xFF1A0F35),
                    Color(0xFF0E1F3A),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.acento, width: 2.5),
                boxShadow: [
                  ...neonGlow(AppColors.acento, blur: 22),
                  ...neonGlow(AppColors.azul, blur: 14),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25.5),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    const Text('🌟', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 4),
                    const Text(
                      '¡FIN DE RONDA!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.acento,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Tocá un jugador para ver sus estadísticas',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textoSuave,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.vertical,
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0;
                                  i < resultado.detalles.length;
                                  i++) ...[
                                if (i > 0) const SizedBox(height: 10),
                                _BotonJugadorExpandible(
                                  detalle: resultado.detalles[i],
                                  color: _colorJugador(i),
                                  expandido: _expandidos.contains(i),
                                  onTap: () => setState(() {
                                    if (!_expandidos.remove(i)) {
                                      _expandidos.add(i);
                                    }
                                  }),
                                  ordinal: _ordinal(resultado.detalles[i].puesto),
                                  objetivo: widget.objetivo,
                                ),
                              ],
                              const SizedBox(height: 14),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(2, 2, 2, 10),
                                child: _CartelPremiosRonda(
                                  premios: _premiosDeLaRonda(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: GlowButtonVictoria(
                        label: widget.labelContinuar ??
                            (widget.esFinPartida
                                ? 'VER GANADOR'
                                : 'SIGUIENTE RONDA'),
                        icon: widget.esFinPartida &&
                                widget.labelContinuar == null
                            ? Icons.emoji_events_rounded
                            : Icons.play_arrow_rounded,
                        color: widget.esFinPartida &&
                                widget.labelContinuar == null
                            ? AppColors.acento
                            : AppColors.mint,
                        onPressed: widget.onContinuar,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartelPremiosRonda extends StatelessWidget {
  const _CartelPremiosRonda({required this.premios});

  final List<String> premios;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.rosa.withValues(alpha: 0.85),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.rosa.withValues(alpha: 0.35),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🏆 Premios de la ronda',
            style: TextStyle(
              color: AppColors.rosa,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          if (premios.isEmpty)
            const Text(
              'Sin premios esta ronda.',
              style: TextStyle(
                color: AppColors.textoSuave,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            )
          else
            for (final p in premios)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '· $p',
                  softWrap: true,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _BotonJugadorExpandible extends StatelessWidget {
  const _BotonJugadorExpandible({
    required this.detalle,
    required this.color,
    required this.expandido,
    required this.onTap,
    required this.ordinal,
    this.objetivo = 30,
  });

  final DetalleJugadorRondaJodete detalle;
  final Color color;
  final bool expandido;
  final VoidCallback onTap;
  final String ordinal;
  final int objetivo;

  @override
  Widget build(BuildContext context) {
    final ptsRonda = detalle.puntosGanados;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.carta.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
        boxShadow: neonGlow(color, blur: expandido ? 14 : 8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detalle.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: ptsRonda > 0
                                      ? AppColors.mint.withValues(alpha: 0.22)
                                      : Colors.black.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  ptsRonda > 0
                                      ? '+$ptsRonda esta ronda'
                                      : '0 esta ronda',
                                  style: TextStyle(
                                    color: ptsRonda > 0
                                        ? AppColors.mint
                                        : AppColors.textoSuave,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              MarcadorPalitosEscoba(
                                puntos: detalle.puntosTrasRonda,
                                color: objetivo == 30 ? Colors.white : color,
                                colorDesdeUmbral:
                                    objetivo == 30 ? AppColors.azul : null,
                                umbralColor: objetivo == 30 ? 15 : null,
                                tamanoGrupo: 18,
                              ),
                              Text(
                                '${detalle.puntosTrasRonda} pts',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expandido ? 0.5 : 0,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeInOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: color,
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: expandido
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(color: AppColors.textoSuave, height: 1),
                          const SizedBox(height: 10),
                          _MiniStat(
                            icon: Icons.emoji_events_rounded,
                            iconColor: AppColors.acento,
                            titulo: 'Puesto',
                            valor: ordinal,
                            detalle: detalle.detallePuntos ??
                                (ptsRonda > 0
                                    ? '+$ptsRonda punto${ptsRonda == 1 ? '' : 's'}'
                                    : 'Sin puntos esta ronda'),
                            destacado: ptsRonda > 0,
                          ),
                          const SizedBox(height: 8),
                          _MiniStat(
                            icon: Icons.scoreboard_rounded,
                            iconColor: AppColors.mint,
                            titulo: 'Total',
                            valor: '${detalle.puntosTrasRonda}',
                            detalle: 'puntos en la partida',
                            destacado: true,
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.iconColor,
    required this.titulo,
    required this.valor,
    required this.detalle,
    required this.destacado,
  });

  final IconData icon;
  final Color iconColor;
  final String titulo;
  final String valor;
  final String detalle;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: destacado
              ? iconColor.withValues(alpha: 0.7)
              : AppColors.cartaBorde,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                Text(
                  valor,
                  style: TextStyle(
                    color: destacado ? iconColor : AppColors.texto,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                Text(
                  detalle,
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
