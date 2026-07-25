import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import 'dado_widget.dart';
import 'motor.dart';
import 'textos.dart';

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
  ResultadoTirada? _ultimaTirada;
  ResumenTirada? _ultimoResumen;
  String? _mensaje;
  bool _esperandoEspecial = false;
  final Map<String, int> _mejorTurno = {};
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _partida = nuevaPartida(widget.nombres, widget.modo);
    iniciarTurno(_partida);
    for (final j in _partida.jugadores) {
      _mejorTurno[j.nombre] = 0;
    }
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

  void _tirar() {
    if (_partida.ganador != null || _esperandoEspecial) return;
    final resultado = ejecutarTirada(_partida);
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
    final resumen = aplicarPuntosTirada(_partida, resultado, especial);
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

    if (resumen.bust && _partida.ganador == null) {
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

    if (_partida.ganador == null) {
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
          const Positioned.fill(child: _NeonBackdrop()),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                    child: Column(
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
                        const SizedBox(height: 12),
                        for (var i = 0; i < _partida.jugadores.length; i++) ...[
                          _PlayerCard(
                            jugador: _partida.jugadores[i],
                            index: i,
                            activo: !terminada &&
                                identical(_partida.jugadores[i], j),
                            esTu: i == 0,
                            mejorTurno:
                                _mejorTurno[_partida.jugadores[i].nombre] ?? 0,
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 4),
                        _TurnoBanner(
                          nombre: terminada
                              ? (_partida.ganador ?? '')
                              : j.nombre,
                          terminada: terminada,
                          ptsTurno: t.puntosTurno,
                          ptsTirada: ptsTirada,
                        ),
                        const SizedBox(height: 14),
                        _DadosZona(
                          cantidad: _partida.modo.dados,
                          dados: _ultimaTirada?.dados,
                          suman: _dadosQueSuman(),
                        ),
                        const SizedBox(height: 12),
                        if (_ultimoResumen != null && !_ultimoResumen!.bust)
                          _CombosBar(
                            combos: _ultimoResumen!.combos,
                            total: _ultimoResumen!.puntosTirada,
                          ),
                        if (_mensaje != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _mensaje!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.texto,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (_esperandoEspecial && _ultimaTirada != null) ...[
                          Text(
                            'Sacaste ${nombreEspecial(_ultimaTirada!.combosOpcionales.first.especial!)} '
                            '(${_ultimaTirada!.combosOpcionales.first.puntos} pts). ¿Aceptás?',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          _ArcadeButton(
                            label: 'ACEPTAR ESPECIAL',
                            icon: Icons.auto_awesome,
                            tono: _BotonTono.dorado,
                            onPressed: () => _responderEspecial(true),
                          ),
                          const SizedBox(height: 10),
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
                          const SizedBox(height: 10),
                          _ArcadeButton(
                            label: 'PLANTARSE',
                            icon: Icons.pan_tool_alt_outlined,
                            tono: _BotonTono.violeta,
                            onPressed:
                                puedePlantarse(_partida) ? _plantarse : null,
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
        ],
      ),
    );
  }
}

class _NeonBackdrop extends StatelessWidget {
  const _NeonBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.15,
          colors: [
            Color(0xFF2A1450),
            AppColors.fondo,
            Color(0xFF070312),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: CustomPaint(painter: _SparklesPainter()),
    );
  }
}

class _SparklesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final paint = Paint();
    for (var i = 0; i < 42; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 0.6 + rng.nextDouble() * 1.8;
      paint.color = [
        AppColors.acento,
        AppColors.azul,
        AppColors.rosa,
        AppColors.violeta,
      ][i % 4]
          .withValues(alpha: 0.18 + rng.nextDouble() * 0.25);
      canvas.drawCircle(Offset(x, y), r, paint);
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
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.white, AppColors.acento, AppColors.azul],
                ).createShader(bounds),
                child: const Text(
                  'DIEZ MIL',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.azulSuave, AppColors.violeta],
                  ),
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: neonGlow(AppColors.azul, blur: 8),
                ),
                child: Text(
                  '★  $dados DADOS  ★',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
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
            border: Border.all(color: AppColors.violeta.withValues(alpha: 0.7)),
            boxShadow: neonGlow(AppColors.violeta, blur: 8),
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
    final borderColor = activo ? accent : accent.withValues(alpha: 0.45);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.carta.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: activo ? 2 : 1.2),
        boxShadow: activo ? neonGlow(accent, blur: 16) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.35),
                      AppColors.fondoSuave,
                    ],
                  ),
                  border: Border.all(color: accent, width: 2.5),
                  boxShadow: neonGlow(accent, blur: 10),
                ),
                child: Icon(
                  index.isEven ? Icons.face : Icons.face_6,
                  color: accent,
                  size: 28,
                ),
              ),
              if (activo)
                Positioned(
                  top: -6,
                  right: -4,
                  child: Icon(Icons.workspace_premium, color: accent, size: 18),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        jugador.nombre.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    if (esTu && activo) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'TU TURNO',
                          style: TextStyle(
                            color: Color(0xFF1A0A00),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_pts(jugador.puntos)} PTS',
                  style: TextStyle(
                    color: accent,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(color: accent.withValues(alpha: 0.6), blurRadius: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'FALTAN ${_pts(faltan)} PTS PARA GANAR',
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: AppColors.fondo,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${(pct * 100).round()}% DEL OBJETIVO',
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (jugador.abierto)
                const _Chip(
                  icon: Icons.check_circle,
                  label: 'ABIERTO',
                  color: AppColors.mint,
                ),
              const SizedBox(height: 4),
              if (activo && mejorTurno > 0)
                _Chip(
                  icon: Icons.local_fire_department,
                  label: 'MEJOR ${_pts(mejorTurno)}',
                  color: AppColors.acento,
                )
              else if (!activo)
                const _Chip(
                  icon: Icons.schedule,
                  label: 'ESPERANDO',
                  color: AppColors.azul,
                ),
            ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnoBanner extends StatelessWidget {
  const _TurnoBanner({
    required this.nombre,
    required this.terminada,
    required this.ptsTurno,
    required this.ptsTirada,
  });

  final String nombre;
  final bool terminada;
  final int ptsTurno;
  final int ptsTirada;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.violeta, AppColors.acentoSuave],
            ),
            borderRadius: BorderRadius.circular(99),
            boxShadow: neonGlow(AppColors.acento, blur: 10),
          ),
          child: Text(
            terminada
                ? '★  GANÓ: ${nombre.toUpperCase()}  ★'
                : '★  TURNO DE: ${nombre.toUpperCase()}  ★',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          terminada
              ? 'Partida terminada'
              : ptsTirada > 0
                  ? '$ptsTirada PTS EN ESTA TIRADA'
                  : 'TURNO: ${_pts(ptsTurno)} PTS',
          style: const TextStyle(
            color: AppColors.mint,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
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
    final width = MediaQuery.sizeOf(context).width;
    final tamano =
        ((width - 40 - (cantidad - 1) * 8) / cantidad).clamp(44.0, 62.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: RadialGradient(
          colors: [
            AppColors.azul.withValues(alpha: 0.22),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < cantidad; i++) ...[
            if (i > 0) const SizedBox(width: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.carta,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cartaBorde),
        boxShadow: neonGlow(AppColors.violeta, blur: 8),
      ),
      child: Row(
        children: [
          const Icon(Icons.star, color: AppColors.acento, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COMBOS ACTIVOS',
                  style: TextStyle(
                    color: AppColors.textoSuave,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  combos.isEmpty
                      ? '—'
                      : combos
                          .map((c) => '${c.nombre.toUpperCase()} (+${c.puntos})')
                          .join('  ·  '),
                  style: const TextStyle(
                    color: AppColors.mint,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'TOTAL +$total',
            style: TextStyle(
              color: AppColors.mint,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: AppColors.mint.withValues(alpha: 0.7),
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
        ? const [Color(0xFFFFE082), AppColors.acento, AppColors.acentoSuave]
        : const [Color(0xFFB388FF), AppColors.violeta, Color(0xFF4527A0)];
    final fg = tono == _BotonTono.dorado
        ? const Color(0xFF1A0A00)
        : AppColors.texto;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: enabled
                  ? neonGlow(
                      tono == _BotonTono.dorado
                          ? AppColors.acento
                          : AppColors.violeta,
                      blur: 12,
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: fg, size: 22),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
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
    (Icons.sports_esports, 'JUGAR', AppColors.acento),
    (Icons.emoji_events, 'RANKING', AppColors.acentoSuave),
    (Icons.pie_chart, 'ESTADÍSTICAS', AppColors.rosa),
    (Icons.menu_book, 'REGLAS', AppColors.azul),
    (Icons.settings, 'AJUSTES', AppColors.violeta),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.nav.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: AppColors.cartaBorde)),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.carta,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: i == index
                              ? _items[i].$3
                              : _items[i].$3.withValues(alpha: 0.35),
                          width: i == index ? 1.6 : 1,
                        ),
                        boxShadow: i == index
                            ? neonGlow(_items[i].$3, blur: 10)
                            : null,
                      ),
                      child: Icon(
                        _items[i].$1,
                        size: 18,
                        color: i == index ? _items[i].$3 : AppColors.textoSuave,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _items[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w800,
                        color: i == index ? _items[i].$3 : AppColors.textoSuave,
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
