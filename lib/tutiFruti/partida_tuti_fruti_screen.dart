import 'dart:async';

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/models/sala.dart';
import 'package:app_juegos_mesa/services/sala_service.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';
import 'package:app_juegos_mesa/tutiFruti/motor_tuti_fruti.dart';
import 'package:app_juegos_mesa/tutiFruti/tuti_fruti_online_codec.dart';

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

  bool get _esMiSpinner =>
      _partida.nombreSpinner == widget.miNombre;
  bool get _esMiParador =>
      _partida.nombreParador == widget.miNombre;

  @override
  void initState() {
    super.initState();
    _partida = nuevaPartidaTuti(
      nombres: widget.nombres,
      categorias: const ['…'],
    );
    _iniciarSincronizacionOnline();
    _tick = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted) return;
      if (_partida.fase == FaseTuti.ruleta || _partida.fase.esContador) {
        setState(() {});
        _talvezAvanzarContador();
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
        .watch(codigo, intervalo: const Duration(milliseconds: 1200))
        .listen(_onSalaOnlineActualizada);
  }

  void _onSalaOnlineActualizada(Sala sala) {
    if (!mounted) return;
    final gameState = sala.gameState;
    if (gameState == null) return;
    final version = (gameState['version'] as num?)?.toInt() ?? 0;
    if (version <= _onlineVersion || _publicandoOnline) return;

    setState(() {
      final host = sala.jugadores
          .where((j) => j.id == sala.anfitrionId)
          .firstOrNull;
      _soyAnfitrion = host?.nombre == widget.miNombre;

      final prevFase = _partida.fase;
      applyTutiGameState(_partida, gameState);
      _onlineVersion = version;
      if (_partida.fase == FaseTuti.escritura &&
          (prevFase != FaseTuti.escritura ||
              _respCtrls.length != _partida.categorias.length)) {
        _rebuildRespCtrls();
      }
    });
  }

  void _rebuildRespCtrls() {
    for (final c in _respCtrls) {
      c.dispose();
    }
    _respCtrls.clear();
    final mias = _partida.respuestas[widget.miNombre] ??
        List.filled(_partida.categorias.length, '');
    for (var i = 0; i < _partida.categorias.length; i++) {
      final ctrl = TextEditingController(text: i < mias.length ? mias[i] : '');
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

  Future<void> _publicarEstadoOnline() async {
    _onlineVersion++;
    _partida.version = _onlineVersion;
    final gameState = encodeTutiGameState(_partida);
    _publicandoOnline = true;
    try {
      await SalaService.instance.actualizarJuego(
        codigo: widget.salaCodigo,
        gameState: gameState,
      );
    } catch (_) {
    } finally {
      _publicandoOnline = false;
    }
  }

  void _mutar(void Function() fn) {
    setState(fn);
    unawaited(_publicarEstadoOnline());
  }

  void _talvezAvanzarContador() {
    if (!_soyAnfitrion) return;
    if (!_partida.fase.esContador) return;
    if (!_partida.contadorTerminado()) return;
    _mutar(() => avanzarContadorTuti(_partida));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
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
              'Tutti Frutti · Ronda ${_partida.ronda}'
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
      FaseTuti.countdownEscritura =>
        'Letra: ${_partida.letra ?? '—'} · ¡A escribir!',
      FaseTuti.countdownRevision => 'Revisando respuestas…',
      _ => 'Cargando…',
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            '${n == 0 ? 1 : n}',
            style: TextStyle(
              color: AppColors.rosa,
              fontWeight: FontWeight.w900,
              fontSize: 96,
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
      onTap: _esMiSpinner
          ? () => _mutar(() => acelerarRuletaTuti(_partida))
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
                  onPressed: () => _mutar(() => pararRuletaTuti(_partida)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.peligro,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(220, 56),
                  ),
                  child: const Text('PARAR'),
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
    final bloqueado =
        _partida.listos[widget.miNombre] == true || _partida.bastaTodos;

    return Padding(
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
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
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
          if (!bloqueado) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _mutar(() => bastaParaMiTuti(_partida, widget.miNombre)),
                    child: const Text('Basta para mí'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _mutar(() => bastaParaTodosTuti(_partida)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.peligro,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Basta para todos'),
                  ),
                ),
              ],
            ),
          ] else
            Text(
              _partida.bastaTodos
                  ? '¡Basta! Esperando revisión…'
                  : 'Listo. Esperando a los demás…',
              style: const TextStyle(color: AppColors.mint),
            ),
          const SizedBox(height: 12),
        ],
      ),
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
            ElevatedButton(
              onPressed: () => _mutar(() => continuarRevisionTuti(_partida)),
              child: Text(
                catIdx + 1 < _partida.categorias.length
                    ? 'Continuar'
                    : 'Siguiente ronda',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _mutar(() => acabarPartidaTuti(_partida)),
              child: const Text('Se acabó la partida'),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Esperando al anfitrión…',
                style: TextStyle(color: AppColors.textoSuave),
              ),
            ),
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
          Text(
            respuesta,
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          if (esMio && onElegirPuntos != null) ...[
            const SizedBox(height: 10),
            const Text(
              'Puntaje obtenido en este turno:',
              textAlign: TextAlign.center,
              style: TextStyle(
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
                    color: AppColors.fondoSuave,
                    border: Border.all(color: AppColors.rosa, width: 2),
                    boxShadow: neonGlow(AppColors.rosa, blur: 10),
                  ),
                  child: Text(
                    puntos == null ? '?' : '$puntos',
                    style: const TextStyle(
                      color: AppColors.texto,
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
