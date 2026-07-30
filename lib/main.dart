import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'shared/carga/pantalla_carga.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JuegosMesaApp());
}

class JuegosMesaApp extends StatelessWidget {
  const JuegosMesaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Juegos de Mesa',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _SplashInicial(),
    );
  }
}

/// Primera pantalla al abrir / reiniciar: carga animada y luego el menú.
class _SplashInicial extends StatefulWidget {
  const _SplashInicial();

  @override
  State<_SplashInicial> createState() => _SplashInicialState();
}

class _SplashInicialState extends State<_SplashInicial> {
  @override
  void initState() {
    super.initState();
    _irAlHome();
  }

  Future<void> _irAlHome() async {
    await Future<void>.delayed(duracionCargaMinima);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const PantallaCarga(
      mensaje: 'Juegos de Mesa',
      duracion: duracionCargaMinima,
    );
  }
}
