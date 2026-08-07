import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/chanchoVa/motor_chancho_va.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

Color colorJugadorTableroChancho(int index) => switch (index % 4) {
      0 => AppColors.acento,
      1 => AppColors.azul,
      2 => AppColors.peligro,
      _ => AppColors.mint,
    };

String etiquetaLetraTableroChancho(String letra) =>
    letra == ' ' ? '·' : letra;

/// Overlay con el tablero de letras estilo arcade (como Generala).
class TableroChanchoOverlay extends StatelessWidget {
  const TableroChanchoOverlay({
    super.key,
    required this.partida,
    this.onCerrar,
  });

  final PartidaChancho partida;
  final VoidCallback? onCerrar;

  @override
  Widget build(BuildContext context) {
    final cerrar = onCerrar ?? () => Navigator.of(context).maybePop();

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: cerrar,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, outer) {
              const anchoIdeal = 400.0;
              const rowH = 34.0;
              const headerH = 38.0;
              final letras = partida.secuenciaLetras;
              final cuerpoFilas = letras.length + 1; // + TOTAL
              final tableH = headerH + cuerpoFilas * rowH + (cuerpoFilas + 1);
              final n = partida.jugadores.length;
              final catFlex = n >= 4 ? 1.15 : 1.35;

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: (outer.maxWidth - 16).clamp(0.0, 540.0),
                    maxHeight:
                        (outer.maxHeight - 12).clamp(0.0, outer.maxHeight),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: GestureDetector(
                      onTap: () {},
                      child: SizedBox(
                        width: anchoIdeal,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF2A1450),
                                  AppColors.carta,
                                  Color(0xFF140828),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.violeta.withValues(alpha: 0.85),
                                width: 1.6,
                              ),
                              boxShadow: [
                                ...neonGlow(AppColors.violeta, blur: 22),
                                ...neonGlow(AppColors.rosa, blur: 12),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.grid_on_rounded,
                                      color: AppColors.acento,
                                      size: 20,
                                      shadows: [
                                        Shadow(
                                          color: AppColors.acento,
                                          blurRadius: 12,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'TABLERO',
                                        style: TextStyle(
                                          color: AppColors.acento,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: cerrar,
                                      tooltip: 'Cerrar',
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        color: AppColors.textoSuave,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  height: tableH,
                                  child: _TableroTablaChancho(
                                    partida: partida,
                                    letras: letras,
                                    catFlex: catFlex,
                                    headerHeight: headerH,
                                    rowHeight: rowH,
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
            },
          ),
        ),
      ),
    );
  }
}

class _TableroTablaChancho extends StatelessWidget {
  const _TableroTablaChancho({
    required this.partida,
    required this.letras,
    required this.catFlex,
    required this.headerHeight,
    required this.rowHeight,
  });

  final PartidaChancho partida;
  final List<String> letras;
  final double catFlex;
  final double headerHeight;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    final border = AppColors.violeta.withValues(alpha: 0.45);
    final jugadores = partida.jugadores;
    const headerFs = 10.0;
    const totalFs = 14.0;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0E061C).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder(
          horizontalInside: BorderSide(color: border, width: 1),
          verticalInside: BorderSide(color: border, width: 1),
        ),
        columnWidths: {
          0: FlexColumnWidth(catFlex),
          for (var i = 0; i < jugadores.length; i++)
            i + 1: const FlexColumnWidth(1),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.violeta.withValues(alpha: 0.55),
                  AppColors.rosa.withValues(alpha: 0.35),
                ],
              ),
            ),
            children: [
              _celda(
                height: headerHeight,
                child: const Text(
                  'LETRAS',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w900,
                    fontSize: headerFs,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              for (var i = 0; i < jugadores.length; i++)
                _celda(
                  height: headerHeight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      jugadores[i].nombre.toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        color: colorJugadorTableroChancho(i),
                        fontWeight: FontWeight.w900,
                        fontSize: headerFs,
                        letterSpacing: 0.2,
                        shadows: [
                          Shadow(
                            color: colorJugadorTableroChancho(i)
                                .withValues(alpha: 0.7),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (var fila = 0; fila < letras.length; fila++)
            TableRow(
              decoration: BoxDecoration(
                color: fila.isEven
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.transparent,
              ),
              children: [
                _celda(
                  height: rowHeight,
                  child: _LetraBadge(
                    letra: letras[fila],
                  ),
                ),
                for (var i = 0; i < jugadores.length; i++)
                  _celda(
                    height: rowHeight,
                    child: _CasillaLetra(
                      tieneLetra: jugadores[i].letras.length > fila,
                      letra: letras[fila],
                      color: colorJugadorTableroChancho(i),
                      esPerdedor: jugadores[i].eliminado ||
                          jugadores[i].nombre == partida.perdedor,
                    ),
                  ),
              ],
            ),
          TableRow(
            decoration: BoxDecoration(
              color: AppColors.acento.withValues(alpha: 0.12),
            ),
            children: [
              _celda(
                height: rowHeight,
                child: const Text(
                  'TOTAL',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.acento,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              for (var i = 0; i < jugadores.length; i++)
                _celda(
                  height: rowHeight,
                  child: Text(
                    '${jugadores[i].letras.length}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorJugadorTableroChancho(i),
                      fontWeight: FontWeight.w900,
                      fontSize: totalFs,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _celda({required double height, required Widget child}) {
    return SizedBox(
      height: height,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: child,
        ),
      ),
    );
  }
}

class _LetraBadge extends StatelessWidget {
  const _LetraBadge({required this.letra});

  final String letra;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE082), AppColors.acento],
        ),
        boxShadow: neonGlow(AppColors.acento, blur: 6),
      ),
      child: Text(
        etiquetaLetraTableroChancho(letra),
        style: const TextStyle(
          color: Color(0xFF1A0A00),
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _CasillaLetra extends StatelessWidget {
  const _CasillaLetra({
    required this.tieneLetra,
    required this.letra,
    required this.color,
    this.esPerdedor = false,
  });

  final bool tieneLetra;
  final String letra;
  final Color color;
  final bool esPerdedor;

  @override
  Widget build(BuildContext context) {
    if (!tieneLetra) {
      return Text(
        '—',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textoSuave.withValues(alpha: 0.55),
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      );
    }

    final acento = esPerdedor ? AppColors.peligro : color;
    return Text(
      etiquetaLetraTableroChancho(letra),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: acento,
        fontWeight: FontWeight.w900,
        fontSize: 16,
        shadows: [
          Shadow(color: acento.withValues(alpha: 0.75), blurRadius: 8),
        ],
      ),
    );
  }
}
