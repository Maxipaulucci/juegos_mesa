import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
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
  });

  final List<String> nombres;
  final Modo modo;

  @override
  State<PartidaDiezMilScreen> createState() => _PartidaDiezMilScreenState();
}

class _PartidaDiezMilScreenState extends State<PartidaDiezMilScreen> {
  late final Partida _partida;
  late final EstadisticasPartida _stats;
  ResultadoTirada? _ultimaTirada;
  ResumenTirada? _ultimoResumen;
  String? _mensaje;
  bool _esperandoEspecial = false;
  bool _mostrarVictoria = false;
  final Map<String, int> _mejorTurno = {};
  int _navIndex = 0;

  // TEMPORAL (testing): fuerza los valores de la próxima tirada.
  List<int>? _dadosForzados;

  @override
  void initState() {
    super.initState();
    _partida = nuevaPartida(widget.nombres, widget.modo);
    _stats = EstadisticasPartida(widget.nombres);
    iniciarTurno(_partida);
    for (final j in _partida.jugadores) {
      _mejorTurno[j.nombre] = 0;
    }
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

  // TEMPORAL (testing): elegí a mano los dados de la próxima tirada.
  Future<void> _configurarDadosForzados() async {
    final cantidad = _partida.turno.dadosEnMano;
    final ctrl = TextEditingController(
      text: _dadosForzados?.join(' ') ?? '',
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Escribí $cantidad valores (1 a 6) separados por espacio.\nEj: 1 1 5 5 6',
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
                style: const TextStyle(color: AppColors.texto),
                decoration: InputDecoration(
                  hintText: List.filled(cantidad, '•').join(' '),
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            if (_dadosForzados != null)
              TextButton(
                onPressed: () => Navigator.of(context).pop(<int>[]),
                child: const Text(
                  'Quitar',
                  style: TextStyle(color: AppColors.peligro),
                ),
              ),
            ElevatedButton(
              onPressed: () {
                final partes = ctrl.text
                    .split(RegExp(r'[\s,;]+'))
                    .where((p) => p.isNotEmpty)
                    .toList();
                final nums = partes.map(int.tryParse).toList();
                if (nums.length != cantidad ||
                    nums.any((n) => n == null || n < 1 || n > 6)) {
                  setDialogState(() {
                    error =
                        'Ingresá exactamente $cantidad números entre 1 y 6.';
                  });
                  return;
                }
                Navigator.of(context).pop(nums.cast<int>());
              },
              child: const Text('Aplicar'),
            ),
          ],
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
    final resumen = aplicarPuntosTirada(_partida, resultado, especial);
    final puntosReg = resumen.bust ? 0 : resumen.puntosTirada;
    _stats.registrar(nombre, puntosReg);

    setState(() {
      _ultimaTirada = resultado;
      _ultimoResumen = resumen;
      _esperandoEspecial = false;
      if (resumen.victoria) {
        _mensaje = '¡${_partida.jugadorActual.nombre} gana!';
      } else if (resumen.bust) {
        _mensaje =
            'No sumaste nada. Perdés los ${resumen.puntosPerdidos} pts del turno.';
      } else if (resumen.hotDice) {
        _mensaje = '¡Hot dice! Tirás de nuevo con ${_partida.modo.dados} dados.';
      } else {
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
          _mejorTurno[nombre] = math.max(_mejorTurno[nombre] ?? 0, sumados);
          _mensaje = '¡$nombre llega a $meta y gana!';
        case 'banco':
          _mejorTurno[nombre] = math.max(_mejorTurno[nombre] ?? 0, sumados);
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
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _Header(
                              dados: _partida.modo.dados,
                              onBack: () => Navigator.of(context).maybePop(),
                              onSettings: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Ajustes próximamente'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                            for (var i = 0;
                                i < _partida.jugadores.length;
                                i++)
                              _PlayerCard(
                                jugador: _partida.jugadores[i],
                                index: i,
                                activo: !terminada &&
                                    identical(_partida.jugadores[i], j),
                                esTu: i == 0,
                                mejorTurno: _mejorTurno[
                                        _partida.jugadores[i].nombre] ??
                                    0,
                              ),
                            _TurnoBanner(
                              nombre: terminada
                                  ? (_partida.ganador ?? '')
                                  : j.nombre,
                              terminada: terminada,
                              ptsTurno: t.puntosTurno,
                              ptsTirada: ptsTirada,
                              mensaje: _mensaje,
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _DadosZona(
                                    cantidad: _partida.modo.dados,
                                    dados: _ultimaTirada?.dados,
                                    suman: _dadosQueSuman(),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // TEMPORAL (testing): forzar próxima tirada
                                Tooltip(
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
                                                    .withValues(alpha: 0.5),
                                            width:
                                                _dadosForzados != null ? 2 : 1,
                                          ),
                                          boxShadow: _dadosForzados != null
                                              ? neonGlow(AppColors.mint,
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
                              ],
                            ),
                            _CombosBar(
                              combos: (_ultimoResumen != null &&
                                      !_ultimoResumen!.bust)
                                  ? _ultimoResumen!.combos
                                  : const [],
                              total: ptsTirada,
                            ),
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
                              _ArcadeButton(
                                label: 'ACEPTAR ESPECIAL',
                                icon: Icons.auto_awesome,
                                tono: _BotonTono.dorado,
                                onPressed: () => _responderEspecial(true),
                              ),
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
                              _ArcadeButton(
                                label: 'PLANTARSE',
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
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _BottomNav(
                  index: _navIndex,
                  onSelect: (i) {
                    setState(() => _navIndex = i);
                    if (i == 3) _mostrarReglas();
                    if (i == 1 || i == 2 || i == 4) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Próximamente'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          if (_mostrarVictoria && _partida.ganador != null)
            Positioned.fill(
              child: VictoriaOverlay(
                ganador: _partida.ganador!,
                estadisticas: _stats,
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
    required this.onBack,
    required this.onSettings,
  });

  final int dados;
  final VoidCallback onBack;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIcon(icon: Icons.menu, onTap: onBack),
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

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.jugador,
    required this.index,
    required this.activo,
    required this.esTu,
    required this.mejorTurno,
  });

  final Jugador jugador;
  final int index;
  final bool activo;
  final bool esTu;
  final int mejorTurno;

  @override
  Widget build(BuildContext context) {
    final accent = index.isEven ? AppColors.acento : AppColors.azul;
    final pct = (jugador.puntos / meta).clamp(0.0, 1.0);
    final faltan = math.max(0, meta - jugador.puntos);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  _Chip(
                    icon: Icons.local_fire_department,
                    label: mejorTurno > 0
                        ? 'MEJOR ${_pts(mejorTurno)}'
                        : 'A JUGAR',
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
                Text(
                  combos.isEmpty
                      ? 'Tirá los dados para sumar puntos'
                      : combos
                          .map((c) =>
                              '${c.nombre.toUpperCase()} (+${c.puntos})')
                          .join('   '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: combos.isEmpty
                        ? AppColors.textoSuave
                        : AppColors.mint,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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
    final glow =
        tono == _BotonTono.dorado ? AppColors.acento : AppColors.rosa;
    final fg = tono == _BotonTono.dorado
        ? const Color(0xFF4A1B6D)
        : Colors.white;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
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
              boxShadow: enabled ? neonGlow(glow, blur: 16, spread: 1) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: fg, size: 24),
                const SizedBox(width: 10),
                Text(
                  label,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.casino, 'JUGAR', AppColors.acento),
    (Icons.emoji_events, 'RANKING', AppColors.azul),
    (Icons.bar_chart, 'ESTADÍSTICAS', AppColors.rosa),
    (Icons.menu_book, 'REGLAS', AppColors.mint),
    (Icons.settings, 'AJUSTES', AppColors.violeta),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.nav.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(
            color: AppColors.violeta.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onSelect(i),
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.carta,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: i == index
                              ? _items[i].$3
                              : _items[i].$3.withValues(alpha: 0.45),
                          width: i == index ? 1.8 : 1.1,
                        ),
                        boxShadow: i == index
                            ? neonGlow(_items[i].$3, blur: 12)
                            : neonGlow(_items[i].$3, blur: 4),
                      ),
                      child: Icon(
                        _items[i].$1,
                        size: 19,
                        color: i == index
                            ? _items[i].$3
                            : _items[i].$3.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _items[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        color: i == index
                            ? _items[i].$3
                            : AppColors.textoSuave,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
