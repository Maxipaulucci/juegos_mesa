import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/laPapa/motor_la_papa.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

class PartidaLaPapaScreen extends StatefulWidget {
  const PartidaLaPapaScreen({
    super.key,
    required this.nombres,
    this.solo = false,
  });

  final List<String> nombres;
  final bool solo;

  @override
  State<PartidaLaPapaScreen> createState() => _PartidaLaPapaScreenState();
}

class _PartidaLaPapaScreenState extends State<PartidaLaPapaScreen> {
  late PartidaPapa _partida;
  final List<Offset> _trazoActual = [];
  /// Trazo con el que se perdió (se muestra en rojo al terminar).
  final List<Offset> _trazoFallido = [];
  final GlobalKey _hojaKey = GlobalKey();
  bool _dibujando = false;
  bool _inicioValido = false;
  /// Ya se alejó del número de partida (evita cerrar el trazo al instante).
  bool _salioDelInicio = false;
  Size? _boardSize;

  @override
  void initState() {
    super.initState();
    _partida = nuevaPartidaPapa(nombres: widget.nombres);
  }

  void _reiniciar() {
    setState(() {
      _partida = nuevaPartidaPapa(nombres: widget.nombres);
      _trazoActual.clear();
      _trazoFallido.clear();
      _dibujando = false;
      _inicioValido = false;
      _salioDelInicio = false;
    });
  }

  void _limpiarTrazo() {
    _trazoActual.clear();
    _dibujando = false;
    _inicioValido = false;
    _salioDelInicio = false;
  }

  /// Mantiene los trazos alineados si el tablero cambia de tamaño
  /// (p. ej. al mostrar botones al terminar, o al redimensionar la ventana).
  Size _sincronizarTamanoHoja(Size boardSize) {
    final prev = _boardSize;
    if (prev != null && prev != boardSize) {
      reescalarTrazosPapa(_partida, prev, boardSize);
      reescalarPuntosPapa(_trazoActual, prev, boardSize);
      reescalarPuntosPapa(_trazoFallido, prev, boardSize);
    }
    _boardSize = boardSize;
    return boardSize;
  }

  bool _dentroHoja(Offset local, Size boardSize) {
    return local.dx >= 0 &&
        local.dy >= 0 &&
        local.dx <= boardSize.width &&
        local.dy <= boardSize.height;
  }

  Offset? _localEnHoja(Offset global) {
    final box = _hojaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return box.globalToLocal(global);
  }

  void _perder(String motivo) {
    perderPapa(_partida, motivo: motivo);
    _trazoFallido
      ..clear()
      ..addAll(_trazoActual);
    _limpiarTrazo();
  }

  void _onPointerDown(Offset local, Size boardSize) {
    if (_partida.terminada) return;
    if (!_dentroHoja(local, boardSize)) return;
    final de = _partida.siguienteConectar;
    if (!cercaDeNumeroPapa(_partida, de, local, boardSize)) {
      return;
    }
    setState(() {
      _boardSize = boardSize;
      _dibujando = true;
      _inicioValido = true;
      _salioDelInicio = false;
      _trazoActual
        ..clear()
        ..add(local);
    });
  }

  void _onPointerMoveGlobal(Offset global) {
    if (!_dibujando || !_inicioValido || _partida.terminada) return;
    final boardSize = _boardSize;
    if (boardSize == null) return;
    final local = _localEnHoja(global);
    if (local == null) return;

    if (!_dentroHoja(local, boardSize)) {
      setState(() {
        _perder(
          '${_partida.jugadorActual} se salió de la hoja. Fin de la partida.',
        );
      });
      return;
    }

    if (_trazoActual.isNotEmpty &&
        (_trazoActual.last - local).distance < 2.5) {
      return;
    }

    final de = _partida.siguienteConectar;
    final a = de + 1;
    final pts = [..._trazoActual, local];
    final chocaPrevios = trazoChocaConPreviosPapa(
      _partida,
      pts,
      boardSize: boardSize,
    );
    final chocaPropio = trazoSeTocaASiMismoPapa(
      pts,
      boardSize: boardSize,
    );

    setState(() {
      _trazoActual.add(local);

      if (chocaPrevios || chocaPropio) {
        _perder(
          chocaPropio
              ? '${_partida.jugadorActual} tocó su propia línea. '
                  'Fin de la partida.'
              : '${_partida.jugadorActual} tocó una línea. Fin de la partida.',
        );
        return;
      }

      if (!_salioDelInicio &&
          !cercaDeNumeroPapa(_partida, de, local, boardSize)) {
        _salioDelInicio = true;
      }

      // Al tocar el destino: solo vale si entrás por un lado libre del círculo.
      if (_salioDelInicio &&
          cercaDeNumeroPapa(_partida, a, local, boardSize) &&
          _trazoActual.length >= 2) {
        if (llegadaPorLadoBloqueadoPapa(
          _partida,
          a,
          _trazoActual,
          boardSize,
        )) {
          _perder(
            '${_partida.jugadorActual} entró al número por un lado bloqueado. '
            'Fin de la partida.',
          );
          return;
        }
        aceptarTrazoPapa(_partida, _trazoActual);
        _limpiarTrazo();
      }
    });
  }

  void _onPointerUpOrCancel() {
    if (!_dibujando || !_inicioValido) {
      setState(_limpiarTrazo);
      return;
    }
    if (_partida.terminada) {
      // Ya perdió en el move: no borrar el trazo fallido.
      setState(() {
        _dibujando = false;
        _inicioValido = false;
        _salioDelInicio = false;
        _trazoActual.clear();
      });
      return;
    }

    // Empezó un trazo y lo soltó sin llegar al número: pierde.
    setState(() {
      _perder(
        '${_partida.jugadorActual} no terminó el trazo en el número. '
        'Fin de la partida.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final de = _partida.siguienteConectar;
    final a = de < maxNumeroPapa ? de + 1 : null;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerMove: (e) => _onPointerMoveGlobal(e.position),
        onPointerUp: (_) => _onPointerUpOrCancel(),
        onPointerCancel: (_) => _onPointerUpOrCancel(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 1.1,
                  colors: [
                    Color(0xFF1A3D32),
                    AppColors.fondo,
                    Color(0xFF05020C),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back,
                              color: AppColors.texto),
                        ),
                        Expanded(
                          child: Text(
                            widget.solo
                                ? 'La papa · Solo'
                                : 'La papa · ${_partida.jugadorActual}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.mint,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Nueva hoja',
                          onPressed: _reiniciar,
                          icon: const Icon(Icons.refresh_rounded,
                              color: AppColors.textoSuave),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _partida.terminada
                          ? (_partida.mensajeFin ?? 'Fin')
                          : (a == null
                              ? '¡Completaste la hoja!'
                              : 'Conectá $de → $a · soltá o salí de la hoja = perdés'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _partida.fase == FasePapa.perdido
                            ? AppColors.peligro
                            : (_partida.fase == FasePapa.ganado
                                ? AppColors.mint
                                : AppColors.textoSuave),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: AspectRatio(
                            aspectRatio: columnasPapa / filasPapa,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final boardSize = _sincronizarTamanoHoja(
                                  Size(
                                    constraints.maxWidth,
                                    constraints.maxHeight,
                                  ),
                                );
                                return DecoratedBox(
                                  key: _hojaKey,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.mint,
                                      width: 2,
                                    ),
                                    boxShadow: neonGlow(
                                      AppColors.mint,
                                      blur: 16,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Listener(
                                      onPointerDown: (e) {
                                        final box = _hojaKey.currentContext
                                                ?.findRenderObject()
                                            as RenderBox?;
                                        if (box == null) return;
                                        final local =
                                            box.globalToLocal(e.position);
                                        _onPointerDown(local, boardSize);
                                      },
                                      child: CustomPaint(
                                        size: boardSize,
                                        painter: _HojaPapaPainter(
                                          partida: _partida,
                                          trazoActual: List.of(_trazoActual),
                                          trazoFallido: List.of(_trazoFallido),
                                          boardSize: boardSize,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Reserva fija: si solo aparece al terminar, la hoja se
                  // achica y los trazos en píxeles quedan desfasados.
                  SizedBox(
                    height: 96,
                    child: _partida.terminada
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _reiniciar,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.mint,
                                      foregroundColor: const Color(0xFF062018),
                                    ),
                                    child: const Text('Otra partida'),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text(
                                    'Volver al menú',
                                    style:
                                        TextStyle(color: AppColors.textoSuave),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HojaPapaPainter extends CustomPainter {
  _HojaPapaPainter({
    required this.partida,
    required this.trazoActual,
    required this.trazoFallido,
    required this.boardSize,
  });

  final PartidaPapa partida;
  final List<Offset> trazoActual;
  final List<Offset> trazoFallido;
  final Size boardSize;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / columnasPapa;
    final cellH = size.height / filasPapa;

    final gridPaint = Paint()
      ..color = const Color(0xFF2A1450).withValues(alpha: 0.55)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var c = 0; c <= columnasPapa; c++) {
      final x = c * cellW;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var r = 0; r <= filasPapa; r++) {
      final y = r * cellH;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final de = partida.siguienteConectar;
    final a = de < maxNumeroPapa ? de + 1 : null;

    for (var i = 0; i < partida.casillas.length; i++) {
      final n = partida.casillas[i];
      if (n == null) continue;
      final c = centroCasillaPapa(i, size);
      final destacado = !partida.terminada && (n == de || n == a);
      if (destacado) {
        canvas.drawCircle(
          c,
          math.min(cellW, cellH) * 0.26,
          Paint()
            ..color = (n == de ? AppColors.mint : AppColors.peligro)
                .withValues(alpha: 0.22)
            ..style = PaintingStyle.fill,
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: '$n',
          style: TextStyle(
            color: destacado
                ? (n == de ? const Color(0xFF0A7A4A) : AppColors.peligro)
                : const Color(0xFF1A0A33),
            fontWeight: FontWeight.w900,
            fontSize: math.min(cellW, cellH) * (destacado ? 0.28 : 0.24),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }

    final strokePaint = Paint()
      ..color = const Color(0xFF1A0A33)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final t in partida.trazos) {
      _dibujarPolyline(canvas, t.puntos, strokePaint);
    }

    if (trazoFallido.length >= 2) {
      _dibujarPolyline(
        canvas,
        trazoFallido,
        Paint()
          ..color = AppColors.peligro
          ..strokeWidth = 3.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    } else if (trazoFallido.length == 1) {
      canvas.drawCircle(
        trazoFallido.first,
        3.5,
        Paint()..color = AppColors.peligro,
      );
    }

    if (trazoActual.length >= 2) {
      _dibujarPolyline(
        canvas,
        trazoActual,
        Paint()
          ..color = AppColors.mint
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    } else if (trazoActual.length == 1) {
      canvas.drawCircle(
        trazoActual.first,
        3,
        Paint()..color = AppColors.mint,
      );
    }
  }

  void _dibujarPolyline(Canvas canvas, List<Offset> pts, Paint paint) {
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HojaPapaPainter oldDelegate) => true;
}
