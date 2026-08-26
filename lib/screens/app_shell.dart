import 'dart:async';

import 'package:flutter/material.dart';

import '../services/usuario_mongo_service.dart';
import '../shared/monedas/monedas_bubble.dart';
import '../shared/monedas/monedas_store.dart';
import '../shared/nav/bottom_nav_bar.dart';
import 'home_screen.dart';
import 'mis_puntos_screen.dart';
import 'salas_screen.dart';
import 'tienda_screen.dart';

/// Contenedor principal con barra de navegación inferior.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// 0 = juegos · 1 = salas · 2 = cuenta · 3 = tienda (nav ítem 4).
  int _tab = 0;
  final _puntosKey = GlobalKey<MisPuntosScreenState>();

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

  /// Nav: 0 juegos · 1 salas · 2 cuenta · 3 ranking · 4 tienda
  int _navDeTab(int tab) => tab == 3 ? 4 : tab;

  void _onNavTap(int index) {
    if (index == 3) return; // ranking bloqueado
    final tab = index == 4 ? 3 : index;
    if (tab == _tab) return;
    setState(() => _tab = tab);
    if (tab == 2) {
      _puntosKey.currentState?.recargar();
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
        indiceActual: _navDeTab(_tab),
        onTap: _onNavTap,
      ),
    );
  }
}
