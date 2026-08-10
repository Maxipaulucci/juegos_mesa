import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../diezMil/menu_diez_mil_screen.dart';
import '../escobaDel15/menu_escoba_screen.dart';
import '../generala/menu_generala_screen.dart';
import '../laPapa/menu_la_papa_screen.dart';
import '../shared/carga/pantalla_carga.dart';
import '../theme/app_theme.dart';
import '../tutiFruti/menu_tuti_fruti_screen.dart';
import '../culoSucio/menu_culo_sucio_screen.dart';
import '../culoSucioV2/menu_culo_sucio_v2_screen.dart';
import '../casitaRobada/menu_casita_robada_screen.dart';
import '../chanchoVa/menu_chancho_va_screen.dart';
import '../desconfio/menu_desconfio_screen.dart';
import '../guerraDeCartas/menu_guerra_screen.dart';
import '../unoSolo/menu_uno_solo_screen.dart';

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
    this.enabled = true,
    this.destacadoFuego = false,
  });

  final _TipoJuegoHome tipo;
  final String titulo;
  final String subtitulo;
  final Color accent;
  final _CategoriaHome categoria;
  final bool enabled;
  /// Resalta la tarjeta (fuego / más divertido), p. ej. Culo sucio v2.
  final bool destacadoFuego;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
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
    // Disponibles, en orden de salida (más viejo → más nuevo).
    _JuegoHome(
      tipo: _TipoJuegoHome.diezMil,
      titulo: 'Diez Mil',
      subtitulo: 'Dados · 5 o 6',
      accent: AppColors.acento,
      categoria: _CategoriaHome.dados,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.generala,
      titulo: 'Generala',
      subtitulo: 'Dados · tabla de anotación',
      accent: AppColors.violeta,
      categoria: _CategoriaHome.dados,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.tuttiFrutti,
      titulo: 'Tutti Frutti',
      subtitulo: 'Letras · categorías online',
      accent: AppColors.rosa,
      categoria: _CategoriaHome.papel,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.laPapa,
      titulo: 'La papa',
      subtitulo: 'Hoja · uní los números',
      accent: AppColors.mint,
      categoria: _CategoriaHome.papel,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.escobaDel15,
      titulo: 'Escoba del 15',
      subtitulo: 'Cartas españolas · a 15',
      accent: AppColors.azul,
      categoria: _CategoriaHome.cartasEspanolas,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.unoSolo,
      titulo: 'Uno solo',
      subtitulo: 'Tablero · una ficha en el centro',
      accent: AppColors.mint,
      categoria: _CategoriaHome.papel,
    ),
    // Culo sucio v2 arriba de v1.
    _JuegoHome(
      tipo: _TipoJuegoHome.culoSucioV2,
      titulo: 'Culo sucio v2',
      subtitulo: 'Cartas · pares y el 1 de oro',
      accent: AppColors.acentoSuave,
      categoria: _CategoriaHome.cartasEspanolas,
      destacadoFuego: true,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.culoSucioV1,
      titulo: 'Culo sucio v1',
      subtitulo: 'Cartas españolas · el 1 de oro pierde',
      accent: AppColors.peligro,
      categoria: _CategoriaHome.cartasEspanolas,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.casitaRobada,
      titulo: 'Casita robada',
      subtitulo: 'Cartas · pares y casitas',
      accent: AppColors.mint,
      categoria: _CategoriaHome.cartasEspanolas,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.chanchoVa,
      titulo: 'Chancho va',
      subtitulo: 'Cartas · cuartetos y CHANCHO VA',
      accent: AppColors.acentoSuave,
      categoria: _CategoriaHome.cartasEspanolas,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.guerraDeCartas,
      titulo: 'Guerra de cartas',
      subtitulo: 'Cartas inglesas · AS alto',
      accent: AppColors.azul,
      categoria: _CategoriaHome.cartasInglesas,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.canasta,
      titulo: 'Canasta',
      subtitulo: 'Próximamente',
      accent: AppColors.violeta,
      categoria: _CategoriaHome.cartasInglesas,
      enabled: false,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.desconfio,
      titulo: 'Desconfío',
      subtitulo: 'Cartas españolas · bluff',
      accent: AppColors.azulSuave,
      categoria: _CategoriaHome.cartasEspanolas,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.jodete,
      titulo: 'Jodete',
      subtitulo: 'Próximamente',
      accent: AppColors.peligro,
      categoria: _CategoriaHome.cartasEspanolas,
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
    // Solo la lista de juegos; el header no se reinicia al cambiar categoría.
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

    // Acumular sobre el destino pendiente (no sobre el offset a medio animar).
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

  VoidCallback? _onTapDe(_JuegoHome juego) {
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
      case _TipoJuegoHome.canasta:
      case _TipoJuegoHome.jodete:
        return null;
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
    // Solo reanima las tarjetas; título, subtítulo y chips quedan quietos.
    _listaEntrada
      ..reset()
      ..forward();
  }

  void _onPointerSignalScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    // Reclama la rueda para que el ListView no haga el salto nativo.
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      final scroll = resolved as PointerScrollEvent;
      _scrollConRueda(scroll.scrollDelta.dy);
    });
  }

  Widget _tarjetaEntrada({required int index, required Widget child}) {
    final start = (0.05 + index * 0.07).clamp(0.0, 0.65);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final curved = CurvedAnimation(
      parent: _listaEntrada,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.18),
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
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
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
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
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
                  const SizedBox(height: 18),
                  FadeTransition(
                    opacity: _tituloOpacidad,
                    child: _BarraCategorias(
                      seleccionada: _categoria,
                      onSeleccionar: _seleccionarCategoria,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                                      // Si el usuario arrastra, sincronizar objetivo.
                                      if (n is ScrollUpdateNotification &&
                                          n.dragDetails != null) {
                                        _ruedaAnimando = false;
                                        _scrollAnimToken++;
                                        _scrollObjetivo =
                                            _scrollController.offset;
                                      }
                                      return false;
                                    },
                                    child: ListView.separated(
                                      key: ValueKey(_categoria),
                                      controller: _scrollController,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 10,
                                      ),
                                      physics: const ClampingScrollPhysics(),
                                      itemCount: filtrados.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 14),
                                      itemBuilder: (context, index) {
                                        final juego = filtrados[index];
                                        return _tarjetaEntrada(
                                          index: index,
                                          child: _JuegoTile(
                                            titulo: juego.titulo,
                                            subtitulo: juego.subtitulo,
                                            accent: juego.accent,
                                            enabled: juego.enabled,
                                            destacadoFuego: juego.destacadoFuego,
                                            onTap: _onTapDe(juego),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  // Encima del ListView para ganar el
                                  // pointerSignalResolver (el primero gana).
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
                  const SizedBox(height: 12),
                  FadeTransition(
                    opacity: _tituloOpacidad,
                    child: const Text(
                      'Elegí un juego para crear o unirte a una sala',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: AppColors.textoSuave, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
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
    this.onTap,
    this.enabled = true,
    this.destacadoFuego = false,
  });

  final String titulo;
  final String subtitulo;
  final Color accent;
  final VoidCallback? onTap;
  final bool enabled;
  final bool destacadoFuego;

  @override
  State<_JuegoTile> createState() => _JuegoTileState();
}

class _JuegoTileState extends State<_JuegoTile>
    with SingleTickerProviderStateMixin {
  bool _presionado = false;
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
    final activo = widget.enabled && widget.onTap != null;
    final fuego = widget.destacadoFuego;

    Widget tile = AnimatedScale(
      scale: _presionado && activo ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedBuilder(
        animation: _fuego,
        builder: (context, child) {
          final t = fuego ? _fuego.value : 0.0;
          final glow = fuego ? (0.28 + t * 0.35) : null;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: fuego
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF6D00)
                            .withValues(alpha: glow!),
                        blurRadius: 18 + t * 10,
                        spreadRadius: 0,
                        offset: Offset.zero,
                      ),
                      BoxShadow(
                        color: AppColors.acento.withValues(alpha: 0.22 + t * 0.2),
                        blurRadius: 28,
                        spreadRadius: -2,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : !widget.enabled
                      ? null
                      : [
                          BoxShadow(
                            color: widget.accent.withValues(
                              alpha: _presionado && activo ? 0.4 : 0.2,
                            ),
                            blurRadius: _presionado && activo ? 18 : 12,
                            spreadRadius: -1,
                            offset: Offset.zero,
                          ),
                          BoxShadow(
                            color: widget.accent.withValues(
                              alpha: _presionado && activo ? 0.18 : 0.08,
                            ),
                            blurRadius: _presionado && activo ? 28 : 20,
                            spreadRadius: 0,
                            offset: const Offset(0, 6),
                          ),
                        ],
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
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: activo ? widget.onTap : null,
            onTapDown:
                activo ? (_) => setState(() => _presionado = true) : null,
            onTapCancel: () => setState(() => _presionado = false),
            onTapUp: (_) => setState(() => _presionado = false),
            borderRadius: BorderRadius.circular(18),
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            splashColor: widget.accent.withValues(alpha: 0.25),
            highlightColor: widget.accent.withValues(alpha: 0.12),
            child: Ink(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                gradient: fuego
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF3A1810),
                          Color(0xFF2A1230),
                          Color(0xFF24143F),
                        ],
                      )
                    : null,
                color: fuego
                    ? null
                    : AppColors.carta
                        .withValues(alpha: widget.enabled ? 0.95 : 0.45),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: fuego
                      ? Color.lerp(
                          const Color(0xFFFF6D00),
                          AppColors.acento,
                          0.35,
                        )!
                      : widget.enabled
                          ? widget.accent
                          : widget.accent.withValues(alpha: 0.25),
                  width: fuego ? 2.2 : (widget.enabled ? 1.6 : 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (fuego) ...[
                              const Icon(
                                Icons.local_fire_department_rounded,
                                color: Color(0xFFFF6D00),
                                size: 22,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                widget.titulo,
                                style: TextStyle(
                                  color: fuego
                                      ? AppColors.texto
                                      : widget.enabled
                                          ? AppColors.texto
                                          : AppColors.textoSuave,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitulo,
                          style: TextStyle(
                            color: fuego
                                ? AppColors.acento
                                : widget.enabled
                                    ? widget.accent
                                    : AppColors.textoSuave,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (fuego)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.whatshot_rounded,
                        color: Color.lerp(
                          const Color(0xFFFF6D00),
                          AppColors.acento,
                          _fuego.value,
                        ),
                        size: 28,
                      ),
                    ),
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 160),
                    offset: _presionado && activo
                        ? const Offset(0.12, 0)
                        : Offset.zero,
                    curve: Curves.easeOut,
                    child: Icon(
                      widget.enabled
                          ? Icons.chevron_right
                          : Icons.lock_outline,
                      color: fuego
                          ? const Color(0xFFFFAB40)
                          : widget.enabled
                              ? widget.accent
                              : AppColors.textoSuave,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (!fuego) return tile;

    // Flama pequeña en la esquina superior derecha.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        tile,
        Positioned(
          top: -8,
          right: 10,
          child: AnimatedBuilder(
            animation: _fuego,
            builder: (context, _) {
              final s = 0.9 + _fuego.value * 0.18;
              return Transform.scale(
                scale: s,
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFFFF9100),
                  size: 30,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
