import 'dart:async';

import 'package:flutter/material.dart';

import '../services/usuario_mongo_service.dart';
import '../shared/nav/bottom_nav_bar.dart';
import 'home_screen.dart';
import 'mis_puntos_screen.dart';
import 'salas_screen.dart';

/// Contenedor principal con barra de navegación inferior.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// 0 = juegos · 1 = salas · 2 = cuenta (puntos).
  int _tab = 0;
  final _puntosKey = GlobalKey<MisPuntosScreenState>();

  @override
  void initState() {
    super.initState();
    unawaited(UsuarioMongoService.instance.despertarBackend());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(HomeScreen.precargar(context));
    });
  }

  void _onNavTap(int index) {
    // 0 juegos · 1 salas · 2 cuenta · 3 ranking · 4 tienda
    if (index == 3 || index == 4) return;
    if (index == _tab) return;
    setState(() => _tab = index);
    if (index == 2) {
      _puntosKey.currentState?.recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          const HomeScreen(),
          SalasScreen(mostrarVolver: false, activa: _tab == 1),
          MisPuntosScreen(key: _puntosKey),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        indiceActual: _tab,
        onTap: _onNavTap,
      ),
    );
  }
}
