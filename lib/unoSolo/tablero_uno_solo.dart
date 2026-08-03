import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/unoSolo/motor_uno_solo.dart';

/// Tablero estilo juguete Ruibal: naranja translúcido + fichas amarillas.
class TableroUnoSolo extends StatelessWidget {
  const TableroUnoSolo({
    super.key,
    required this.partida,
    required this.seleccion,
    required this.destinos,
    required this.medios,
    required this.onTap,
    this.ordenEliminacion,
    this.mostrarOrdenEnVacias = false,
    this.proximoDesde,
    this.proximoMedio,
  });

  final PartidaUnoSolo partida;
  final int? seleccion;
  final Set<int> destinos;
  final Set<int> medios;
  final ValueChanged<int>? onTap;
  /// Casilla → texto del orden (p. ej. "3" o "3·18").
  final Map<int, String>? ordenEliminacion;
  /// Si true, muestra el orden en vacías y ocupadas (repaso tras la partida).
  /// Si false, solo sobre fichas (modo dios / tutorial).
  final bool mostrarOrdenEnVacias;
  final int? proximoDesde;
  /// Ficha a comer del próximo salto de la guía (modo dios).
  final int? proximoMedio;

  static const _naranjaClaro = Color(0xFFFFB74D);
  static const _naranja = Color(0xFFFF9800);
  static const _naranjaFuerte = Color(0xFFEF6C00);
  static const _naranjaOscuro = Color(0xFFE65100);
  static const _ambarHueco = Color(0xFFBF360C);
  static const _amarilloClaro = Color(0xFFFFF59D);
  static const _amarillo = Color(0xFFFFEB3B);
  static const _amarilloFuerte = Color(0xFFFBC02D);
  static const _amarilloBorde = Color(0xFFF57F17);

  /// Fichas iniciales del solitario inglés (cruz 33 huecos, 1 vacío).
  static const _fichasIniciales = 32;

  @override
  Widget build(BuildContext context) {
    final eliminadas =
        (_fichasIniciales - partida.fichasRestantes).clamp(0, _fichasIniciales);
    final porBandeja = List<int>.filled(4, eliminadas ~/ 4);
    for (var i = 0; i < eliminadas % 4; i++) {
      porBandeja[i]++;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFCC80),
            _naranja,
            _naranjaFuerte,
            _naranjaOscuro,
          ],
          stops: [0.0, 0.35, 0.7, 1.0],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFFFE0B2), width: 2.8),
        boxShadow: [
          BoxShadow(
            color: _naranja.withValues(alpha: 0.45),
            blurRadius: 22,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = math.min(constraints.maxWidth, constraints.maxHeight);
            final cell = side / PartidaUnoSolo.columnas;
            return SizedBox(
              width: side,
              height: side,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    width: cell * 2,
                    height: cell * 2,
                    child: _BandejaEsquina(fichas: porBandeja[0]),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    width: cell * 2,
                    height: cell * 2,
                    child: _BandejaEsquina(fichas: porBandeja[1]),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    width: cell * 2,
                    height: cell * 2,
                    child: _BandejaEsquina(fichas: porBandeja[2]),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    width: cell * 2,
                    height: cell * 2,
                    child: _BandejaEsquina(fichas: porBandeja[3]),
                  ),
                  GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: PartidaUnoSolo.columnas,
                    ),
                    itemCount: PartidaUnoSolo.total,
                    itemBuilder: (context, i) => _celda(i),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _celda(int i) {
    final celda = partida.celdas[i];
    if (celda == CeldaUnoSolo.invalida) {
      return const SizedBox.shrink();
    }
    final seleccionada = seleccion == i;
    final destino = destinos.contains(i);
    final medio = medios.contains(i);
    final nGuia = ordenEliminacion?[i];
    final esProximo = proximoDesde == i;
    final esProximoComer = proximoMedio == i;
    final badgeOrden = nGuia == null
        ? null
        : Positioned(
            top: esProximoComer ? 12 : -1,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF3E2723),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.acento, width: 1.2),
                ),
                child: Text(
                  nGuia,
                  style: TextStyle(
                    color: AppColors.acento,
                    fontWeight: FontWeight.w900,
                    fontSize: nGuia.length > 3 ? 8 : 10,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          );

    final flechaComer = !esProximoComer
        ? null
        : const Positioned(
            top: -16,
            left: 0,
            right: 0,
            child: Center(
              child: Icon(
                Icons.arrow_drop_down_rounded,
                color: AppColors.acento,
                size: 34,
                shadows: [
                  Shadow(
                    color: Color(0xCC000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          );

    final mostrarBadge = badgeOrden != null &&
        (mostrarOrdenEnVacias || celda == CeldaUnoSolo.ocupada);

    return Padding(
      padding: const EdgeInsets.all(2.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap == null ? null : () => onTap!(i),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.25, -0.3),
                radius: 0.95,
                colors: [
                  _naranjaClaro.withValues(alpha: 0.55),
                  _ambarHueco.withValues(alpha: 0.92),
                ],
              ),
              border: Border.all(
                color: esProximoComer
                    ? AppColors.acento
                    : esProximo || seleccionada
                        ? Colors.white
                        : destino
                            ? const Color(0xFFFFFDE7)
                            : medio
                                ? const Color(0xFFFF8A65)
                                : (mostrarOrdenEnVacias && nGuia != null)
                                    ? AppColors.acento.withValues(alpha: 0.7)
                                    : _naranjaOscuro.withValues(alpha: 0.55),
                width: esProximoComer ||
                        esProximo ||
                        seleccionada ||
                        destino
                    ? 2.6
                    : 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                  spreadRadius: -0.5,
                ),
                if (esProximoComer)
                  BoxShadow(
                    color: AppColors.acento.withValues(alpha: 0.65),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                else if (esProximo || seleccionada)
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.55),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                else if (destino)
                  BoxShadow(
                    color: _amarillo.withValues(alpha: 0.55),
                    blurRadius: 8,
                  ),
              ],
            ),
            child: celda == CeldaUnoSolo.ocupada
                ? Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: _FichaAmarilla(
                          resaltada:
                              seleccionada || esProximo || esProximoComer,
                        ),
                      ),
                      if (flechaComer != null) flechaComer,
                      if (mostrarBadge) badgeOrden!,
                    ],
                  )
                : Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (destino)
                        Center(
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _amarilloClaro.withValues(alpha: 0.95),
                              boxShadow: [
                                BoxShadow(
                                  color: _amarillo.withValues(alpha: 0.7),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (mostrarBadge) badgeOrden!,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _FichaAmarilla extends StatelessWidget {
  const _FichaAmarilla({this.resaltada = false});

  final bool resaltada;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: resaltada
              ? const [
                  Color(0xFFFFFDE7),
                  Color(0xFFFFF176),
                  Color(0xFFFFD54F),
                ]
              : const [
                  TableroUnoSolo._amarilloClaro,
                  TableroUnoSolo._amarillo,
                  TableroUnoSolo._amarilloFuerte,
                ],
        ),
        border: Border.all(
          color: resaltada ? Colors.white : TableroUnoSolo._amarilloBorde,
          width: resaltada ? 2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.45),
            blurRadius: 2,
            offset: const Offset(-1, -1),
          ),
        ],
      ),
      child: Align(
        alignment: const Alignment(-0.35, -0.4),
        child: Container(
          width: 9,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

class _BandejaEsquina extends StatelessWidget {
  const _BandejaEsquina({required this.fichas});

  final int fichas;

  @override
  Widget build(BuildContext context) {
    final mostrar = fichas.clamp(0, 12);
    return Padding(
      padding: const EdgeInsets.all(5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFCC80).withValues(alpha: 0.35),
              const Color(0xFFE65100).withValues(alpha: 0.5),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFFE0B2).withValues(alpha: 0.55),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Wrap(
            spacing: 3,
            runSpacing: 3,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < mostrar; i++)
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFF59D),
                        Color(0xFFFBC02D),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFFF57F17),
                      width: 0.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 1.5,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
