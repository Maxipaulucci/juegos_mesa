import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_juegos_mesa/generala/generala_online_codec.dart';
import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/dados/dado_widget.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/partida_ui/epic_backdrop.dart';
import 'package:app_juegos_mesa/generala/motor_generala.dart';
import 'package:app_juegos_mesa/generala/opciones_generala.dart';
import 'package:app_juegos_mesa/generala/standby_store.dart';
import 'package:app_juegos_mesa/generala/tablero_generala.dart';
import 'package:app_juegos_mesa/generala/textos.dart';
import 'package:app_juegos_mesa/generala/victoria_generala_overlay.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

class PartidaGeneralaScreen extends StatefulWidget {
  const PartidaGeneralaScreen({
    super.key,
    required this.nombres,
    this.modo, // ignorado: Generala siempre usa 5 dados
    this.partidaRapida = false,
    this.contraPc = false,
    this.dificultadPc = DificultadPc.medio,
    this.modoDios = false,
    this.ajustesIniciales = const AjustesEstado(),
    this.resume,
    this.salaCodigo,
    this.miNombre,
    this.opciones = const OpcionesGenerala(),
  });

  final List<String> nombres;
  final Object? modo;
  final bool partidaRapida;
  final bool contraPc;
  final DificultadPc dificultadPc;
  final bool modoDios;
  final AjustesEstado ajustesIniciales;
  final PartidaGeneralaResume? resume;
  /// Código de sala online. Si es no nulo (junto con [miNombre]), la
  /// partida se sincroniza con el rival vía [SalaService].
  final String? salaCodigo;
  /// Nombre del jugador local en la sala online.
  final String? miNombre;
  final OpcionesGenerala opciones;

  @override
  State<PartidaGeneralaScreen> createState() => _PartidaGeneralaScreenState();
}

class _PartidaGeneralaScreenState extends State<PartidaGeneralaScreen> {
  late PartidaGenerala _partida;
  late List<String> _nombres;
  late AjustesEstado _ajustes;

  bool _mostrarVictoria = false;
  bool _mostrarMenu = false;
  bool _mostrarAjustes = false;
  bool _mostrarTablero = false;
  bool _modoAnotar = false;
  bool _confirmarRendicion = false;
  bool _animandoTirada = false;
  /// Pausa tras la 3.ª tirada para ver los dados antes del tablero.
  bool _pausandoResultado = false;
  /// Casilla que la PC va a anotar (flecha en el tablero).
  CategoriaGenerala? _categoriaPcResaltada;
  List<int>? _dadosAnimados;
  List<int>? _dadosForzados;
  int _pcToken = 0;
  String? _subtituloVictoria;
  final _rng = math.Random();

  StreamSubscription<Sala>? _onlineSub;
  int _onlineVersion = 0;
  bool _publicandoOnline = false;

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

  JugadorGenerala get _j => _partida.jugadorActual;
  EstadoTurnoGenerala get _t => _partida.turno;

  static const int _maxNombre = 15;

  bool _puedeRenombrar(int index) {
    if (_esOnline) return false;
    if (_partida.ganador != null) return false;
    if (_partida.jugadores[index].rendido) return false;
    final nombre = _partida.jugadores[index].nombre;
    if (widget.contraPc) return nombre != nombreJugadorPc;
    return widget.partidaRapida;
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
      if (_partida.ganador == anterior) {
        _partida.ganador = nuevo;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.resume != null) {
      final r = widget.resume!;
      _nombres = List.of(r.nombres);
      _ajustes = r.ajustesIniciales;
      _partida = r.partida;
      _mostrarVictoria = false;
      _mostrarMenu = false;
      _mostrarAjustes = false;
      _mostrarTablero = false;
      _modoAnotar = false;
      _confirmarRendicion = false;
      _subtituloVictoria = null;
      _animandoTirada = false;
      _pausandoResultado = false;
      _categoriaPcResaltada = null;
      _dadosAnimados = null;
      _dadosForzados = null;
      _pcToken++;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_turnoDeLaPc) _programarJugadaPc();
    });
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
    // El servidor ya tiene version 1 al iniciar la sala.
    if (_onlineVersion < 1) _onlineVersion = 1;
    // Pull inmediato para no publicar con versión vieja.
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

    final resultado = applyGeneralaGameState(_partida, gameState);
    setState(() {
      _onlineVersion = version;
      _modoAnotar = resultado.modoAnotar;
      _mostrarTablero = resultado.modoAnotar;
      _mostrarVictoria = resultado.mostrarVictoria;
      _subtituloVictoria = resultado.subtituloVictoria;
      _animandoTirada = false;
      _dadosAnimados = null;
      _pausandoResultado = false;
      _categoriaPcResaltada = null;
    });
  }

  /// Publica nuestro estado tras una acción propia (tirar/toggle/anotar/
  /// rendirse). Se llama solo desde lugares donde el actor local hizo el
  /// cambio; no depende de a quién le toque después.
  Future<void> _publicarEstadoOnline() async {
    if (!_esOnline) return;
    final codigo = widget.salaCodigo;
    if (codigo == null) return;

    _onlineVersion++;
    final gameState = encodeGeneralaGameState(
      partida: _partida,
      version: _onlineVersion,
      modoAnotar: _modoAnotar,
      mostrarVictoria: _mostrarVictoria,
      subtituloVictoria: _subtituloVictoria,
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
    _partida = nuevaPartidaGenerala(
      _nombres,
      escaleraCircular: widget.opciones.escaleraCircular,
    );
    iniciarTurnoGenerala(_partida);
    _mostrarVictoria = false;
    _mostrarMenu = false;
    _mostrarAjustes = false;
    _mostrarTablero = false;
    _modoAnotar = false;
    _confirmarRendicion = false;
    _subtituloVictoria = null;
    _animandoTirada = false;
    _pausandoResultado = false;
    _categoriaPcResaltada = null;
    _dadosAnimados = null;
    _dadosForzados = null;
  }

  void _volverAJugar() {
    GeneralaStandByStore.limpiar();
    setState(_iniciarPartidaNueva);
    if (_turnoDeLaPc) _programarJugadaPc();
  }

  void _salirGuardandoResumeYVolverAlMenu() {
    if (!widget.contraPc) return;
    if (_partida.ganador != null) {
      GeneralaStandByStore.limpiar();
      Navigator.of(context).pop();
      return;
    }

    GeneralaStandByStore.guardar(
      PartidaGeneralaResume(
        partida: _partida,
        nombres: _nombres,
        contraPc: true,
        dificultadPc: widget.dificultadPc,
        modoDios: widget.modoDios,
        ajustesIniciales: _ajustes,
      ),
    );

    _pcToken++; // cancela cualquier jugada pendiente de la PC
    Navigator.of(context).pop();
  }

  Future<void> _abrirAjustes() async {
    setState(() {
      _mostrarAjustes = true;
      _mostrarMenu = false;
      _mostrarTablero = false;
    });
  }

  void _programarJugadaPc({int demoraMs = 700}) {
    if (!_turnoDeLaPc) return;
    final token = _pcToken;
    Future<void>.delayed(Duration(milliseconds: demoraMs), () {
      if (!mounted || token != _pcToken || !_turnoDeLaPc) return;
      _ejecutarJugadaPc();
    });
  }

  Future<void> _ejecutarJugadaPc() async {
    if (!_turnoDeLaPc || _mostrarVictoria || _modoAnotar) return;

    // Tirar hasta 3 veces; la auto-selección corre dentro de _tirar.
    while (_puedeTirarAhora && mounted && _turnoDeLaPc) {
      await _tirar(animar: true);
      if (!mounted || !_turnoDeLaPc) return;
      if (_t.debeAnotar) break;
      // Todos guardados → no tiene sentido seguir tirando.
      if (!_puedeTirarAhora) break;
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }
    if (!mounted || !_turnoDeLaPc) return;
    // Si la PC anota sin haber llegado a la 3.ª tirada, también
    // deja ver los dados un momento antes del tablero.
    if (!_modoAnotar) {
      setState(() => _pausandoResultado = true);
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted || !_turnoDeLaPc) return;
      setState(() => _pausandoResultado = false);
      _abrirAnotar();
    }

    final cat = elegirCategoriaPc(
      _j,
      _t.dados,
      servida: _t.tiradasHechas == 1,
      escaleraCircular: _partida.escaleraCircular,
    );
    if (!mounted || !_turnoDeLaPc) return;

    if (cat == null) {
      // No debería pasar; cerrar tablero para no dejar la partida trabada.
      setState(() {
        _modoAnotar = false;
        _mostrarTablero = false;
        _categoriaPcResaltada = null;
      });
      return;
    }

    // Muestra la flecha sobre la casilla elegida y deja ver el tablero.
    setState(() => _categoriaPcResaltada = cat);
    await Future<void>.delayed(const Duration(milliseconds: 1700));
    if (!mounted || !_turnoDeLaPc) return;
    _anotar(cat);
  }

  Future<void> _tirar({bool animar = true}) async {
    if (_animandoTirada || _pausandoResultado || _partida.ganador != null) {
      return;
    }
    if (!_puedeTirarAhora) return;
    if (_modoAnotar) return;
    if (!_esMiTurno) return;

    // Alinea los guardados a la izquierda antes de animar/tirar.
    if (_t.hayDados) {
      compactarDadosGuardados(_t);
      setState(() {});
    }

    final maskGuardados = List<bool>.of(_t.guardados);

    if (animar && _ajustes.animaciones) {
      setState(() {
        _animandoTirada = true;
        _dadosAnimados = [
          for (var i = 0; i < dadosGenerala; i++)
            maskGuardados[i] && _t.hayDados
                ? _t.dados[i]
                : _rng.nextInt(6) + 1,
        ];
      });
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 45));
        if (!mounted) return;
        setState(() {
          _dadosAnimados = [
            for (var j = 0; j < dadosGenerala; j++)
              maskGuardados[j] && _t.hayDados
                  ? _t.dados[j]
                  : _rng.nextInt(6) + 1,
          ];
        });
      }
    }

    final forzados = _dadosForzados;
    _dadosForzados = null;
    tirarDadosGenerala(_t, dadosForzados: forzados, rng: _rng);
    autoSeleccionarDadosUtiles(
      _j,
      _t,
      escaleraCircular: _partida.escaleraCircular,
    );

    setState(() {
      _animandoTirada = false;
      _dadosAnimados = null;
    });

    if (_t.debeAnotar ||
        (!_turnoDeLaPc &&
            debeForzarAnotarTemprano(
              _j,
              _t.dados,
              servida: _t.tiradasHechas == 1,
            ))) {
      setState(() => _pausandoResultado = true);
      // PC: 1 s extra para mirar los dados antes del tablero.
      final pausa = _turnoDeLaPc
          ? const Duration(seconds: 3)
          : const Duration(seconds: 2);
      await Future<void>.delayed(pausa);
      if (!mounted) return;
      setState(() => _pausandoResultado = false);
      _abrirAnotar();
    }
    _publicarEstadoOnline();
  }

  void _toggleDado(int index) {
    if (_animandoTirada ||
        _pausandoResultado ||
        _turnoDeLaPc ||
        _esperandoRivalOnline ||
        _modoAnotar) {
      return;
    }
    if (!_t.hayDados || !_t.puedeTirar) return;
    setState(() {
      toggleDadoGuardado(_t, index);
      // Al elegir/guardar, los amarillos se van a la izquierda.
      compactarDadosGuardados(_t);
    });
    _publicarEstadoOnline();
  }

  void _abrirAnotar() {
    if (!_t.puedeAnotar) return;
    if (!_esMiTurno) return;
    setState(() {
      _modoAnotar = true;
      _mostrarTablero = true;
      _mostrarMenu = false;
      _mostrarAjustes = false;
    });
    _publicarEstadoOnline();
  }

  /// Escalera / FULL / Generala armados y casilla libre → anotar antes.
  /// Póker: servido (1.ª), o en cualquier tirada si ambas generalas están llenas.
  /// Si ambas generalas llenas y salen 5 iguales → anotar el número.
  bool get _puedeAnotarTemprano {
    if (!_t.hayDados || !_t.puedeAnotar) return false;
    // En la 3.ª tirada el flujo fuerza el tablero; el botón temprano no hace falta.
    if (!_t.puedeTirar) return false;
    return puedeAnotarTemprano(
      _j,
      _t.dados,
      servida: _t.tiradasHechas == 1,
      escaleraCircular: _partida.escaleraCircular,
    );
  }

  /// Seguir tirando empeoraría (p. ej. póker con generalas llenas).
  bool get _debeForzarAnotarTemprano {
    if (!_puedeAnotarTemprano) return false;
    return debeForzarAnotarTemprano(
      _j,
      _t.dados,
      servida: _t.tiradasHechas == 1,
      escaleraCircular: _partida.escaleraCircular,
    );
  }

  /// Hay tiradas y al menos un dado sin guardar (si ya tiró una vez).
  bool get _puedeTirarAhora {
    if (_debeForzarAnotarTemprano) return false;
    if (!_t.puedeTirar) return false;
    if (!_t.hayDados) return true;
    return _t.guardados.any((g) => !g);
  }

  void _abrirTablero({bool forzarAnotar = false}) {
    final anotar = forzarAnotar || _puedeAnotarTemprano;
    if (anotar && _t.puedeAnotar && _esMiTurno) {
      _abrirAnotar();
      return;
    }
    setState(() {
      _mostrarTablero = true;
      _mostrarMenu = false;
      _mostrarAjustes = false;
    });
  }

  void _anotar(CategoriaGenerala cat) {
    if (!_modoAnotar) return;
    if (!_esMiTurno) return;
    // En vs PC el humano no debe poder tocar casillas en el turno de la PC.
    if (_turnoDeLaPc && cat != _categoriaPcResaltada) return;
    if (_turnoDeLaPc && _categoriaPcResaltada == null) return;
    // Casilla ya usada (u otra restricción): no anotar de nuevo.
    if (!puedeElegirCategoria(
      _j,
      cat,
      dados: _t.dados,
      servida: _t.tiradasHechas == 1,
    )) {
      return;
    }
    anotarCategoria(_partida, cat);
    setState(() {
      _modoAnotar = false;
      _mostrarTablero = false;
      _categoriaPcResaltada = null;
      if (_partida.ganador != null) {
        _mostrarVictoria = true;
      }
    });
    // Aunque el turno ya haya pasado al rival, fuimos nosotros quienes
    // anotamos: publicamos el nuevo estado.
    _publicarEstadoOnline();
    if (_partida.ganador == null && _turnoDeLaPc) {
      _programarJugadaPc(demoraMs: 800);
    }
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
                'REGLAS · GENERALA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.acento,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                reglasGenerala(),
                style: const TextStyle(color: AppColors.texto, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _abrirMenu() {
    if (_modoAnotar) return;
    if (_partida.ganador == null && _partida.jugadorActual.rendido) return;
    setState(() {
      _mostrarMenu = true;
      _confirmarRendicion = false;
      _mostrarAjustes = false;
      _mostrarTablero = false;
    });
  }

  void _rendirse() {
    if (_partida.ganador != null) return;
    if (widget.contraPc) {
      _salirGuardandoResumeYVolverAlMenu();
      return;
    }

    // En modo online el jugador local que se rinde no es necesariamente
    // el jugadorActual (puede no ser su turno). Buscamos al jugador local.
    final JugadorGenerala rendido;
    if (_esOnline) {
      final miNombre = widget.miNombre!;
      final encontrado = _partida.jugadores
          .where((j) => j.nombre == miNombre && !j.rendido)
          .firstOrNull;
      if (encontrado == null) return;
      rendido = encontrado;
    } else {
      final j = _partida.jugadorActual;
      if (j.rendido) return;
      rendido = j;
    }

    final eraSuTurnoActivo = _partida.jugadorActual == rendido;
    final partidaLarga = _partida.jugadores.length >= 3;

    _pcToken++;
    setState(() {
      rendido.rendido = true;
      _mostrarMenu = false;
      _confirmarRendicion = false;
      _modoAnotar = false;
      _mostrarTablero = false;
      _categoriaPcResaltada = null;
      _animandoTirada = false;
      _dadosAnimados = null;

      final activos = _partida.jugadoresActivos;
      if (!partidaLarga || activos.length <= 1) {
        if (activos.isEmpty) return;
        _partida.ganador = activos.first.nombre;
        _subtituloVictoria = 'Has ganado por abandono';
        _mostrarVictoria = true;
      } else if (eraSuTurnoActivo) {
        pasarTurnoGenerala(_partida);
      }
    });
    _publicarEstadoOnline();

    // En online con más de 2 jugadores, el jugador que se rinde vuelve al
    // menú. Si quedó un solo activo, la pantalla de victoria se muestra
    // primero y el tap de "volver" navegará normalmente.
    if (_esOnline && _partida.ganador == null && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _pedirDadosForzados() async {
    final cantidad = _t.hayDados
        ? _t.guardados.where((g) => !g).length
        : dadosGenerala;
    if (cantidad <= 0) return;

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
                'Ej: ${'1' * cantidad.clamp(1, 5)}',
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

    if (valores == null || !mounted) return;
    setState(() {
      _dadosForzados = valores.isEmpty ? null : valores;
    });
  }

  @override
  Widget build(BuildContext context) {
    final terminada = _partida.ganador != null;
    final dados = _animandoTirada ? _dadosAnimados : (_t.hayDados ? _t.dados : null);
    final guardados = _t.hayDados ? _t.guardados : List.filled(dadosGenerala, false);

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
                            children: [
                              _Header(
                                onMenu: _modoAnotar ? () {} : _abrirMenu,
                                onSettings: _abrirAjustes,
                              ),
                              const SizedBox(height: 8),
                              for (var i = 0; i < _partida.jugadores.length; i++) ...[
                                _PlayerCard(
                                  jugador: _partida.jugadores[i],
                                  index: i,
                                  activo: !terminada &&
                                      i == _partida.indiceTurno,
                                  esTu: i == 0,
                                  puedeRenombrar: _puedeRenombrar(i),
                                  onRenombrar: _puedeRenombrar(i)
                                      ? () => _renombrarJugador(i)
                                      : null,
                                ),
                                const SizedBox(height: 6),
                              ],
                              _TurnoBanner(
                                nombre: terminada
                                    ? (_partida.ganador ?? '')
                                    : _j.nombre,
                                terminada: terminada,
                                tirada: _t.tiradasHechas,
                              ),
                              const SizedBox(height: 6),
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: widget.modoDios ? 46 : 0,
                                    ),
                                    child: _DadosZona(
                                      dados: dados,
                                      guardados: guardados,
                                      animando: _animandoTirada,
                                      onTapDado: _toggleDado,
                                    ),
                                  ),
                                  if (widget.modoDios &&
                                      !_turnoDeLaPc &&
                                      _esMiTurno)
                                    Positioned(
                                      right: 0,
                                      child: Tooltip(
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
                                                    _animandoTirada ||
                                                    _pausandoResultado
                                                ? null
                                                : _pedirDadosForzados,
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
                              if (_t.hayDados &&
                                  _t.puedeTirar &&
                                  !_modoAnotar &&
                                  !_turnoDeLaPc &&
                                  !_esperandoRivalOnline)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Tocá para guardar (amarillo, a la izquierda)',
                                    style: TextStyle(
                                      color: AppColors.textoSuave,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              if (!terminada &&
                                  !_turnoDeLaPc &&
                                  !_esperandoRivalOnline &&
                                  !_modoAnotar) ...[
                                if (_puedeAnotarTemprano &&
                                    !_animandoTirada &&
                                    !_pausandoResultado) ...[
                                  _ArcadeButton(
                                    label: 'ANOTAR EN EL TABLERO',
                                    icon: Icons.edit_note_rounded,
                                    tono: _BotonTono.azul,
                                    onPressed: _abrirAnotar,
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                _ArcadeButton(
                                  label: _t.puedeTirar
                                      ? (_debeForzarAnotarTemprano
                                          ? 'NO CONVIENE TIRAR'
                                          : 'TIRAR DADOS · ${_t.tiradasHechas}/$maxTiradasGenerala')
                                      : 'SIN TIRADAS',
                                  icon: Icons.casino,
                                  tono: _BotonTono.dorado,
                                  onPressed: _puedeTirarAhora &&
                                          !_animandoTirada &&
                                          !_pausandoResultado
                                      ? () => _tirar()
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                _ArcadeButton(
                                  label: 'VER TABLERO',
                                  icon: Icons.grid_view_rounded,
                                  tono: _BotonTono.violeta,
                                  onPressed: !_animandoTirada &&
                                          !_pausandoResultado
                                      ? () => _abrirTablero()
                                      : null,
                                ),
                              ] else if (!terminada &&
                                  (_turnoDeLaPc || _esperandoRivalOnline))
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    _turnoDeLaPc
                                        ? 'Turno de la PC…'
                                        : 'Turno de ${_j.nombre}…',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.textoSuave,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              else if (!_modoAnotar)
                                _ArcadeButton(
                                  label: 'VER TABLERO',
                                  icon: Icons.grid_view_rounded,
                                  tono: _BotonTono.violeta,
                                  onPressed: () => _abrirTablero(),
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
          if (_mostrarVictoria && _partida.ganador != null)
            Positioned.fill(
              child: VictoriaGeneralaOverlay(
                partida: _partida,
                ganador: _partida.ganador!,
                subtitulo: _subtituloVictoria,
                animaciones: _ajustes.animaciones,
                onVolverAJugar: _volverAJugar,
                onVolver: () {
                  GeneralaStandByStore.limpiar();
                  Navigator.of(context).pop();
                },
              ),
            ),
          if (_mostrarMenu)
            Positioned.fill(
              child: _MenuOverlay(
                jugador: terminada
                    ? (_partida.ganador ?? _j.nombre)
                    : _j.nombre,
                esContraPc: widget.contraPc,
                partidaTerminada: terminada,
                confirmarRendicion: _confirmarRendicion && !widget.contraPc,
                onCerrar: () => setState(() {
                  _mostrarMenu = false;
                  _confirmarRendicion = false;
                }),
                onReglas: _abrirReglas,
                onSalirORendirse: terminada
                    ? () {
                        GeneralaStandByStore.limpiar();
                        Navigator.of(context).pop();
                      }
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
          if (_mostrarTablero)
            Positioned.fill(
              child: TableroGeneralaOverlay(
                partida: _partida,
                modoAnotar: _modoAnotar,
                dadosActuales: _t.hayDados ? _t.dados : null,
                // Durante el turno de la PC (o del rival online) no se
                // toca: solo se ve la flecha / se espera.
                onElegirCategoria: _modoAnotar &&
                        !_turnoDeLaPc &&
                        !_esperandoRivalOnline
                    ? _anotar
                    : null,
                categoriaResaltada: _categoriaPcResaltada,
                // Tras 3 tiradas hay que anotar: no se puede cerrar.
                // Si anotás temprano (aún quedan tiradas), sí.
                permitirCerrar: !_modoAnotar || _t.puedeTirar,
                onCerrar: () {
                  setState(() {
                    _mostrarTablero = false;
                    if (_esMiTurno) {
                      _modoAnotar = false;
                      _categoriaPcResaltada = null;
                    }
                  });
                  if (_esMiTurno) _publicarEstadoOnline();
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─── UI ───────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onMenu, required this.onSettings});

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
                  Text(
                    'GENERALA',
                    style: TextStyle(
                      fontSize: 34,
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
                      'GENERALA',
                      style: TextStyle(
                        fontSize: 34,
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
                ),
                child: const Text(
                  '★  5 DADOS  ★',
                  style: TextStyle(
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
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: AppColors.texto),
        ),
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

  final JugadorGenerala jugador;
  final int index;
  final bool activo;
  final bool esTu;
  final bool puedeRenombrar;
  final VoidCallback? onRenombrar;

  Color get accent => colorJugadorTablero(index);

  static IconData iconoDe(int index) => switch (index % 4) {
        0 => Icons.face,
        1 => Icons.face_6,
        2 => Icons.face_retouching_natural,
        _ => Icons.emoji_emotions,
      };

  Widget _avatar({double size = 48}) {
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
        if (activo && !jugador.rendido)
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

  Widget _nombre() {
    return Align(
      alignment: Alignment.centerLeft,
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
              children: [
                Flexible(
                  child: Text(
                    jugador.nombre.toUpperCase(),
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
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

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.carta.withValues(alpha: 0.95),
            const Color(0xFF190B33).withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: activo && !jugador.rendido
              ? accent
              : accent.withValues(alpha: 0.45),
          width: activo && !jugador.rendido ? 2.4 : 1.4,
        ),
        boxShadow:
            activo && !jugador.rendido ? neonGlow(accent, blur: 18) : null,
      ),
      child: Row(
        children: [
          _avatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _nombre(),
                if (jugador.rendido) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.peligro.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: AppColors.peligro),
                      ),
                      child: const Text(
                        'RENDIDO',
                        style: TextStyle(
                          color: AppColors.peligro,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ] else if (activo) ...[
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
                  '${jugador.total} PTS',
                  style: TextStyle(
                    color: accent,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        color: accent.withValues(alpha: 0.75),
                        blurRadius: 10,
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

    if (jugador.rendido) {
      return Opacity(opacity: 0.55, child: card);
    }
    return card;
  }
}

class _TurnoBanner extends StatelessWidget {
  const _TurnoBanner({
    required this.nombre,
    required this.terminada,
    required this.tirada,
  });

  final String nombre;
  final bool terminada;
  final int tirada;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.violeta,
                AppColors.rosa,
                AppColors.acentoSuave,
              ],
            ),
            borderRadius: BorderRadius.circular(99),
            boxShadow: neonGlow(AppColors.rosa, blur: 14),
          ),
          child: Text(
            terminada
                ? '★ GANÓ: ${nombre.toUpperCase()} ★'
                : '★ TURNO DE: ${nombre.toUpperCase()} ★',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
        ),
        if (!terminada) ...[
          const SizedBox(height: 6),
          Text(
            'TIRADA $tirada / $maxTiradasGenerala',
            style: TextStyle(
              color: AppColors.mint,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              shadows: [
                Shadow(
                  color: AppColors.mint.withValues(alpha: 0.7),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DadosZona extends StatelessWidget {
  const _DadosZona({
    required this.dados,
    required this.guardados,
    required this.animando,
    required this.onTapDado,
  });

  final List<int>? dados;
  final List<bool> guardados;
  final bool animando;
  final ValueChanged<int> onTapDado;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tamano =
            ((constraints.maxWidth - (dadosGenerala - 1) * 10) / dadosGenerala)
                .clamp(44.0, 72.0);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < dadosGenerala; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                GestureDetector(
                  onTap: animando || dados == null
                      ? null
                      : () => onTapDado(i),
                  child: DadoFace(
                    valor: dados?[i] ?? 1,
                    vacio: dados == null,
                    suma: dados != null && guardados[i],
                    tamano: tamano,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MenuOverlay extends StatelessWidget {
  const _MenuOverlay({
    required this.jugador,
    required this.esContraPc,
    required this.partidaTerminada,
    required this.confirmarRendicion,
    required this.onCerrar,
    required this.onReglas,
    required this.onSalirORendirse,
    required this.onConfirmarRendicion,
    required this.onCancelarRendicion,
  });

  final String jugador;
  final bool esContraPc;
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
    late final List<Color> colors;
    late final Color glow;
    late final Color fg;

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
