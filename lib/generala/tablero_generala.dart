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
/// El tablero se escala al espacio disponible: sin scroll horizontal ni vertical.
class TableroGeneralaOverlay extends StatefulWidget {
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
  State<TableroGeneralaOverlay> createState() =>
      _TableroGeneralaOverlayState();
}

class _TableroGeneralaOverlayState extends State<TableroGeneralaOverlay> {
  /// true mientras el jugador mantiene apretado el botón ojo.
  bool _verDados = false;

  @override
  Widget build(BuildContext context) {
    final cerrar =
        widget.onCerrar ?? () => Navigator.of(context).maybePop();

    return Material(
      color: _verDados
          ? Colors.transparent
          : Colors.black.withValues(alpha: 0.72),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: (!_verDados && widget.permitirCerrar) ? cerrar : null,
        child: SafeArea(
          child: Stack(
            children: [
              if (!_verDados)
                LayoutBuilder(
                  builder: (context, outer) {
                    // Márgenes mínimos: el panel ocupa casi toda la pantalla.
                    final maxW = (outer.maxWidth - 8).clamp(280.0, outer.maxWidth);
                    final maxH =
                        (outer.maxHeight - 8).clamp(280.0, outer.maxHeight);

                    return Center(
                      child: GestureDetector(
                        onTap: () {},
                        child: SizedBox(
                          width: maxW,
                          height: maxH,
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
                                  color: AppColors.violeta
                                      .withValues(alpha: 0.85),
                                  width: 1.6,
                                ),
                                boxShadow: [
                                  ...neonGlow(AppColors.violeta, blur: 22),
                                  ...neonGlow(AppColors.rosa, blur: 12),
                                ],
                              ),
                              child: Column(
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
                                      Expanded(
                                        child: Text(
                                          widget.modoAnotar
                                              ? 'ELEGÍ QUÉ ANOTAR'
                                              : 'TABLERO',
                                          style: const TextStyle(
                                            color: AppColors.acento,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                      ),
                                      if (widget.dadosActuales != null)
                                        const SizedBox(width: 42),
                                      if (widget.permitirCerrar)
                                        IconButton(
                                          onPressed: cerrar,
                                          tooltip: 'Cerrar',
                                          visualDensity:
                                              VisualDensity.compact,
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            color: AppColors.textoSuave,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (widget.modoAnotar) ...[
                                    Text(
                                      'Turno de ${widget.partida.jugadorActual.nombre}',
                                      style: const TextStyle(
                                        color: AppColors.textoSuave,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final n = widget
                                            .partida.jugadores.length;
                                        // header + categorías + TOTAL
                                        final cuerpoFilas =
                                            CategoriaGenerala
                                                    .values.length +
                                                1;
                                        // Restar bordes internos/externos de
                                        // la tabla (~1px × filas) para que
                                        // TOTAL no quede cortado.
                                        final filasTotales =
                                            cuerpoFilas + 1;
                                        final altoDisp =
                                            (constraints.maxHeight -
                                                    filasTotales)
                                                .clamp(
                                          120.0,
                                          constraints.maxHeight,
                                        );
                                        final headerH =
                                            altoDisp / (cuerpoFilas + 1.2);
                                        final bodyH =
                                            (altoDisp - headerH) /
                                                cuerpoFilas;
                                        final escala =
                                            (bodyH / 42).clamp(0.55, 1.0);
                                        // Flex: categorías un poco más anchas.
                                        final catFlex =
                                            n >= 4 ? 1.2 : 1.45;

                                        return _TableroTabla(
                                          partida: widget.partida,
                                          modoAnotar: widget.modoAnotar,
                                          dadosActuales:
                                              widget.dadosActuales,
                                          onElegirCategoria:
                                              widget.onElegirCategoria,
                                          categoriaResaltada:
                                              widget.categoriaResaltada,
                                          catFlex: catFlex,
                                          headerHeight: headerH,
                                          rowHeight: bodyH,
                                          escala: escala,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              if (widget.dadosActuales != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _BotonOjoDados(
                    viendo: _verDados,
                    onPressStart: () => setState(() => _verDados = true),
                    onPressEnd: () => setState(() => _verDados = false),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón que se mantiene presionado para ocultar el tablero y ver los dados.
class _BotonOjoDados extends StatelessWidget {
  const _BotonOjoDados({
    required this.viendo,
    required this.onPressStart,
    required this.onPressEnd,
  });

  final bool viendo;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Mantené para ver los dados',
      child: Listener(
        onPointerDown: (_) => onPressStart(),
        onPointerUp: (_) => onPressEnd(),
        onPointerCancel: (_) => onPressEnd(),
        child: Container(
          width: 38,
          height: 38,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: viendo
                ? AppColors.azul.withValues(alpha: 0.35)
                : AppColors.carta,
            border: Border.all(
              color: viendo ? AppColors.azul : AppColors.cartaBorde,
              width: 1.5,
            ),
            boxShadow: viendo ? neonGlow(AppColors.azul, blur: 10) : null,
          ),
          child: Icon(
            viendo ? Icons.visibility : Icons.visibility_outlined,
            size: 18,
            color: viendo ? AppColors.azul : AppColors.textoSuave,
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
    required this.catFlex,
    required this.headerHeight,
    required this.rowHeight,
    this.escala = 1.0,
  });

  final PartidaGenerala partida;
  final bool modoAnotar;
  final List<int>? dadosActuales;
  final ValueChanged<CategoriaGenerala>? onElegirCategoria;
  final CategoriaGenerala? categoriaResaltada;
  final double catFlex;
  final double headerHeight;
  final double rowHeight;
  final double escala;

  @override
  Widget build(BuildContext context) {
    final border = AppColors.violeta.withValues(alpha: 0.45);
    final jugadores = partida.jugadores;
    final categorias = CategoriaGenerala.values;
    final headerFs = (10.0 * escala).clamp(8.0, 11.0);
    final totalFs = (14.0 * escala).clamp(11.0, 16.0);

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
                child: Text(
                  'CATEGORÍAS',
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
                        color: colorJugadorTablero(i),
                        fontWeight: FontWeight.w900,
                        fontSize: headerFs,
                        letterSpacing: 0.2,
                        shadows: [
                          Shadow(
                            color: colorJugadorTablero(i)
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
          for (final cat in categorias)
            TableRow(
              decoration: BoxDecoration(
                color: cat.index.isEven
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.transparent,
              ),
              children: [
                _celda(
                  height: rowHeight,
                  child: _CategoriaLabel(
                    texto: cat.etiqueta,
                    escala: escala,
                  ),
                ),
                for (var i = 0; i < jugadores.length; i++)
                  _celda(
                    height: rowHeight,
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
                      escala: escala,
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
                child: Text(
                  'TOTAL',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.acento,
                    fontWeight: FontWeight.w900,
                    fontSize: (11 * escala).clamp(9.0, 12.0),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              for (var i = 0; i < jugadores.length; i++)
                _celda(
                  height: rowHeight,
                  child: Text(
                    '${jugadores[i].total}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorJugadorTablero(i),
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
    this.escala = 1.0,
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
  final double escala;

  @override
  Widget build(BuildContext context) {
    final valor = jugador.casillas[categoria];
    final color = colorJugadorTablero(indexJugador);
    final fs = (15.0 * escala).clamp(11.0, 16.0);

    if (casillaOcupada(jugador, categoria) || valor != null) {
      return Text(
        '${valor ?? 0}',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: fs,
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
          fontSize: fs,
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
            size: (14 * escala).clamp(11.0, 16.0),
            color: AppColors.acento,
            shadows: [
              Shadow(
                color: AppColors.acento.withValues(alpha: 0.9),
                blurRadius: 10,
              ),
            ],
          ),
          const SizedBox(width: 1),
        ],
        Text(
          preview > 0 ? '$preview' : '0',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: resaltada
                ? AppColors.acento
                : (preview > 0 ? AppColors.mint : AppColors.textoSuave),
            fontWeight: FontWeight.w900,
            fontSize: (14 * escala).clamp(10.0, 15.0),
          ),
        ),
      ],
    );

    final caja = Ink(
      padding: EdgeInsets.symmetric(
        vertical: (3 * escala).clamp(1.0, 4.0),
        horizontal: 2,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: resaltada
              ? AppColors.acento
              : color.withValues(alpha: 0.85),
          width: resaltada ? 2 : 1,
        ),
        color: resaltada
            ? AppColors.acento.withValues(alpha: 0.22)
            : color.withValues(alpha: 0.12),
        boxShadow: resaltada ? neonGlow(AppColors.acento, blur: 8) : null,
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
        borderRadius: BorderRadius.circular(6),
        child: caja,
      ),
    );
  }
}

class _CategoriaLabel extends StatelessWidget {
  const _CategoriaLabel({required this.texto, this.escala = 1.0});

  final String texto;
  final double escala;

  bool get _esEspecial =>
      texto == 'ESCALERA' ||
      texto == 'FULL' ||
      texto == 'POKER' ||
      texto == 'GENERALA' ||
      texto == 'GENERALA DOBLE';

  @override
  Widget build(BuildContext context) {
    if (!_esEspecial && texto.length == 1) {
      final s = (24 * escala).clamp(18.0, 26.0);
      return Container(
        width: s,
        height: s,
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
          texto,
          style: TextStyle(
            color: const Color(0xFF1A0A00),
            fontWeight: FontWeight.w900,
            fontSize: (13 * escala).clamp(10.0, 14.0),
          ),
        ),
      );
    }

    final color = switch (texto) {
      'ESCALERA' => AppColors.acentoSuave,
      'FULL' => AppColors.mint,
      'POKER' => AppColors.azul,
      'GENERALA' => AppColors.acento,
      _ => AppColors.rosa,
    };

    final base = texto == 'GENERALA DOBLE' ? 9.0 : 11.0;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        texto,
        textAlign: TextAlign.center,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: (base * escala).clamp(8.0, 12.0),
          letterSpacing: 0.3,
          shadows: [
            Shadow(color: color.withValues(alpha: 0.75), blurRadius: 8),
          ],
        ),
      ),
    );
  }
}
