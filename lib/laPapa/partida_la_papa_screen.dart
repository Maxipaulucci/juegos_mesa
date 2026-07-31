import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/laPapa/motor_la_papa.dart';
import 'package:app_juegos_mesa/laPapa/opciones_la_papa.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

class PartidaLaPapaScreen extends StatefulWidget {
  const PartidaLaPapaScreen({
    super.key,
    required this.nombres,
    this.solo = false,
    this.opciones = const OpcionesPapa(),
  });

  final List<String> nombres;
  final bool solo;
  final OpcionesPapa opciones;

  @override
  State<PartidaLaPapaScreen> createState() => _PartidaLaPapaScreenState();
}

class _PartidaLaPapaScreenState extends State<PartidaLaPapaScreen> {
  late PartidaPapa _partida;
  late List<String> _nombres;
  final List<Offset> _trazoActual = [];
  /// Trazo con el que se perdió (o el último fallo con vidas).
  final List<Offset> _trazoFallido = [];
  final GlobalKey _hojaKey = GlobalKey();
  bool _dibujando = false;
  bool _inicioValido = false;
  bool _salioDelInicio = false;
  Size? _boardSize;
  String? _avisoVida;
  GrosorTrazoPapa _grosor = GrosorTrazoPapa.normal;
  static const int _maxNombre = 15;

  @override
  void initState() {
    super.initState();
    _nombres = List.of(widget.nombres);
    _partida = nuevaPartidaPapa(
      nombres: _nombres,
      opciones: widget.opciones,
    );
  }

  void _reiniciar() {
    setState(() {
      _partida = nuevaPartidaPapa(
        nombres: _nombres,
        opciones: widget.opciones,
      );
      _trazoActual.clear();
      _trazoFallido.clear();
      _dibujando = false;
      _inicioValido = false;
      _salioDelInicio = false;
      _avisoVida = null;
    });
  }

  void _limpiarTrazo() {
    _trazoActual.clear();
    _dibujando = false;
    _inicioValido = false;
    _salioDelInicio = false;
  }

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

  void _fallar(String motivo) {
    _trazoFallido
      ..clear()
      ..addAll(_trazoActual);
    final termino = registrarFalloPapa(_partida, motivo: motivo);
    _limpiarTrazo();
    if (!termino) {
      final quedan = _partida.vidasDelActual() ?? 0;
      _avisoVida =
          '${_partida.jugadorActual} perdió una vida · quedan $quedan';
    } else {
      _avisoVida = null;
    }
  }

  void _onTapColocar(Offset local, Size boardSize) {
    if (_partida.fase != FasePapa.colocando) return;
    for (var i = 0; i < totalCasillasPapa; i++) {
      if (rectCasillaPapa(i, boardSize).contains(local)) {
        final err = colocarNumeroEnCasillaPapa(_partida, i);
        setState(() {
          _avisoVida = err;
        });
        return;
      }
    }
  }

  void _onPointerDown(Offset local, Size boardSize) {
    if (_partida.fase == FasePapa.colocando) {
      _onTapColocar(local, boardSize);
      return;
    }
    if (_partida.terminada || _partida.fase != FasePapa.jugando) return;
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
      _avisoVida = null;
      _trazoFallido.clear();
      _trazoActual
        ..clear()
        ..add(local);
    });
  }

  void _onPointerMoveGlobal(Offset global) {
    if (_partida.fase != FasePapa.jugando) return;
    if (!_dibujando || !_inicioValido || _partida.terminada) return;
    final boardSize = _boardSize;
    if (boardSize == null) return;
    final local = _localEnHoja(global);
    if (local == null) return;

    if (!_dentroHoja(local, boardSize)) {
      setState(() {
        _fallar(
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
      grosorActual: _grosor,
    );
    final chocaPropio = trazoSeTocaASiMismoPapa(
      pts,
      boardSize: boardSize,
      grosor: _grosor,
    );

    setState(() {
      _trazoActual.add(local);

      if (chocaPrevios || chocaPropio) {
        _fallar(
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

      if (_salioDelInicio &&
          cercaDeNumeroPapa(_partida, a, local, boardSize) &&
          _trazoActual.length >= 2) {
        if (llegadaPorLadoBloqueadoPapa(
          _partida,
          a,
          _trazoActual,
          boardSize,
        )) {
          _fallar(
            '${_partida.jugadorActual} entró al número por un lado bloqueado. '
            'Fin de la partida.',
          );
          return;
        }
        aceptarTrazoPapa(_partida, _trazoActual, grosor: _grosor);
        _trazoFallido.clear();
        _limpiarTrazo();
      }
    });
  }

  void _onPointerUpOrCancel() {
    if (_partida.fase != FasePapa.jugando) return;
    if (!_dibujando || !_inicioValido) {
      setState(_limpiarTrazo);
      return;
    }
    if (_partida.terminada) {
      setState(() {
        _dibujando = false;
        _inicioValido = false;
        _salioDelInicio = false;
        _trazoActual.clear();
      });
      return;
    }

    setState(() {
      _fallar(
        '${_partida.jugadorActual} no terminó el trazo en el número. '
        'Fin de la partida.',
      );
    });
  }

  String get _prefijoTitulo {
    if (widget.opciones.modoFantasma) return 'La papa · Fantasma';
    if (widget.solo) return 'La papa · Solo';
    return 'La papa';
  }

  String? _validarNombre(String nombre, int index) {
    if (nombre.isEmpty) return 'El nombre no puede estar vacío.';
    if (nombre.length > _maxNombre) {
      return 'Máximo $_maxNombre caracteres.';
    }
    final ocupado = _nombres.asMap().entries.any(
          (e) => e.key != index && e.value == nombre,
        );
    if (ocupado) return 'Ese nombre ya está en uso.';
    return null;
  }

  Future<void> _renombrarJugadorActual() async {
    if (_dibujando) return;
    final index = _partida.indiceTurno % _nombres.length;
    final actual = _nombres[index];
    final ctrl = TextEditingController(text: actual);
    String? error;

    final nuevo = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.carta,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Cambiar nombre',
            style: TextStyle(color: AppColors.mint, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Máximo 15 caracteres.',
                style: TextStyle(color: AppColors.textoSuave, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: _maxNombre,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: AppColors.texto),
                decoration: InputDecoration(
                  hintText: 'Nombre del jugador',
                  errorText: error,
                  counterStyle:
                      const TextStyle(color: AppColors.textoSuave),
                ),
                onSubmitted: (_) {
                  final t = ctrl.text.trim();
                  if (_validarNombre(t, index) case final e?) {
                    setDialogState(() => error = e);
                    return;
                  }
                  Navigator.of(context).pop(t);
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final t = ctrl.text.trim();
                    if (_validarNombre(t, index) case final e?) {
                      setDialogState(() => error = e);
                      return;
                    }
                    Navigator.of(context).pop(t);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mint,
                    foregroundColor: const Color(0xFF062018),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'Guardar',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.peligro,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 4,
                    shadowColor: Colors.black54,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (nuevo == null || nuevo == actual || !mounted) return;
    setState(() {
      _nombres[index] = nuevo;
      _partida.nombres[index] = nuevo;
    });
  }

  Widget _chipNombre() {
    final nombre = _partida.jugadorActual;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _dibujando ? null : _renombrarJugadorActual,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0E061C),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.violeta.withValues(alpha: 0.7),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  nombre.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.edit_rounded,
                size: 14,
                color: AppColors.violeta.withValues(alpha: 0.95),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _mensajeEstado {
    if (_partida.terminada) return _partida.mensajeFin ?? 'Fin';
    if (_avisoVida != null) return _avisoVida!;
    if (_partida.fase == FasePapa.colocando) {
      return '${_partida.jugadorActual}: colocá el '
          '${_partida.siguienteAColocar} '
          '(${_partida.siguienteAColocar - 1}/${_partida.maxNumero})';
    }
    final de = _partida.siguienteConectar;
    final a = de < _partida.maxNumero ? de + 1 : null;
    if (a == null) return '¡Completaste la hoja!';
    return 'Conectá $de → $a · soltá o salí de la hoja = perdés';
  }

  Widget _selectorGrosor() {
    return Row(
      children: [
        for (final g in GrosorTrazoPapa.values) ...[
          if (g != GrosorTrazoPapa.values.first) const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _dibujando
                    ? null
                    : () => setState(() => _grosor = g),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: _grosor == g
                        ? AppColors.mint.withValues(alpha: 0.18)
                        : const Color(0xFF1A0F2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _grosor == g
                          ? AppColors.mint
                          : AppColors.textoSuave.withValues(alpha: 0.35),
                      width: _grosor == g ? 1.8 : 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomPaint(
                        size: const Size(48, 14),
                        painter: _MuestraGrosorPainter(
                          ancho: g.ancho,
                          color: _grosor == g
                              ? AppColors.mint
                              : AppColors.textoSuave,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        g.etiqueta,
                        style: TextStyle(
                          color: _grosor == g
                              ? AppColors.mint
                              : AppColors.textoSuave,
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
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final de = _partida.siguienteConectar;
    final a = de < _partida.maxNumero ? de + 1 : null;
    final vidas = _partida.vidasDelActual();

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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  '$_prefijoTitulo · ',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.mint,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Flexible(child: _chipNombre()),
                            ],
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
                  if (vidas != null &&
                      _partida.fase == FasePapa.jugando &&
                      !_partida.terminada)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < OpcionesPapa.vidasIniciales; i++)
                            Icon(
                              i < vidas
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: AppColors.peligro,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _mensajeEstado,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _partida.fase == FasePapa.perdido ||
                                (_avisoVida != null &&
                                    _partida.fase == FasePapa.colocando)
                            ? AppColors.peligro
                            : (_partida.fase == FasePapa.ganado
                                ? AppColors.mint
                                : (_avisoVida != null
                                    ? AppColors.peligro
                                    : AppColors.textoSuave)),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_partida.fase == FasePapa.jugando &&
                      !_partida.terminada)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: _selectorGrosor(),
                    ),
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
                                          numeroActual: de,
                                          numeroSiguiente: a,
                                          grosorActual: _grosor,
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
    required this.numeroActual,
    required this.numeroSiguiente,
    required this.grosorActual,
  });

  final PartidaPapa partida;
  final List<Offset> trazoActual;
  final List<Offset> trazoFallido;
  final Size boardSize;
  final int numeroActual;
  final int? numeroSiguiente;
  final GrosorTrazoPapa grosorActual;

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

    final colocando = partida.fase == FasePapa.colocando;
    final fantasma =
        partida.modoFantasma && partida.fase == FasePapa.jugando;

    for (var i = 0; i < partida.casillas.length; i++) {
      final n = partida.casillas[i];
      if (n == null) continue;
      if (fantasma && n != numeroActual && n != numeroSiguiente) {
        continue;
      }
      final c = centroCasillaPapa(i, size);
      final destacado = !partida.terminada &&
          !colocando &&
          (n == numeroActual || n == numeroSiguiente);
      if (destacado) {
        canvas.drawCircle(
          c,
          math.min(cellW, cellH) * 0.26,
          Paint()
            ..color = (n == numeroActual ? AppColors.mint : AppColors.peligro)
                .withValues(alpha: 0.22)
            ..style = PaintingStyle.fill,
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: '$n',
          style: TextStyle(
            color: destacado
                ? (n == numeroActual
                    ? const Color(0xFF0A7A4A)
                    : AppColors.peligro)
                : const Color(0xFF1A0A33),
            fontWeight: FontWeight.w900,
            fontSize: math.min(cellW, cellH) * (destacado ? 0.28 : 0.24),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }

    for (final t in partida.trazos) {
      _dibujarPolyline(
        canvas,
        t.puntos,
        Paint()
          ..color = const Color(0xFF1A0A33)
          ..strokeWidth = t.grosor.ancho
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }

    if (trazoFallido.length >= 2) {
      _dibujarPolyline(
        canvas,
        trazoFallido,
        Paint()
          ..color = AppColors.peligro
          ..strokeWidth = grosorActual.ancho + 0.3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    } else if (trazoFallido.length == 1) {
      canvas.drawCircle(
        trazoFallido.first,
        math.max(2.5, grosorActual.ancho * 0.7),
        Paint()..color = AppColors.peligro,
      );
    }

    if (trazoActual.length >= 2) {
      _dibujarPolyline(
        canvas,
        trazoActual,
        Paint()
          ..color = AppColors.mint
          ..strokeWidth = grosorActual.ancho + 0.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    } else if (trazoActual.length == 1) {
      canvas.drawCircle(
        trazoActual.first,
        math.max(2.0, grosorActual.ancho * 0.65),
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

class _MuestraGrosorPainter extends CustomPainter {
  _MuestraGrosorPainter({required this.ancho, required this.color});

  final double ancho;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawLine(
      Offset(2, y),
      Offset(size.width - 2, y),
      Paint()
        ..color = color
        ..strokeWidth = ancho
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _MuestraGrosorPainter oldDelegate) =>
      oldDelegate.ancho != ancho || oldDelegate.color != color;
}
