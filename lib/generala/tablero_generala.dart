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
    this.categoriaResaltada,
    this.onCerrar,
    this.permitirCerrar = true,
  });

  final PartidaGenerala partida;
  /// Si true, el jugador actual puede tocar casillas vacías para anotar.
  final bool modoAnotar;
  final List<int>? dadosActuales;
  final ValueChanged<CategoriaGenerala>? onElegirCategoria;
  /// Casilla que la PC va a elegir (muestra flecha).
  final CategoriaGenerala? categoriaResaltada;
  final VoidCallback? onCerrar;
  /// Si false (anotar obligatorio tras 3 tiradas), no hay cruz ni tap afuera.
  final bool permitirCerrar;

  @override
  Widget build(BuildContext context) {
    final cerrar = onCerrar ?? () => Navigator.of(context).maybePop();
    final size = MediaQuery.sizeOf(context);
    final n = partida.jugadores.length;
    // Con 3–4 jugadores achicamos columnas para que entren en pantalla.
    final catW = n >= 4 ? 112.0 : (n == 3 ? 120.0 : 132.0);
    final colW = n >= 4 ? 78.0 : (n == 3 ? 88.0 : 96.0);
    final anchoNecesario = catW + colW * n + 56;
    final maxW = anchoNecesario.clamp(300.0, size.width - 12);
    final maxH = (size.height - 20).clamp(360.0, 720.0);

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
                constraints: BoxConstraints(
                  maxWidth: maxW,
                  maxHeight: maxH,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
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
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final tabla = _TableroTabla(
                                partida: partida,
                                modoAnotar: modoAnotar,
                                dadosActuales: dadosActuales,
                                onElegirCategoria: onElegirCategoria,
                                categoriaResaltada: categoriaResaltada,
                                catWidth: catW,
                                colWidth: colW,
                              );
                              final tablaAncho = catW + colW * n;
                              final necesitaScrollH =
                                  tablaAncho > constraints.maxWidth;
                              Widget body = SingleChildScrollView(
                                child: tabla,
                              );
                              if (necesitaScrollH) {
                                body = SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: tablaAncho,
                                    child: body,
                                  ),
                                );
                              } else {
                                body = SizedBox(
                                  width: constraints.maxWidth,
                                  child: body,
                                );
                              }
                              return body;
                            },
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
    this.categoriaResaltada,
    this.catWidth = 132,
    this.colWidth = 96,
  });

  final PartidaGenerala partida;
  final bool modoAnotar;
  final List<int>? dadosActuales;
  final ValueChanged<CategoriaGenerala>? onElegirCategoria;
  final CategoriaGenerala? categoriaResaltada;
  final double catWidth;
  final double colWidth;

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
          0: FixedColumnWidth(catWidth),
          for (var i = 0; i < jugadores.length; i++)
            i + 1: FixedColumnWidth(colWidth),
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
                      resaltada: categoriaResaltada == cat &&
                          i == partida.indiceTurno,
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
    this.resaltada = false,
  });

  final JugadorGenerala jugador;
  final int indexJugador;
  final CategoriaGenerala categoria;
  final bool esTurnoActual;
  final bool modoAnotar;
  final List<int>? dadosActuales;
  final bool servida;
  final ValueChanged<CategoriaGenerala>? onElegir;
  final bool resaltada;

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

    final puedeMostrarPreview = modoAnotar &&
        esTurnoActual &&
        dadosActuales != null &&
        dadosActuales!.length == dadosGenerala &&
        puedeElegirCategoria(
          jugador,
          categoria,
          dados: dadosActuales,
          servida: servida,
        );

    if (!puedeMostrarPreview) {
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

    final contenido = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (resaltada) ...[
          Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: AppColors.acento,
            shadows: [
              Shadow(
                color: AppColors.acento.withValues(alpha: 0.9),
                blurRadius: 10,
              ),
            ],
          ),
          const SizedBox(width: 2),
        ],
        Text(
          preview > 0 ? '$preview' : '0',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: resaltada
                ? AppColors.acento
                : (preview > 0 ? AppColors.mint : AppColors.textoSuave),
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ],
    );

    final caja = Ink(
      width: resaltada ? 56 : 44,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: resaltada
              ? AppColors.acento
              : color.withValues(alpha: 0.85),
          width: resaltada ? 2 : 1,
        ),
        color: resaltada
            ? AppColors.acento.withValues(alpha: 0.22)
            : color.withValues(alpha: 0.12),
        boxShadow: resaltada ? neonGlow(AppColors.acento, blur: 10) : null,
      ),
      child: contenido,
    );

    if (onElegir == null) {
      return caja;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!puedeElegirCategoria(
            jugador,
            categoria,
            dados: dadosActuales,
            servida: servida,
          )) {
            return;
          }
          onElegir!.call(categoria);
        },
        borderRadius: BorderRadius.circular(8),
        child: caja,
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
