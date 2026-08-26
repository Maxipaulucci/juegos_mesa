import 'package:flutter/material.dart';

import '../models/usuario_mongo.dart';
import '../services/usuario_mongo_service.dart';
import '../theme/app_theme.dart';

/// Top 10 jugadores por puntuación (global / online).
class RankingScreen extends StatefulWidget {
  const RankingScreen({
    super.key,
    this.activa = true,
  });

  /// Si false (pestaña oculta), no recarga al reconstruir.
  final bool activa;

  @override
  State<RankingScreen> createState() => RankingScreenState();
}

class RankingScreenState extends State<RankingScreen> {
  List<PuestoRanking> _filas = const [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    recargar();
  }

  @override
  void didUpdateWidget(covariant RankingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activa && !oldWidget.activa) {
      recargar();
    }
  }

  Future<void> recargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await UsuarioMongoService.instance.ranking(
        juego: 'global',
        limite: 10,
      );
      if (!mounted) return;
      setState(() {
        _filas = lista;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Bad state: ', '');
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.4),
                  radius: 1.2,
                  colors: [
                    Color(0xFF3A1450),
                    AppColors.fondo,
                    Color(0xFF070312),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Ranking',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.texto,
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Actualizar',
                        onPressed: _cargando ? null : recargar,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: AppColors.acento,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 14),
                  child: Text(
                    'Top 10 · mayor puntuación online',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textoSuave,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(child: _cuerpo()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _filas.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.acento),
      );
    }
    if (_error != null && _filas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.peligro),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: recargar,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_filas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'Todavía no hay puntuaciones.\n'
            'Ganá partidas online para aparecer acá.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textoSuave.withValues(alpha: 0.95),
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.acento,
      onRefresh: recargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: AppColors.carta.withValues(alpha: 0.92),
              border: Border.all(
                color: AppColors.acento.withValues(alpha: 0.55),
                width: 1.5,
              ),
              boxShadow: neonGlow(AppColors.acento, blur: 12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _cabeceraTabla(),
                for (var i = 0; i < _filas.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.cartaBorde.withValues(alpha: 0.85),
                    ),
                  _filaTabla(_filas[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cabeceraTabla() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: AppColors.fondo.withValues(alpha: 0.55),
      child: const Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '#',
              style: TextStyle(
                color: AppColors.acento,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Jugador',
              style: TextStyle(
                color: AppColors.acento,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          SizedBox(
            width: 88,
            child: Text(
              'Puntos',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.acento,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaTabla(PuestoRanking p) {
    if (p.puesto >= 4) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                '${p.puesto}º',
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: Text(
                p.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            SizedBox(
              width: 88,
              child: Text(
                _fmtPts(p.puntos),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final estilo = switch (p.puesto) {
      1 => (
          puestoSize: 22.0,
          nombreSize: 20.0,
          puntosSize: 20.0,
          paddingV: 18.0,
          color: AppColors.acento,
          mostrarCopa: true,
        ),
      2 => (
          puestoSize: 18.0,
          nombreSize: 17.0,
          puntosSize: 17.0,
          paddingV: 15.0,
          color: AppColors.texto,
          mostrarCopa: false,
        ),
      _ => (
          puestoSize: 16.0,
          nombreSize: 15.0,
          puntosSize: 15.0,
          paddingV: 13.0,
          color: AppColors.texto,
          mostrarCopa: false,
        ),
    };

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: estilo.paddingV,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '${p.puesto}º',
              style: TextStyle(
                color: estilo.color,
                fontWeight: FontWeight.w900,
                fontSize: estilo.puestoSize,
              ),
            ),
          ),
          Expanded(
            child: Text(
              p.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: estilo.color,
                fontWeight: FontWeight.w900,
                fontSize: estilo.nombreSize,
              ),
            ),
          ),
          SizedBox(
            width: estilo.mostrarCopa ? 72 : 88,
            child: Text(
              _fmtPts(p.puntos),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: estilo.color,
                fontWeight: FontWeight.w900,
                fontSize: estilo.puntosSize,
              ),
            ),
          ),
          if (estilo.mostrarCopa) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.emoji_events_rounded,
              color: AppColors.acento,
              size: 30,
            ),
          ],
        ],
      ),
    );
  }

  String _fmtPts(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final desdeFin = s.length - i;
      if (i > 0 && desdeFin % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
