import 'package:flutter/material.dart';

import 'motor_generala.dart';
import '../theme/app_theme.dart';

Color colorJugadorTablero(int index) => switch (index % 4) {
      0 => AppColors.acento,
      1 => AppColors.azul,
      2 => AppColors.peligro,
      _ => AppColors.mint,
    };

/// Overlay con el tablero de anotación estilo arcade.
class TableroGeneralaOverlay extends StatelessWidget {
  const TableroGeneralaOverlay({
    super.key,
    required this.partida,
    this.modoAnotar = false,
    this.dadosActuales,
    this.onElegirCategoria,
    this.onCerrar,
    this.permitirCerrar = true,
  });

  final PartidaGenerala partida;
  /// Si true, el jugador actual puede tocar casillas vacías para anotar.
  final bool modoAnotar;
  final List<int>? dadosActuales;
  final ValueChanged<CategoriaGenerala>? onElegirCategoria;
  final VoidCallback? onCerrar;
  /// Si false (anotar obligatorio tras 3 tiradas), no hay cruz ni tap afuera.
  final bool permitirCerrar;

  @override
  Widget build(BuildContext context) {
    final cerrar = onCerrar ?? () => Navigator.of(context).maybePop();
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: permitirCerrar ? cerrar : null,
        child: SafeArea(
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 520, maxHeight: 700),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
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
                      borderRadius: BorderRadius.circular(22),
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
                              size: 22,
                              shadows: [
                                Shadow(
                                  color: AppColors.acento,
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                modoAnotar ? 'ELEGÍ QUÉ ANOTAR' : 'TABLERO',
                                style: const TextStyle(
                                  color: AppColors.acento,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            if (permitirCerrar)
                              IconButton(
                                onPressed: cerrar,
                                tooltip: 'Cerrar',
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.textoSuave,
                                ),
                              ),
                          ],
                        ),
                        if (modoAnotar) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Turno de ${partida.jugadorActual.nombre}',
                            style: const TextStyle(
                              color: AppColors.textoSuave,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Flexible(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: _TableroTabla(
                                partida: partida,
                                modoAnotar: modoAnotar,
                                dadosActuales: dadosActuales,
                                onElegirCategoria: onElegirCategoria,
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
        ),
      ),
    );
  }
}

class _TableroTabla extends StatelessWidget {
  const _TableroTabla({
    required this.partida,
    required this.modoAnotar,
    this.dadosActuales,
    this.onElegirCategoria,
  });

  final PartidaGenerala partida;
  final bool modoAnotar;
  final List<int>? dadosActuales;
  final ValueChanged<CategoriaGenerala>? onElegirCategoria;

  static const _catWidth = 132.0;
  static const _colWidth = 96.0;
  static const _rowHeight = 42.0;
  static const _headerHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final border = AppColors.violeta.withValues(alpha: 0.45);
    final jugadores = partida.jugadores;
    final categorias = CategoriaGenerala.values;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E061C).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
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
          0: const FixedColumnWidth(_catWidth),
          for (var i = 0; i < jugadores.length; i++)
            i + 1: const FixedColumnWidth(_colWidth),
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
                height: _headerHeight,
                child: const Text(
                  'CATEGORÍAS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              for (var i = 0; i < jugadores.length; i++)
                _celda(
                  height: _headerHeight,
                  child: Text(
                    jugadores[i].nombre.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorJugadorTablero(i),
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 0.4,
                      shadows: [
                        Shadow(
                          color:
                              colorJugadorTablero(i).withValues(alpha: 0.7),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          for (final cat in categorias)
            TableRow(
              decoration: BoxDecoration(
                color: cat.index.isEven
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.transparent,
              ),
              children: [
                _celda(
                  height: _rowHeight,
                  child: _CategoriaLabel(texto: cat.etiqueta),
                ),
                for (var i = 0; i < jugadores.length; i++)
                  _celda(
                    height: _rowHeight,
                    child: _Casilla(
                      jugador: jugadores[i],
                      indexJugador: i,
                      categoria: cat,
                      esTurnoActual: i == partida.indiceTurno,
                      modoAnotar: modoAnotar,
                      dadosActuales: dadosActuales,
                      servida: partida.turno.tiradasHechas == 1,
                      onElegir: onElegirCategoria,
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
                height: _rowHeight,
                child: const Text(
                  'TOTAL',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.acento,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ),
              for (var i = 0; i < jugadores.length; i++)
                _celda(
                  height: _rowHeight,
                  child: Text(
                    '${jugadores[i].total}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorJugadorTablero(i),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
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
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: child,
        ),
      ),
    );
  }
}

class _Casilla extends StatelessWidget {
  const _Casilla({
    required this.jugador,
    required this.indexJugador,
    required this.categoria,
    required this.esTurnoActual,
    required this.modoAnotar,
    this.dadosActuales,
    this.servida = false,
    this.onElegir,
  });

  final JugadorGenerala jugador;
  final int indexJugador;
  final CategoriaGenerala categoria;
  final bool esTurnoActual;
  final bool modoAnotar;
  final List<int>? dadosActuales;
  final bool servida;
  final ValueChanged<CategoriaGenerala>? onElegir;

  @override
  Widget build(BuildContext context) {
    final valor = jugador.casillas[categoria];
    final color = colorJugadorTablero(indexJugador);

    // Ya anotada: solo se muestra el valor, nunca se puede volver a tocar.
    if (casillaOcupada(jugador, categoria) || valor != null) {
      return Text(
        '${valor ?? 0}',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 16,
          shadows: [
            Shadow(color: color.withValues(alpha: 0.6), blurRadius: 8),
          ],
        ),
      );
    }

    final elegible = modoAnotar &&
        esTurnoActual &&
        onElegir != null &&
        puedeElegirCategoria(jugador, categoria) &&
        dadosActuales != null &&
        dadosActuales!.length == dadosGenerala;

    if (!elegible) {
      return Text(
        '—',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color.withValues(alpha: 0.3),
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      );
    }

    final preview = puntosCategoria(
      categoria,
      dadosActuales!,
      yaTieneGenerala: jugador.generalaAnotada,
      servida: servida,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!puedeElegirCategoria(jugador, categoria)) return;
          onElegir!.call(categoria);
        },
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          width: 44,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.85)),
            color: color.withValues(alpha: 0.12),
          ),
          child: Text(
            preview > 0 ? '$preview' : '0',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: preview > 0 ? AppColors.mint : AppColors.textoSuave,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoriaLabel extends StatelessWidget {
  const _CategoriaLabel({required this.texto});

  final String texto;

  bool get _esEspecial =>
      texto == 'ESCALERA' ||
      texto == 'FULL' ||
      texto == 'POKER' ||
      texto == 'GENERALA' ||
      texto == 'GENERALA DOBLE';

  @override
  Widget build(BuildContext context) {
    if (!_esEspecial && texto.length == 1) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFE082), AppColors.acento],
              ),
              boxShadow: neonGlow(AppColors.acento, blur: 8),
            ),
            child: Text(
              texto,
              style: const TextStyle(
                color: Color(0xFF1A0A00),
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      );
    }

    final color = switch (texto) {
      'ESCALERA' => AppColors.acentoSuave,
      'FULL' => AppColors.mint,
      'POKER' => AppColors.azul,
      'GENERALA' => AppColors.acento,
      _ => AppColors.rosa,
    };

    return Text(
      texto,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w900,
        fontSize: texto == 'GENERALA DOBLE' ? 10 : 12,
        letterSpacing: 0.6,
        shadows: [
          Shadow(color: color.withValues(alpha: 0.75), blurRadius: 10),
        ],
      ),
    );
  }
}
