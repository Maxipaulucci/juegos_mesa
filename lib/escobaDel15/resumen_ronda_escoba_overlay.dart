import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/escobaDel15/marcador_palitos.dart';
import 'package:app_juegos_mesa/escobaDel15/motor_escoba.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/theme/victoria_celebration.dart';

/// Cartel de fin de ronda: jugadores expandibles con sus estadísticas.
class ResumenRondaEscobaOverlay extends StatefulWidget {
  const ResumenRondaEscobaOverlay({
    super.key,
    required this.resultado,
    required this.onContinuar,
    this.esFinPartida = false,
    this.labelContinuar,
    this.continuarHabilitado = true,
  });

  final ResultadoRondaEscoba resultado;
  final VoidCallback onContinuar;
  final bool esFinPartida;
  final String? labelContinuar;
  final bool continuarHabilitado;

  @override
  State<ResumenRondaEscobaOverlay> createState() =>
      _ResumenRondaEscobaOverlayState();
}

class _ResumenRondaEscobaOverlayState extends State<ResumenRondaEscobaOverlay> {
  final Set<int> _expandidos = {};

  Color _colorJugador(int i) => switch (i % 4) {
        0 => AppColors.mint,
        1 => AppColors.azul,
        2 => AppColors.rosa,
        _ => AppColors.acento,
      };

  int _puntosEstaRonda(int i) {
    final r = widget.resultado;
    var p = r.puntosEscobas[i];
    if (r.idxMasCartas == i) p++;
    if (r.idxMasOros == i) p++;
    if (r.idxSieteOro == i) p++;
    if (r.idxMasSietes == i) p++;
    return p;
  }

  List<String> _premiosDeLaRonda() {
    final r = widget.resultado;
    final lineas = <String>[];
    if (r.idxMasCartas != null) {
      lineas.add('Más cartas: ${r.detalles[r.idxMasCartas!].nombre} (+1)');
    } else if (r.empateMasCartas) {
      lineas.add('Más cartas: empate · nadie suma');
    }
    if (r.idxMasOros != null) {
      lineas.add('Más oros: ${r.detalles[r.idxMasOros!].nombre} (+1)');
    } else if (r.empateMasOros) {
      lineas.add('Más oros: empate · nadie suma');
    }
    if (r.idxSieteOro != null) {
      lineas.add('7 de oro: ${r.detalles[r.idxSieteOro!].nombre} (+1)');
    }
    if (r.idxMasSietes != null) {
      final porDesempate = r.desempateSietesLineas.isNotEmpty;
      lineas.add(
        porDesempate
            ? 'Más sietes: ${r.detalles[r.idxMasSietes!].nombre} (+1, por desempate)'
            : 'Más sietes: ${r.detalles[r.idxMasSietes!].nombre} (+1)',
      );
    } else if (r.empateMasSietes) {
      lineas.add('Más sietes: empate · nadie suma');
    }
    for (final d in r.desempateSietesLineas) {
      lineas.add('Desempate sietes · $d');
    }
    for (var i = 0; i < r.puntosEscobas.length; i++) {
      if (r.puntosEscobas[i] > 0) {
        lineas.add(
          'Escobas de ${r.detalles[i].nombre}: +${r.puntosEscobas[i]}',
        );
      }
    }
    return lineas;
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    final resultado = widget.resultado;
    final hayExpandido = _expandidos.isNotEmpty;

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
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        scrollbars: hayExpandido,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        physics: hayExpandido
                            ? const ClampingScrollPhysics()
                            : const NeverScrollableScrollPhysics(),
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
                                puntosEstaRonda: _puntosEstaRonda(i),
                                expandido: _expandidos.contains(i),
                                onTap: () => setState(() {
                                  if (!_expandidos.remove(i)) {
                                    _expandidos.add(i);
                                  }
                                }),
                                ganoMasCartas: resultado.idxMasCartas == i,
                                ganoMasOros: resultado.idxMasOros == i,
                                ganoSieteOro: resultado.idxSieteOro == i,
                                ganoMasSietes: resultado.idxMasSietes == i,
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
                    child: Opacity(
                      opacity: widget.continuarHabilitado ? 1 : 0.55,
                      child: IgnorePointer(
                        ignoring: !widget.continuarHabilitado,
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
            spreadRadius: 0,
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
    required this.puntosEstaRonda,
    required this.expandido,
    required this.onTap,
    required this.ganoMasCartas,
    required this.ganoMasOros,
    required this.ganoSieteOro,
    required this.ganoMasSietes,
  });

  final DetalleJugadorRondaEscoba detalle;
  final Color color;
  final int puntosEstaRonda;
  final bool expandido;
  final VoidCallback onTap;
  final bool ganoMasCartas;
  final bool ganoMasOros;
  final bool ganoSieteOro;
  final bool ganoMasSietes;

  @override
  Widget build(BuildContext context) {
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
                                  color: puntosEstaRonda > 0
                                      ? AppColors.mint.withValues(alpha: 0.22)
                                      : Colors.black.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  puntosEstaRonda > 0
                                      ? '+$puntosEstaRonda esta ronda'
                                      : '0 esta ronda',
                                  style: TextStyle(
                                    color: puntosEstaRonda > 0
                                        ? AppColors.mint
                                        : AppColors.textoSuave,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              MarcadorPalitosEscoba(
                                puntos: detalle.puntosTrasRonda,
                                color: color,
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
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onTap,
                                borderRadius: BorderRadius.circular(999),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.28),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.arrow_back_rounded,
                                        color: color,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Volver',
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _MiniStat(
                            icon: Icons.auto_awesome_rounded,
                            iconColor: AppColors.acento,
                            titulo: 'Escobas',
                            valor: '${detalle.escobas}',
                            detalle: detalle.escobas == 0
                                ? 'Sin escobas esta ronda'
                                : '+${detalle.escobas} punto${detalle.escobas == 1 ? '' : 's'}',
                            destacado: detalle.escobas > 0,
                          ),
                          const SizedBox(height: 8),
                          _MiniStat(
                            icon: Icons.style_rounded,
                            iconColor: AppColors.azul,
                            titulo: 'Cartas juntadas',
                            valor: '${detalle.cantidadCartas}',
                            detalle: detalle.cartas.isEmpty
                                ? 'Ninguna'
                                : detalle.cartas
                                    .map((c) => c.etiqueta)
                                    .join(' · '),
                            destacado: ganoMasCartas,
                            badge: ganoMasCartas ? '¡Más cartas! +1' : null,
                          ),
                          const SizedBox(height: 8),
                          _MiniStat(
                            icon: Icons.monetization_on_rounded,
                            iconColor: const Color(0xFFFFC107),
                            titulo: 'Oros',
                            valor: '${detalle.cantidadOros}',
                            detalle: detalle.oros.isEmpty
                                ? 'Sin oros'
                                : detalle.oros
                                    .map((c) => c.etiqueta)
                                    .join(' · '),
                            destacado: ganoMasOros,
                            badge: ganoMasOros ? '¡Más oros! +1' : null,
                          ),
                          const SizedBox(height: 8),
                          _MiniStat(
                            icon: Icons.filter_7_rounded,
                            iconColor: AppColors.mint,
                            titulo: 'Sietes',
                            valor: '${detalle.cantidadSietes}',
                            detalle: detalle.sietes.isEmpty
                                ? 'Sin sietes'
                                : detalle.sietes
                                    .map((c) => c.etiqueta)
                                    .join(' · '),
                            destacado: ganoMasSietes,
                            badge: ganoMasSietes ? '¡Más sietes! +1' : null,
                          ),
                          const SizedBox(height: 8),
                          _MiniStat(
                            icon: Icons.workspace_premium_rounded,
                            iconColor: const Color(0xFFFFD54F),
                            titulo: '7 de oro',
                            valor: ganoSieteOro ? '1' : '0',
                            detalle: ganoSieteOro || detalle.tieneSieteOro
                                ? '7 de oro'
                                : 'No lo juntó esta ronda',
                            destacado: ganoSieteOro,
                            badge: ganoSieteOro ? '¡Se lo llevó! +1' : null,
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
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
    this.destacado = false,
    this.badge,
  });

  final IconData icon;
  final Color iconColor;
  final String titulo;
  final String valor;
  final String detalle;
  final bool destacado;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: destacado
            ? AppColors.mint.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: destacado
              ? AppColors.mint.withValues(alpha: 0.55)
              : AppColors.textoSuave.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: iconColor.withValues(alpha: 0.55)),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        titulo,
                        style: const TextStyle(
                          color: AppColors.texto,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      valor,
                      style: TextStyle(
                        color: destacado ? AppColors.mint : AppColors.acento,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    if (destacado)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.star_rounded,
                          color: AppColors.mint,
                          size: 16,
                        ),
                      ),
                  ],
                ),
                if (badge != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    badge!,
                    style: TextStyle(
                      color: destacado ? AppColors.mint : AppColors.rosa,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  detalle,
                  softWrap: true,
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    height: 1.25,
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
