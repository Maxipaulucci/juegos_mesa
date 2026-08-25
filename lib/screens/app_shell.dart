import 'dart:async';

import 'package:flutter/material.dart';

import '../services/usuario_mongo_service.dart';
import '../shared/nav/bottom_nav_bar.dart';
import 'home_screen.dart';
import 'hub_screen.dart';
import 'mis_puntos_screen.dart';

/// Contenedor principal con barra de navegación inferior.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// 0 = juegos, 1 = cuenta (puntos).
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

  void _irAlHub() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const HubScreen(),
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  void _onNavTap(int index) {
    // 0 inicio · 1 juegos · 2 cuenta · 3 ranking · 4 tienda
    if (index == 0) {
      _irAlHub();
      return;
    }
    if (index == 3 || index == 4) return;
    final tab = index - 1;
    if (tab == _tab) return;
    setState(() => _tab = tab);
    if (tab == 1) {
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
          MisPuntosScreen(key: _puntosKey),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        // En AppShell nunca estamos en “inicio”; resalta juegos o cuenta.
        indiceActual: _tab + 1,
        onTap: _onNavTap,
      ),
    );
  }
}
