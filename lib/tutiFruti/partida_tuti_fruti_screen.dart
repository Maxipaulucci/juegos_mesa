import 'dart:async';

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/tutiFruti/motor_tuti_fruti.dart';
import 'package:app_juegos_mesa/tutiFruti/tuti_fruti_online_codec.dart';
import 'package:app_juegos_mesa/tutiFruti/victoria_tuti_fruti_overlay.dart';

class PartidaTutiFrutiScreen extends StatefulWidget {
  const PartidaTutiFrutiScreen({
    super.key,
    required this.nombres,
    required this.salaCodigo,
    required this.miNombre,
  });

  final List<String> nombres;
  final String salaCodigo;
  final String miNombre;

  @override
  State<PartidaTutiFrutiScreen> createState() => _PartidaTutiFrutiScreenState();
}

class _PartidaTutiFrutiScreenState extends State<PartidaTutiFrutiScreen> {
  late PartidaTuti _partida;
  StreamSubscription<Sala>? _onlineSub;
  int _onlineVersion = 0;
  bool _publicandoOnline = false;
  Timer? _tick;
  Timer? _debounceRespuestas;
  final List<TextEditingController> _respCtrls = [];
  bool _soyAnfitrion = false;
  /// Momento local en que ESTE cliente vio el aviso de basta (solo rivales).
  int? _bastaLocalInicioMs;
  /// Cola de publicaciones para no pisar PARAR con aceleraciones.
  Future<void> _colaPublicacion = Future<void>.value();
  bool _parandoRuleta = false;
  DateTime? _ultimoAcelerarPub;

  bool get _esMiSpinner =>
      _partida.nombreSpinner == widget.miNombre;
  bool get _esMiParador =>
      _partida.nombreParador == widget.miNombre;

  bool get _yoDijeBasta =>
      _partida.bastaTodos && _partida.bastaPor == widget.miNombre;

  /// Aviso solo para quienes NO apretaron BASTA.
  bool get _mostrarAvisoBasta =>
      _partida.fase == FaseTuti.escritura &&
      _partida.bastaTodos &&
      !_yoDijeBasta &&
      _bastaLocalInicioMs != null;

  double get _progresoBastaLocal {
    final inicio = _bastaLocalInicioMs;
    if (inicio == null) return 1;
    final elapsed =
        DateTime.now().millisecondsSinceEpoch - inicio;
    final t = 1.0 - (elapsed / duracionBastaTuti.inMilliseconds);
    return t.clamp(0.0, 1.0);
  }

  bool get _escrituraBloqueadaLocal {
    if (_partida.fase != FaseTuti.escritura) return true;
    if (!_partida.bastaTodos) return false;
    // Quien dijo basta: ya no escribe.
    if (_yoDijeBasta) return true;
    // Los demás: bloquean al terminar SU contador local de gracia.
    if (_bastaLocalInicioMs == null) return false;
    return _progresoBastaLocal <= 0;
  }

  @override
  void initState() {
    super.initState();
    _partida = nuevaPartidaTuti(
      nombres: widget.nombres,
      categorias: const ['…'],
    );
    _iniciarSincronizacionOnline();
    _tick = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      if (_partida.fase == FaseTuti.ruleta || _partida.fase.esContador) {
        setState(() {});
        _talvezAvanzarContador();
      } else if (_partida.fase == FaseTuti.escritura && _partida.bastaTodos) {
        setState(() {});
        _talvezCerrarBasta();
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _debounceRespuestas?.cancel();
    _onlineSub?.cancel();
    for (final c in _respCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _iniciarSincronizacionOnline() {
    final codigo = widget.salaCodigo;
    // Empezamos en 0 para aplicar el gameState inicial (version 1) del servidor.
    _onlineVersion = 0;
    unawaited(() async {
      try {
        final sala = await SalaService.instance.obtener(codigo);
        if (mounted) _onSalaOnlineActualizada(sala);
      } catch (_) {}
    }());
    _onlineSub = SalaService.instance
        .watch(codigo, intervalo: const Duration(milliseconds: 300))
        .listen(_onSalaOnlineActualizada);
  }

  void _flushRespuestasLocales() {
    for (var i = 0; i < _respCtrls.length && i < _partida.categorias.length; i++) {
      setRespuestaTuti(
        _partida,
        widget.miNombre,
        i,
        _respCtrls[i].text,
      );
    }
  }

  /// Si llegó un Basta ajeno, mezclamos nuestras respuestas locales
  /// (pueden no haberse subido aún por el debounce) y republicamos.
  void _fusionarMisRespuestasTrasBasta() {
    _flushRespuestasLocales();
    // setRespuesta bloquea si bastaTodos; forzar escritura directa:
    final mias = _partida.respuestas.putIfAbsent(
      widget.miNombre,
      () => List.filled(_partida.categorias.length, ''),
    );
    for (var i = 0; i < _respCtrls.length && i < mias.length; i++) {
      final t = _respCtrls[i].text;
      mias[i] = t.length > 40 ? t.substring(0, 40) : t;
    }
  }

  void _onSalaOnlineActualizada(Sala sala) {
    if (!mounted) return;
    final gameState = sala.gameState;
    if (gameState == null) return;
    final version = (gameState['version'] as num?)?.toInt() ?? 0;
    final remoteFase = FaseTutiX.fromId(gameState['fase']?.toString());
    final remotoMasAvanzado = remoteFase.orden > _partida.fase.orden;
    final bastaNuevo =
        gameState['bastaTodos'] == true && !_partida.bastaTodos;
    final urgente = remotoMasAvanzado || bastaNuevo;

    // Versión optimista local puede quedar por encima tras un publish ignorado;
    // si el remoto ya avanzó de fase o hay BASTA, hay que aplicar igual.
    if (version <= _onlineVersion && !urgente) return;
    // Mientras publicamos, solo aceptamos avances urgentes (PARAR / BASTA).
    if (_publicandoOnline && !urgente) return;

    // No volver atrás: p.ej. ruleta vieja no pisa un PARAR ya aplicado.
    if (remoteFase.orden < _partida.fase.orden &&
        _partida.fase.orden >= FaseTuti.countdownEscritura.orden) {
      unawaited(_publicarEstadoOnline(forzar: true));
      return;
    }

    _aplicarGameStateDeSala(sala, gameState, remoteFase);
  }

  void _aplicarGameStateDeSala(
    Sala sala,
    Map<String, dynamic> gameState,
    FaseTuti remoteFase,
  ) {
    final version = (gameState['version'] as num?)?.toInt() ?? 0;
    final remoteBasta = gameState['bastaTodos'] == true;
    final estabaEscribiendo = _partida.fase == FaseTuti.escritura;
    final deboFusionar = remoteBasta &&
        estabaEscribiendo &&
        !_partida.bastaTodos &&
        remoteFase == FaseTuti.escritura;

    if (deboFusionar) {
      _fusionarMisRespuestasTrasBasta();
    }

    setState(() {
      final host = sala.jugadores
          .where((j) => j.id == sala.anfitrionId)
          .firstOrNull;
      _soyAnfitrion = host?.nombre == widget.miNombre;

      final prevFase = _partida.fase;
      final prevRonda = _partida.ronda;
      final misLocales = deboFusionar
          ? List<String>.from(
              _partida.respuestas[widget.miNombre] ?? const [],
            )
          : null;

      applyTutiGameState(_partida, gameState);
      _onlineVersion = version;

      if (_partida.fase == FaseTuti.escritura &&
          _partida.bastaTodos &&
          _partida.bastaPor != widget.miNombre) {
        _bastaLocalInicioMs ??= DateTime.now().millisecondsSinceEpoch;
      }
      if (!_partida.bastaTodos || _partida.fase != FaseTuti.escritura) {
        _bastaLocalInicioMs = null;
      }

      if (misLocales != null && misLocales.isNotEmpty) {
        final dest = _partida.respuestas.putIfAbsent(
          widget.miNombre,
          () => List.filled(_partida.categorias.length, ''),
        );
        for (var i = 0; i < misLocales.length && i < dest.length; i++) {
          if (misLocales[i].trim().isNotEmpty) {
            dest[i] = misLocales[i];
          }
        }
      }

      final entroAEscritura = _partida.fase == FaseTuti.escritura &&
          prevFase != FaseTuti.escritura;
      final nuevaRondaEscritura = _partida.fase == FaseTuti.escritura &&
          prevRonda != _partida.ronda;
      if (entroAEscritura ||
          nuevaRondaEscritura ||
          (_partida.fase == FaseTuti.escritura &&
              _respCtrls.length != _partida.categorias.length)) {
        _rebuildRespCtrls();
      }
    });

    if (deboFusionar) {
      unawaited(_publicarEstadoOnline());
    }
  }

  void _rebuildRespCtrls() {
    for (final c in _respCtrls) {
      c.dispose();
    }
    _respCtrls.clear();
    final forzarVacios = _partida.fase == FaseTuti.escritura &&
        !_partida.bastaTodos;
    if (forzarVacios) {
      final dest = _partida.respuestas.putIfAbsent(
        widget.miNombre,
        () => List.filled(_partida.categorias.length, ''),
      );
      for (var i = 0; i < dest.length; i++) {
        dest[i] = '';
      }
    }
    final mias = _partida.respuestas[widget.miNombre] ??
        List.filled(_partida.categorias.length, '');
    for (var i = 0; i < _partida.categorias.length; i++) {
      final texto = forzarVacios
          ? ''
          : (i < mias.length ? mias[i] : '');
      final ctrl = TextEditingController(text: texto);
      final idx = i;
      ctrl.addListener(() {
        setRespuestaTuti(_partida, widget.miNombre, idx, ctrl.text);
        _debounceRespuestas?.cancel();
        _debounceRespuestas = Timer(const Duration(milliseconds: 400), () {
          _publicarEstadoOnline();
        });
      });
      _respCtrls.add(ctrl);
    }
  }

  Future<void> _publicarEstadoOnline({bool forzar = false}) {
    final trabajo = () async {
      if (!mounted) return;
      for (var intento = 0; intento < 4; intento++) {
        if (!mounted) return;
        final faseAlPublicar = _partida.fase;
        _onlineVersion++;
        _partida.version = _onlineVersion;
        final gameState = encodeTutiGameState(_partida);
        _publicandoOnline = true;
        try {
          final res = await SalaService.instance.actualizarJuego(
            codigo: widget.salaCodigo,
            gameState: gameState,
          );
          if (!res.ignored) {
            final v =
                (res.sala.gameState?['version'] as num?)?.toInt() ??
                    _onlineVersion;
            _onlineVersion = v;
            _partida.version = v;
            return;
          }
          // Ignorado: alinear versión al servidor (puede ser menor que la optimista).
          final remoteGs = res.sala.gameState;
          final remoteV = res.sala.gameVersion;
          _onlineVersion = remoteV;
          _partida.version = remoteV;
          final remoteFase = FaseTutiX.fromId(remoteGs?['fase']?.toString());

          // El rival ya avanzó (PARAR / countdown) o publicó BASTA: adoptar.
          final remoteBasta = remoteGs?['bastaTodos'] == true;
          final bastaRemotoNuevo =
              remoteBasta && gameState['bastaTodos'] != true;
          if (remoteGs != null &&
              (remoteFase.orden > faseAlPublicar.orden || bastaRemotoNuevo)) {
            if (mounted) {
              _aplicarGameStateDeSala(res.sala, remoteGs, remoteFase);
            }
            return;
          }

          // Solo reintentar si debemos forzar un avance o el remoto está atrasado.
          if (forzar ||
              remoteFase.orden < faseAlPublicar.orden ||
              (gameState['bastaTodos'] == true && !remoteBasta)) {
            await Future<void>.delayed(
              Duration(milliseconds: 80 * (intento + 1)),
            );
            continue;
          }
          return;
        } catch (_) {
          await Future<void>.delayed(
            Duration(milliseconds: 120 * (intento + 1)),
          );
        } finally {
          _publicandoOnline = false;
        }
      }
    };

    _colaPublicacion = _colaPublicacion.then((_) => trabajo());
    return _colaPublicacion;
  }

  void _mutar(void Function() fn) {
    setState(fn);
    unawaited(_publicarEstadoOnline());
  }

  Future<void> _pararRuleta() async {
    if (_parandoRuleta) return;
    if (_partida.fase != FaseTuti.ruleta) return;
    setState(() {
      _parandoRuleta = true;
      pararRuletaTuti(_partida);
    });
    await _publicarEstadoOnline(forzar: true);
    if (mounted) setState(() => _parandoRuleta = false);
  }

  void _talvezAvanzarContador() {
    if (!_partida.fase.esContador) return;
    if (!_partida.contadorTerminado()) return;
    if (_publicandoOnline || _parandoRuleta) return;
    // Evita que muchos clientes avancen a la vez: solo anfitrión o parador.
    final soyParador =
        _partida.nombreParador == widget.miNombre;
    if (!_soyAnfitrion &&
        !(_partida.fase == FaseTuti.countdownEscritura && soyParador)) {
      return;
    }
    _mutar(() {
      avanzarContadorTuti(_partida);
      if (_partida.fase == FaseTuti.escritura) {
        _bastaLocalInicioMs = null;
        _rebuildRespCtrls();
      }
    });
  }

  void _talvezCerrarBasta() {
    if (_partida.fase != FaseTuti.escritura) return;
    if (!_partida.bastaTodos || !_partida.listoParaCerrarBasta()) return;
    // Quien dijo basta o el anfitrión cierra la escritura.
    final soyQuienDijo =
        _partida.bastaPor != null && _partida.bastaPor == widget.miNombre;
    if (!_soyAnfitrion && !soyQuienDijo) return;
    _debounceRespuestas?.cancel();
    _mutar(() {
      _flushRespuestasLocales();
      final mias = _partida.respuestas.putIfAbsent(
        widget.miNombre,
        () => List.filled(_partida.categorias.length, ''),
      );
      for (var i = 0; i < _respCtrls.length && i < mias.length; i++) {
        final t = _respCtrls[i].text;
        mias[i] = t.length > 40 ? t.substring(0, 40) : t;
      }
      cerrarEscrituraTrasBastaTuti(_partida);
      _bastaLocalInicioMs = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.25),
                radius: 1.15,
                colors: [
                  Color(0xFF3A1450),
                  AppColors.fondo,
                  Color(0xFF05020C),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _barraSuperior(),
                Expanded(child: _cuerpoFase()),
              ],
            ),
          ),
          if (_partida.fase == FaseTuti.fin)
            Positioned.fill(
              child: VictoriaTutiFrutiOverlay(
                partida: _partida,
                onVolver: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _barraSuperior() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, color: AppColors.texto),
          ),
          Expanded(
            child: Text(
              'Tutti Frutti · Ronda ${_partida.ronda}/${_partida.maxRondas}'
              '${_partida.letra != null ? ' · ${_partida.letra}' : ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.acento,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _cuerpoFase() {
    switch (_partida.fase) {
      case FaseTuti.countdownRuleta:
      case FaseTuti.countdownEscritura:
      case FaseTuti.countdownRevision:
        return _vistaContador();
      case FaseTuti.ruleta:
        return _vistaRuleta();
      case FaseTuti.escritura:
        return _vistaEscritura();
      case FaseTuti.revision:
        return _vistaRevision();
      case FaseTuti.fin:
        return _vistaFin();
    }
  }

  Widget _vistaContador() {
    final n = _partida.segundosRestantesContador();
    final label = switch (_partida.fase) {
      FaseTuti.countdownRuleta => 'Preparando ruleta…',
      FaseTuti.countdownEscritura => '¡A escribir!',
      FaseTuti.countdownRevision => 'Revisando respuestas…',
      _ => 'Cargando…',
    };
    final letraGrande = _partida.fase == FaseTuti.countdownEscritura &&
        (_partida.letra != null && _partida.letra!.isNotEmpty);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (letraGrande) ...[
            const Text(
              'Letra',
              style: TextStyle(
                color: AppColors.textoSuave,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _partida.letra!,
              style: TextStyle(
                color: AppColors.acento,
                fontWeight: FontWeight.w900,
                fontSize: 96,
                shadows: neonGlow(AppColors.acento, blur: 24),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${n == 0 ? 1 : n}',
            style: TextStyle(
              color: AppColors.rosa,
              fontWeight: FontWeight.w900,
              fontSize: 72,
              shadows: neonGlow(AppColors.rosa, blur: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vistaRuleta() {
    final letra = _partida.letraActualRuleta();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
              onTap: _esMiSpinner &&
              !_parandoRuleta &&
              _partida.fase == FaseTuti.ruleta
          ? () {
              if (_partida.fase != FaseTuti.ruleta) return;
              setState(() => acelerarRuletaTuti(_partida));
              final ahora = DateTime.now();
              final ultimo = _ultimoAcelerarPub;
              if (ultimo == null ||
                  ahora.difference(ultimo) >
                      const Duration(milliseconds: 350)) {
                _ultimoAcelerarPub = ahora;
                unawaited(_publicarEstadoOnline());
              }
            }
          : null,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _esMiSpinner
                    ? 'Tocá para acelerar'
                    : (_esMiParador
                        ? '¡Pará la ruleta!'
                        : 'Ruleta de ${_partida.nombreSpinner}'),
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                letra,
                style: TextStyle(
                  color: AppColors.acento,
                  fontWeight: FontWeight.w900,
                  fontSize: 120,
                  shadows: neonGlow(AppColors.acento, blur: 28),
                ),
              ),
              const SizedBox(height: 28),
              if (_esMiParador)
                ElevatedButton(
                  onPressed: _parandoRuleta ? null : () => _pararRuleta(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.peligro,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(220, 56),
                  ),
                  child: _parandoRuleta
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('PARAR'),
                )
              else if (!_esMiSpinner)
                Text(
                  'Espera a que ${_partida.nombreParador} pare…',
                  style: const TextStyle(color: AppColors.textoSuave),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vistaEscritura() {
    if (_respCtrls.length != _partida.categorias.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(_rebuildRespCtrls);
      });
    }
    final bloqueado = _escrituraBloqueadaLocal;
    final bastaActivo = _mostrarAvisoBasta;

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Text(
                'Letra: ${_partida.letra ?? '—'}',
                style: const TextStyle(
                  color: AppColors.acento,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              if (bastaActivo) const SizedBox(height: 88),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
                  ),
                  itemCount: _partida.categorias.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    return Row(
                      children: [
                        Container(
                          width: 110,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5A5568),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _partida.categorias[i],
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: i < _respCtrls.length
                                ? _respCtrls[i]
                                : null,
                            enabled: !bloqueado && i < _respCtrls.length,
                            textInputAction: i < _partida.categorias.length - 1
                                ? TextInputAction.next
                                : TextInputAction.done,
                            scrollPadding: const EdgeInsets.only(
                              top: 100,
                              bottom: 160,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Escribí…',
                              filled: true,
                              fillColor: Color(0xFFF5F5F5),
                              hintStyle: TextStyle(color: Colors.black45),
                            ),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              if (!bastaActivo && !bloqueado && !_partida.bastaTodos)
                ElevatedButton(
                  onPressed: () {
                    _debounceRespuestas?.cancel();
                    setState(() {
                      _flushRespuestasLocales();
                      bastaTuti(_partida, widget.miNombre);
                      // Quien dice basta no ve el aviso ni el contador.
                      _bastaLocalInicioMs = null;
                    });
                    unawaited(_publicarEstadoOnline(forzar: true));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.peligro,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(58),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Basta para mi, basta para todos',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      height: 1.2,
                    ),
                  ),
                )
              else if (_yoDijeBasta && _partida.fase == FaseTuti.escritura)
                const Text(
                  'Dijiste BASTA. Esperando a los demás…',
                  style: TextStyle(color: AppColors.mint),
                )
              else if (bloqueado)
                const Text(
                  '¡Tiempo! Esperando revisión…',
                  style: TextStyle(color: AppColors.mint),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        if (bastaActivo)
          Positioned(
            top: 0,
            left: 12,
            right: 12,
            child: Material(
              color: Colors.transparent,
              child: _AvisoBastaOverlay(
                quien: _partida.bastaPor ?? 'Alguien',
                progreso: _progresoBastaLocal,
              ),
            ),
          ),
      ],
    );
  }

  Widget _vistaRevision() {
    final catIdx = _partida.categoriaRevision;
    final catNombre = catIdx < _partida.categorias.length
        ? _partida.categorias[catIdx]
        : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Text(
            'Categoría: $catNombre',
            style: const TextStyle(
              color: AppColors.acento,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          Text(
            'Letra ${_partida.letra ?? '—'} · '
            '${catIdx + 1}/${_partida.categorias.length}',
            style: const TextStyle(color: AppColors.textoSuave),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _partida.nombres.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final nombre = _partida.nombres[i];
                final respList = _partida.respuestas[nombre] ?? const <String>[];
                final ptsList = _partida.puntajes[nombre] ?? const <int?>[];
                final respRaw =
                    catIdx < respList.length ? respList[catIdx] : '';
                final resp =
                    respRaw.trim().isEmpty ? '—' : respRaw;
                final pts = catIdx < ptsList.length ? ptsList[catIdx] : null;
                final esMio = nombre == widget.miNombre;
                return _TarjetaRespuesta(
                  nombre: nombre,
                  respuesta: resp,
                  puntos: pts,
                  esMio: esMio,
                  onElegirPuntos: esMio
                      ? (v) => _mutar(
                            () => setPuntajePropioTuti(
                              _partida,
                              widget.miNombre,
                              catIdx,
                              v,
                            ),
                          )
                      : null,
                );
              },
            ),
          ),
          if (_soyAnfitrion) ...[
            if (!todosVotaronCategoriaTuti(_partida)) ...[
              Text(
                'Falta que voten: ${pendientesVotoTuti(_partida).join(', ')}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Builder(
              builder: (_) {
                final ultimaCat = esUltimaCategoriaRevisionTuti(_partida);
                final quedan = quedanRondasTuti(_partida);
                final puedenContinuar =
                    todosVotaronCategoriaTuti(_partida);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!ultimaCat)
                      ElevatedButton(
                        onPressed: puedenContinuar
                            ? () => _mutar(
                                  () => continuarRevisionTuti(_partida),
                                )
                            : null,
                        child: const Text('Continuar'),
                      )
                    else ...[
                      if (quedan)
                        ElevatedButton(
                          onPressed: puedenContinuar
                              ? () => _mutar(
                                    () => continuarRevisionTuti(_partida),
                                  )
                              : null,
                          child: const Text('Siguiente ronda'),
                        ),
                      if (quedan) const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: puedenContinuar
                            ? () =>
                                _mutar(() => acabarPartidaTuti(_partida))
                            : null,
                        child: Text(
                          quedan
                              ? 'Se acabó la partida'
                              : 'Ver ranking',
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Builder(
                builder: (_) {
                  final mis =
                      _partida.puntajes[widget.miNombre] ?? const <int?>[];
                  final yaVote =
                      catIdx < mis.length && mis[catIdx] != null;
                  final texto = todosVotaronCategoriaTuti(_partida)
                      ? 'Esperando al anfitrión…'
                      : (yaVote
                          ? 'Esperando que voten los demás…'
                          : 'Elegí tu puntaje para continuar');
                  return Text(
                    texto,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textoSuave),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _vistaFin() {
    final ranking = rankingTuti(_partida);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            '¡Fin de la partida!',
            style: TextStyle(
              color: AppColors.acento,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: ranking.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final e = ranking[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.carta,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cartaBorde),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '#${i + 1}',
                        style: const TextStyle(
                          color: AppColors.rosa,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          e.key,
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        '${e.value}',
                        style: const TextStyle(
                          color: AppColors.acento,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Volver al menú'),
          ),
        ],
      ),
    );
  }
}

class _TarjetaRespuesta extends StatelessWidget {
  const _TarjetaRespuesta({
    required this.nombre,
    required this.respuesta,
    required this.puntos,
    required this.esMio,
    this.onElegirPuntos,
  });

  final String nombre;
  final String respuesta;
  final int? puntos;
  final bool esMio;
  final ValueChanged<int>? onElegirPuntos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.carta,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: esMio ? AppColors.rosa : AppColors.cartaBorde,
          width: esMio ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nombre,
                  style: TextStyle(
                    color: esMio ? AppColors.rosa : AppColors.texto,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                puntos == null ? '—' : '$puntos',
                style: const TextStyle(
                  color: AppColors.acento,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              respuesta,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          if (esMio && onElegirPuntos != null) ...[
            const SizedBox(height: 10),
            Text(
              puntos == null
                  ? 'Tocá el círculo y elegí tu puntaje'
                  : 'Puntaje obtenido en este turno:',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textoSuave,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: InkWell(
                onTap: () async {
                  final v = await showModalBottomSheet<int>(
                    context: context,
                    backgroundColor: AppColors.carta,
                    builder: (ctx) {
                      return SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Elegí puntaje',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                children: [
                                  for (final p in [0, 5, 10, 20])
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, p),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.rosa,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(64, 48),
                                      ),
                                      child: Text('$p'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                  if (v != null) onElegirPuntos!(v);
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: puntos == null
                        ? Colors.transparent
                        : AppColors.fondoSuave,
                    border: Border.all(
                      color: puntos == null
                          ? AppColors.textoSuave
                          : AppColors.rosa,
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                    boxShadow: puntos == null
                        ? null
                        : neonGlow(AppColors.rosa, blur: 10),
                  ),
                  child: Text(
                    puntos == null ? '—' : '$puntos',
                    style: TextStyle(
                      color: puntos == null
                          ? AppColors.textoSuave
                          : AppColors.texto,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Aviso de BASTA: mensaje + anillo que se vacía en la gracia local.
class _AvisoBastaOverlay extends StatelessWidget {
  const _AvisoBastaOverlay({
    required this.quien,
    required this.progreso,
  });

  final String quien;
  final double progreso;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.carta.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.peligro, width: 1.6),
        boxShadow: [
          ...neonGlow(AppColors.peligro, blur: 16),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¡BASTA! · $quien',
                  style: const TextStyle(
                    color: AppColors.peligro,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Últimos segundos para escribir…',
                  style: TextStyle(
                    color: AppColors.textoSuave,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            height: 64,
            child: CustomPaint(
              painter: _AnilloBastaPainter(
                progreso: progreso,
                color: AppColors.peligro,
              ),
              child: Center(
                child: Text(
                  progreso <= 0
                      ? '0'
                      : '${(progreso * 2).ceil().clamp(1, 2)}',
                  style: const TextStyle(
                    color: AppColors.peligro,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnilloBastaPainter extends CustomPainter {
  _AnilloBastaPainter({required this.progreso, required this.color});

  final double progreso;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final fondo = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, fondo);

    final arco = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    const start = -1.57079632679; // -pi/2
    final sweep = 6.28318530718 * progreso.clamp(0.0, 1.0);
    if (sweep > 0.001) {
      canvas.drawArc(rect, start, sweep, false, arco);
    }
  }

  @override
  bool shouldRepaint(covariant _AnilloBastaPainter oldDelegate) =>
      oldDelegate.progreso != progreso || oldDelegate.color != color;
}

