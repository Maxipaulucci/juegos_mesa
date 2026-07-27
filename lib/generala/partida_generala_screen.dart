import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/diezMil/ajustes_overlay.dart';
import 'package:app_juegos_mesa/diezMil/dado_widget.dart';
import 'package:app_juegos_mesa/diezMil/ia_diez_mil.dart';
import 'package:app_juegos_mesa/generala/motor_generala.dart';
import 'package:app_juegos_mesa/generala/tablero_generala.dart';
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
    this.resume, // reservado; Generala aún no persiste standby
  });

  final List<String> nombres;
  final Object? modo;
  final bool partidaRapida;
  final bool contraPc;
  final DificultadPc dificultadPc;
  final bool modoDios;
  final AjustesEstado ajustesIniciales;
  final Object? resume;

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
  List<int>? _dadosAnimados;
  List<int>? _dadosForzados;
  int _pcToken = 0;
  String? _subtituloVictoria;
  final _rng = math.Random();

  bool get _turnoDeLaPc =>
      widget.contraPc &&
      _partida.ganador == null &&
      _partida.jugadorActual.nombre == nombreJugadorPc;

  JugadorGenerala get _j => _partida.jugadorActual;
  EstadoTurnoGenerala get _t => _partida.turno;

  static const int _maxNombre = 15;

  bool _puedeRenombrar(int index) {
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
    _nombres = List.of(widget.nombres);
    _ajustes = widget.ajustesIniciales;
    _iniciarPartidaNueva();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_turnoDeLaPc) _programarJugadaPc();
    });
  }

  void _iniciarPartidaNueva() {
    _pcToken++;
    _partida = nuevaPartidaGenerala(_nombres);
    iniciarTurnoGenerala(_partida);
    _mostrarVictoria = false;
    _mostrarMenu = false;
    _mostrarAjustes = false;
    _mostrarTablero = false;
    _modoAnotar = false;
    _confirmarRendicion = false;
    _subtituloVictoria = null;
    _animandoTirada = false;
    _dadosAnimados = null;
    _dadosForzados = null;
  }

  void _volverAJugar() {
    setState(_iniciarPartidaNueva);
    if (_turnoDeLaPc) _programarJugadaPc();
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

    // Tirar hasta 3 veces con una heurística simple de guardado.
    while (_t.puedeTirar && mounted && _turnoDeLaPc) {
      await _tirar(animar: true);
      if (!mounted || !_turnoDeLaPc) return;
      if (_t.debeAnotar) break;
      _elegirGuardadosPc();
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }
    if (!mounted || !_turnoDeLaPc) return;
    _abrirAnotar();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted || !_turnoDeLaPc) return;
    final cat = _mejorCategoriaPc();
    if (cat != null) _anotar(cat);
  }

  void _elegirGuardadosPc() {
    if (!_t.hayDados) return;
    final counts = contarCaras(_t.dados);
    var mejorCara = 1;
    var mejorN = 0;
    counts.forEach((cara, n) {
      if (n > mejorN || (n == mejorN && cara > mejorCara)) {
        mejorN = n;
        mejorCara = cara;
      }
    });
    for (var i = 0; i < dadosGenerala; i++) {
      _t.guardados[i] = _t.dados[i] == mejorCara;
    }
    compactarDadosGuardados(_t);
    setState(() {});
  }

  CategoriaGenerala? _mejorCategoriaPc() {
    final j = _j;
    CategoriaGenerala? mejor;
    var mejorPts = -1;
    for (final cat in CategoriaGenerala.values) {
      if (!puedeElegirCategoria(j, cat)) continue;
      final pts = puntosCategoria(
        cat,
        _t.dados,
        yaTieneGenerala: j.generalaAnotada,
      );
      // Prefiere puntos positivos; si todo es 0, tacha el número más bajo vacío.
      final score = pts > 0 ? pts + 1000 : (cat.esNumero ? -cat.index : -100);
      if (score > mejorPts) {
        mejorPts = score;
        mejor = cat;
      }
    }
    return mejor;
  }

  Future<void> _tirar({bool animar = true}) async {
    if (_animandoTirada || _partida.ganador != null) return;
    if (!_t.puedeTirar) return;
    if (_modoAnotar) return;

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

    setState(() {
      _animandoTirada = false;
      _dadosAnimados = null;
    });

    if (_t.debeAnotar) {
      _abrirAnotar();
    }
  }

  void _toggleDado(int index) {
    if (_animandoTirada || _turnoDeLaPc || _modoAnotar) return;
    if (!_t.hayDados || !_t.puedeTirar) return;
    setState(() {
      toggleDadoGuardado(_t, index);
      // Al elegir/guardar, los amarillos se van a la izquierda.
      compactarDadosGuardados(_t);
    });
  }

  void _abrirAnotar() {
    if (!_t.puedeAnotar) return;
    setState(() {
      _modoAnotar = true;
      _mostrarTablero = true;
      _mostrarMenu = false;
      _mostrarAjustes = false;
    });
  }

  void _anotar(CategoriaGenerala cat) {
    if (!_modoAnotar) return;
    anotarCategoria(_partida, cat);
    setState(() {
      _modoAnotar = false;
      _mostrarTablero = false;
      if (_partida.ganador != null) {
        _mostrarVictoria = true;
      }
    });
    if (_partida.ganador == null && _turnoDeLaPc) {
      _programarJugadaPc(demoraMs: 800);
    }
  }

  void _abrirMenu() {
    if (_partida.ganador != null || _modoAnotar) return;
    if (_partida.jugadorActual.rendido) return;
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
      Navigator.of(context).pop();
      return;
    }

    final rendido = _partida.jugadorActual;
    if (rendido.rendido) return;

    final eraSuTurno = true;
    final partidaLarga = _partida.jugadores.length >= 3;

    _pcToken++;
    setState(() {
      rendido.rendido = true;
      _mostrarMenu = false;
      _confirmarRendicion = false;
      _modoAnotar = false;
      _mostrarTablero = false;
      _animandoTirada = false;
      _dadosAnimados = null;

      final activos = _partida.jugadoresActivos;
      if (!partidaLarga || activos.length <= 1) {
        if (activos.isEmpty) return;
        _partida.ganador = activos.first.nombre;
        _subtituloVictoria = 'Has ganado por abandono';
        _mostrarVictoria = true;
      } else if (eraSuTurno) {
        pasarTurnoGenerala(_partida);
      }
    });
  }

  Future<void> _pedirDadosForzados() async {
    final cantidad = _t.hayDados
        ? _t.guardados.where((g) => !g).length
        : dadosGenerala;
    if (cantidad <= 0) return;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.carta,
        title: const Text(
          'Modo Dios',
          style: TextStyle(color: AppColors.acento),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.texto),
          decoration: InputDecoration(
            labelText: '$cantidad valores (ej: 1,2,3…)',
            labelStyle: const TextStyle(color: AppColors.textoSuave),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final parts = ctrl.text.split(RegExp(r'[,;\s]+')).where((s) => s.isNotEmpty);
    final vals = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 1 || n > 6) continue;
      vals.add(n);
      if (vals.length >= cantidad) break;
    }
    if (vals.isEmpty) return;
    setState(() => _dadosForzados = vals);
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
                            children: [
                              _Header(
                                onMenu: terminada || _modoAnotar
                                    ? () {}
                                    : _abrirMenu,
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
                                  if (widget.modoDios && !_turnoDeLaPc)
                                    Positioned(
                                      right: 0,
                                      child: IconButton(
                                        onPressed: _animandoTirada
                                            ? null
                                            : _pedirDadosForzados,
                                        icon: Icon(
                                          Icons.bug_report,
                                          color: _dadosForzados != null
                                              ? AppColors.mint
                                              : AppColors.textoSuave,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (_t.hayDados &&
                                  _t.puedeTirar &&
                                  !_modoAnotar &&
                                  !_turnoDeLaPc)
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
                              _VerTableroButton(
                                onPressed: () {
                                  if (_modoAnotar) return;
                                  setState(() {
                                    _mostrarTablero = true;
                                    _mostrarMenu = false;
                                    _mostrarAjustes = false;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              if (!terminada && !_turnoDeLaPc && !_modoAnotar) ...[
                                _ArcadeButton(
                                  label: _t.puedeTirar
                                      ? 'TIRAR DADOS · ${_t.tiradasHechas}/$maxTiradasGenerala'
                                      : 'SIN TIRADAS',
                                  icon: Icons.casino,
                                  tono: _BotonTono.dorado,
                                  onPressed: _t.puedeTirar && !_animandoTirada
                                      ? () => _tirar()
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                _ArcadeButton(
                                  label: 'ANOTAR EN EL TABLERO',
                                  icon: Icons.edit_note_rounded,
                                  tono: _BotonTono.violeta,
                                  onPressed: _t.puedeAnotar && !_animandoTirada
                                      ? _abrirAnotar
                                      : null,
                                ),
                              ] else if (!terminada && _turnoDeLaPc)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    'Turno de la PC…',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textoSuave,
                                      fontWeight: FontWeight.w700,
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
          if (_mostrarVictoria && _partida.ganador != null)
            Positioned.fill(
              child: _VictoriaGeneralaOverlay(
                ganador: _partida.ganador!,
                total: _partida.jugadores
                    .firstWhere((j) => j.nombre == _partida.ganador)
                    .total,
                subtitulo: _subtituloVictoria,
                onVolverAJugar: _volverAJugar,
                onSalir: () => Navigator.of(context).pop(),
              ),
            ),
          if (_mostrarMenu)
            Positioned.fill(
              child: _MenuOverlay(
                jugador: _j.nombre,
                esContraPc: widget.contraPc,
                confirmarRendicion: _confirmarRendicion && !widget.contraPc,
                onCerrar: () => setState(() {
                  _mostrarMenu = false;
                  _confirmarRendicion = false;
                }),
                onSalirORendirse: widget.contraPc
                    ? () => Navigator.of(context).pop()
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
          if (_mostrarTablero)
            Positioned.fill(
              child: TableroGeneralaOverlay(
                partida: _partida,
                modoAnotar: _modoAnotar,
                dadosActuales: _t.hayDados ? _t.dados : null,
                onElegirCategoria: _modoAnotar ? _anotar : null,
                onCerrar: () => setState(() {
                  _mostrarTablero = false;
                  _modoAnotar = false;
                }),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── UI ───────────────────────────────────────────────────────────────

class _EpicBackdrop extends StatelessWidget {
  const _EpicBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.15,
          colors: [
            Color(0xFF2A1450),
            AppColors.fondo,
            Color(0xFF070312),
          ],
        ),
      ),
    );
  }
}

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

  Widget _nombre() {
    return Material(
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
                  color: AppColors.violeta.withValues(alpha: 0.95),
                ),
              ],
            ],
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
          CircleAvatar(
            backgroundColor: accent.withValues(alpha: 0.25),
            child: Icon(Icons.person, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: _nombre()),
                    if (jugador.rendido) ...[
                      const SizedBox(width: 8),
                      Container(
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
                    ] else if (activo) ...[
                      const SizedBox(width: 8),
                      Container(
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
                    ],
                  ],
                ),
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

class _VerTableroButton extends StatelessWidget {
  const _VerTableroButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.carta, Color(0xFF190B33)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.violeta.withValues(alpha: 0.6)),
            boxShadow: neonGlow(AppColors.violeta, blur: 10),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.grid_view_rounded, color: AppColors.acento),
              SizedBox(width: 10),
              Text(
                'Ver tablero',
                style: TextStyle(
                  color: AppColors.texto,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VictoriaGeneralaOverlay extends StatelessWidget {
  const _VictoriaGeneralaOverlay({
    required this.ganador,
    required this.total,
    required this.onVolverAJugar,
    required this.onSalir,
    this.subtitulo,
  });

  final String ganador;
  final int total;
  final String? subtitulo;
  final VoidCallback onVolverAJugar;
  final VoidCallback onSalir;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.carta,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.acento, width: 1.6),
            boxShadow: neonGlow(AppColors.acento, blur: 20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '¡GANÓ!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.acento,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                ganador.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),
              if (subtitulo != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitulo!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                '$total PTS',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.mint,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onVolverAJugar,
                child: const Text('Volver a jugar'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: onSalir,
                child: const Text('Salir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuOverlay extends StatelessWidget {
  const _MenuOverlay({
    required this.jugador,
    required this.esContraPc,
    required this.confirmarRendicion,
    required this.onCerrar,
    required this.onSalirORendirse,
    required this.onConfirmarRendicion,
    required this.onCancelarRendicion,
  });

  final String jugador;
  final bool esContraPc;
  final bool confirmarRendicion;
  final VoidCallback onCerrar;
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          'Turno actual',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textoSuave.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (esContraPc)
                          ElevatedButton(
                            onPressed: onSalirORendirse,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.peligro,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: const Text('SALIR'),
                          )
                        else if (!confirmarRendicion)
                          ElevatedButton(
                            onPressed: onSalirORendirse,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.peligro,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: const Text('RENDIRSE'),
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
                          ElevatedButton(
                            onPressed: onConfirmarRendicion,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.peligro,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: const Text('CONFIRMAR RENDICIÓN'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: onCancelarRendicion,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: const Text('CANCELAR'),
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

enum _BotonTono { dorado, violeta }

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
    final colors = tono == _BotonTono.dorado
        ? const [Color(0xFFFFF3B0), Color(0xFFFFD54F), Color(0xFFFF9800)]
        : const [Color(0xFFCE93D8), Color(0xFFAB47BC), Color(0xFF6A1B9A)];
    final fg =
        tono == _BotonTono.dorado ? const Color(0xFF4A1B6D) : Colors.white;
    final glow =
        tono == _BotonTono.dorado ? AppColors.acento : AppColors.rosa;

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
