import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';

enum _PaloOrden { oro, copa, espada, basto }

class _CartaOrden {
  const _CartaOrden({required this.numero, required this.palo});

  /// 1–12.
  final int numero;
  final _PaloOrden palo;

  String get nombrePalo => switch (palo) {
        _PaloOrden.oro => 'oro',
        _PaloOrden.copa => 'copa',
        _PaloOrden.espada => 'espada',
        _PaloOrden.basto => 'basto',
      };

  String get etiqueta => '$numero de $nombrePalo';

  @override
  bool operator ==(Object other) =>
      other is _CartaOrden && other.numero == numero && other.palo == palo;

  @override
  int get hashCode => Object.hash(numero, palo);
}

/// Mazo español completo: 12 cartas × 4 palos = 48 (sin comodines).
List<_CartaOrden> _crearMazoOrden() => [
      for (final palo in _PaloOrden.values)
        for (var n = 1; n <= 12; n++) _CartaOrden(numero: n, palo: palo),
    ];

/// Cada jugador saca una carta del mazo español; gana el número más alto
/// (el palo no importa). Empates: solo los empatados vuelven a sacar,
/// sin repetir cartas ya salidas.
class DecidirOrdenScreen extends StatefulWidget {
  const DecidirOrdenScreen({super.key, required this.nombres});

  final List<String> nombres;

  @override
  State<DecidirOrdenScreen> createState() => _DecidirOrdenScreenState();
}

class _ResultadoTiradaOrden {
  _ResultadoTiradaOrden({required this.nombre, required this.indiceOriginal});

  final String nombre;
  final int indiceOriginal;
  /// Historial de cartas: la 1.ª define el grupo; las siguientes solo
  /// desempatan dentro del mismo prefijo de números.
  final List<_CartaOrden> cartas = [];

  _CartaOrden? get cartaMostrada => cartas.isEmpty ? null : cartas.last;

  /// Clave de grupo por números (sin palo), para empates.
  String get claveGrupo =>
      [for (final c in cartas) c.numero].join(',');
}

class _DecidirOrdenScreenState extends State<DecidirOrdenScreen> {
  final _rng = math.Random();
  late final List<_ResultadoTiradaOrden> _jugadores;
  late final List<_CartaOrden> _mazo;
  /// Índices en [_jugadores] que deben sacar en esta ronda.
  late List<int> _cola;
  int _posCola = 0;
  bool _sacando = false;
  _CartaOrden? _cartaAnimada;
  bool _mostrarOrden = false;
  bool _puedeSacar = true;

  _ResultadoTiradaOrden get _actual => _jugadores[_cola[_posCola]];

  bool get _rondaDeDesempate =>
      _jugadores.any((j) => j.cartas.isNotEmpty) &&
      _cola.length < _jugadores.length;

  @override
  void initState() {
    super.initState();
    _jugadores = [
      for (var i = 0; i < widget.nombres.length; i++)
        _ResultadoTiradaOrden(
          nombre: widget.nombres[i],
          indiceOriginal: i,
        ),
    ];
    _cola = List.generate(_jugadores.length, (i) => i);
    _mazo = _crearMazoOrden()..shuffle(_rng);
  }

  static Color _colorDe(int index) => switch (index) {
        0 => AppColors.acento,
        1 => AppColors.azul,
        2 => AppColors.peligro,
        _ => AppColors.mint,
      };

  _CartaOrden _sacarDelMazo() {
    if (_mazo.isEmpty) {
      // Por si se agotara el mazo en desempatados extremos: reponer sin
      // las cartas ya usadas en el historial actual.
      final usadas = <_CartaOrden>{
        for (final j in _jugadores) ...j.cartas,
      };
      _mazo.addAll([
        for (final c in _crearMazoOrden())
          if (!usadas.contains(c)) c,
      ]);
      _mazo.shuffle(_rng);
    }
    return _mazo.removeLast();
  }

  Future<void> _sacarCarta() async {
    if (!_puedeSacar || _sacando || _mostrarOrden) return;
    setState(() {
      _puedeSacar = false;
      _sacando = true;
      _cartaAnimada = null;
    });

    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 55));
      if (!mounted) return;
      // Animación solo visual; no consume del mazo real.
      final preview = _mazo.isEmpty
          ? _crearMazoOrden()[_rng.nextInt(48)]
          : _mazo[_rng.nextInt(_mazo.length)];
      setState(() => _cartaAnimada = preview);
    }

    final carta = _sacarDelMazo();
    _actual.cartas.add(carta);
    if (!mounted) return;
    setState(() {
      _cartaAnimada = carta;
      _sacando = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    _avanzarTrasSacar();

    if (!mounted || _mostrarOrden) return;
    setState(() => _puedeSacar = true);
  }

  void _avanzarTrasSacar() {
    if (_posCola < _cola.length - 1) {
      setState(() {
        _posCola++;
        _cartaAnimada = null;
      });
      return;
    }

    // Empates: mismo historial de números. Un 5 de desempate entre los
    // que sacaron 1 no compite con quien sacó 5 en la 1.ª ronda.
    final porGrupo = <String, List<int>>{};
    for (var i = 0; i < _jugadores.length; i++) {
      final j = _jugadores[i];
      if (j.cartas.isEmpty) continue;
      porGrupo.putIfAbsent(j.claveGrupo, () => []).add(i);
    }
    final empatados = <int>[
      for (final grupo in porGrupo.values)
        if (grupo.length > 1) ...grupo,
    ];

    if (empatados.isNotEmpty) {
      setState(() {
        _cola = empatados;
        _posCola = 0;
        _cartaAnimada = null;
      });
      return;
    }

    setState(() => _mostrarOrden = true);
  }

  /// Orden: se compara número a número (más alto gana). El palo no importa.
  List<_ResultadoTiradaOrden> get _ordenFinal {
    final lista = List<_ResultadoTiradaOrden>.of(_jugadores);
    lista.sort((a, b) {
      final n = math.max(a.cartas.length, b.cartas.length);
      for (var i = 0; i < n; i++) {
        final va = i < a.cartas.length ? a.cartas[i].numero : -1;
        final vb = i < b.cartas.length ? b.cartas[i].numero : -1;
        if (va != vb) return vb.compareTo(va);
      }
      return a.indiceOriginal.compareTo(b.indiceOriginal);
    });
    return lista;
  }

  void _confirmarOrden() {
    Navigator.of(context).pop(
      _ordenFinal.map((j) => j.nombre).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: const Text('Decidir orden'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _rondaDeDesempate
                            ? 'Desempate'
                            : 'Cartas para el orden',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.acento,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _rondaDeDesempate
                            ? 'Hay empate: solo vuelven a sacar quienes empataron.'
                            : 'Cada jugador saca una carta del mazo español. '
                                'Gana el número más alto (el palo no importa).',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textoSuave,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cartas en el mazo: ${_mazo.length}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textoSuave,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _jugadores.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final j = _jugadores[i];
                            final idxEnCola = _cola.indexOf(i);
                            final enCola = idxEnCola >= 0;
                            final esActual = !_mostrarOrden &&
                                enCola &&
                                idxEnCola == _posCola;
                            final accent = _colorDe(j.indiceOriginal);
                            final pendiente = !_mostrarOrden &&
                                enCola &&
                                idxEnCola > _posCola;
                            return _FilaResultado(
                              nombre: j.nombre,
                              carta: j.cartaMostrada,
                              accent: accent,
                              destacado: esActual,
                              pendiente:
                                  pendiente && j.cartaMostrada == null,
                            );
                          },
                        ),
                      ),
                      if (!_mostrarOrden) ...[
                        const SizedBox(height: 12),
                        Text(
                          _actual.nombre.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _colorDe(_actual.indiceOriginal),
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            shadows: [
                              Shadow(
                                color: _colorDe(_actual.indiceOriginal)
                                    .withValues(alpha: 0.7),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Te toca sacar una carta',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textoSuave,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: _CartaFace(
                            carta: _cartaAnimada,
                            vacia: _cartaAnimada == null,
                            tamano: 108,
                          ),
                        ),
                        const SizedBox(height: 22),
                        ElevatedButton(
                          onPressed: (_puedeSacar && !_sacando)
                              ? _sacarCarta
                              : null,
                          child: Text(
                            _sacando ? 'Sacando…' : 'Sacar carta',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_mostrarOrden)
            _CartelOrden(
              orden: _ordenFinal,
              colorDe: _colorDe,
              onConfirmar: _confirmarOrden,
            ),
        ],
      ),
    );
  }
}

class _CartaFace extends StatelessWidget {
  const _CartaFace({
    required this.carta,
    this.vacia = false,
    this.tamano = 72,
  });

  final _CartaOrden? carta;
  final bool vacia;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final c = carta;
    return Container(
      width: tamano * 0.72,
      height: tamano,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.carta,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: vacia || c == null
              ? AppColors.textoSuave.withValues(alpha: 0.4)
              : AppColors.acento,
          width: 2,
        ),
        boxShadow: vacia || c == null
            ? null
            : neonGlow(AppColors.acento, blur: 10),
      ),
      child: vacia || c == null
          ? const Text(
              '?',
              style: TextStyle(
                color: AppColors.textoSuave,
                fontWeight: FontWeight.w900,
                fontSize: 28,
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${c.numero}',
                  style: const TextStyle(
                    color: AppColors.acento,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  c.nombrePalo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
    );
  }
}

class _FilaResultado extends StatelessWidget {
  const _FilaResultado({
    required this.nombre,
    required this.carta,
    required this.accent,
    required this.destacado,
    required this.pendiente,
  });

  final String nombre;
  final _CartaOrden? carta;
  final Color accent;
  final bool destacado;
  final bool pendiente;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.carta.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: destacado ? accent : accent.withValues(alpha: 0.45),
          width: destacado ? 2.2 : 1.2,
        ),
        boxShadow: destacado ? neonGlow(accent, blur: 12) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              nombre,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                shadows: [
                  Shadow(color: accent.withValues(alpha: 0.5), blurRadius: 8),
                ],
              ),
            ),
          ),
          if (carta != null)
            Text(
              carta!.etiqueta,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            )
          else
            Text(
              pendiente ? 'Pendiente' : '—',
              style: TextStyle(
                color: pendiente ? AppColors.acentoSuave : AppColors.textoSuave,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }
}

class _CartelOrden extends StatelessWidget {
  const _CartelOrden({
    required this.orden,
    required this.colorDe,
    required this.onConfirmar,
  });

  final List<_ResultadoTiradaOrden> orden;
  final Color Function(int) colorDe;
  final VoidCallback onConfirmar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
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
                        Icons.style_rounded,
                        color: AppColors.acento,
                        size: 36,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'El orden ha sido decidido',
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
                        'Así empieza la partida:',
                        style: TextStyle(
                          color: AppColors.textoSuave,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (var i = 0; i < orden.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorDe(orden[i].indiceOriginal)
                                    .withValues(alpha: 0.25),
                                border: Border.all(
                                  color: colorDe(orden[i].indiceOriginal),
                                ),
                              ),
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: colorDe(orden[i].indiceOriginal),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                orden[i].nombre,
                                style: const TextStyle(
                                  color: AppColors.texto,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (orden[i].cartas.isNotEmpty)
                              Text(
                                orden[i].cartas.first.etiqueta,
                                style: TextStyle(
                                  color: colorDe(orden[i].indiceOriginal),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 22),
                      ElevatedButton(
                        onPressed: onConfirmar,
                        child: const Text('Empezar partida'),
                      ),
                    ],
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
