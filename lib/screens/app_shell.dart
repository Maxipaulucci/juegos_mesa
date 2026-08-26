import 'dart:async';

import 'package:flutter/material.dart';

import '../services/usuario_mongo_service.dart';
import '../shared/monedas/monedas_bubble.dart';
import '../shared/monedas/monedas_store.dart';
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

class _AppShellState extends State<AppShell> {
  /// 0 juegos · 1 salas · 2 cuenta · 3 ranking · 4 tienda
  int _tab = 0;
  final _puntosKey = GlobalKey<MisPuntosScreenState>();
  final _rankingKey = GlobalKey<RankingScreenState>();

  @override
  void initState() {
    super.initState();
    unawaited(UsuarioMongoService.instance.despertarBackend());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(HomeScreen.precargar(context));
    });
    MonedasStore.instance.addListener(_onMonedas);
  }

  @override
  void dispose() {
    MonedasStore.instance.removeListener(_onMonedas);
    super.dispose();
  }

  void _onMonedas() {
    if (mounted) setState(() {});
  }

  void _onNavTap(int index) {
    if (index == _tab) {
      if (index == 2) _puntosKey.currentState?.recargar();
      if (index == 3) _rankingKey.currentState?.recargar();
      return;
    }
    setState(() => _tab = index);
    if (index == 2) {
      _puntosKey.currentState?.recargar();
    }
    if (index == 3) {
      _rankingKey.currentState?.recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _tab,
            children: [
              const HomeScreen(),
              SalasScreen(mostrarVolver: false, activa: _tab == 1),
              MisPuntosScreen(key: _puntosKey),
              RankingScreen(key: _rankingKey, activa: _tab == 3),
              const TiendaScreen(),
            ],
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
}
