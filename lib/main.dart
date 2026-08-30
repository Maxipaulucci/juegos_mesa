import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/app_shell.dart';
import 'screens/home_screen.dart';
import 'services/usuario_mongo_service.dart';
import 'shared/ajustes/ajustes_store.dart';
import 'shared/carga/pantalla_carga.dart';
import 'shared/persistencia/almacen_local.dart';
import 'shared/persistencia/standby_restaurar.dart';
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

  runApp(const _BootstrapApp());
}

/// Carga sesión y partidas vs PC guardadas antes de mostrar la UI.
class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  late final Future<void> _init = _preparar();

  Future<void> _preparar() async {
    await AlmacenLocal.init();
    AjustesStore.instance.cargar();
    await UsuarioMongoService.instance.restaurarSesionLocal();
    await StandbyRestaurar.todos();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.noScaling,
              ),
              child: child ?? const SizedBox.shrink(),
            ),
            home: const PantallaCarga(mensaje: 'Cargando…'),
          );
        }
        Widget app = const JuegosMesaApp();
        if (_esWindowsEscritorio) {
          app = ExcludeSemantics(child: app);
        }
        return app;
      },
    );
  }
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
        Widget page = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child ?? const SizedBox.shrink(),
        );
        if (_esWindowsEscritorio) {
          page = ExcludeSemantics(child: page);
        }
        return page;
      },
      home: const _SplashInicial(),
    );
  }
}

/// Primera pantalla al abrir / reiniciar: carga animada y luego los juegos.
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
    _irAJuegos();
  }

  Future<void> _irAJuegos() async {
    final prep = Future<void>(() async {
      await Future<void>.delayed(Duration.zero);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await HomeScreen.precargar(context);
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
