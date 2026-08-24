import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/app_shell.dart';
import 'shared/carga/pantalla_carga.dart';
import 'theme/app_theme.dart';

bool get _esWindowsEscritorio =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Bug de Flutter en Windows (AXTree / accessibility_bridge): se corrompe
  // con Tooltips y overlays. Cortamos actualizaciones semánticas al engine.
  // https://github.com/flutter/flutter/issues/182444
  if (_esWindowsEscritorio) {
    final dispatcher = PlatformDispatcher.instance;
    void apagarArbol() => dispatcher.setSemanticsTreeEnabled(false);
    dispatcher.onSemanticsEnabledChanged = apagarArbol;
    apagarArbol();
    WidgetsBinding.instance.addPostFrameCallback((_) => apagarArbol());
  }

  Widget app = const JuegosMesaApp();
  if (_esWindowsEscritorio) {
    app = ExcludeSemantics(child: app);
  }
  runApp(app);
}

class JuegosMesaApp extends StatelessWidget {
  const JuegosMesaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Juegos de Mesa',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, child) {
        final page = child ?? const SizedBox.shrink();
        if (!_esWindowsEscritorio) return page;
        return ExcludeSemantics(child: page);
      },
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
  final Completer<void> _barraListo = Completer<void>();

  @override
  void initState() {
    super.initState();
    _irAlHome();
  }

  Future<void> _irAlHome() async {
    final prep = Future<void>(() async {
      await Future<void>.delayed(Duration.zero);
      await WidgetsBinding.instance.endOfFrame;
    });

    await Future.wait<void>([_barraListo.future, prep]);
    await Future<void>.delayed(pausaTrasCienPorCiento);
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const AppShell(),
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PantallaCarga(
      mensaje: 'Juegos de Mesa',
      duracion: duracionCargaMinima,
      onBarraCompleta: () {
        if (!_barraListo.isCompleted) _barraListo.complete();
      },
    );
  }
}
