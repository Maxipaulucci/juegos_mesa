import 'dart:async';

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/models/cofre_estado.dart';
import 'package:app_juegos_mesa/shared/monedas/cofres_store.dart';
import 'package:app_juegos_mesa/shared/ui/notificacion_tope.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Cofres de madera (10 mon / 4 h) y oro (75 mon / día) en una burbuja abajo a la izquierda.
class CofresFlotantes extends StatefulWidget {
  const CofresFlotantes({super.key});

  @override
  State<CofresFlotantes> createState() => _CofresFlotantesState();
}

class _CofresFlotantesState extends State<CofresFlotantes> {
  String? _abriendo;

  @override
  void initState() {
    super.initState();
    CofresStore.instance.addListener(_onCofres);
  }

  @override
  void dispose() {
    CofresStore.instance.removeListener(_onCofres);
    super.dispose();
  }

  void _onCofres() {
    if (mounted) setState(() {});
  }

  void _abrirCartelBloqueados() {
    showDialog<void>(
      context: context,
      builder: (ctx) => const _CartelCofresBloqueados(),
    );
  }

  Future<void> _tocarBurbujaBloqueada() async {
    _abrirCartelBloqueados();
  }

  Future<void> _tocarCofreListo({
    required _TipoCofre tipo,
    required CofreEstado estado,
  }) async {
    final store = CofresStore.instance;
    if (!store.haySesion) {
      mostrarNotificacionTope(
        context,
        mensaje: 'Iniciá sesión para reclamar los cofres de monedas.',
      );
      return;
    }
    if (!estado.listo) {
      mostrarNotificacionTope(
        context,
        mensaje:
            'Cofre de ${tipo.etiqueta}: disponible en ${_fmtRestante(estado.restanteMs)}.',
      );
      return;
    }
    if (_abriendo != null) return;

    setState(() => _abriendo = tipo.id);
    try {
      final sumadas = await store.reclamar(tipo.id);
      if (!mounted) return;
      if (sumadas != null && sumadas > 0) {
        mostrarNotificacionTope(
          context,
          mensaje: '¡+$sumadas monedas del cofre de ${tipo.etiqueta}!',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 1400));
    } catch (e) {
      if (mounted) {
        mostrarNotificacionTope(
          context,
          mensaje: e is StateError
              ? e.message
              : 'No se pudo reclamar el cofre. Intentá de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _abriendo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = CofresStore.instance;
    final estado = store.estado;
    final haySesion = store.haySesion;
    final oroListo = haySesion && estado.oro.listo;
    final bloqueado =
        !haySesion || (!estado.madera.listo && !estado.oro.listo);

    if (!bloqueado) {
      final tipo = oroListo ? _TipoCofre.oro : _TipoCofre.madera;
      final cofreEstado = oroListo ? estado.oro : estado.madera;
      return _BurbujaCofres(
        resaltada: true,
        tachada: false,
        child: _CofreEnBurbuja(
          tipo: tipo,
          estado: cofreEstado,
          abriendo: _abriendo == tipo.id,
          listo: true,
          onTap: () => _tocarCofreListo(tipo: tipo, estado: cofreEstado),
        ),
      );
    }

    return _BurbujaCofres(
      resaltada: false,
      tachada: true,
      onTap: _tocarBurbujaBloqueada,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CofreEnBurbuja(
            tipo: _TipoCofre.oro,
            estado: estado.oro,
            abriendo: false,
            listo: false,
          ),
          const SizedBox(height: 2),
          _CofreEnBurbuja(
            tipo: _TipoCofre.madera,
            estado: estado.madera,
            abriendo: false,
            listo: false,
          ),
        ],
      ),
    );
  }
}

class _BurbujaCofres extends StatelessWidget {
  const _BurbujaCofres({
    required this.resaltada,
    required this.tachada,
    required this.child,
    this.onTap,
  });

  static const _cofreAncho = 52.0;
  static const _cofreAlto = 46.0;

  final bool resaltada;
  final bool tachada;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.carta.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: resaltada
                  ? AppColors.acento.withValues(alpha: 0.9)
                  : AppColors.cartaBorde.withValues(alpha: 0.9),
              width: 1.6,
            ),
            boxShadow: resaltada
                ? neonGlow(AppColors.acento, blur: 12)
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              child,
              if (tachada)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _LineaBloqueoBurbujaPainter(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cartel al tocar la burbuja cuando ningún cofre está disponible.
class _CartelCofresBloqueados extends StatefulWidget {
  const _CartelCofresBloqueados();

  @override
  State<_CartelCofresBloqueados> createState() =>
      _CartelCofresBloqueadosState();
}

class _CartelCofresBloqueadosState extends State<_CartelCofresBloqueados> {
  @override
  void initState() {
    super.initState();
    CofresStore.instance.addListener(_onCofres);
  }

  @override
  void dispose() {
    CofresStore.instance.removeListener(_onCofres);
    super.dispose();
  }

  void _onCofres() {
    if (!mounted) return;
    final store = CofresStore.instance;
    final estado = store.estado;
    final haySesion = store.haySesion;
    if (haySesion && (estado.madera.listo || estado.oro.listo)) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = CofresStore.instance;
    final estado = store.estado;
    final haySesion = store.haySesion;

    return AlertDialog(
      backgroundColor: AppColors.carta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Cofres de monedas',
        style: TextStyle(
          color: AppColors.acento,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!haySesion) ...[
            const Text(
              'Iniciá sesión para reclamar los cofres.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textoSuave, height: 1.35),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CofreTachadoConTiempo(
                tipo: _TipoCofre.oro,
                estado: estado.oro,
                haySesion: haySesion,
              ),
              _CofreTachadoConTiempo(
                tipo: _TipoCofre.madera,
                estado: estado.madera,
                haySesion: haySesion,
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cerrar',
            style: TextStyle(
              color: AppColors.acento,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _CofreTachadoConTiempo extends StatelessWidget {
  const _CofreTachadoConTiempo({
    required this.tipo,
    required this.estado,
    required this.haySesion,
  });

  final _TipoCofre tipo;
  final CofreEstado estado;
  final bool haySesion;

  @override
  Widget build(BuildContext context) {
    final titulo = tipo.id == 'oro' ? 'Cofre de oro' : 'Cofre de madera';
    final subtitulo = haySesion
        ? (estado.listo
            ? 'Disponible ahora'
            : 'Disponible en ${_fmtRestante(estado.restanteMs)}')
        : 'Iniciá sesión';

    return SizedBox(
      width: 118,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 72,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  tipo.cerrado,
                  width: 64,
                  height: 58,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LineaBloqueoBurbujaPainter(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.texto,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '+${estado.monedas} monedas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textoSuave.withValues(alpha: 0.95),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitulo,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: haySesion && !estado.listo
                  ? AppColors.acento
                  : AppColors.textoSuave,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

enum _TipoCofre {
  oro('oro', 'oro'),
  madera('madera', 'madera');

  const _TipoCofre(this.id, this.etiqueta);

  final String id;
  final String etiqueta;

  String get cerrado => id == 'oro'
      ? 'assets/img/cofres/cofreOroCerrado.png'
      : 'assets/img/cofres/cofreMaderaCerrado.png';

  String get abierto => id == 'oro'
      ? 'assets/img/cofres/cofreOroAbierto.png'
      : 'assets/img/cofres/cofreMaderaAbierto.png';
}

class _CofreEnBurbuja extends StatelessWidget {
  const _CofreEnBurbuja({
    required this.tipo,
    required this.estado,
    required this.abriendo,
    required this.listo,
    this.onTap,
  });

  final _TipoCofre tipo;
  final CofreEstado estado;
  final bool abriendo;
  final bool listo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final asset = abriendo ? tipo.abierto : tipo.cerrado;

    return Tooltip(
      message: listo
          ? '${tipo.etiqueta}: +${estado.monedas} monedas'
          : (estado.restanteMs > 0
              ? '${tipo.etiqueta}: ${_fmtRestante(estado.restanteMs)}'
              : tipo.etiqueta),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: _BurbujaCofres._cofreAncho,
          height: _BurbujaCofres._cofreAlto,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Image.asset(
                  asset,
                  width: 48,
                  height: 44,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              if (listo && !abriendo)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                      boxShadow: neonGlow(AppColors.mint, blur: 5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Línea diagonal atravesando toda la burbuja (sin sesión o ambos en cooldown).
class _LineaBloqueoBurbujaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.peligro.withValues(alpha: 0.92)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    const inset = 5.0;
    canvas.drawLine(
      Offset(inset, size.height - inset),
      Offset(size.width - inset, inset),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _fmtRestante(int ms) {
  if (ms <= 0) return 'ahora';
  final totalSec = (ms / 1000).ceil();
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  final s = totalSec % 60;
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
  return '${s}s';
}
