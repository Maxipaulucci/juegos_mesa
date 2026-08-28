import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/shared/formato/numero_formato.dart';
import 'package:app_juegos_mesa/shared/monedas/cartel_como_ganar_monedas.dart';
import 'package:app_juegos_mesa/shared/monedas/monedas_store.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Burbuja de monedas (esquina inferior derecha, encima de la nav).
class MonedasBubble extends StatefulWidget {
  const MonedasBubble({super.key});

  @override
  State<MonedasBubble> createState() => _MonedasBubbleState();
}

class _MonedasBubbleState extends State<MonedasBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const _radio = BorderRadius.all(Radius.circular(999));
  static const _duracionBarrido = Duration(milliseconds: 3800);
  static const _pausaReflejo = Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: _duracionBarrido + _pausaReflejo,
    )..repeat();
  }

  /// 0→1 durante el barrido; -1 en la pausa (reflejo oculto).
  double _progresoReflejo(double raw) {
    final totalMs =
        (_duracionBarrido + _pausaReflejo).inMilliseconds.toDouble();
    final finBarrido = _duracionBarrido.inMilliseconds / totalMs;
    if (raw >= finBarrido) return -1;
    return Curves.easeInOut.transform(raw / finBarrido);
  }

  double _pulsoSuave() {
    final ms = _ctrl.lastElapsedDuration?.inMilliseconds ?? 0;
    return 0.5 + 0.5 * math.sin(ms / 1400 * math.pi);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MonedasStore.instance,
      builder: (context, _) {
        if (!MonedasStore.instance.visible) {
          return const SizedBox.shrink();
        }
        final n = MonedasStore.instance.monedas;

        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value;
            final reflejo = _progresoReflejo(t);
            final reflejoVisible = reflejo >= 0;
            final reflejoT = reflejoVisible ? reflejo : 0.0;
            final reflejoFuerza = reflejoVisible ? 1.0 : 0.0;
            final pulso = _pulsoSuave();
            final borde = Color.lerp(
              AppColors.acento.withValues(alpha: 0.82),
              const Color(0xFFFFF8E1),
              0.28 + 0.42 * pulso,
            )!;
            final iconoColor = Color.lerp(
              AppColors.acento,
              const Color(0xFFFFF8E1),
              0.2 + 0.25 * pulso,
            );
            final fondoBrillo = Color.lerp(
              AppColors.carta,
              AppColors.acento.withValues(alpha: 0.24),
              0.32 + 0.38 * pulso,
            )!;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => mostrarCartelComoGanarMonedas(context),
                borderRadius: _radio,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: _radio,
                    border: Border.all(color: borde, width: 1.8),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.acento.withValues(alpha: 0.18 * pulso),
                        blurRadius: 12 + 8 * pulso,
                        spreadRadius: 0.4 * pulso,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: _radio,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(
                                  -0.9 + 0.25 * pulso,
                                  -1,
                                ),
                                end: Alignment(
                                  1,
                                  0.85 - 0.2 * pulso,
                                ),
                                colors: [
                                  AppColors.carta,
                                  fondoBrillo,
                                  AppColors.carta,
                                ],
                                stops: [
                                  0,
                                  0.42 + 0.18 * pulso,
                                  1,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(
                                    -1.35 + reflejoT * 2.7,
                                    -0.35,
                                  ),
                                  end: Alignment(
                                    -0.15 + reflejoT * 2.7,
                                    0.35,
                                  ),
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(
                                      alpha: 0.18 * pulso * reflejoFuerza,
                                    ),
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.38, 0.5, 0.62, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Align(
                              alignment: Alignment(-1.15 + reflejoT * 2.3, 0),
                              child: FractionallySizedBox(
                                widthFactor: 0.34,
                                heightFactor: 1,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.transparent,
                                        Colors.white.withValues(
                                          alpha: 0.1 * pulso * reflejoFuerza,
                                        ),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.monetization_on_rounded,
                                color: iconoColor,
                                size: 22,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                formatoNumero(n),
                                style: const TextStyle(
                                  color: AppColors.texto,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
