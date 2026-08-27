import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Pastilla arcade compacta (mismo look que el menú de juegos).
class HomeArcadePill extends StatelessWidget {
  const HomeArcadePill({
    super.key,
    required this.label,
    required this.icon,
    required this.colors,
    required this.glow,
    required this.foreground,
    this.width,
    this.onPressed,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final List<Color> colors;
  final Color glow;
  final Color foreground;
  final double? width;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled || loading ? 1 : 0.4,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: glow.withValues(alpha: 0.38),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: loading ? null : onPressed,
              borderRadius: BorderRadius.circular(999),
              splashColor: Colors.white24,
              highlightColor: Colors.white10,
              child: Ink(
                width: width,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: colors,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.65),
                    width: 1.4,
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  child: Row(
                    mainAxisSize:
                        width == null ? MainAxisSize.min : MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (loading)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: foreground,
                          ),
                        )
                      else
                        Icon(icon, color: foreground, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          shadows: const [
                            Shadow(color: Colors.white38, blurRadius: 3),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Misma proporción de tarjeta que el menú principal (Diez Mil).
const kAspectPortadaHome = 1448 / 1086;

/// Reserva fija del pie (título + eslogan + botones), igual que en home.
const kChromeMinPortadaHome = 218.0;

double altoTarjetaPortadaHome(
  double ancho, {
  double chromeMin = kChromeMinPortadaHome,
  double altoMax = 400,
}) {
  final alto = chromeMin + ancho / kAspectPortadaHome;
  return math.min(altoMax, math.max(260, alto));
}

/// Tarjeta con portada + pie personalizable (mismo estilo que el menú de juegos).
class JuegoPortadaCard extends StatelessWidget {
  const JuegoPortadaCard({
    super.key,
    required this.portadaAsset,
    required this.accent,
    required this.anchoFijo,
    required this.altoImg,
    required this.altoTotal,
    required this.pie,
    this.enabled = true,
    this.destacadoFuego = false,
    this.onTap,
  });

  final String portadaAsset;
  final Color accent;
  final double anchoFijo;
  final double altoImg;
  final double altoTotal;
  final Widget pie;
  final bool enabled;
  final bool destacadoFuego;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fuego = destacadoFuego;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: fuego
            ? [
                BoxShadow(
                  color: const Color(0xFFFF6D00).withValues(alpha: 0.35),
                  blurRadius: 12,
                ),
              ]
            : enabled
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.16),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
      ),
      child: SizedBox(
        width: anchoFijo,
        height: altoTotal,
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            splashColor: accent.withValues(alpha: 0.18),
            highlightColor: accent.withValues(alpha: 0.08),
            child: Ink(
            decoration: BoxDecoration(
              color: AppColors.carta.withValues(alpha: enabled ? 0.95 : 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: fuego
                      ? const Color(0xFFFF6D00)
                      : enabled
                          ? accent
                          : accent.withValues(alpha: 0.3),
                  width: fuego ? 1.6 : 1.2,
                ),
              ),
              position: DecorationPosition.foreground,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: altoImg,
                    width: anchoFijo,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(11),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: AppColors.fondo.withValues(alpha: 0.55),
                            child: Image.asset(
                              portadaAsset,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(
                                  Icons.casino_rounded,
                                  color: accent,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                          if (fuego)
                            const Positioned(
                              top: 4,
                              right: 4,
                              child: Icon(
                                Icons.local_fire_department_rounded,
                                color: Color(0xFFFF9100),
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(child: pie),
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

/// Pie estándar de tarjeta: título, eslogan opcional y botones arcade.
class JuegoPortadaCardPie extends StatelessWidget {
  const JuegoPortadaCardPie({
    super.key,
    required this.titulo,
    this.eslogan,
    required this.botones,
    this.compacto = false,
  });

  final String titulo;
  final String? eslogan;
  final Widget botones;
  /// Tarjetas angostas (celular 2 columnas): tipografía más chica.
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final estiloEslogan = TextStyle(
      color: AppColors.textoSuave.withValues(alpha: 0.98),
      fontSize: compacto ? 9.5 : 10.5,
      fontWeight: FontWeight.w600,
      height: 1.28,
      fontStyle: FontStyle.italic,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(8, compacto ? 4 : 6, 8, compacto ? 6 : 8),
      child: Column(
        children: [
          Text(
            titulo,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.texto,
              fontSize: compacto ? 13 : 15,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          if (eslogan != null) ...[
            SizedBox(height: compacto ? 4 : 6),
            Text(
              eslogan!,
              textAlign: TextAlign.center,
              maxLines: compacto ? 4 : 6,
              overflow: TextOverflow.ellipsis,
              style: estiloEslogan,
            ),
          ],
          Expanded(
            child: Center(child: botones),
          ),
        ],
      ),
    );
  }
}
