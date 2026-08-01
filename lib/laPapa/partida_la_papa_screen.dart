import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/laPapa/motor_la_papa.dart';
import 'package:app_juegos_mesa/laPapa/opciones_la_papa.dart';
import 'package:app_juegos_mesa/laPapa/textos.dart';
import 'package:app_juegos_mesa/laPapa/victoria_la_papa_overlay.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

class PartidaLaPapaScreen extends StatefulWidget {
  const PartidaLaPapaScreen({
    super.key,
    required this.nombres,
    this.solo = false,
    this.opciones = const OpcionesPapa(),
    this.ajustesIniciales = const AjustesEstado(),
  });

  final List<String> nombres;
  final bool solo;
  final OpcionesPapa opciones;
  final AjustesEstado ajustesIniciales;

  @override
  State<PartidaLaPapaScreen> createState() => _PartidaLaPapaScreenState();
}

class _PartidaLaPapaScreenState extends State<PartidaLaPapaScreen> {
  late PartidaPapa _partida;
  late List<String> _nombres;
  late AjustesEstado _ajustes;
  final List<Offset> _trazoActual = [];
  /// Trazo con el que se perdió (o el último fallo con vidas).
  final List<Offset> _trazoFallido = [];
  final GlobalKey _hojaKey = GlobalKey();
  bool _dibujando = false;
  bool _inicioValido = false;
  bool _salioDelInicio = false;
  /// Punto local en la hoja bajo el dedo/clic (para la lupa).
  Offset? _lupaPunto;
  Size? _boardSize;
  String? _avisoVida;
  GrosorTrazoPapa _grosor = GrosorTrazoPapa.normal;
  bool _mostrarMenu = false;
  bool _mostrarAjustes = false;
  bool _confirmarRendicion = false;
  static const int _maxNombre = 15;

  @override
  void initState() {
    super.initState();
    _nombres = List.of(widget.nombres);
    _ajustes = widget.ajustesIniciales;
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
      _lupaPunto = null;
      _avisoVida = null;
      _mostrarMenu = false;
      _mostrarAjustes = false;
      _confirmarRendicion = false;
    });
  }

  void _limpiarTrazo() {
    _trazoActual.clear();
    _dibujando = false;
    _inicioValido = false;
    _salioDelInicio = false;
    _lupaPunto = null;
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
    if (_mostrarMenu || _mostrarAjustes) return;
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
      _lupaPunto = local;
      _trazoFallido.clear();
      _trazoActual
        ..clear()
        ..add(local);
    });
  }

  void _onPointerMoveGlobal(Offset global) {
    if (_mostrarMenu || _mostrarAjustes) return;
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
      setState(() => _lupaPunto = local);
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
      _lupaPunto = local;
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
        _lupaPunto = null;
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
    if (widget.opciones.modoInfernal) return 'La papa · Infernal';
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
    if (_dibujando || _partida.terminada) return;
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
    final puedeRenombrar = !_dibujando && !_partida.terminada;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: puedeRenombrar ? _renombrarJugadorActual : null,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: EdgeInsets.symmetric(
            vertical: puedeRenombrar ? 4 : 2,
            horizontal: puedeRenombrar ? 8 : 2,
          ),
          decoration: puedeRenombrar
              ? BoxDecoration(
                  color: const Color(0xFF0E061C),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.violeta.withValues(alpha: 0.7),
                    width: 1.2,
                  ),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  nombre.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: puedeRenombrar ? AppColors.texto : AppColors.mint,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (puedeRenombrar) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.edit_rounded,
                  size: 14,
                  color: AppColors.violeta.withValues(alpha: 0.95),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _abrirMenu() {
    if (_dibujando) return;
    setState(() {
      _mostrarMenu = true;
      _confirmarRendicion = false;
      _mostrarAjustes = false;
    });
  }

  void _abrirAjustes() {
    if (_dibujando) return;
    setState(() {
      _mostrarAjustes = true;
      _mostrarMenu = false;
      _confirmarRendicion = false;
    });
  }

  void _abrirReglas() {
    setState(() {
      _mostrarMenu = false;
      _confirmarRendicion = false;
    });
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.carta,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'REGLAS · LA PAPA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.mint,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                reglasLaPapa(opciones: widget.opciones),
                style: const TextStyle(color: AppColors.texto, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _salirAlMenu() {
    Navigator.of(context).pop();
  }

  void _rendirse() {
    if (_partida.terminada) return;
    if (widget.solo) {
      _salirAlMenu();
      return;
    }

    final index = _partida.indiceTurno % _nombres.length;
    final nombre = _nombres[index];
    final otros = [
      for (var i = 0; i < _nombres.length; i++)
        if (i != index) _nombres[i],
    ];

    setState(() {
      _mostrarMenu = false;
      _confirmarRendicion = false;
      _limpiarTrazo();
      _trazoFallido.clear();
      if (otros.isEmpty) {
        _partida.fase = FasePapa.perdido;
        _partida.ganador = null;
        _partida.mensajeFin = '$nombre se rindió.';
      } else {
        _partida.fase = FasePapa.ganado;
        _partida.ganador = otros.first;
        _partida.mensajeFin = otros.length == 1
            ? '$nombre se rindió. ¡${otros.first} gana!'
            : '$nombre se rindió. Ganan: ${otros.join(', ')}';
      }
    });
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

  Widget _selectorGrosor({ValueChanged<GrosorTrazoPapa>? onElegir}) {
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
                    : () {
                        setState(() => _grosor = g);
                        onElegir?.call(g);
                      },
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

  Future<void> _abrirSelectorTrazos() async {
    if (_dibujando || _partida.terminada) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.carta,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'TRAZOS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.mint,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Elegí el grosor del lápiz',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textoSuave,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                StatefulBuilder(
                  builder: (context, setSheetState) {
                    return _selectorGrosor(
                      onElegir: (_) {
                        setSheetState(() {});
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _botonTrazos() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: neonGlow(AppColors.mint, blur: 10),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _dibujando ? null : _abrirSelectorTrazos,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.mint.withValues(alpha: 0.95),
                      AppColors.mint.withValues(alpha: 0.65),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.brush_rounded, color: Color(0xFF062018)),
                    SizedBox(width: 8),
                    Text(
                      'Trazos',
                      style: TextStyle(
                        color: Color(0xFF062018),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final de = _partida.siguienteConectar;
    final a = de < _partida.maxNumero ? de + 1 : null;
    final vidas = _partida.vidasDelActual();

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Listener(
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
                        _RoundIcon(
                          icon: Icons.menu,
                          onTap: _abrirMenu,
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
                        _RoundIcon(
                          icon: Icons.settings,
                          onTap: _abrirAjustes,
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
                  const SizedBox(height: 4),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 2, 10, 4),
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
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Listener(
                                          onPointerDown: (e) {
                                            final box = _hojaKey
                                                    .currentContext
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
                                              trazoActual:
                                                  List.of(_trazoActual),
                                              trazoFallido:
                                                  List.of(_trazoFallido),
                                              boardSize: boardSize,
                                              numeroActual: de,
                                              numeroSiguiente: a,
                                              grosorActual: _grosor,
                                              mostrarCuadricula: widget
                                                  .opciones
                                                  .mostrarCuadriculaEfectiva,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_dibujando && _lupaPunto != null)
                                        _LupaTrazoPapa(
                                          focus: _lupaPunto!,
                                          boardSize: boardSize,
                                          partida: _partida,
                                          trazoActual: List.of(_trazoActual),
                                          trazoFallido:
                                              List.of(_trazoFallido),
                                          numeroActual: de,
                                          numeroSiguiente: a,
                                          grosorActual: _grosor,
                                          mostrarCuadricula: widget
                                              .opciones
                                              .mostrarCuadriculaEfectiva,
                                        ),
                                    ],
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
                    height: 52,
                    child: _partida.fase == FasePapa.jugando &&
                            !_partida.terminada
                        ? Align(
                            alignment: Alignment.bottomCenter,
                            child: _botonTrazos(),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
            ),
          ),
          if (_mostrarMenu)
            Positioned.fill(
              child: _MenuOverlay(
                jugador: _partida.jugadorActual,
                esSolo: widget.solo,
                partidaTerminada: _partida.terminada,
                confirmarRendicion: _confirmarRendicion && !widget.solo,
                onCerrar: () => setState(() {
                  _mostrarMenu = false;
                  _confirmarRendicion = false;
                }),
                onReglas: _abrirReglas,
                onSalirORendirse: _partida.terminada || widget.solo
                    ? _salirAlMenu
                    : () => setState(() => _confirmarRendicion = true),
                onConfirmarRendicion: _rendirse,
                onCancelarRendicion: () =>
                    setState(() => _confirmarRendicion = false),
              ),
            ),
          if (_mostrarAjustes)
            Positioned.fill(
              child: AjustesOverlay(
                ajustes: _ajustes,
                onChanged: (a) => setState(() => _ajustes = a),
                onCerrar: () => setState(() => _mostrarAjustes = false),
              ),
            ),
          if (_partida.terminada)
            Positioned.fill(
              child: VictoriaLaPapaOverlay(
                partida: _partida,
                ganador: _partida.ganador,
                subtitulo: _partida.mensajeFin,
                animaciones: _ajustes.animaciones,
                esSolo: widget.solo,
                onVolverAJugar: _reiniciar,
                onVolver: _salirAlMenu,
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.carta,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: AppColors.texto),
        ),
      ),
    );
  }
}

class _MenuOverlay extends StatelessWidget {
  const _MenuOverlay({
    required this.jugador,
    required this.esSolo,
    required this.partidaTerminada,
    required this.confirmarRendicion,
    required this.onCerrar,
    required this.onReglas,
    required this.onSalirORendirse,
    required this.onConfirmarRendicion,
    required this.onCancelarRendicion,
  });

  final String jugador;
  final bool esSolo;
  final bool partidaTerminada;
  final bool confirmarRendicion;
  final VoidCallback onCerrar;
  final VoidCallback onReglas;
  final VoidCallback onSalirORendirse;
  final VoidCallback onConfirmarRendicion;
  final VoidCallback onCancelarRendicion;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onCerrar,
        child: SafeArea(
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF3B1D6E),
                          Color(0xFF1A0A33),
                          Color(0xFF2A1050),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.acento, width: 2),
                      boxShadow: neonGlow(AppColors.acento, blur: 18),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'MENÚ',
                                style: TextStyle(
                                  color: AppColors.acento,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: onCerrar,
                              icon: const Icon(
                                Icons.close,
                                color: AppColors.texto,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          jugador.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.texto,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            shadows: [
                              Shadow(
                                color: AppColors.acento.withValues(alpha: 0.7),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          partidaTerminada
                              ? 'Partida terminada'
                              : 'Turno actual',
                          style: TextStyle(
                            color:
                                AppColors.textoSuave.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _ArcadeButton(
                          label: 'REGLAS',
                          icon: Icons.menu_book_rounded,
                          tono: _BotonTono.azul,
                          onPressed: onReglas,
                        ),
                        const SizedBox(height: 10),
                        if (partidaTerminada || esSolo)
                          _ArcadeButton(
                            label: 'SALIR',
                            icon: Icons.logout_rounded,
                            tono: _BotonTono.rojo,
                            onPressed: onSalirORendirse,
                          )
                        else if (!confirmarRendicion)
                          _ArcadeButton(
                            label: 'RENDIRSE',
                            icon: Icons.flag_rounded,
                            tono: _BotonTono.rojo,
                            onPressed: onSalirORendirse,
                          )
                        else ...[
                          const Text(
                            '¿Confirmás tu derrota?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.peligro,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _ArcadeButton(
                            label: 'CONFIRMAR RENDICIÓN',
                            icon: Icons.check_circle_outline,
                            tono: _BotonTono.rojo,
                            onPressed: onConfirmarRendicion,
                          ),
                          const SizedBox(height: 10),
                          _ArcadeButton(
                            label: 'CANCELAR',
                            icon: Icons.close,
                            tono: _BotonTono.violeta,
                            onPressed: onCancelarRendicion,
                          ),
                        ],
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

enum _BotonTono { violeta, azul, rojo }

class _ArcadeButton extends StatelessWidget {
  const _ArcadeButton({
    required this.label,
    required this.icon,
    required this.tono,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final _BotonTono tono;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    late final List<Color> colors;
    late final Color glow;
    late final Color fg;

    switch (tono) {
      case _BotonTono.violeta:
        colors = const [
          Color(0xFFCE93D8),
          Color(0xFFAB47BC),
          Color(0xFF6A1B9A),
        ];
        glow = AppColors.rosa;
        fg = Colors.white;
      case _BotonTono.azul:
        colors = const [
          Color(0xFF81D4FA),
          Color(0xFF29B6F6),
          Color(0xFF0277BD),
        ];
        glow = AppColors.azul;
        fg = Colors.white;
      case _BotonTono.rojo:
        colors = const [
          Color(0xFFFF8A80),
          Color(0xFFFF5252),
          Color(0xFFC62828),
        ];
        glow = AppColors.peligro;
        fg = Colors.white;
    }

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: enabled ? neonGlow(glow, blur: 16) : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Ink(
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: colors,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white70, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: fg),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LupaTrazoPapa extends StatelessWidget {
  const _LupaTrazoPapa({
    required this.focus,
    required this.boardSize,
    required this.partida,
    required this.trazoActual,
    required this.trazoFallido,
    required this.numeroActual,
    required this.numeroSiguiente,
    required this.grosorActual,
    required this.mostrarCuadricula,
  });

  static const diametro = 118.0;
  static const zoom = 2.35;
  /// Desplazamiento del centro de la lupa respecto al dedo (arriba-derecha).
  static const offsetDedo = Offset(52, -70);

  final Offset focus;
  final Size boardSize;
  final PartidaPapa partida;
  final List<Offset> trazoActual;
  final List<Offset> trazoFallido;
  final int numeroActual;
  final int? numeroSiguiente;
  final GrosorTrazoPapa grosorActual;
  final bool mostrarCuadricula;

  @override
  Widget build(BuildContext context) {
    const r = diametro / 2;
    var dx = offsetDedo.dx;
    var dy = offsetDedo.dy;
    // Si se sale mucho del borde, voltear el lado para no perderla.
    if (focus.dx + dx + r > boardSize.width + 8) dx = -offsetDedo.dx;
    if (focus.dy + dy - r < -8) dy = -offsetDedo.dy;

    return Positioned(
      left: focus.dx + dx - r,
      top: focus.dy + dy - r,
      width: diametro,
      height: diametro,
      child: IgnorePointer(
        child: CustomPaint(
          size: const Size(diametro, diametro),
          painter: _LupaPapaPainter(
            focus: focus,
            boardSize: boardSize,
            zoom: zoom,
            hoja: _HojaPapaPainter(
              partida: partida,
              trazoActual: trazoActual,
              trazoFallido: trazoFallido,
              boardSize: boardSize,
              numeroActual: numeroActual,
              numeroSiguiente: numeroSiguiente,
              grosorActual: grosorActual,
              mostrarCuadricula: mostrarCuadricula,
            ),
          ),
        ),
      ),
    );
  }
}

class _LupaPapaPainter extends CustomPainter {
  _LupaPapaPainter({
    required this.focus,
    required this.boardSize,
    required this.zoom,
    required this.hoja,
  });

  final Offset focus;
  final Size boardSize;
  final double zoom;
  final _HojaPapaPainter hoja;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radio = size.width / 2;

    canvas.drawCircle(
      center.translate(1.5, 2.5),
      radio,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radio - 1)),
    );

    canvas.translate(center.dx, center.dy);
    canvas.scale(zoom);
    canvas.translate(-focus.dx, -focus.dy);

    final paper = Rect.fromLTWH(0, 0, boardSize.width, boardSize.height);
    // Fuera de la hoja (para que el borde mint se note cerca del límite).
    canvas.drawRect(
      paper.inflate(500),
      Paint()..color = const Color(0xFF0A1A14),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(paper, const Radius.circular(6)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(paper, const Radius.circular(6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.mint,
    );
    hoja.paint(canvas, boardSize);
    canvas.restore();

    canvas.drawCircle(
      center,
      radio - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.mint,
    );
    canvas.drawCircle(
      center,
      radio - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.85),
    );

    // Cruz suave en el centro (punto bajo el dedo).
    final cruz = Paint()
      ..color = AppColors.mint.withValues(alpha: 0.55)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const arm = 7.0;
    canvas.drawLine(
      center.translate(-arm, 0),
      center.translate(arm, 0),
      cruz,
    );
    canvas.drawLine(
      center.translate(0, -arm),
      center.translate(0, arm),
      cruz,
    );
  }

  @override
  bool shouldRepaint(covariant _LupaPapaPainter oldDelegate) =>
      oldDelegate.focus != focus ||
      oldDelegate.boardSize != boardSize ||
      oldDelegate.zoom != zoom;
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
    this.mostrarCuadricula = true,
  });

  final PartidaPapa partida;
  final List<Offset> trazoActual;
  final List<Offset> trazoFallido;
  final Size boardSize;
  final int numeroActual;
  final int? numeroSiguiente;
  final GrosorTrazoPapa grosorActual;
  final bool mostrarCuadricula;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / columnasPapa;
    final cellH = size.height / filasPapa;

    if (mostrarCuadricula) {
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
