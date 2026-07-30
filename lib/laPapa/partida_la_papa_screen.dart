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
  bool _dibujando = false;
  bool _inicioValido = false;

  @override
  void initState() {
    super.initState();
    _partida = nuevaPartidaPapa(nombres: widget.nombres);
  }

  void _reiniciar() {
    setState(() {
      _partida = nuevaPartidaPapa(nombres: widget.nombres);
      _trazoActual.clear();
      _dibujando = false;
      _inicioValido = false;
    });
  }

  void _onPointerDown(Offset local, Size boardSize) {
    if (_partida.terminada) return;
    final de = _partida.siguienteConectar;
    if (!cercaDeNumeroPapa(_partida, de, local, boardSize)) {
      return;
    }
    setState(() {
      _dibujando = true;
      _inicioValido = true;
      _trazoActual
        ..clear()
        ..add(local);
    });
  }

  void _onPointerMove(Offset local, Size boardSize) {
    if (!_dibujando || !_inicioValido || _partida.terminada) return;
    if (_trazoActual.isNotEmpty &&
        (_trazoActual.last - local).distance < 2.5) {
      return;
    }
    final choca = trazoChocaAlAgregar(_partida, _trazoActual, local);
    setState(() {
      _trazoActual.add(local);
      if (choca) {
        _dibujando = false;
        _inicioValido = false;
        perderPapa(
          _partida,
          motivo:
              '${_partida.jugadorActual} tocó una línea. Fin de la partida.',
        );
        _trazoActual.clear();
      }
    });
  }

  void _onPointerUp(Offset? local, Size boardSize) {
    if (!_dibujando || !_inicioValido) {
      setState(() {
        _dibujando = false;
        _inicioValido = false;
        _trazoActual.clear();
      });
      return;
    }
    if (_partida.terminada) return;

    final fin = local ?? (_trazoActual.isEmpty ? null : _trazoActual.last);
    final a = _partida.siguienteConectar + 1;
    final okFin =
        fin != null && cercaDeNumeroPapa(_partida, a, fin, boardSize);

    setState(() {
      if (okFin && _trazoActual.length >= 2) {
        aceptarTrazoPapa(_partida, _trazoActual);
      }
      _trazoActual.clear();
      _dibujando = false;
      _inicioValido = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final de = _partida.siguienteConectar;
    final a = de < maxNumeroPapa ? de + 1 : null;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Stack(
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
                            : 'Conectá $de → $a trazando el camino'),
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
                              final boardSize = Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              return DecoratedBox(
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
                                      final box = context.findRenderObject()
                                          as RenderBox?;
                                      if (box == null) return;
                                      final local =
                                          box.globalToLocal(e.position);
                                      _onPointerDown(local, boardSize);
                                    },
                                    onPointerMove: (e) {
                                      final box = context.findRenderObject()
                                          as RenderBox?;
                                      if (box == null) return;
                                      final local =
                                          box.globalToLocal(e.position);
                                      if (local.dx < 0 ||
                                          local.dy < 0 ||
                                          local.dx > boardSize.width ||
                                          local.dy > boardSize.height) {
                                        return;
                                      }
                                      _onPointerMove(local, boardSize);
                                    },
                                    onPointerUp: (e) {
                                      final box = context.findRenderObject()
                                          as RenderBox?;
                                      if (box == null) {
                                        _onPointerUp(null, boardSize);
                                        return;
                                      }
                                      final local =
                                          box.globalToLocal(e.position);
                                      _onPointerUp(local, boardSize);
                                    },
                                    onPointerCancel: (_) =>
                                        _onPointerUp(null, boardSize),
                                    child: CustomPaint(
                                      size: boardSize,
                                      painter: _HojaPapaPainter(
                                        partida: _partida,
                                        trazoActual: List.of(_trazoActual),
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
                if (_partida.terminada)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Column(
                      children: [
                        ElevatedButton(
                          onPressed: _reiniciar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.mint,
                            foregroundColor: const Color(0xFF062018),
                          ),
                          child: const Text('Otra partida'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Volver al menú',
                            style: TextStyle(color: AppColors.textoSuave),
                          ),
                        ),
                      ],
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

class _HojaPapaPainter extends CustomPainter {
  _HojaPapaPainter({
    required this.partida,
    required this.trazoActual,
    required this.boardSize,
  });

  final PartidaPapa partida;
  final List<Offset> trazoActual;
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
          math.min(cellW, cellH) * 0.38,
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
            fontSize: math.min(cellW, cellH) * (destacado ? 0.42 : 0.36),
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
