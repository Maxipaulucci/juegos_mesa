import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import 'ajustes_overlay.dart';
import 'dado_widget.dart';
import 'estadisticas.dart';
import 'motor.dart';
import 'textos.dart';
import 'victoria_overlay.dart';

final _fmt = NumberFormat('#,###', 'es_AR');

String _pts(int n) => _fmt.format(n).replaceAll(',', '.');

class PartidaDiezMilScreen extends StatefulWidget {
  const PartidaDiezMilScreen({
    super.key,
    required this.nombres,
    required this.modo,
    this.partidaRapida = false,
    this.modoDios = false,
    this.ajustesIniciales = const AjustesEstado(),
  });

  final List<String> nombres;
  final Modo modo;
  /// Solo en partida rápida se puede editar el nombre tocando la tarjeta.
  final bool partidaRapida;
  /// Muestra el botón temporal para forzar la próxima tirada.
  final bool modoDios;
  final AjustesEstado ajustesIniciales;

  @override
  State<PartidaDiezMilScreen> createState() => _PartidaDiezMilScreenState();
}

class _PartidaDiezMilScreenState extends State<PartidaDiezMilScreen> {
  late Partida _partida;
  late EstadisticasPartida _stats;
  late List<String> _nombres;
  ResultadoTirada? _ultimaTirada;
  ResumenTirada? _ultimoResumen;
  String? _mensaje;
  bool _esperandoEspecial = false;
  bool _mostrarVictoria = false;
  bool _mostrarMenu = false;
  bool _mostrarAjustes = false;
  bool _confirmarRendicion = false;
  String? _subtituloVictoria;
  int _mejorTiradaPartida = 0;
  String? _mejorTiradaJugador;
  late AjustesEstado _ajustes;

  // TEMPORAL (testing): fuerza los valores de la próxima tirada.
  List<int>? _dadosForzados;

  static const int _maxNombre = 15;

  @override
  void initState() {
    super.initState();
    _nombres = List.of(widget.nombres);
    _ajustes = widget.ajustesIniciales;
    _iniciarPartidaNueva();
  }

  void _iniciarPartidaNueva() {
    _partida = nuevaPartida(_nombres, widget.modo);
    _stats = EstadisticasPartida(_nombres);
    iniciarTurno(_partida);
    _ultimaTirada = null;
    _ultimoResumen = null;
    _mensaje = null;
    _esperandoEspecial = false;
    _mostrarVictoria = false;
    _mostrarMenu = false;
    _mostrarAjustes = false;
    _confirmarRendicion = false;
    _subtituloVictoria = null;
    _mejorTiradaPartida = 0;
    _mejorTiradaJugador = null;
    _dadosForzados = null;
  }

  void _volverAJugar() {
    setState(_iniciarPartidaNueva);
  }

  Future<void> _renombrarJugador(int index) async {
    if (!widget.partidaRapida || _partida.ganador != null) return;
    final actual = _partida.jugadores[index].nombre;
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
            style: TextStyle(color: AppColors.acento, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  counterStyle: const TextStyle(color: AppColors.textoSuave),
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final t = ctrl.text.trim();
                if (_validarNombre(t, index) case final e?) {
                  setDialogState(() => error = e);
                  return;
                }
                Navigator.of(context).pop(t);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (nuevo == null || nuevo == actual || !mounted) return;

    setState(() {
      final anterior = _partida.jugadores[index].nombre;
      _partida.jugadores[index].nombre = nuevo;
      _nombres[index] = nuevo;
      _stats.renombrar(anterior, nuevo);
      if (_mejorTiradaJugador == anterior) {
        _mejorTiradaJugador = nuevo;
      }
      if (_partida.ganador == anterior) {
        _partida.ganador = nuevo;
      }
      if (_subtituloVictoria != null &&
          _subtituloVictoria!.contains(anterior)) {
        _subtituloVictoria =
            _subtituloVictoria!.replaceFirst(anterior, nuevo);
      }
    });
  }

  String? _validarNombre(String nombre, int index) {
    if (nombre.isEmpty) return 'El nombre no puede estar vacío.';
    if (nombre.length > _maxNombre) {
      return 'Máximo $_maxNombre caracteres.';
    }
    final ocupado = _partida.jugadores.asMap().entries.any(
          (e) => e.key != index && e.value.nombre == nombre,
        );
    if (ocupado) return 'Ese nombre ya está en uso.';
    return null;
  }

  void _lanzarVictoria() {
    if (_mostrarVictoria) return;
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted || _partida.ganador == null) return;
      setState(() => _mostrarVictoria = true);
    });
  }

  void _mostrarReglas() {
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
          child: Text(
            reglasDe(_partida.modo),
            style: const TextStyle(color: AppColors.texto, height: 1.45),
          ),
        ),
      ),
    );
  }

  void _abrirMenu() {
    if (_partida.ganador != null || _mostrarVictoria) return;
    setState(() {
      _mostrarMenu = true;
      _confirmarRendicion = false;
    });
  }

  void _cerrarMenu() {
    setState(() {
      _mostrarMenu = false;
      _confirmarRendicion = false;
    });
  }

  void _rendirse() {
    if (_partida.ganador != null) return;
    final rendido = _partida.jugadorActual;
    final rivales =
        _partida.jugadores.where((j) => !identical(j, rendido)).toList();
    if (rivales.isEmpty) return;

    rivales.sort((a, b) => b.puntos.compareTo(a.puntos));
    final ganador = rivales.first;

    setState(() {
      _partida.ganador = ganador.nombre;
      _subtituloVictoria = '${rendido.nombre} se ha rendido';
      _mostrarMenu = false;
      _confirmarRendicion = false;
      _esperandoEspecial = false;
      _mensaje = null;
    });
    _lanzarVictoria();
  }

  // TEMPORAL (testing): elegí a mano los dados de la próxima tirada.
  Future<void> _configurarDadosForzados() async {
    final cantidad = _partida.turno.dadosEnMano;
    final ctrl = TextEditingController(
      text: _dadosForzados?.join('') ?? '',
    );
    String? error;

    final valores = await showDialog<List<int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.carta,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '🎯 Forzar próxima tirada',
            style: TextStyle(color: AppColors.acento, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Escribí $cantidad números del 1 al 6, sin espacios.\n'
                'Ej: ${List.filled(cantidad, '1').join()}',
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: cantidad,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[1-6]')),
                  LengthLimitingTextInputFormatter(cantidad),
                ],
                style: const TextStyle(
                  color: AppColors.texto,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: List.filled(cantidad, '•').join(),
                  counterText: '',
                  errorText: error,
                ),
                onChanged: (_) {
                  if (error != null) {
                    setDialogState(() => error = null);
                  }
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final texto = ctrl.text.trim();
                  if (texto.length != cantidad ||
                      texto.split('').any((c) {
                        final n = int.tryParse(c);
                        return n == null || n < 1 || n > 6;
                      })) {
                    setDialogState(() {
                      error =
                          'Ingresá exactamente $cantidad números entre 1 y 6.';
                    });
                    return;
                  }
                  final nums = texto.split('').map(int.parse).toList();
                  Navigator.of(context).pop(nums);
                },
                child: const Text('Aplicar'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.peligro,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cancelar'),
              ),
              if (_dadosForzados != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(<int>[]),
                  child: const Text(
                    'Quitar',
                    style: TextStyle(color: AppColors.peligro),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (valores == null) return;
    setState(() {
      _dadosForzados = valores.isEmpty ? null : valores;
    });
  }

  void _tirar() {
    if (_partida.ganador != null || _esperandoEspecial) return;
    final resultado = ejecutarTirada(_partida, dadosForzados: _dadosForzados);
    _dadosForzados = null;
    if (hayOpcionales(resultado)) {
      setState(() {
        _ultimaTirada = resultado;
        _ultimoResumen = null;
        _esperandoEspecial = true;
        _mensaje = null;
      });
      return;
    }
    _aplicar(resultado, null);
  }

  void _aplicar(ResultadoTirada resultado, Especial? especial) {
    final nombre = _partida.jugadorActual.nombre;
    final turnoPrevio = _partida.turno.puntosTurno;
    final resumen = aplicarPuntosTirada(_partida, resultado, especial);
    final puntosReg = resumen.bust ? 0 : resumen.puntosTirada;
    _stats.registrar(nombre, puntosReg);

    setState(() {
      _ultimaTirada = resultado;
      _ultimoResumen = resumen;
      _esperandoEspecial = false;
      // Al ganar por tirada se banca el turno completo: cuenta como su total.
      if (resumen.victoria) {
        _registrarMejorTirada(nombre, turnoPrevio + puntosReg);
      }
      if (resumen.victoria) {
        _mensaje = '¡${_partida.jugadorActual.nombre} gana!';
      } else if (resumen.bust) {
        _mensaje =
            'No sumaste nada. Perdés los ${resumen.puntosPerdidos} pts del turno.';
      } else {
        // Hot dice y tiradas normales usan el mismo texto del banner
        // ("X PTS EN ESTA TIRADA · TURNO Y").
        _mensaje = null;
      }
    });

    if (_partida.ganador != null) {
      _lanzarVictoria();
      return;
    }

    if (resumen.bust) {
      Future<void>.delayed(const Duration(milliseconds: 1100), () {
        if (!mounted || _partida.ganador != null) return;
        setState(() {
          pasarTurno(_partida);
          _ultimaTirada = null;
          _ultimoResumen = null;
          _mensaje = null;
        });
      });
    }
  }

  void _responderEspecial(bool aceptar) {
    final tirada = _ultimaTirada;
    if (tirada == null) return;
    _aplicar(tirada, aceptar ? tirada.combosOpcionales.first.especial : null);
  }

  void _registrarMejorTirada(String nombre, int puntos) {
    if (puntos > _mejorTiradaPartida) {
      _mejorTiradaPartida = puntos;
      _mejorTiradaJugador = nombre;
    }
  }

  void _plantarse() {
    if (!puedePlantarse(_partida) || _esperandoEspecial) return;
    final nombre = _partida.jugadorActual.nombre;
    final sumados = _partida.turno.puntosTurno;
    final banco = plantarse(_partida);

    setState(() {
      switch (banco.motivo) {
        case 'apertura':
          _mensaje = 'No llegaste a $apertura. Seguís en ${_pts(banco.puntos)}.';
        case 'pasado':
          _mensaje =
              'Te pasaste (${_pts(banco.intento ?? 0)}). Seguís en ${_pts(banco.puntos)}.';
        case 'victoria':
          _registrarMejorTirada(nombre, sumados);
          _mensaje = '¡$nombre llega a $meta y gana!';
        case 'banco':
          _registrarMejorTirada(nombre, banco.sumados ?? sumados);
          _mensaje =
              'Bancás ${_pts(banco.sumados ?? 0)}. Total: ${_pts(banco.puntos)}.';
        default:
          _mensaje = null;
      }
    });


    if (_partida.ganador != null) {
      _lanzarVictoria();
      return;
    }

    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || _partida.ganador != null) return;
      setState(() {
        pasarTurno(_partida);
        _ultimaTirada = null;
        _ultimoResumen = null;
        _mensaje = null;
      });
    });
  }

  List<bool> _dadosQueSuman() {
    final tirada = _ultimaTirada;
    final resumen = _ultimoResumen;
    if (tirada == null || resumen == null || resumen.bust) {
      return List.filled(tirada?.dados.length ?? 0, false);
    }
    return marcarDadosQueSuman(
      tirada.dados,
      resumen.combos.map((c) => ComboUsados(c.dadosUsados)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final j = _partida.jugadorActual;
    final t = _partida.turno;
    final terminada = _partida.ganador != null;
    final ptsTirada = (_ultimoResumen != null && !_ultimoResumen!.bust)
        ? _ultimoResumen!.puntosTirada
        : 0;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Stack(
        children: [
          const Positioned.fill(child: _EpicBackdrop()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _Header(
                                dados: _partida.modo.dados,
                                onMenu: terminada ? () {} : _abrirMenu,
                                onSettings: () {
                                  setState(() {
                                    _mostrarAjustes = true;
                                    _mostrarMenu = false;
                                    _confirmarRendicion = false;
                                  });
                                },
                              ),
                              const SizedBox(height: 6),
                              for (var i = 0;
                                  i < _partida.jugadores.length;
                                  i++) ...[
                                _PlayerCard(
                                  jugador: _partida.jugadores[i],
                                  index: i,
                                  activo: !terminada &&
                                      identical(_partida.jugadores[i], j),
                                  esTu: i == 0,
                                  puedeRenombrar: widget.partidaRapida &&
                                      !terminada,
                                  onRenombrar: widget.partidaRapida &&
                                          !terminada
                                      ? () => _renombrarJugador(i)
                                      : null,
                                ),
                                const SizedBox(height: 6),
                              ],
                              Center(
                                child: _MejorTiradaBanner(
                                  puntos: _mejorTiradaPartida,
                                  jugador: _mejorTiradaJugador,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _TurnoBanner(
                                nombre: terminada
                                    ? (_partida.ganador ?? '')
                                    : j.nombre,
                                terminada: terminada,
                                ptsTurno: t.puntosTurno,
                                ptsTirada: ptsTirada,
                                mensaje: _mensaje,
                              ),
                              const SizedBox(height: 6),
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Margen simétrico solo si el botón de
                                  // testing está visible (Modo Dios).
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: widget.modoDios ? 46 : 0,
                                    ),
                                    child: _DadosZona(
                                      cantidad: _partida.modo.dados,
                                      dados: _ultimaTirada?.dados,
                                      suman: _dadosQueSuman(),
                                    ),
                                  ),
                                  // TEMPORAL (testing): forzar próxima tirada
                                  if (widget.modoDios)
                                    Positioned(
                                      right: 0,
                                      child: Tooltip(
                                        message: _dadosForzados == null
                                            ? 'Forzar próxima tirada'
                                            : 'Próxima: ${_dadosForzados!.join(' ')}',
                                        child: Material(
                                          color: AppColors.carta,
                                          shape: const CircleBorder(),
                                          child: InkWell(
                                            customBorder: const CircleBorder(),
                                            onTap: terminada
                                                ? null
                                                : _configurarDadosForzados,
                                            child: Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: _dadosForzados != null
                                                      ? AppColors.mint
                                                      : AppColors.textoSuave
                                                          .withValues(
                                                              alpha: 0.5),
                                                  width: _dadosForzados != null
                                                      ? 2
                                                      : 1,
                                                ),
                                                boxShadow:
                                                    _dadosForzados != null
                                                        ? neonGlow(
                                                            AppColors.mint,
                                                            blur: 10)
                                                        : null,
                                              ),
                                              child: Icon(
                                                Icons.bug_report,
                                                size: 20,
                                                color: _dadosForzados != null
                                                    ? AppColors.mint
                                                    : AppColors.textoSuave,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _CombosBar(
                                combos: (_ultimoResumen != null &&
                                        !_ultimoResumen!.bust)
                                    ? _ultimoResumen!.combos
                                    : const [],
                                total: ptsTirada,
                              ),
                              const SizedBox(height: 6),
                              if (_esperandoEspecial &&
                                  _ultimaTirada != null) ...[
                                Text(
                                  'Sacaste ${nombreEspecial(_ultimaTirada!.combosOpcionales.first.especial!)} '
                                  '(${_ultimaTirada!.combosOpcionales.first.puntos} pts). ¿Aceptás?',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _ArcadeButton(
                                  label: 'ACEPTAR ESPECIAL',
                                  icon: Icons.auto_awesome,
                                  tono: _BotonTono.dorado,
                                  onPressed: () => _responderEspecial(true),
                                ),
                                const SizedBox(height: 6),
                                _ArcadeButton(
                                  label: 'COMBOS NORMALES',
                                  icon: Icons.casino_outlined,
                                  tono: _BotonTono.violeta,
                                  onPressed: () => _responderEspecial(false),
                                ),
                              ] else if (!terminada) ...[
                                _ArcadeButton(
                                  label: 'TIRAR DADOS',
                                  icon: Icons.casino,
                                  tono: _BotonTono.dorado,
                                  onPressed: _tirar,
                                ),
                                const SizedBox(height: 6),
                                _ArcadeButton(
                                  label: !j.abierto &&
                                          t.puntosTurno < apertura
                                      ? 'PLANTARSE · FALTAN ${_pts(apertura - t.puntosTurno)}'
                                      : 'PLANTARSE',
                                  icon: Icons.pan_tool_alt_outlined,
                                  tono: _BotonTono.violeta,
                                  onPressed: puedePlantarse(_partida)
                                      ? _plantarse
                                      : null,
                                ),
                              ] else
                                _ArcadeButton(
                                  label: 'VOLVER',
                                  icon: Icons.arrow_back,
                                  tono: _BotonTono.dorado,
                                  onPressed: () =>
                                      Navigator.of(context).pop(),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (_mostrarMenu && !terminada)
            Positioned.fill(
              child: _PartidaMenuOverlay(
                jugador: j.nombre,
                confirmarRendicion: _confirmarRendicion,
                onCerrar: _cerrarMenu,
                onReglas: () {
                  _cerrarMenu();
                  _mostrarReglas();
                },
                onRendirse: () =>
                    setState(() => _confirmarRendicion = true),
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
          if (_mostrarVictoria && _partida.ganador != null)
            Positioned.fill(
              child: VictoriaOverlay(
                ganador: _partida.ganador!,
                estadisticas: _stats,
                subtitulo: _subtituloVictoria,
                animaciones: _ajustes.animaciones,
                onVolverAJugar: _volverAJugar,
                onVolver: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fondo épico: rayos láser diagonales + destellos + resplandor central.
class _EpicBackdrop extends StatelessWidget {
  const _EpicBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.25),
          radius: 1.25,
          colors: [
            Color(0xFF321A5E),
            Color(0xFF1B0D38),
            Color(0xFF0A0418),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: CustomPaint(painter: _LasersPainter(), size: Size.infinite),
    );
  }
}

class _LasersPainter extends CustomPainter {
  static const _colores = [
    AppColors.acento,
    AppColors.azul,
    AppColors.rosa,
    AppColors.violeta,
    AppColors.mint,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height * 0.30);
    final rng = math.Random(11);

    // Rayos láser que salen del centro hacia afuera
    for (var i = 0; i < 22; i++) {
      final angulo = rng.nextDouble() * math.pi * 2;
      final largo = size.longestSide * (0.5 + rng.nextDouble() * 0.6);
      final color = _colores[i % _colores.length];
      final ancho = 1.2 + rng.nextDouble() * 2.6;

      final fin = Offset(
        centro.dx + math.cos(angulo) * largo,
        centro.dy + math.sin(angulo) * largo,
      );
      final inicio = Offset(
        centro.dx + math.cos(angulo) * 30,
        centro.dy + math.sin(angulo) * 30,
      );

      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: 0.5),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromPoints(inicio, fin))
        ..strokeWidth = ancho
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(inicio, fin, paint);
    }

    // Destellos / partículas brillantes
    for (var i = 0; i < 70; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 0.6 + rng.nextDouble() * 2.2;
      final color = _colores[i % _colores.length];
      final paint = Paint()
        ..color = color.withValues(alpha: 0.25 + rng.nextDouble() * 0.45);
      canvas.drawCircle(Offset(x, y), r, paint);

      // Cruz de brillo en algunas estrellas
      if (i % 6 == 0) {
        final linea = Paint()
          ..color = color.withValues(alpha: 0.5)
          ..strokeWidth = 0.8;
        canvas.drawLine(Offset(x - r * 3, y), Offset(x + r * 3, y), linea);
        canvas.drawLine(Offset(x, y - r * 3), Offset(x, y + r * 3), linea);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.dados,
    required this.onMenu,
    required this.onSettings,
  });

  final int dados;
  final VoidCallback onMenu;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIcon(icon: Icons.menu, onTap: onMenu),
        Expanded(
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // Sombra 3D del título
                  Text(
                    'DIEZ MIL',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 7
                        ..color = const Color(0xFF2A1160),
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white,
                        Color(0xFFFFE082),
                        AppColors.acento,
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'DIEZ MIL',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: AppColors.acento, blurRadius: 18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.azulSuave, AppColors.violeta],
                  ),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: AppColors.acento.withValues(alpha: 0.8),
                  ),
                  boxShadow: neonGlow(AppColors.azul, blur: 10),
                ),
                child: Text(
                  '★  $dados DADOS  ★',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        _RoundIcon(icon: Icons.settings, onTap: onSettings),
      ],
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
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border:
                Border.all(color: AppColors.rosa.withValues(alpha: 0.85), width: 1.6),
            boxShadow: neonGlow(AppColors.rosa, blur: 10),
          ),
          child: Icon(icon, color: AppColors.texto, size: 20),
        ),
      ),
    );
  }
}

/// Menú central: jugador actual, reglas y rendirse.
class _PartidaMenuOverlay extends StatelessWidget {
  const _PartidaMenuOverlay({
    required this.jugador,
    required this.confirmarRendicion,
    required this.onCerrar,
    required this.onReglas,
    required this.onRendirse,
    required this.onConfirmarRendicion,
    required this.onCancelarRendicion,
  });

  final String jugador;
  final bool confirmarRendicion;
  final VoidCallback onCerrar;
  final VoidCallback onReglas;
  final VoidCallback onRendirse;
  final VoidCallback onConfirmarRendicion;
  final VoidCallback onCancelarRendicion;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: Center(
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
                          icon: const Icon(Icons.close, color: AppColors.texto),
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
                      'Turno actual',
                      style: TextStyle(
                        color: AppColors.textoSuave.withValues(alpha: 0.95),
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
                    if (!confirmarRendicion)
                      _ArcadeButton(
                        label: 'RENDIRSE',
                        icon: Icons.flag_rounded,
                        tono: _BotonTono.rojo,
                        onPressed: onRendirse,
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
    );
  }
}

class _MejorTiradaBanner extends StatelessWidget {
  const _MejorTiradaBanner({
    required this.puntos,
    this.jugador,
  });

  final int puntos;
  final String? jugador;

  @override
  Widget build(BuildContext context) {
    const violeta = AppColors.violeta;
    const rosa = AppColors.rosa;
    final detalle = puntos > 0
        ? '${jugador != null ? '${jugador!.toUpperCase()} · ' : ''}${_pts(puntos)} PTS'
        : '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A1450).withValues(alpha: 0.95),
            const Color(0xFF1A0B33).withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rosa.withValues(alpha: 0.85),
          width: 1.4,
        ),
        boxShadow: [
          ...neonGlow(rosa, blur: 12),
          ...neonGlow(violeta, blur: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events,
            color: AppColors.acento,
            size: 16,
            shadows: [
              Shadow(color: AppColors.acento, blurRadius: 10),
            ],
          ),
          const SizedBox(width: 8),
          const Text(
            'MEJOR TIRADA',
            style: TextStyle(
              color: AppColors.texto,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            detalle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: violeta,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: violeta.withValues(alpha: 0.85),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.jugador,
    required this.index,
    required this.activo,
    required this.esTu,
    this.puedeRenombrar = false,
    this.onRenombrar,
  });

  final Jugador jugador;
  final int index;
  final bool activo;
  final bool esTu;
  final bool puedeRenombrar;
  final VoidCallback? onRenombrar;

  @override
  Widget build(BuildContext context) {
    final accent = index.isEven ? AppColors.acento : AppColors.azul;
    final pct = (jugador.puntos / meta).clamp(0.0, 1.0);
    final faltan = math.max(0, meta - jugador.puntos);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.carta.withValues(alpha: 0.95),
            const Color(0xFF190B33).withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: activo ? accent : accent.withValues(alpha: 0.55),
          width: activo ? 2.4 : 1.4,
        ),
        boxShadow: activo
            ? neonGlow(accent, blur: 20, spread: 1)
            : neonGlow(accent, blur: 8),
      ),
      child: Row(
        children: [
          // Avatar con anillo brillante y corona
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent,
                      accent.withValues(alpha: 0.25),
                    ],
                  ),
                  boxShadow: neonGlow(accent, blur: 14),
                ),
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.fondoSuave,
                  ),
                  child: Icon(
                    index.isEven ? Icons.face : Icons.face_6,
                    color: accent,
                    size: 32,
                  ),
                ),
              ),
              if (activo)
                const Positioned(
                  top: -12,
                  child: Icon(
                    Icons.workspace_premium,
                    color: AppColors.acento,
                    size: 22,
                    shadows: [
                      Shadow(color: AppColors.acento, blurRadius: 12),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Columna principal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: puedeRenombrar ? onRenombrar : null,
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
                                      color: AppColors.violeta
                                          .withValues(alpha: 0.7),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.45),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  )
                                : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    jugador.nombre.toUpperCase(),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                if (puedeRenombrar) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.edit_rounded,
                                    size: 14,
                                    color: AppColors.violeta
                                        .withValues(alpha: 0.95),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (activo) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFE082), AppColors.acento],
                          ),
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: neonGlow(AppColors.acento, blur: 8),
                        ),
                        child: Text(
                          esTu ? 'TU TURNO' : 'SU TURNO',
                          style: const TextStyle(
                            color: Color(0xFF1A0A00),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${_pts(jugador.puntos)} PTS',
                  style: TextStyle(
                    color: accent,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    shadows: [
                      Shadow(
                        color: accent.withValues(alpha: 0.8),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.emoji_events,
                        color: AppColors.acento, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      'FALTAN ${_pts(faltan)} PTS PARA GANAR',
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.95),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 9,
                          backgroundColor:
                              Colors.black.withValues(alpha: 0.45),
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(pct * 100).round()}%',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Panel de estado a la derecha
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Chip(
                  icon: jugador.abierto
                      ? Icons.check_circle
                      : Icons.lock_outline,
                  label: jugador.abierto ? 'ABIERTO' : 'SIN ABRIR',
                  color: jugador.abierto
                      ? AppColors.mint
                      : AppColors.textoSuave,
                ),
                const SizedBox(height: 5),
                if (activo)
                  const _Chip(
                    icon: Icons.campaign,
                    label: 'SU TURNO',
                    color: AppColors.acentoSuave,
                  )
                else
                  const _Chip(
                    icon: Icons.schedule,
                    label: 'ESPERANDO',
                    color: AppColors.azul,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color, shadows: [
          Shadow(color: color.withValues(alpha: 0.8), blurRadius: 8),
        ]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _TurnoBanner extends StatelessWidget {
  const _TurnoBanner({
    required this.nombre,
    required this.terminada,
    required this.ptsTurno,
    required this.ptsTirada,
    required this.mensaje,
  });

  final String nombre;
  final bool terminada;
  final int ptsTurno;
  final int ptsTirada;
  final String? mensaje;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '«',
              style: TextStyle(
                color: AppColors.violeta,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.violeta,
                    AppColors.rosa,
                    AppColors.acentoSuave,
                  ],
                ),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                boxShadow: neonGlow(AppColors.rosa, blur: 14),
              ),
              child: Text(
                terminada
                    ? '★ GANÓ: ${nombre.toUpperCase()} ★'
                    : '★ TURNO DE: ${nombre.toUpperCase()} ★',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.6,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '»',
              style: TextStyle(
                color: AppColors.violeta,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: Center(
            child: Text(
              mensaje ??
                  (terminada
                      ? 'PARTIDA TERMINADA'
                      : ptsTirada > 0
                          ? '$ptsTirada PTS EN ESTA TIRADA · TURNO ${_pts(ptsTurno)}'
                          : 'TURNO: ${_pts(ptsTurno)} PTS'),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.mint,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                shadows: [
                  Shadow(
                    color: AppColors.mint.withValues(alpha: 0.7),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DadosZona extends StatelessWidget {
  const _DadosZona({
    required this.cantidad,
    required this.dados,
    required this.suman,
  });

  final int cantidad;
  final List<int>? dados;
  final List<bool> suman;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tamano = ((constraints.maxWidth - (cantidad - 1) * 10) /
                cantidad)
            .clamp(44.0, 76.0);

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: RadialGradient(
              radius: 1.2,
              colors: [
                AppColors.violeta.withValues(alpha: 0.3),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < cantidad; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                if (dados == null)
                  DadoFace(valor: 1, vacio: true, tamano: tamano)
                else if (i < dados!.length)
                  DadoFace(
                    valor: dados![i],
                    suma: i < suman.length && suman[i],
                    tamano: tamano,
                  )
                else
                  DadoFace(valor: 1, vacio: true, tamano: tamano),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CombosBar extends StatelessWidget {
  const _CombosBar({required this.combos, required this.total});

  final List<Combo> combos;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.carta,
            Color(0xFF190B33),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.violeta.withValues(alpha: 0.6)),
        boxShadow: neonGlow(AppColors.violeta, blur: 10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.star,
            color: AppColors.acento,
            size: 20,
            shadows: [Shadow(color: AppColors.acento, blurRadius: 10)],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'COMBOS ACTIVOS',
                  style: TextStyle(
                    color: AppColors.acento,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                if (combos.isEmpty)
                  const Text(
                    'Tirá los dados para sumar puntos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textoSuave,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < combos.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          _ComboChip(combo: combos[i]),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'TOTAL +$total',
            style: TextStyle(
              color: AppColors.mint,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: AppColors.mint.withValues(alpha: 0.85),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip visual: "3 [dado] (+500)" o etiqueta legible para especiales.
class _ComboChip extends StatelessWidget {
  const _ComboChip({required this.combo});

  final Combo combo;

  static const _nombresEspeciales = {
    'escalera': 'Escalera',
    'tres_pares': 'Tres pares',
    'cuatro_y_par': 'Cuatro y par',
  };

  @override
  Widget build(BuildContext context) {
    final especial = _nombresEspeciales[combo.nombre];
    final caraUnica = combo.dadosUsados.isNotEmpty &&
        combo.dadosUsados.every((d) => d == combo.dadosUsados.first);

    final estiloPts = const TextStyle(
      color: AppColors.mint,
      fontSize: 12,
      fontWeight: FontWeight.w900,
    );

    if (especial != null || !caraUnica) {
      return Text(
        '${especial ?? combo.nombre} (+${combo.puntos})',
        style: estiloPts,
      );
    }

    final cantidad = combo.dadosUsados.length;
    final cara = combo.dadosUsados.first;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$cantidad',
          style: estiloPts,
        ),
        const SizedBox(width: 4),
        DadoFace(valor: cara, suma: true, tamano: 18),
        const SizedBox(width: 4),
        Text('(+${combo.puntos})', style: estiloPts),
      ],
    );
  }
}

enum _BotonTono { dorado, violeta, azul, rojo }

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
    final List<Color> colors;
    final Color glow;
    final Color fg;

    switch (tono) {
      case _BotonTono.dorado:
        colors = const [
          Color(0xFFFFF3B0),
          Color(0xFFFFD54F),
          Color(0xFFFF9800),
        ];
        glow = AppColors.acento;
        fg = const Color(0xFF4A1B6D);
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
          boxShadow: enabled ? neonGlow(glow, blur: 16, spread: 1) : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(20),
            splashColor: Colors.white24,
            highlightColor: Colors.white10,
            child: Ink(
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: colors,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.65),
                  width: 1.6,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: fg, size: 24),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        shadows: const [
                          Shadow(color: Colors.white38, blurRadius: 4),
                        ],
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



