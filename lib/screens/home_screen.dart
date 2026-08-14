import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../casitaRobada/menu_casita_robada_screen.dart';
import '../casitaRobada/textos.dart';
import '../chanchoVa/menu_chancho_va_screen.dart';
import '../chanchoVa/textos.dart';
import '../culoSucio/menu_culo_sucio_screen.dart';
import '../culoSucio/textos.dart';
import '../culoSucioV2/menu_culo_sucio_v2_screen.dart';
import '../culoSucioV2/textos.dart';
import '../desconfio/menu_desconfio_screen.dart';
import '../desconfio/textos.dart';
import '../diezMil/menu_diez_mil_screen.dart';
import '../diezMil/opciones_diez_mil.dart';
import '../diezMil/textos.dart';
import '../escobaDel15/menu_escoba_screen.dart';
import '../escobaDel15/textos.dart';
import '../generala/menu_generala_screen.dart';
import '../generala/textos.dart';
import '../guerraDeCartas/menu_guerra_screen.dart';
import '../guerraDeCartas/textos.dart';
import '../jodete/menu_jodete_screen.dart';
import '../jodete/opciones_jodete.dart';
import '../jodete/textos.dart';
import '../laPapa/menu_la_papa_screen.dart';
import '../laPapa/textos.dart';
import '../shared/carga/pantalla_carga.dart';
import '../theme/app_theme.dart';
import '../tutiFruti/menu_tuti_fruti_screen.dart';
import '../tutiFruti/motor_tuti_fruti.dart';
import '../unoSolo/menu_uno_solo_screen.dart';
import '../unoSolo/textos.dart';

enum _CategoriaHome {
  todo('Todo'),
  cartasEspanolas('Cartas españolas'),
  dados('Dados'),
  cartasInglesas('Cartas inglesas'),
  papel('Papel');

  const _CategoriaHome(this.label);
  final String label;
}

enum _TipoJuegoHome {
  diezMil,
  generala,
  tuttiFrutti,
  culoSucioV1,
  culoSucioV2,
  laPapa,
  unoSolo,
  escobaDel15,
  canasta,
  casitaRobada,
  chanchoVa,
  guerraDeCartas,
  desconfio,
  jodete,
}

class _JuegoHome {
  const _JuegoHome({
    required this.tipo,
    required this.titulo,
    required this.subtitulo,
    required this.accent,
    required this.categoria,
    required this.portadaAsset,
    this.enabled = true,
    this.destacadoFuego = false,
    this.tarjetaCuadrada = false,
    this.eslogan,
    this.aspectPortada,
  });

  final _TipoJuegoHome tipo;
  final String titulo;
  final String subtitulo;
  final Color accent;
  final _CategoriaHome categoria;
  final String portadaAsset;
  final bool enabled;
  final bool destacadoFuego;
  /// Layout alto, botones en columna y portada completa (p. ej. Diez Mil).
  final bool tarjetaCuadrada;
  /// Texto estilo “caja de juego”, arriba de Jugar.
  final String? eslogan;
  /// Ancho/alto de la portada: la tarjeta se estrecha al ancho de la foto.
  final double? aspectPortada;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  static const _portadaProximamente =
      'assets/img/portadas/portadaProximamente.png';
  static const _portadaDiezMil = 'assets/img/portadas/portadaDiezMil.png';
  static const _portadaGenerala = 'assets/img/portadas/portadaGenerala.png';

  bool _navegando = false;
  _CategoriaHome _categoria = _CategoriaHome.todo;
  late final AnimationController _entrada;
  late final AnimationController _listaEntrada;
  late final Animation<double> _tituloOpacidad;
  late final Animation<Offset> _tituloDesliz;
  final ScrollController _scrollController = ScrollController();
  double _scrollObjetivo = 0;
  int _scrollAnimToken = 0;
  bool _ruedaAnimando = false;

  static const _juegos = <_JuegoHome>[
    _JuegoHome(
      tipo: _TipoJuegoHome.diezMil,
      titulo: 'Diez Mil',
      subtitulo: 'Dados · 5 o 6',
      accent: AppColors.acento,
      categoria: _CategoriaHome.dados,
      portadaAsset: _portadaDiezMil,
      tarjetaCuadrada: true,
      aspectPortada: 1448 / 1086,
      eslogan:
          'Seis dados, una meta imposible de 10.000 y esa vocecita '
          'que te dice “una tirada más”. Sumás de a poco, arriesgás de más y, '
          'cuando creés que la tenés… ¡fuiste! Todo al piso. Ideal para pelear '
          'con amigos o en familia, insultar a la suerte y fingir que “era estrategia”. '
          '¿Estás listo para jugar?',
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.generala,
      titulo: 'Generala',
      subtitulo: 'Dados · tabla de anotación',
      accent: AppColors.violeta,
      categoria: _CategoriaHome.dados,
      portadaAsset: _portadaGenerala,
      tarjetaCuadrada: true,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.tuttiFrutti,
      titulo: 'Tutti Frutti',
      subtitulo: 'Letras · categorías online',
      accent: AppColors.rosa,
      categoria: _CategoriaHome.papel,
      portadaAsset: _portadaProximamente,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.laPapa,
      titulo: 'La papa',
      subtitulo: 'Hoja · uní los números',
      accent: AppColors.mint,
      categoria: _CategoriaHome.papel,
      portadaAsset: _portadaProximamente,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.escobaDel15,
      titulo: 'Escoba del 15',
      subtitulo: 'Cartas españolas · a 15',
      accent: AppColors.azul,
      categoria: _CategoriaHome.cartasEspanolas,
      portadaAsset: _portadaProximamente,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.unoSolo,
      titulo: 'Uno solo',
      subtitulo: 'Tablero · una ficha en el centro',
      accent: AppColors.mint,
      categoria: _CategoriaHome.papel,
      portadaAsset: _portadaProximamente,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.culoSucioV2,
      titulo: 'Culo sucio v2',
      subtitulo: 'Cartas · pares y el 1 de oro',
      accent: AppColors.acentoSuave,
      categoria: _CategoriaHome.cartasEspanolas,
      portadaAsset: _portadaProximamente,
      destacadoFuego: true,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.culoSucioV1,
      titulo: 'Culo sucio v1',
      subtitulo: 'Cartas españolas · el 1 de oro pierde',
      accent: AppColors.peligro,
      categoria: _CategoriaHome.cartasEspanolas,
      portadaAsset: _portadaProximamente,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.casitaRobada,
      titulo: 'Casita robada',
      subtitulo: 'Cartas · pares y casitas',
      accent: AppColors.mint,
      categoria: _CategoriaHome.cartasEspanolas,
      portadaAsset: _portadaProximamente,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.chanchoVa,
      titulo: 'Chancho va',
      subtitulo: 'Cartas · cuartetos y CHANCHO VA',
      accent: AppColors.acentoSuave,
      categoria: _CategoriaHome.cartasEspanolas,
      portadaAsset: _portadaProximamente,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.guerraDeCartas,
      titulo: 'Guerra de cartas',
      subtitulo: 'Cartas inglesas · AS alto',
      accent: AppColors.azul,
      categoria: _CategoriaHome.cartasInglesas,
      portadaAsset: _portadaProximamente,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.desconfio,
      titulo: 'Desconfío',
      subtitulo: 'Cartas españolas · bluff',
      accent: AppColors.azulSuave,
      categoria: _CategoriaHome.cartasEspanolas,
      portadaAsset: _portadaProximamente,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.jodete,
      titulo: 'Jodete',
      subtitulo: 'Españolas · 50 cartas',
      accent: AppColors.peligro,
      categoria: _CategoriaHome.cartasEspanolas,
      portadaAsset: _portadaProximamente,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.canasta,
      titulo: 'Canasta',
      subtitulo: 'Próximamente',
      accent: AppColors.violeta,
      categoria: _CategoriaHome.cartasInglesas,
      portadaAsset: _portadaProximamente,
      enabled: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entrada = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _listaEntrada = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _tituloOpacidad = CurvedAnimation(
      parent: _entrada,
      curve: const Interval(0, 0.35, curve: Curves.easeOut),
    );
    _tituloDesliz = Tween<Offset>(
      begin: const Offset(0, -0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entrada,
        curve: const Interval(0, 0.4, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _listaEntrada.dispose();
    _entrada.dispose();
    super.dispose();
  }

  void _scrollConRueda(double delta) {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= pos.minScrollExtent) return;

    final base = _ruedaAnimando ? _scrollObjetivo : pos.pixels;
    final siguiente =
        (base + delta).clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if ((siguiente - pos.pixels).abs() < 0.5 &&
        (siguiente - _scrollObjetivo).abs() < 0.5) {
      return;
    }
    _scrollObjetivo = siguiente;
    _ruedaAnimando = true;

    final token = ++_scrollAnimToken;
    _scrollController
        .animateTo(
      _scrollObjetivo,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    )
        .whenComplete(() {
      if (!mounted || token != _scrollAnimToken) return;
      _ruedaAnimando = false;
      if (_scrollController.hasClients) {
        _scrollObjetivo = _scrollController.offset;
      }
    });
  }

  List<_JuegoHome> get _juegosFiltrados {
    if (_categoria == _CategoriaHome.todo) return _juegos;
    return [
      for (final j in _juegos)
        if (j.categoria == _categoria) j,
    ];
  }

  int _columnasPara(double ancho) {
    if (ancho >= 820) return 3;
    if (ancho >= 520) return 2;
    return 1;
  }

  Future<void> _abrirJuego({
    required Widget menu,
    required Color acento,
    required String mensaje,
  }) async {
    if (_navegando) return;
    setState(() => _navegando = true);
    try {
      await navegarConCarga<void>(
        context,
        builder: (_) => menu,
        mensaje: mensaje,
        acento: acento,
      );
    } finally {
      if (mounted) setState(() => _navegando = false);
    }
  }

  VoidCallback? _onJugarDe(_JuegoHome juego) {
    if (_navegando || !juego.enabled) return null;
    switch (juego.tipo) {
      case _TipoJuegoHome.diezMil:
        return () => _abrirJuego(
              menu: const MenuDiezMilScreen(),
              acento: AppColors.acento,
              mensaje: 'Diez Mil',
            );
      case _TipoJuegoHome.generala:
        return () => _abrirJuego(
              menu: const MenuGeneralaScreen(),
              acento: AppColors.violeta,
              mensaje: 'Generala',
            );
      case _TipoJuegoHome.tuttiFrutti:
        return () => _abrirJuego(
              menu: const MenuTutiFrutiScreen(),
              acento: AppColors.rosa,
              mensaje: 'Tutti Frutti',
            );
      case _TipoJuegoHome.laPapa:
        return () => _abrirJuego(
              menu: const MenuLaPapaScreen(),
              acento: AppColors.mint,
              mensaje: 'La papa',
            );
      case _TipoJuegoHome.unoSolo:
        return () => _abrirJuego(
              menu: const MenuUnoSoloScreen(),
              acento: AppColors.mint,
              mensaje: 'Uno solo',
            );
      case _TipoJuegoHome.escobaDel15:
        return () => _abrirJuego(
              menu: const MenuEscobaScreen(),
              acento: AppColors.azul,
              mensaje: 'Escoba del 15',
            );
      case _TipoJuegoHome.culoSucioV1:
        return () => _abrirJuego(
              menu: const MenuCuloSucioScreen(),
              acento: AppColors.peligro,
              mensaje: 'Culo sucio v1',
            );
      case _TipoJuegoHome.culoSucioV2:
        return () => _abrirJuego(
              menu: const MenuCuloSucioV2Screen(),
              acento: AppColors.acentoSuave,
              mensaje: 'Culo sucio v2',
            );
      case _TipoJuegoHome.casitaRobada:
        return () => _abrirJuego(
              menu: const MenuCasitaRobadaScreen(),
              acento: AppColors.mint,
              mensaje: 'Casita robada',
            );
      case _TipoJuegoHome.chanchoVa:
        return () => _abrirJuego(
              menu: const MenuChanchoVaScreen(),
              acento: AppColors.acentoSuave,
              mensaje: 'Chancho va',
            );
      case _TipoJuegoHome.guerraDeCartas:
        return () => _abrirJuego(
              menu: const MenuGuerraScreen(),
              acento: AppColors.azul,
              mensaje: 'Guerra de cartas',
            );
      case _TipoJuegoHome.desconfio:
        return () => _abrirJuego(
              menu: const MenuDesconfioScreen(),
              acento: AppColors.azulSuave,
              mensaje: 'Desconfío',
            );
      case _TipoJuegoHome.jodete:
        return () => _abrirJuego(
              menu: const MenuJodeteScreen(),
              acento: AppColors.peligro,
              mensaje: 'Jodete',
            );
      case _TipoJuegoHome.canasta:
        return null;
    }
  }

  void _mostrarDialogoReglas(String texto) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.carta,
        title: const Text(
          'Reglas',
          style: TextStyle(
            color: AppColors.mint,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            texto,
            style: const TextStyle(
              color: AppColors.texto,
              height: 1.35,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  VoidCallback? _onReglasDe(_JuegoHome juego) {
    switch (juego.tipo) {
      case _TipoJuegoHome.diezMil:
        return () {
          final ops = DiezMilMenuConfig.opciones;
          _mostrarDialogoReglas(
            reglasDe(
              ops.modo,
              combosEspeciales: ops.combosEspeciales,
              escalera: ops.escalera,
              escaleraCircular: ops.escaleraCircular,
            ),
          );
        };
      case _TipoJuegoHome.generala:
        return () => _mostrarDialogoReglas(reglasGenerala());
      case _TipoJuegoHome.tuttiFrutti:
        return () => _mostrarDialogoReglas(reglasTutiFruti());
      case _TipoJuegoHome.laPapa:
        return () => _mostrarDialogoReglas(reglasLaPapa());
      case _TipoJuegoHome.unoSolo:
        return () => _mostrarDialogoReglas(reglasUnoSolo());
      case _TipoJuegoHome.escobaDel15:
        return () => _mostrarDialogoReglas(reglasEscobaDel15());
      case _TipoJuegoHome.culoSucioV1:
        return () => _mostrarDialogoReglas(
              reglasCuloSucio(comodines: false),
            );
      case _TipoJuegoHome.culoSucioV2:
        return () =>
            _mostrarDialogoReglas(TextosCuloSucioV2.reglasCompletas());
      case _TipoJuegoHome.casitaRobada:
        return () => _mostrarDialogoReglas(reglasCasitaRobada());
      case _TipoJuegoHome.chanchoVa:
        return () => _mostrarDialogoReglas(TextosChancho.reglas());
      case _TipoJuegoHome.guerraDeCartas:
        return () => _mostrarDialogoReglas(TextosGuerra.reglas());
      case _TipoJuegoHome.desconfio:
        return () => _mostrarDialogoReglas(reglasDesconfio());
      case _TipoJuegoHome.jodete:
        return () {
          final ops = JodeteMenuConfig.opciones;
          _mostrarDialogoReglas(
            reglasJodete(
              comodines: ops.comodines,
              objetivo: ops.objetivo,
              puntajePorCartas: ops.puntajePorCartas,
              apilarDoses: ops.apilarDoses,
              ganarConEspecial: ops.ganarConEspecial,
            ),
          );
        };
      case _TipoJuegoHome.canasta:
        return () => _mostrarDialogoReglas(
              'Canasta todavía no está disponible. ¡Próximamente!',
            );
    }
  }

  void _seleccionarCategoria(_CategoriaHome cat) {
    if (cat == _categoria) return;
    setState(() => _categoria = cat);
    _scrollAnimToken++;
    _scrollObjetivo = 0;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _listaEntrada
      ..reset()
      ..forward();
  }

  void _onPointerSignalScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      final scroll = resolved as PointerScrollEvent;
      _scrollConRueda(scroll.scrollDelta.dy);
    });
  }

  Widget _tarjetaEntrada({required int index, required Widget child}) {
    final start = (0.04 + index * 0.045).clamp(0.0, 0.7);
    final end = (start + 0.35).clamp(0.0, 1.0);
    final curved = CurvedAnimation(
      parent: _listaEntrada,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _juegosFiltrados;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.35),
                  radius: 1.1,
                  colors: [
                    Color(0xFF2A1450),
                    AppColors.fondo,
                    Color(0xFF070312),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: _tituloOpacidad,
                    child: SlideTransition(
                      position: _tituloDesliz,
                      child: Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                Colors.white,
                                AppColors.acento,
                                AppColors.azul,
                              ],
                            ).createShader(bounds),
                            child: const Text(
                              'JUEGOS DE MESA',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Argentinos · multijugador',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textoSuave,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeTransition(
                    opacity: _tituloOpacidad,
                    child: _BarraCategorias(
                      seleccionada: _categoria,
                      onSeleccionar: _seleccionarCategoria,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtrados.isEmpty
                        ? FadeTransition(
                            opacity: _listaEntrada,
                            child: const Center(
                              child: Text(
                                'No hay juegos en esta categoría',
                                style: TextStyle(color: AppColors.textoSuave),
                              ),
                            ),
                          )
                        : Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true,
                            child: ClipRect(
                              child: Stack(
                                children: [
                                  NotificationListener<ScrollNotification>(
                                    onNotification: (n) {
                                      if (n is ScrollUpdateNotification &&
                                          n.dragDetails != null) {
                                        _ruedaAnimando = false;
                                        _scrollAnimToken++;
                                        _scrollObjetivo =
                                            _scrollController.offset;
                                      }
                                      return false;
                                    },
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final columnas =
                                            _columnasPara(constraints.maxWidth);
                                        const altoCompacta = 132.0;
                                        const altoCuadrada = 248.0;
                                        const altoCuadradaConEslogan = 420.0;
                                        const gap = 10.0;

                                        double altoDe(_JuegoHome j) {
                                          if (!j.tarjetaCuadrada) {
                                            return altoCompacta;
                                          }
                                          return j.eslogan != null
                                              ? altoCuadradaConEslogan
                                              : altoCuadrada;
                                        }

                                        final filas = <List<_JuegoHome>>[];
                                        for (var i = 0;
                                            i < filtrados.length;
                                            i += columnas) {
                                          final fin =
                                              (i + columnas < filtrados.length)
                                                  ? i + columnas
                                                  : filtrados.length;
                                          filas.add(
                                            filtrados.sublist(i, fin),
                                          );
                                        }

                                        return ListView.separated(
                                          key: ValueKey(_categoria),
                                          controller: _scrollController,
                                          padding: const EdgeInsets.fromLTRB(
                                            6,
                                            6,
                                            6,
                                            10,
                                          ),
                                          physics:
                                              const ClampingScrollPhysics(),
                                          itemCount: filas.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: gap),
                                          itemBuilder: (context, rowIndex) {
                                            final fila = filas[rowIndex];
                                            final altoFila = fila
                                                .map(altoDe)
                                                .fold<double>(
                                                  altoCompacta,
                                                  (a, b) => a > b ? a : b,
                                                );
                                            final baseIndex =
                                                rowIndex * columnas;

                                            return SizedBox(
                                              height: altoFila,
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  for (var c = 0;
                                                      c < columnas;
                                                      c++) ...[
                                                    if (c > 0)
                                                      const SizedBox(
                                                        width: gap,
                                                      ),
                                                    Expanded(
                                                      child: c < fila.length
                                                          ? _tarjetaEntrada(
                                                              index:
                                                                  baseIndex +
                                                                      c,
                                                              child: Align(
                                                                alignment:
                                                                    Alignment
                                                                        .topCenter,
                                                                child:
                                                                    SizedBox(
                                                                  height:
                                                                      altoDe(
                                                                    fila[c],
                                                                  ),
                                                                  width: fila[c]
                                                                              .aspectPortada ==
                                                                          null
                                                                      ? null
                                                                      : double
                                                                          .infinity,
                                                                  child:
                                                                      _JuegoTile(
                                                                    titulo: fila[
                                                                            c]
                                                                        .titulo,
                                                                    subtitulo:
                                                                        fila[c]
                                                                            .subtitulo,
                                                                    accent: fila[
                                                                            c]
                                                                        .accent,
                                                                    enabled: fila[
                                                                            c]
                                                                        .enabled,
                                                                    destacadoFuego:
                                                                        fila[c]
                                                                            .destacadoFuego,
                                                                    portadaAsset:
                                                                        fila[c]
                                                                            .portadaAsset,
                                                                    tarjetaCuadrada:
                                                                        fila[c]
                                                                            .tarjetaCuadrada,
                                                                    eslogan: fila[
                                                                            c]
                                                                        .eslogan,
                                                                    aspectPortada:
                                                                        fila[c]
                                                                            .aspectPortada,
                                                                    onJugar:
                                                                        _onJugarDe(
                                                                      fila[c],
                                                                    ),
                                                                    onReglas:
                                                                        _onReglasDe(
                                                                      fila[c],
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            )
                                                          : const SizedBox
                                                              .shrink(),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Listener(
                                      behavior: HitTestBehavior.translucent,
                                      onPointerSignal: _onPointerSignalScroll,
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: _tituloOpacidad,
                    child: const Text(
                      'Elegí un juego para crear o unirte a una sala',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: AppColors.textoSuave, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraCategorias extends StatelessWidget {
  const _BarraCategorias({
    required this.seleccionada,
    required this.onSeleccionar,
  });

  final _CategoriaHome seleccionada;
  final ValueChanged<_CategoriaHome> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    const accentActiva = AppColors.azul;

    Widget chip(_CategoriaHome cat) {
      final activa = cat == seleccionada;
      const radio = BorderRadius.all(Radius.circular(999));
      return Material(
        color: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onSeleccionar(cat),
          customBorder: const StadiumBorder(),
          borderRadius: radio,
          splashColor: accentActiva.withValues(alpha: 0.2),
          highlightColor: accentActiva.withValues(alpha: 0.08),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: activa
                  ? accentActiva.withValues(alpha: 0.18)
                  : AppColors.carta.withValues(alpha: 0.7),
              borderRadius: radio,
              border: Border.all(
                color: activa
                    ? accentActiva
                    : AppColors.textoSuave.withValues(alpha: 0.35),
                width: activa ? 1.6 : 1,
              ),
              boxShadow: activa ? neonGlow(accentActiva, blur: 10) : null,
            ),
            child: Text(
              cat.label,
              style: TextStyle(
                color: activa ? accentActiva : AppColors.textoSuave,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _CategoriaHome.values.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    chip(_CategoriaHome.values[i]),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _JuegoTile extends StatefulWidget {
  const _JuegoTile({
    required this.titulo,
    required this.subtitulo,
    required this.accent,
    required this.portadaAsset,
    this.onJugar,
    this.onReglas,
    this.enabled = true,
    this.destacadoFuego = false,
    this.tarjetaCuadrada = false,
    this.eslogan,
    this.aspectPortada,
  });

  final String titulo;
  final String subtitulo;
  final Color accent;
  final String portadaAsset;
  final VoidCallback? onJugar;
  final VoidCallback? onReglas;
  final bool enabled;
  final bool destacadoFuego;
  final bool tarjetaCuadrada;
  final String? eslogan;
  final double? aspectPortada;

  @override
  State<_JuegoTile> createState() => _JuegoTileState();
}

class _JuegoTileState extends State<_JuegoTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fuego;

  @override
  void initState() {
    super.initState();
    _fuego = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.destacadoFuego) {
      _fuego.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _JuegoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.destacadoFuego && !_fuego.isAnimating) {
      _fuego.repeat(reverse: true);
    } else if (!widget.destacadoFuego && _fuego.isAnimating) {
      _fuego.stop();
    }
  }

  @override
  void dispose() {
    _fuego.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activo = widget.enabled && widget.onJugar != null;
    final fuego = widget.destacadoFuego;
    final cuadrada = widget.tarjetaCuadrada;

    Widget botonJugar({required bool anchoCompleto}) {
      return FilledButton(
        onPressed: activo ? widget.onJugar : null,
        style: FilledButton.styleFrom(
          backgroundColor: widget.accent,
          foregroundColor: AppColors.fondo,
          disabledBackgroundColor: widget.accent.withValues(alpha: 0.25),
          minimumSize: const Size(0, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        child: const Text('Jugar'),
      );
    }

    Widget botonReglas({required bool anchoCompleto}) {
      return OutlinedButton(
        onPressed: widget.onReglas,
        style: OutlinedButton.styleFrom(
          foregroundColor: widget.accent,
          backgroundColor: Colors.transparent,
          minimumSize: const Size(0, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          side: BorderSide(
            color: widget.accent.withValues(alpha: 0.8),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        child: const Text('Reglas'),
      );
    }

    final botones = cuadrada
        ? Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.eslogan != null) ...[
                  Text(
                    widget.eslogan!,
                    textAlign: TextAlign.center,
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textoSuave.withValues(alpha: 0.98),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                _HomeArcadePill(
                  label: 'JUGAR',
                  icon: Icons.play_arrow_rounded,
                  colors: const [
                    Color(0xFFFFF3B0),
                    Color(0xFFFFD54F),
                    Color(0xFFFF9800),
                  ],
                  glow: AppColors.acento,
                  foreground: const Color(0xFF4A1B6D),
                  width: 118,
                  onPressed: activo ? widget.onJugar : null,
                ),
                const SizedBox(height: 6),
                _HomeArcadePill(
                  label: 'REGLAS',
                  icon: Icons.menu_book_rounded,
                  colors: const [
                    Color(0xFF81D4FA),
                    Color(0xFF29B6F6),
                    Color(0xFF0277BD),
                  ],
                  glow: AppColors.azul,
                  foreground: Colors.white,
                  width: 118,
                  onPressed: widget.onReglas,
                ),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
            child: Row(
              children: [
                Expanded(child: botonJugar(anchoCompleto: false)),
                const SizedBox(width: 5),
                Expanded(child: botonReglas(anchoCompleto: false)),
              ],
            ),
          );

    Widget pieConEsloganFlexible() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          children: [
            if (widget.eslogan != null) ...[
              Flexible(
                child: Text(
                  widget.eslogan!,
                  textAlign: TextAlign.center,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textoSuave.withValues(alpha: 0.98),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            _HomeArcadePill(
              label: 'JUGAR',
              icon: Icons.play_arrow_rounded,
              colors: const [
                Color(0xFFFFF3B0),
                Color(0xFFFFD54F),
                Color(0xFFFF9800),
              ],
              glow: AppColors.acento,
              foreground: const Color(0xFF4A1B6D),
              width: 118,
              onPressed: activo ? widget.onJugar : null,
            ),
            const SizedBox(height: 6),
            _HomeArcadePill(
              label: 'REGLAS',
              icon: Icons.menu_book_rounded,
              colors: const [
                Color(0xFF81D4FA),
                Color(0xFF29B6F6),
                Color(0xFF0277BD),
              ],
              glow: AppColors.azul,
              foreground: Colors.white,
              width: 118,
              onPressed: widget.onReglas,
            ),
          ],
        ),
      );
    }

    // Si hay aspect de portada, el borde de la tarjeta = ancho de la foto.
    final portadaAlAncho = widget.aspectPortada != null;
    final fitPortada = portadaAlAncho
        ? BoxFit.cover
        : (cuadrada ? BoxFit.contain : BoxFit.cover);

    Widget tarjeta({
      required double anchoFijo,
      required double altoImg,
      required double altoTotal,
    }) {
      return AnimatedBuilder(
        animation: _fuego,
        builder: (context, child) {
          final t = fuego ? _fuego.value : 0.0;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: fuego
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF6D00)
                            .withValues(alpha: 0.22 + t * 0.25),
                        blurRadius: 10 + t * 6,
                      ),
                    ]
                  : widget.enabled
                      ? [
                          BoxShadow(
                            color: widget.accent.withValues(alpha: 0.16),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
            ),
            child: child,
          );
        },
        child: SizedBox(
          width: anchoFijo,
          height: altoTotal,
          child: Material(
            color: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: BoxDecoration(
                color: AppColors.carta.withValues(
                  alpha: widget.enabled ? 0.95 : 0.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              // Borde por encima de la portada (si va en decoration, la foto lo tapa).
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: fuego
                        ? const Color(0xFFFF6D00)
                        : widget.enabled
                            ? widget.accent
                            : widget.accent.withValues(alpha: 0.3),
                    width: fuego ? 1.6 : 1.2,
                  ),
                ),
                position: DecorationPosition.foreground,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: altoImg,
                      width: anchoFijo,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(11),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: AppColors.fondo.withValues(alpha: 0.55),
                              child: Image.asset(
                                widget.portadaAsset,
                                fit: fitPortada,
                                alignment: Alignment.center,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Icon(
                                    Icons.casino_rounded,
                                    color: widget.accent,
                                    size: cuadrada ? 40 : 28,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      AppColors.fondo.withValues(alpha: 0.9),
                                    ],
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    cuadrada ? 10 : 8,
                                    cuadrada ? 22 : 16,
                                    cuadrada ? 10 : 8,
                                    cuadrada ? 8 : 6,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.titulo,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.texto,
                                          fontSize: cuadrada ? 15 : 13,
                                          fontWeight: FontWeight.w900,
                                          height: 1.1,
                                          shadows: const [
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        widget.subtitulo,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: widget.accent,
                                          fontSize: cuadrada ? 11 : 10,
                                          fontWeight: FontWeight.w700,
                                          height: 1.15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (fuego)
                              const Positioned(
                                top: 4,
                                right: 4,
                                child: Icon(
                                  Icons.local_fire_department_rounded,
                                  color: Color(0xFFFF9100),
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(child: pieConEsloganFlexible()),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!portadaAlAncho) {
      // Layout anterior: llena el alto del slot; la imagen va en Expanded.
      return AnimatedBuilder(
        animation: _fuego,
        builder: (context, child) {
          final t = fuego ? _fuego.value : 0.0;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: fuego
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF6D00)
                            .withValues(alpha: 0.22 + t * 0.25),
                        blurRadius: 10 + t * 6,
                      ),
                    ]
                  : widget.enabled
                      ? [
                          BoxShadow(
                            color: widget.accent.withValues(alpha: 0.16),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
            ),
            child: child,
          );
        },
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: cuadrada ? Clip.none : Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.carta.withValues(
                alpha: widget.enabled ? 0.95 : 0.5,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: fuego
                    ? const Color(0xFFFF6D00)
                    : widget.enabled
                        ? widget.accent
                        : widget.accent.withValues(alpha: 0.3),
                width: fuego ? 1.6 : 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(11),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: AppColors.fondo.withValues(alpha: 0.55),
                          child: Image.asset(
                            widget.portadaAsset,
                            fit: fitPortada,
                            alignment: Alignment.center,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(
                                Icons.casino_rounded,
                                color: widget.accent,
                                size: cuadrada ? 40 : 28,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  AppColors.fondo.withValues(alpha: 0.9),
                                ],
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                cuadrada ? 10 : 8,
                                cuadrada ? 22 : 16,
                                cuadrada ? 10 : 8,
                                cuadrada ? 8 : 6,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.titulo,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.texto,
                                      fontSize: cuadrada ? 15 : 13,
                                      fontWeight: FontWeight.w900,
                                      height: 1.1,
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    widget.subtitulo,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: widget.accent,
                                      fontSize: cuadrada ? 11 : 10,
                                      fontWeight: FontWeight.w700,
                                      height: 1.15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (fuego)
                          const Positioned(
                            top: 4,
                            right: 4,
                            child: Icon(
                              Icons.local_fire_department_rounded,
                              color: Color(0xFFFF9100),
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                botones,
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final aspect = widget.aspectPortada!;
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 420.0;
        // Reserva segura para eslogan + Jugar + Reglas (evita overflow).
        final chromeMin = widget.eslogan != null ? 196.0 : 92.0;
        final anchoIdeal = (maxH - chromeMin) * aspect;
        final ancho = math.min(maxW, math.max(120.0, anchoIdeal));
        final altoImg = math.min(ancho / aspect, maxH - chromeMin);
        return Align(
          alignment: Alignment.topCenter,
          child: tarjeta(
            anchoFijo: ancho,
            altoImg: altoImg,
            altoTotal: maxH,
          ),
        );
      },
    );
  }
}

/// Pastilla arcade compacta (mismo look que el menú de partida).
class _HomeArcadePill extends StatelessWidget {
  const _HomeArcadePill({
    required this.label,
    required this.icon,
    required this.colors,
    required this.glow,
    required this.foreground,
    this.width,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final List<Color> colors;
  final Color glow;
  final Color foreground;
  final double? width;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: enabled ? neonGlow(glow, blur: 10, spread: 0.5) : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(999),
              splashColor: Colors.white24,
              highlightColor: Colors.white10,
              child: Ink(
                width: width,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: colors,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.65),
                    width: 1.4,
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  child: Row(
                    mainAxisSize:
                        width == null ? MainAxisSize.min : MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: foreground, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          shadows: const [
                            Shadow(color: Colors.white38, blurRadius: 3),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
