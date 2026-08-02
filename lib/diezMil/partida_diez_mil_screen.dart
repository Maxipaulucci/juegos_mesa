import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/dados/dado_widget.dart';
import 'package:app_juegos_mesa/shared/partida_ui/epic_backdrop.dart';
import 'diez_mil_online_codec.dart';
import 'estadisticas.dart';
import 'ia_diez_mil.dart';
import 'motor.dart';
import 'standby_store.dart';
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
    this.contraPc = false,
    this.dificultadPc = DificultadPc.medio,
    this.modoDios = false,
    this.ajustesIniciales = const AjustesEstado(),
    this.resume,
    this.salaCodigo,
    this.miNombre,
  });

  final List<String> nombres;
  final Modo modo;
  /// Solo en partida rápida se puede editar el nombre tocando la tarjeta.
  final bool partidaRapida;
  /// Partida local contra la PC (segundo jugador).
  final bool contraPc;
  /// Cómo juega la PC (solo aplica si [contraPc] es true).
  final DificultadPc dificultadPc;
  /// Muestra el botón temporal para forzar la próxima tirada.
  final bool modoDios;
  final AjustesEstado ajustesIniciales;
  /// Si no es `null`, la pantalla arranca restaurando el estado en memoria.
  final PartidaDiezMilResume? resume;
  /// Código de sala online. Si es no nulo (junto con [miNombre]), la
  /// partida se sincroniza con el rival vía [SalaService].
  final String? salaCodigo;
  /// Nombre del jugador local en la sala online.
  final String? miNombre;

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
  bool _mostrarVictoria = false;
  bool _mostrarMenu = false;
  bool _mostrarAjustes = false;
  bool _confirmarRendicion = false;
  bool _mostrarListaJugadores = false;
  String? _subtituloVictoria;
  int _mejorTiradaPartida = 0;
  String? _mejorTiradaJugador;
  late AjustesEstado _ajustes;
  /// Pausa simple en modo vs PC: el juego queda en espera sin guardar.
  bool _standBy = false;

  // TEMPORAL (testing): fuerza los valores de la próxima tirada.
  List<int>? _dadosForzados;
  int _pcToken = 0;
  /// Puntos que bancó el humano en su último turno (para la IA difícil).
  int _ultimoTurnoHumano = 0;
  /// Animación de caras aleatorias al tirar (como en Decidir orden).
  bool _animandoTirada = false;
  List<int>? _dadosAnimados;
  final _rngTirada = math.Random();

  StreamSubscription<Sala>? _onlineSub;
  int _onlineVersion = 0;
  bool _publicandoOnline = false;

  static const int _maxNombre = 15;

  bool get _turnoDeLaPc =>
      widget.contraPc &&
      _partida.ganador == null &&
      _partida.jugadorActual.nombre == nombreJugadorPc;

  bool get _esOnline => widget.salaCodigo != null && widget.miNombre != null;

  bool get _esMiTurno =>
      !_esOnline ||
      (_partida.ganador == null &&
          _partida.jugadorActual.nombre == widget.miNombre);

  /// Le toca al rival online: hay que bloquear controles y avisar.
  bool get _esperandoRivalOnline =>
      _esOnline && !_esMiTurno && _partida.ganador == null;

  /// Con 3+ activos: una sola tarjeta (turno actual) + botón "Jugadores".
  /// Si en una partida de 3/4 quedan 2 activos, se usa el layout de 2 jugadores.
  bool get _layoutMuchosJugadores => _partida.jugadoresActivos.length >= 3;

  /// Tras bust o pasarse de 10.000 el turno ya está perdido y espera el cambio.
  bool get _esperandoCambioDeTurno {
    final r = _ultimoResumen;
    return r != null && (r.bust || r.pasado);
  }

  bool _puedeRenombrar(int index) {
    if (_esOnline) return false;
    if (_partida.ganador != null) return false;
    if (_partida.jugadores[index].rendido) return false;
    final nombre = _partida.jugadores[index].nombre;
    if (widget.contraPc) return nombre != nombreJugadorPc;
    return widget.partidaRapida;
  }

  @override
  void initState() {
    super.initState();
    if (widget.resume != null) {
      final r = widget.resume!;
      _nombres = r.nombres;
      _ajustes = r.ajustesIniciales;
      _partida = r.partida;
      _stats = r.estadisticas;
      _ultimaTirada = r.ultimaTirada;
      _ultimoResumen = r.ultimoResumen;
      _mensaje = r.mensaje;
      _mejorTiradaPartida = r.mejorTiradaPartida;
      _mejorTiradaJugador = r.mejorTiradaJugador;
      _ultimoTurnoHumano = r.ultimoTurnoHumano;

      _mostrarVictoria = false;
      _mostrarMenu = false;
      _mostrarAjustes = false;
      _confirmarRendicion = false;
      _mostrarListaJugadores = false;
      _subtituloVictoria = null;
      _animandoTirada = false;
      _dadosAnimados = null;
      _dadosForzados = null;
      _standBy = false;
      _pcToken++;
      // Si al reingresar toca jugar a la PC, reprogramamos.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_turnoDeLaPc) _programarJugadaPc();
      });
      if (_esOnline) _iniciarSincronizacionOnline();
      return;
    }

    _nombres = List.of(widget.nombres);
    _ajustes = widget.ajustesIniciales;
    _iniciarPartidaNueva();
    if (_esOnline) _iniciarSincronizacionOnline();
  }

  @override
  void dispose() {
    _onlineSub?.cancel();
    super.dispose();
  }

  void _iniciarSincronizacionOnline() {
    final codigo = widget.salaCodigo;
    if (codigo == null) return;
    if (_onlineVersion < 1) _onlineVersion = 1;
    unawaited(() async {
      try {
        final sala = await SalaService.instance.obtener(codigo);
        if (mounted) _onSalaOnlineActualizada(sala);
      } catch (_) {}
    }());
    _onlineSub = SalaService.instance
        .watch(codigo, intervalo: const Duration(milliseconds: 1200))
        .listen(_onSalaOnlineActualizada);
  }

  /// Aplica el estado remoto si es más nuevo que el nuestro. Preferimos
  /// siempre el estado del servidor por sobre el estado local inicial.
  void _onSalaOnlineActualizada(Sala sala) {
    if (!mounted) return;
    final gameState = sala.gameState;
    if (gameState == null) return;
    final version = (gameState['version'] as num?)?.toInt() ?? 0;
    if (version <= _onlineVersion || _publicandoOnline) return;

    final resultado = applyDiezMilGameState(_partida, gameState);
    setState(() {
      _onlineVersion = version;
      _mostrarVictoria = resultado.mostrarVictoria;
      _subtituloVictoria = resultado.subtituloVictoria;
      _mensaje = resultado.mensaje;
      _ultimaTirada = resultado.ultimaTirada;
      _ultimoResumen = resultado.ultimoResumen;
      _animandoTirada = false;
      _dadosAnimados = null;
    });
  }

  /// Publica nuestro estado tras una acción propia (tirar/plantarse/pasar
  /// turno/rendirse). Se llama solo desde lugares donde el actor local hizo
  /// el cambio; no depende de a quién le toque después.
  Future<void> _publicarEstadoOnline() async {
    if (!_esOnline) return;
    final codigo = widget.salaCodigo;
    if (codigo == null) return;

    _onlineVersion++;
    final gameState = encodeDiezMilGameState(
      partida: _partida,
      version: _onlineVersion,
      mostrarVictoria: _mostrarVictoria,
      subtituloVictoria: _subtituloVictoria,
      mensaje: _mensaje,
      ultimaTirada: _ultimaTirada,
      ultimoResumen: _ultimoResumen,
    );

    _publicandoOnline = true;
    try {
      await SalaService.instance.actualizarJuego(
        codigo: codigo,
        gameState: gameState,
      );
    } catch (_) {
      // Red momentánea: el rival puede quedar un paso atrás hasta la
      // próxima acción local o su propio watch reintentando.
    } finally {
      _publicandoOnline = false;
    }
  }

  void _iniciarPartidaNueva() {
    _pcToken++;
    _partida = nuevaPartida(_nombres, widget.modo);
    _stats = EstadisticasPartida(_nombres);
    iniciarTurno(_partida);
    _ultimaTirada = null;
    _ultimoResumen = null;
    _mensaje = null;
    _mostrarVictoria = false;
    _mostrarMenu = false;
    _mostrarAjustes = false;
    _confirmarRendicion = false;
    _mostrarListaJugadores = false;
    _subtituloVictoria = null;
    _mejorTiradaPartida = 0;
    _mejorTiradaJugador = null;
    _animandoTirada = false;
    _dadosAnimados = null;
    _dadosForzados = null;
    _ultimoTurnoHumano = 0;
    _standBy = false;
  }

  void _volverAJugar() {
    setState(_iniciarPartidaNueva);
  }

  void _programarJugadaPc({int demoraMs = 900}) {
    if (!_turnoDeLaPc) return;
    final token = _pcToken;
    Future<void>.delayed(Duration(milliseconds: demoraMs), () {
      if (!mounted || token != _pcToken || !_turnoDeLaPc) return;
      _ejecutarJugadaPc();
    });
  }

  void _ejecutarJugadaPc() {
    if (!_turnoDeLaPc || _mostrarVictoria || _standBy) return;

    // Tras una tirada con puntos: plantarse o seguir.
    if (_ultimoResumen != null &&
        !_ultimoResumen!.bust &&
        _partida.turno.puntosTurno > 0) {
      if (iaDebePlantarse(
        _partida,
        dificultad: widget.dificultadPc,
        ultimoTurnoRival: _ultimoTurnoHumano,
      )) {
        _plantarse();
        return;
      }
    }

    _tirar();
  }

  void _pasarTurnoYContinuar() {
    if (!mounted || _partida.ganador != null || _standBy) return;
    setState(() {
      pasarTurno(_partida);
      _ultimaTirada = null;
      _ultimoResumen = null;
      _mensaje = null;
    });
    _publicarEstadoOnline();
    _programarJugadaPc();
  }

  void _continuarDesdeStandBy() {
    if (!widget.contraPc) return;
    setState(() => _standBy = false);
    if (_turnoDeLaPc) _programarJugadaPc();
  }

  void _salirGuardandoResumeYVolverAlMenu() {
    if (!widget.contraPc) return;
    if (_partida.ganador != null) return;

    DiezMilStandByStore.guardar(
      PartidaDiezMilResume(
        partida: _partida,
        estadisticas: _stats,
        nombres: _nombres,
        modo: widget.modo,
        contraPc: true,
        dificultadPc: widget.dificultadPc,
        modoDios: widget.modoDios,
        ajustesIniciales: _ajustes,
        ultimaTirada: _ultimaTirada,
        ultimoResumen: _ultimoResumen,
        mensaje: _mensaje,
        mejorTiradaPartida: _mejorTiradaPartida,
        mejorTiradaJugador: _mejorTiradaJugador,
        ultimoTurnoHumano: _ultimoTurnoHumano,
      ),
    );

    _pcToken++; // cancela cualquier jugada pendiente
    Navigator.of(context).pop();
  }

  Future<void> _renombrarJugador(int index) async {
    if (!_puedeRenombrar(index)) return;
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
              const SizedBox(height: 20),
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
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.peligro,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cancelar'),
              ),
            ],
          ),
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

  void _lanzarVictoria({
    Duration demora = const Duration(milliseconds: 450),
  }) {
    if (_mostrarVictoria) return;
    final token = _pcToken;
    Future<void>.delayed(demora, () {
      if (!mounted ||
          token != _pcToken ||
          _partida.ganador == null) {
        return;
      }
      setState(() => _mostrarVictoria = true);
      _publicarEstadoOnline();
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
    setState(() {
      _mostrarMenu = true;
      _confirmarRendicion = false;
      _mostrarListaJugadores = false;
      _mostrarAjustes = false;
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
    // En vs PC siempre se rinde el humano, aunque sea turno de la máquina.
    final rendido = widget.contraPc
        ? _partida.jugadores.firstWhere(
            (j) => j.nombre != nombreJugadorPc,
            orElse: () => _partida.jugadorActual,
          )
        : _partida.jugadorActual;
    if (rendido.rendido) return;

    final eraSuTurno = identical(rendido, _partida.jugadorActual);
    final partidaLarga = _partida.jugadores.length >= 3;

    _pcToken++;
    setState(() {
      rendido.rendido = true;
      _mostrarMenu = false;
      _confirmarRendicion = false;
      _animandoTirada = false;
      _dadosAnimados = null;
      _ultimaTirada = null;
      _ultimoResumen = null;
      _mensaje = '${rendido.nombre} se ha rendido.';

      if (eraSuTurno) {
        _partida.turno.puntosTurno = 0;
      }

      final activos = _partida.jugadoresActivos;
      // Al pasar a layout de 2 (o menos), ocultar el overlay "Jugadores".
      if (activos.length < 3) {
        _mostrarListaJugadores = false;
      }
      // 2 jugadores, o quedó uno solo en 3/4: gana el que sigue en pie.
      if (!partidaLarga || activos.length <= 1) {
        if (activos.isEmpty) return;
        final ganador = activos.first;
        _partida.ganador = ganador.nombre;
        _subtituloVictoria = 'Has ganado por abandono';
      } else if (eraSuTurno) {
        // Siguen varios activos: pasa al siguiente que no se haya rendido.
        pasarTurno(_partida);
      }
    });
    _publicarEstadoOnline();

    if (_partida.ganador != null) {
      _lanzarVictoria();
    } else {
      _programarJugadaPc();
    }
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
                'Escribí de 1 a $cantidad números del 1 al 6, sin espacios.\n'
                'Los que falten salen al azar.\n'
                'Ej: 1111',
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
                  if (texto.isEmpty ||
                      texto.length > cantidad ||
                      texto.split('').any((c) {
                        final n = int.tryParse(c);
                        return n == null || n < 1 || n > 6;
                      })) {
                    setDialogState(() {
                      error =
                          'Ingresá entre 1 y $cantidad números entre 1 y 6.';
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

  Future<void> _tirar() async {
    if (_partida.ganador != null ||
        _esperandoCambioDeTurno ||
        _partida.jugadorActual.rendido ||
        _standBy ||
        _animandoTirada ||
        !_esMiTurno) {
      return;
    }

    final token = _pcToken;
    final forzados = _dadosForzados;
    _dadosForzados = null;

    // Se tira ya el resultado real; la animación solo lo “revela”.
    final cantidad = _partida.turno.dadosEnMano;
    final dadosFinales = forzados == null
        ? null
        : [
            ...forzados,
            ...tirar(math.max(0, cantidad - forzados.length), _rngTirada),
          ];
    final tirada = ejecutarTirada(_partida, dadosForzados: dadosFinales);
    final resultado = filtrarEspecialesQuePasanMeta(_partida, tirada);
    final finales = resultado.dados;

    if (_ajustes.animaciones) {
      setState(() {
        _animandoTirada = true;
        _dadosAnimados =
            List.generate(finales.length, (_) => _rngTirada.nextInt(6) + 1);
        _mensaje = null;
      });

      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 55));
        if (!mounted || token != _pcToken) return;
        setState(() {
          _dadosAnimados =
              List.generate(finales.length, (_) => _rngTirada.nextInt(6) + 1);
        });
      }
      if (!mounted || token != _pcToken) return;
    }

    // Fin de animación + resultado en el mismo frame.
    // Especiales (tres pares / cuatro+par) se aplican solos si no pasan meta.
    if (!mounted || token != _pcToken) return;
    final especial = hayOpcionales(resultado)
        ? resultado.combosOpcionales.first.especial
        : null;
    _aplicar(resultado, especial);
  }

  void _aplicar(ResultadoTirada resultado, Especial? especial) {
    final nombre = _partida.jugadorActual.nombre;
    final turnoPrevio = _partida.turno.puntosTurno;
    final resumen = aplicarPuntosTirada(_partida, resultado, especial);
    final puntosReg = resumen.bust ? 0 : resumen.puntosTirada;
    _stats.registrar(nombre, puntosReg);

    setState(() {
      _animandoTirada = false;
      _dadosAnimados = null;
      _ultimaTirada = resultado;
      _ultimoResumen = resumen;
      // Al ganar por tirada se banca el turno completo: cuenta como su total.
      if (resumen.victoria) {
        _registrarMejorTirada(nombre, turnoPrevio + puntosReg);
      }
      if (resumen.victoria) {
        // Se muestra la tirada/turno en el banner (no "X gana!").
        _mensaje = null;
      } else if (resumen.pasado) {
        _mensaje =
            '¡Te pasaste de 10.000 (${_pts(resumen.intentoTotal ?? 0)})! '
            'Perdés los ${_pts(resumen.puntosPerdidos)} pts del turno.';
      } else if (resumen.bust) {
        _mensaje =
            'No sumaste nada. Perdés los ${resumen.puntosPerdidos} pts del turno.';
      } else {
        // Hot dice y tiradas normales usan el mismo texto del banner
        // ("X PTS EN ESTA TIRADA · TURNO Y").
        _mensaje = null;
      }
    });
    _publicarEstadoOnline();

    if (_partida.ganador != null) {
      _lanzarVictoria(
        demora: resultado.victoriaInmediata
            ? const Duration(milliseconds: 450)
            : const Duration(seconds: 3),
      );
      return;
    }

    if (resumen.bust || resumen.pasado) {
      final token = _pcToken;
      Future<void>.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted || token != _pcToken || _partida.ganador != null) return;
        _pasarTurnoYContinuar();
      });
      return;
    }

    if (_turnoDeLaPc) _programarJugadaPc(demoraMs: 850);
  }

  void _registrarMejorTirada(String nombre, int puntos) {
    if (puntos > _mejorTiradaPartida) {
      _mejorTiradaPartida = puntos;
      _mejorTiradaJugador = nombre;
    }
  }

  void _plantarse() {
    if (!puedePlantarse(_partida) ||
        _esperandoCambioDeTurno ||
        _animandoTirada ||
        _partida.jugadorActual.rendido ||
        _standBy ||
        !_esMiTurno) {
      return;
    }
    final nombre = _partida.jugadorActual.nombre;
    final sumados = _partida.turno.puntosTurno;
    final banco = plantarse(_partida);

    setState(() {
      switch (banco.motivo) {
        case 'apertura':
          _mensaje =
              'No llegaste a ${_partida.modo.apertura}. Seguís en ${_pts(banco.puntos)}.';
        case 'pasado':
          _mensaje =
              'Te pasaste (${_pts(banco.intento ?? 0)}). Seguís en ${_pts(banco.puntos)}.';
        case 'victoria':
          _registrarMejorTirada(nombre, sumados);
          // Banner: puntos del turno ganador (no "X gana!").
          _mensaje = null;
        case 'banco':
          _registrarMejorTirada(nombre, banco.sumados ?? sumados);
          if (widget.contraPc && nombre != nombreJugadorPc) {
            _ultimoTurnoHumano = banco.sumados ?? sumados;
          }
          _mensaje =
              'Bancás ${_pts(banco.sumados ?? 0)}. Total: ${_pts(banco.puntos)}.';
        default:
          _mensaje = null;
      }
    });
    _publicarEstadoOnline();

    if (_partida.ganador != null) {
      _lanzarVictoria();
      return;
    }

    final token = _pcToken;
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || token != _pcToken || _partida.ganador != null) return;
      _pasarTurnoYContinuar();
    });
  }

  List<bool> _dadosQueSuman() {
    final tirada = _ultimaTirada;
    final resumen = _ultimoResumen;
    if (tirada == null) return const [];
    if (resumen == null || resumen.bust) {
      return List.filled(tirada.dados.length, false);
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
    // Tras victoria el turno queda en 0; el resumen guarda el total bancado.
    final ptsTurno = (_ultimoResumen != null && !_ultimoResumen!.bust)
        ? _ultimoResumen!.puntosTurno
        : t.puntosTurno;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Stack(
        children: [
          const Positioned.fill(child: EpicBackdrop()),
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
                                onMenu: _abrirMenu,
                                onSettings: () {
                                  setState(() {
                                    _mostrarAjustes = true;
                                    _mostrarMenu = false;
                                    _confirmarRendicion = false;
                                    _mostrarListaJugadores = false;
                                  });
                                },
                              ),
                              const SizedBox(height: 6),
                              if (_layoutMuchosJugadores) ...[
                                _PlayerCard(
                                  jugador: j,
                                  index: _partida.indiceTurno,
                                  activo: !terminada,
                                  esTu: _partida.indiceTurno == 0,
                                  puedeRenombrar:
                                      _puedeRenombrar(_partida.indiceTurno),
                                  onRenombrar:
                                      _puedeRenombrar(_partida.indiceTurno)
                                          ? () => _renombrarJugador(
                                                _partida.indiceTurno,
                                              )
                                          : null,
                                ),
                                const SizedBox(height: 6),
                                // Mismo hueco que la 2.ª tarjeta; el botón
                                // conserva su tamaño original, centrado.
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    IgnorePointer(
                                      child: Opacity(
                                        opacity: 0,
                                        child: _PlayerCard(
                                          jugador: j,
                                          index: _partida.indiceTurno,
                                          activo: false,
                                          esTu: false,
                                        ),
                                      ),
                                    ),
                                    _ArcadeButton(
                                      label: 'JUGADORES',
                                      icon: Icons.groups_rounded,
                                      tono: _BotonTono.violeta,
                                      onPressed: () => setState(
                                        () => _mostrarListaJugadores = true,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                              ] else
                                // 2 jugadores (partida de 2, o 3/4 con 2 vivos):
                                // ambas tarjetas a la vista, color = índice original.
                                for (var i = 0;
                                    i < _partida.jugadores.length;
                                    i++)
                                  if (!_partida.jugadores[i].rendido) ...[
                                    _PlayerCard(
                                      jugador: _partida.jugadores[i],
                                      index: i,
                                      activo: !terminada &&
                                          identical(_partida.jugadores[i], j),
                                      esTu: i == 0,
                                      puedeRenombrar: _puedeRenombrar(i),
                                      onRenombrar: _puedeRenombrar(i)
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
                                ptsTurno: ptsTurno,
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
                                      dados: _animandoTirada
                                          ? _dadosAnimados
                                          : _ultimaTirada?.dados,
                                      suman: _animandoTirada
                                          ? List.filled(
                                              _dadosAnimados?.length ?? 0,
                                              false,
                                            )
                                          : _dadosQueSuman(),
                                    ),
                                  ),
                                  // TEMPORAL (testing): forzar próxima tirada
                                  if (widget.modoDios)
                                    Positioned(
                                      right: 0,
                                      child: Tooltip(
                                        excludeFromSemantics: true,
                                        message: _dadosForzados == null
                                            ? 'Forzar próxima tirada'
                                            : 'Próxima: ${_dadosForzados!.join(' ')}'
                                                ' + azar',
                                        child: Material(
                                          color: AppColors.carta,
                                          shape: const CircleBorder(),
                                          child: InkWell(
                                            customBorder: const CircleBorder(),
                                            onTap: terminada ||
                                                    _turnoDeLaPc ||
                                                    _esperandoRivalOnline
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
                              if (!terminada) ...[
                                if (_esperandoCambioDeTurno ||
                                    _turnoDeLaPc ||
                                    _esperandoRivalOnline)
                                  // Misma altura que TIRAR + espacio + PLANTARSE
                                  // para que el layout no salte al turno de la PC.
                                  SizedBox(
                                    height: 52 + 6 + 52,
                                    child: Center(
                                      child: Text(
                                        _esperandoCambioDeTurno
                                            ? 'Cambiando de turno…'
                                            : (_turnoDeLaPc
                                                ? 'Turno de la PC…'
                                                : 'Turno de ${_partida.jugadorActual.nombre}…'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: AppColors.textoSuave,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  )
                                else ...[
                                  _ArcadeButton(
                                    label: 'TIRAR DADOS',
                                    icon: Icons.casino,
                                    tono: _BotonTono.dorado,
                                    onPressed: _animandoTirada ? null : _tirar,
                                  ),
                                  const SizedBox(height: 6),
                                  _ArcadeButton(
                                    label: !j.abierto &&
                                            t.puntosTurno <
                                                _partida.modo.apertura
                                        ? 'PLANTARSE · FALTAN ${_pts(_partida.modo.apertura - t.puntosTurno)}'
                                        : 'PLANTARSE',
                                    icon: Icons.pan_tool_alt_outlined,
                                    tono: _BotonTono.violeta,
                                    onPressed: (!_animandoTirada &&
                                            puedePlantarse(_partida))
                                        ? _plantarse
                                        : null,
                                  ),
                                ],
                              ] else
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    '¡${_partida.ganador} LLEGÓ A 10.000!',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.acento,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
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
          if (_mostrarListaJugadores)
            Positioned.fill(
              child: _ListaJugadoresOverlay(
                jugadores: _partida.jugadores,
                indiceActivo: terminada ? -1 : _partida.indiceTurno,
                puedeRenombrar: _puedeRenombrar,
                onRenombrar: (i) {
                  setState(() => _mostrarListaJugadores = false);
                  _renombrarJugador(i);
                },
                onCerrar: () =>
                    setState(() => _mostrarListaJugadores = false),
              ),
            ),
          if (_standBy)
            Positioned.fill(
              child: _StandByOverlay(
                onContinuar: _continuarDesdeStandBy,
                onVolverAlMenu: () {
                  _pcToken++;
                  Navigator.of(context).pop();
                },
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
          // Menú / ajustes encima de la victoria para poder usarlos con el ojo.
          if (_mostrarMenu)
            Positioned.fill(
              child: _PartidaMenuOverlay(
                jugador: terminada
                    ? (_partida.ganador ?? j.nombre)
                    : (widget.contraPc
                        ? _partida.jugadores
                            .firstWhere(
                              (p) => p.nombre != nombreJugadorPc,
                              orElse: () => j,
                            )
                            .nombre
                        : j.nombre),
                esContraPc: widget.contraPc,
                partidaTerminada: terminada,
                confirmarRendicion: _confirmarRendicion && !widget.contraPc,
                onCerrar: _cerrarMenu,
                onReglas: () {
                  _cerrarMenu();
                  _mostrarReglas();
                },
                onRendirse: terminada
                    ? () => Navigator.of(context).pop()
                    : (widget.contraPc
                        ? _salirGuardandoResumeYVolverAlMenu
                        : () => setState(() => _confirmarRendicion = true)),
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
        ],
      ),
    );
  }
}

/// Fondo épico: rayos láser diagonales + destellos + resplandor central.

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
class _ListaJugadoresOverlay extends StatelessWidget {
  const _ListaJugadoresOverlay({
    required this.jugadores,
    required this.indiceActivo,
    required this.puedeRenombrar,
    required this.onRenombrar,
    required this.onCerrar,
  });

  final List<Jugador> jugadores;
  final int indiceActivo;
  final bool Function(int index) puedeRenombrar;
  final ValueChanged<int> onRenombrar;
  final VoidCallback onCerrar;

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
                constraints: const BoxConstraints(maxWidth: 440, maxHeight: 620),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Container(
                    clipBehavior: Clip.none,
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                    decoration: BoxDecoration(
                      color: AppColors.carta,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppColors.violeta.withValues(alpha: 0.7),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'JUGADORES',
                                style: TextStyle(
                                  color: AppColors.acento,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: onCerrar,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: AppColors.textoSuave,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Flexible(
                          child: SingleChildScrollView(
                            clipBehavior: Clip.none,
                            padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final cols = jugadores.length >= 3 ? 2 : 1;
                                final gap = 10.0;
                                final cardW =
                                    (constraints.maxWidth - gap * (cols - 1)) /
                                        cols;
                                return Wrap(
                                  spacing: gap,
                                  runSpacing: gap,
                                  children: [
                                    for (var i = 0;
                                        i < jugadores.length;
                                        i++)
                                      SizedBox(
                                        width: cardW,
                                        child: _PlayerCard(
                                          jugador: jugadores[i],
                                          index: i,
                                          activo: i == indiceActivo,
                                          esTu: i == 0,
                                          vertical: true,
                                          puedeRenombrar: puedeRenombrar(i),
                                          onRenombrar: puedeRenombrar(i)
                                              ? () => onRenombrar(i)
                                              : null,
                                        ),
                                      ),
                                  ],
                                );
                              },
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

class _PartidaMenuOverlay extends StatelessWidget {
  const _PartidaMenuOverlay({
    required this.jugador,
    required this.esContraPc,
    required this.partidaTerminada,
    required this.confirmarRendicion,
    required this.onCerrar,
    required this.onReglas,
    required this.onRendirse,
    required this.onConfirmarRendicion,
    required this.onCancelarRendicion,
  });

  final String jugador;
  final bool esContraPc;
  final bool partidaTerminada;
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
                          partidaTerminada ? 'Partida terminada' : 'Turno actual',
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
                        if (partidaTerminada || esContraPc)
                          _ArcadeButton(
                            label: 'SALIR',
                            icon: Icons.logout_rounded,
                            tono: _BotonTono.rojo,
                            onPressed: onRendirse,
                          )
                        else if (!confirmarRendicion)
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
        ),
      ),
    );
  }
}

/// Overlay simple de pausa (stand by) para modo vs PC.
/// No guarda la partida: solo detiene la PC hasta que se presione "Continuar".
class _StandByOverlay extends StatelessWidget {
  const _StandByOverlay({
    required this.onContinuar,
    required this.onVolverAlMenu,
  });

  final VoidCallback onContinuar;
  final VoidCallback onVolverAlMenu;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
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
                    const Icon(
                      Icons.pause_circle_rounded,
                      color: AppColors.acento,
                      size: 44,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Partida en espera',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.acento,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'La PC quedó pausada. Podés continuar cuando quieras.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textoSuave,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ArcadeButton(
                      label: 'CONTINUAR',
                      icon: Icons.play_arrow_rounded,
                      tono: _BotonTono.azul,
                      onPressed: onContinuar,
                    ),
                    const SizedBox(height: 10),
                    _ArcadeButton(
                      label: 'VOLVER AL MENÚ',
                      icon: Icons.home_rounded,
                      tono: _BotonTono.violeta,
                      onPressed: onVolverAlMenu,
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
    this.vertical = false,
    this.puedeRenombrar = false,
    this.onRenombrar,
  });

  final Jugador jugador;
  final int index;
  final bool activo;
  final bool esTu;
  final bool vertical;
  final bool puedeRenombrar;
  final VoidCallback? onRenombrar;

  static Color colorDe(int index) => switch (index) {
        0 => AppColors.acento,
        1 => AppColors.azul,
        2 => AppColors.peligro,
        _ => AppColors.mint,
      };

  static IconData iconoDe(int index) => switch (index) {
        0 => Icons.face,
        1 => Icons.face_6,
        2 => Icons.face_retouching_natural,
        _ => Icons.emoji_emotions,
      };

  @override
  Widget build(BuildContext context) {
    final accent = colorDe(index);
    final pct = (jugador.puntos / meta).clamp(0.0, 1.0);
    final faltan = math.max(0, meta - jugador.puntos);

    final sombras = vertical
        ? <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: activo ? 0.45 : 0.28),
              blurRadius: activo ? 14 : 8,
            ),
          ]
        : (activo
            ? neonGlow(accent, blur: 20, spread: 1)
            : neonGlow(accent, blur: 8));

    final card = Container(
      padding: EdgeInsets.symmetric(
        horizontal: vertical ? 10 : 12,
        vertical: vertical ? 10 : 8,
      ),
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
        boxShadow: sombras,
      ),
      child: vertical
          ? _buildVertical(accent, pct, faltan)
          : _buildHorizontal(accent, pct, faltan),
    );

    if (jugador.rendido) {
      return Opacity(opacity: 0.62, child: card);
    }
    return card;
  }

  List<Widget> _chipsEstado() {
    if (jugador.rendido) {
      return const [
        _Chip(
          icon: Icons.flag_rounded,
          label: 'RENDIDO',
          color: AppColors.peligro,
        ),
      ];
    }
    return [
      _Chip(
        icon: jugador.abierto ? Icons.check_circle : Icons.lock_outline,
        label: jugador.abierto ? 'ABIERTO' : 'SIN ABRIR',
        color: jugador.abierto ? AppColors.mint : AppColors.textoSuave,
      ),
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
    ];
  }

  Widget _avatar(Color accent, {double size = 58}) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: size,
          height: size,
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
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.45),
                blurRadius: 10,
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.fondoSuave,
            ),
            child: Icon(
              iconoDe(index),
              color: accent,
              size: size * 0.55,
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
    );
  }

  Widget _nombre(Color accent) {
    return Align(
      alignment: vertical ? Alignment.center : Alignment.centerLeft,
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
                      color: AppColors.violeta.withValues(alpha: 0.7),
                      width: 1.2,
                    ),
                  )
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: vertical
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    jugador.nombre.toUpperCase(),
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    textAlign: vertical ? TextAlign.center : TextAlign.start,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: vertical ? 12 : 14,
                      letterSpacing: 0.5,
                      height: 1.15,
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
      ),
    );
  }

  Widget _barra(Color accent, double pct) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: vertical ? 7 : 9,
              backgroundColor: Colors.black.withValues(alpha: 0.45),
              color: accent,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(pct * 100).floor()}%',
          style: TextStyle(
            color: accent,
            fontSize: vertical ? 10 : 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildVertical(Color accent, double pct, int faltan) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _avatar(accent, size: 48),
        const SizedBox(height: 8),
        _nombre(accent),
        if (activo) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE082), AppColors.acento],
              ),
              borderRadius: BorderRadius.circular(99),
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
        const SizedBox(height: 4),
        Text(
          '${_pts(jugador.puntos)} PTS',
          style: TextStyle(
            color: accent,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 1.1,
            shadows: [
              Shadow(
                color: accent.withValues(alpha: 0.75),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'FALTAN ${_pts(faltan)}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: accent.withValues(alpha: 0.95),
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        _barra(accent, pct),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: _chipsEstado(),
        ),
      ],
    );
  }

  Widget _buildHorizontal(Color accent, double pct, int faltan) {
    return Row(
      children: [
        _avatar(accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _nombre(accent),
              if (activo) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
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
                ),
              ],
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
                  Flexible(
                    child: Text(
                      'FALTAN ${_pts(faltan)} PTS PARA GANAR',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.95),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _barra(accent, pct),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Builder(
            builder: (context) {
              final chips = _chipsEstado();
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < chips.length; i++) ...[
                    if (i > 0) const SizedBox(height: 5),
                    chips[i],
                  ],
                ],
              );
            },
          ),
        ),
      ],
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
                  (ptsTirada > 0
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

