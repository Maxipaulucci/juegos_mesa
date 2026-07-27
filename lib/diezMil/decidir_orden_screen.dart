import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'dado_widget.dart';

/// Cada jugador tira un dado; el más alto empieza. Empates se resuelven
/// volviendo a tirar solo los empatados (el desempate solo ordena dentro
/// de ese grupo, sin pisar a quienes ya sacaron más alto).
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
  /// Historial de tiradas: la 1.ª define el grupo; las siguientes solo
  /// desempatan dentro del mismo prefijo.
  final List<int> tiradas = [];

  int? get valorMostrado => tiradas.isEmpty ? null : tiradas.last;

  String get claveGrupo => tiradas.join(',');
}

class _DecidirOrdenScreenState extends State<DecidirOrdenScreen> {
  final _rng = math.Random();
  late final List<_ResultadoTiradaOrden> _jugadores;
  /// Índices en [_jugadores] que deben tirar en esta ronda.
  late List<int> _cola;
  int _posCola = 0;
  bool _tirando = false;
  int? _valorAnimado;
  bool _mostrarOrden = false;
  /// Se apaga al tirar y vuelve al pasar el turno al siguiente.
  bool _puedeTirar = true;

  _ResultadoTiradaOrden get _actual => _jugadores[_cola[_posCola]];

  bool get _rondaDeDesempate => _jugadores.any((j) => j.tiradas.isNotEmpty) &&
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
  }

  static Color _colorDe(int index) => switch (index) {
        0 => AppColors.acento,
        1 => AppColors.azul,
        2 => AppColors.peligro,
        _ => AppColors.mint,
      };

  Future<void> _tirar() async {
    if (!_puedeTirar || _tirando || _mostrarOrden) return;
    setState(() {
      _puedeTirar = false;
      _tirando = true;
      _valorAnimado = null;
    });

    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 55));
      if (!mounted) return;
      setState(() => _valorAnimado = _rng.nextInt(6) + 1);
    }

    final valor = _rng.nextInt(6) + 1;
    _actual.tiradas.add(valor);
    if (!mounted) return;
    setState(() {
      _valorAnimado = valor;
      _tirando = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    _avanzarTrasTirada();

    // Recién cuando ya cambió el turno (nombre / dado vacío) se puede tirar.
    if (!mounted || _mostrarOrden) return;
    setState(() => _puedeTirar = true);
  }

  void _avanzarTrasTirada() {
    if (_posCola < _cola.length - 1) {
      setState(() {
        _posCola++;
        _valorAnimado = null;
      });
      return;
    }

    // Empates: mismo historial completo (mismo grupo). Un 5 de desempate
    // entre los que sacaron 1 no compite con quien sacó 5 en la 1.ª ronda.
    final porGrupo = <String, List<int>>{};
    for (var i = 0; i < _jugadores.length; i++) {
      final j = _jugadores[i];
      if (j.tiradas.isEmpty) continue;
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
        _valorAnimado = null;
      });
      return;
    }

    setState(() => _mostrarOrden = true);
  }

  /// Orden: se compara tirada a tirada (más alto gana). Así [5] queda
  /// delante de [1, 5], y [1, 5] delante de [1, 2].
  List<_ResultadoTiradaOrden> get _ordenFinal {
    final lista = List<_ResultadoTiradaOrden>.of(_jugadores);
    lista.sort((a, b) {
      final n = math.max(a.tiradas.length, b.tiradas.length);
      for (var i = 0; i < n; i++) {
        final va = i < a.tiradas.length ? a.tiradas[i] : -1;
        final vb = i < b.tiradas.length ? b.tiradas[i] : -1;
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
                            : 'Tirada para el orden',
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
                            ? 'Hay empate: solo vuelven a tirar quienes empataron.'
                            : 'Cada jugador tira un dado. El más alto empieza.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textoSuave,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 18),
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
                              valor: j.valorMostrado,
                              accent: accent,
                              destacado: esActual,
                              pendiente: pendiente && j.valorMostrado == null,
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
                          'Te toca tirar',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textoSuave,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: DadoFace(
                            valor: _valorAnimado ?? 1,
                            vacio: _valorAnimado == null,
                            suma: true,
                            tamano: 88,
                          ),
                        ),
                        const SizedBox(height: 22),
                        ElevatedButton(
                          onPressed:
                              (_puedeTirar && !_tirando) ? _tirar : null,
                          child: Text(_tirando ? 'Tirando…' : 'Tirar dado'),
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

class _FilaResultado extends StatelessWidget {
  const _FilaResultado({
    required this.nombre,
    required this.valor,
    required this.accent,
    required this.destacado,
    required this.pendiente,
  });

  final String nombre;
  final int? valor;
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
          if (valor != null)
            DadoFace(valor: valor!, suma: true, tamano: 36)
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
                        Icons.casino_rounded,
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
                            if (orden[i].tiradas.isNotEmpty)
                              DadoFace(
                                valor: orden[i].tiradas.first,
                                suma: true,
                                tamano: 32,
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
