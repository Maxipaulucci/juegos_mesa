import 'dart:async';

import 'package:flutter/material.dart';

import '../services/usuario_mongo_service.dart';
import '../shared/ajustes/ajustes_store.dart';
import '../shared/cuenta/cuenta_overlay_store.dart';
import '../shared/monedas/cofres_flotantes.dart';
import '../shared/monedas/cofres_store.dart';
import '../shared/monedas/monedas_bubble.dart';
import '../shared/monedas/monedas_store.dart';
import '../shared/monedas/racha_login_service.dart';
import '../shared/nav/bottom_nav_bar.dart';
import 'home_screen.dart';
import 'mis_puntos_screen.dart';
import 'ranking_screen.dart';
import 'salas_screen.dart';
import 'tienda_screen.dart';

/// Contenedor principal con barra de navegación inferior.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  /// 0 juegos · 1 salas · 2 cuenta · 3 ranking · 4 tienda
  int _tab = 0;
  int _tabAnterior = 0;
  /// 1 = destino a la derecha (entra desde la derecha) · -1 = a la izquierda.
  int _dir = 1;

  final _puntosKey = GlobalKey<MisPuntosScreenState>();
  final _rankingKey = GlobalKey<RankingScreenState>();

  late final AnimationController _transicion;
  late final Animation<double> _progreso;

  @override
  void initState() {
    super.initState();
    _transicion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1,
    );
    _progreso = CurvedAnimation(
      parent: _transicion,
      curve: Curves.easeOutCubic,
    );

    unawaited(UsuarioMongoService.instance.despertarBackend());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(HomeScreen.precargar(context));
        RachaLoginService.instance.mostrarPendienteSiHay(context);
      }
    });
    MonedasStore.instance.addListener(_onMonedas);
    CuentaOverlayStore.instance.addListener(_onCuentaOverlay);
    AjustesStore.instance.addListener(_onAjustes);
    CofresStore.instance.iniciar();
  }

  @override
  void dispose() {
    _transicion.dispose();
    MonedasStore.instance.removeListener(_onMonedas);
    CuentaOverlayStore.instance.removeListener(_onCuentaOverlay);
    AjustesStore.instance.removeListener(_onAjustes);
    CofresStore.instance.disposeStore();
    super.dispose();
  }

  void _onMonedas() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        RachaLoginService.instance.mostrarPendienteSiHay(context);
      }
    });
    setState(() {});
  }

  void _onCuentaOverlay() {
    if (mounted) setState(() {});
  }

  void _onAjustes() {
    if (mounted) setState(() {});
  }

  void _onNavTap(int index) {
    if (index == _tab) {
      if (index == 2) _puntosKey.currentState?.recargar();
      if (index == 3) _rankingKey.currentState?.recargar();
      return;
    }
    final conAnim = AjustesStore.instance.animaciones;
    setState(() {
      _tabAnterior = _tab;
      _dir = index > _tab ? 1 : -1;
      _tab = index;
    });
    if (conAnim) {
      _transicion.forward(from: 0);
    } else {
      _transicion.value = 1;
    }
    if (index == 2) {
      _puntosKey.currentState?.recargar();
    }
    if (index == 3) {
      _rankingKey.currentState?.recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mostrarCofres =
        _tab != 2 && _tab != 3 && !CuentaOverlayStore.instance.abierta;

    final paginas = <Widget>[
      const HomeScreen(),
      SalasScreen(mostrarVolver: false, activa: _tab == 1),
      MisPuntosScreen(key: _puntosKey),
      RankingScreen(key: _rankingKey, activa: _tab == 3),
      const TiendaScreen(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          ClipRect(
            child: AnimatedBuilder(
              animation: _progreso,
              builder: (context, _) {
                final t = _progreso.value;
                final animando = t < 1 && _tabAnterior != _tab;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    for (var i = 0; i < paginas.length; i++)
                      _capaSeccion(
                        index: i,
                        t: t,
                        animando: animando,
                        child: paginas[i],
                      ),
                  ],
                );
              },
            ),
          ),
          if (mostrarCofres)
            const Positioned(
              left: 14,
              bottom: 10,
              child: CofresFlotantes(),
            ),
          const Positioned(
            right: 14,
            bottom: 10,
            child: MonedasBubble(),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        indiceActual: _tab,
        onTap: _onNavTap,
      ),
    );
  }

  Widget _capaSeccion({
    required int index,
    required double t,
    required bool animando,
    required Widget child,
  }) {
    final esActual = index == _tab;
    final esAnterior = animando && index == _tabAnterior;

    if (!esActual && !esAnterior) {
      return Offstage(
        offstage: true,
        child: TickerMode(enabled: false, child: child),
      );
    }

    // Destino a la derecha: entra desde +1 y la anterior sale hacia -1.
    // Destino a la izquierda: entra desde -1 y la anterior sale hacia +1.
    final dx = esActual ? (1 - t) * _dir : -t * _dir;

    return FractionalTranslation(
      translation: Offset(dx, 0),
      child: TickerMode(
        enabled: esActual || esAnterior,
        child: child,
      ),
    );
  }
}
