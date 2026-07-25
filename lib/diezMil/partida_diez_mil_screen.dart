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
    final especial = aceptar ? tirada.combosOpcionales.first.especial : null;
    _aplicar(tirada, especial);
  }

  void _plantarse() {
    if (!puedePlantarse(_partida) || _esperandoEspecial) return;
    final nombre = _partida.jugadorActual.nombre;
    final sumados = _partida.turno.puntosTurno;
    final banco = plantarse(_partida);

    setState(() {
      switch (banco.motivo) {
        case 'apertura':
          _mensaje =
              'No llegaste a $apertura. Seguís en ${_pts(banco.puntos)}.';
        case 'pasado':
          _mensaje =
              'Te pasaste (${_pts(banco.intento ?? 0)}). Seguís en ${_pts(banco.puntos)}.';
        case 'victoria':
          _mejorTurno[nombre] = math.max(_mejorTurno[nombre] ?? 0, sumados);
          _mensaje = '¡$nombre llega a $meta y gana!';
        case 'banco':
          _mejorTurno[nombre] = math.max(_mejorTurno[nombre] ?? 0, sumados);
          _mensaje = 'Bancás ${_pts(banco.sumados ?? 0)}. Total: ${_pts(banco.puntos)}.';
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F3326), AppColors.fondo, Color(0xFF071A12)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    children: [
                      _Header(
                        dados: _partida.modo.dados,
                        onBack: () => Navigator.of(context).maybePop(),
                        onHelp: _mostrarReglas,
                      ),
                      const SizedBox(height: 14),
                      for (var i = 0; i < _partida.jugadores.length; i++) ...[
                        _PlayerCard(
                          jugador: _partida.jugadores[i],
                          activo: !terminada &&
                              identical(_partida.jugadores[i], j),
                          esTu: i == 0,
                          mejorTurno: _mejorTurno[_partida.jugadores[i].nombre] ?? 0,
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 6),
                      _TurnoChip(
                        nombre: terminada ? (_partida.ganador ?? '') : j.nombre,
                        terminada: terminada,
                        ptsTurno: t.puntosTurno,
                        ptsTirada: ptsTirada,
                      ),
                      const SizedBox(height: 16),
                      _DadosFila(
                        cantidad: _partida.modo.dados,
                        dados: _ultimaTirada?.dados,
                        suman: _dadosQueSuman(),
                      ),
                      const SizedBox(height: 14),
                      if (_ultimoResumen != null && !_ultimoResumen!.bust)
                        _CombosBar(
                          combos: _ultimoResumen!.combos,
                          total: _ultimoResumen!.puntosTirada,
                        ),
                      if (_mensaje != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _mensaje!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.texto,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      if (_esperandoEspecial && _ultimaTirada != null) ...[
                        Text(
                          'Sacaste ${nombreEspecial(_ultimaTirada!.combosOpcionales.first.especial!)} '
                          '(${_ultimaTirada!.combosOpcionales.first.puntos} pts). ¿Aceptás?',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.texto),
                        ),
                        const SizedBox(height: 12),
                        _GoldButton(
                          label: 'ACEPTAR ESPECIAL',
                          icon: Icons.auto_awesome,
                          onPressed: () => _responderEspecial(true),
                        ),
                        const SizedBox(height: 10),
                        _OutlineGameButton(
                          label: 'COMBOS NORMALES',
                          icon: Icons.casino_outlined,
                          onPressed: () => _responderEspecial(false),
                        ),
                      ] else if (!terminada) ...[
                        _GoldButton(
                          label: 'TIRAR DADOS',
                          icon: Icons.casino,
                          onPressed: _tirar,
                        ),
                        const SizedBox(height: 10),
                        _OutlineGameButton(
                          label: 'PLANTARSE',
                          icon: Icons.pan_tool_alt_outlined,
                          onPressed: puedePlantarse(_partida) ? _plantarse : null,
                        ),
                      ] else
                        _GoldButton(
                          label: 'VOLVER',
                          icon: Icons.arrow_back,
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
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.dados,
    required this.onBack,
    required this.onHelp,
  });

  final int dados;
  final VoidCallback onBack;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleIcon(icon: Icons.chevron_left, onTap: onBack),
        Expanded(
          child: Column(
            children: [
              Text(
                'DIEZ MIL',
                style: TextStyle(
                  color: AppColors.acento,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  fontFamily: 'Georgia',
                ),
              ),
              Text(
                '$dados DADOS',
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        _CircleIcon(icon: Icons.help_outline, onTap: onHelp),
      ],
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.onTap});

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
          width: 40,
          height: 40,
          child: Icon(icon, color: AppColors.texto, size: 22),
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.jugador,
    required this.activo,
    required this.esTu,
    required this.mejorTurno,
  });

  final Jugador jugador;
  final bool activo;
  final bool esTu;
  final int mejorTurno;

  @override
  Widget build(BuildContext context) {
    final pct = (jugador.puntos / meta).clamp(0.0, 1.0);
    final faltan = math.max(0, meta - jugador.puntos);
    final accent = activo ? AppColors.acento : AppColors.mint;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.carta.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: activo ? AppColors.acento : AppColors.cartaBorde,
          width: activo ? 1.8 : 1,
        ),
        boxShadow: activo
            ? [
                BoxShadow(
                  color: AppColors.acento.withValues(alpha: 0.28),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.18),
              border: Border.all(color: accent, width: 2),
            ),
            child: Icon(
              activo ? Icons.workspace_premium : Icons.person,
              color: accent,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (esTu)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.acento,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'TÚ',
                          style: TextStyle(
                            color: Color(0xFF1A1204),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        jugador.nombre,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.emoji_events, size: 16, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      '${_pts(jugador.puntos)} pts',
                      style: TextStyle(
                        color: accent,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 7,
                    backgroundColor: AppColors.fondoSuave,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(pct * 100).round()}% del objetivo',
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 108,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (activo) ...[
                  Text(
                    'FALTAN',
                    style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    _pts(faltan),
                    style: TextStyle(
                      color: accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'para ganar',
                    style: TextStyle(color: AppColors.textoSuave, fontSize: 10),
                  ),
                ],
                const SizedBox(height: 6),
                if (jugador.abierto)
                  const _MiniBadge(
                    icon: Icons.check_circle,
                    label: 'ABIERTO',
                    color: AppColors.mint,
                  ),
                if (activo && mejorTurno > 0) ...[
                  const SizedBox(height: 4),
                  _MiniBadge(
                    icon: Icons.local_fire_department,
                    label: 'MEJOR ${_pts(mejorTurno)}',
                    color: AppColors.acento,
                  ),
                ],
                if (!activo)
                  const _MiniBadge(
                    icon: Icons.schedule,
                    label: 'ESPERANDO',
                    color: AppColors.textoSuave,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
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
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnoChip extends StatelessWidget {
  const _TurnoChip({
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
            color: AppColors.carta,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: AppColors.acento.withValues(alpha: 0.55)),
          ),
          child: Text(
            terminada
                ? 'GANÓ: ${nombre.toUpperCase()}'
                : 'TURNO DE: ${nombre.toUpperCase()}',
            style: const TextStyle(
              color: AppColors.acento,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          terminada
              ? 'Partida terminada'
              : ptsTirada > 0
                  ? '$ptsTirada pts en esta tirada · turno ${_pts(ptsTurno)}'
                  : 'Turno: ${_pts(ptsTurno)} pts',
          style: const TextStyle(
            color: AppColors.mint,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DadosFila extends StatelessWidget {
  const _DadosFila({
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
    final tamano = ((width - 32 - (cantidad - 1) * 10) / cantidad)
        .clamp(44.0, 64.0);

    return Row(
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.carta,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cartaBorde),
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
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  combos.isEmpty
                      ? '—'
                      : combos
                          .map((c) => '${c.nombre.toUpperCase()} (+${c.puntos})')
                          .join('  ·  '),
                  style: const TextStyle(
                    color: AppColors.mint,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+$total',
            style: const TextStyle(
              color: AppColors.mint,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.acento,
          foregroundColor: const Color(0xFF1A1204),
          elevation: 4,
          shadowColor: AppColors.acento.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _OutlineGameButton extends StatelessWidget {
  const _OutlineGameButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.texto,
          backgroundColor: AppColors.carta,
          disabledForegroundColor: AppColors.textoSuave.withValues(alpha: 0.4),
          side: const BorderSide(color: AppColors.cartaBorde, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
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
    (Icons.home_filled, 'JUGAR'),
    (Icons.emoji_events_outlined, 'RANKING'),
    (Icons.pie_chart_outline, 'ESTADÍSTICAS'),
    (Icons.menu_book_outlined, 'REGLAS'),
    (Icons.settings_outlined, 'AJUSTES'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      decoration: const BoxDecoration(
        color: AppColors.nav,
        border: Border(top: BorderSide(color: AppColors.cartaBorde)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onSelect(i),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _items[i].$1,
                        size: 22,
                        color: i == index ? AppColors.acento : AppColors.textoSuave,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _items[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color:
                              i == index ? AppColors.acento : AppColors.textoSuave,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
