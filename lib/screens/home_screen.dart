import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../diezMil/menu_diez_mil_screen.dart';
import '../generala/menu_generala_screen.dart';
import '../laPapa/menu_la_papa_screen.dart';
import '../shared/carga/pantalla_carga.dart';
import '../theme/app_theme.dart';
import '../tutiFruti/menu_tuti_fruti_screen.dart';

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
  culoSucio,
  laPapa,
  escobaDel15,
  canasta,
  casitaRobada,
  chanchoVa,
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
  });

  final _TipoJuegoHome tipo;
  final String titulo;
  final String subtitulo;
  final Color accent;
  final _CategoriaHome categoria;
  final bool enabled;
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
      tipo: _TipoJuegoHome.culoSucio,
      titulo: 'Culo sucio',
      subtitulo: 'Próximamente',
      accent: AppColors.peligro,
      categoria: _CategoriaHome.cartasEspanolas,
      enabled: false,
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
      subtitulo: 'Próximamente',
      accent: AppColors.azul,
      categoria: _CategoriaHome.cartasEspanolas,
      enabled: false,
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
      tipo: _TipoJuegoHome.casitaRobada,
      titulo: 'Casita robada',
      subtitulo: 'Próximamente',
      accent: AppColors.mint,
      categoria: _CategoriaHome.cartasEspanolas,
      enabled: false,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.chanchoVa,
      titulo: 'Chancho va',
      subtitulo: 'Próximamente',
      accent: AppColors.acentoSuave,
      categoria: _CategoriaHome.cartasEspanolas,
      enabled: false,
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.desconfio,
      titulo: 'Desconfío',
      subtitulo: 'Próximamente',
      accent: AppColors.azulSuave,
      categoria: _CategoriaHome.cartasEspanolas,
      enabled: false,
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
      case _TipoJuegoHome.culoSucio:
      case _TipoJuegoHome.escobaDel15:
      case _TipoJuegoHome.canasta:
      case _TipoJuegoHome.casitaRobada:
      case _TipoJuegoHome.chanchoVa:
      case _TipoJuegoHome.desconfio:
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
                                    physics: const ClampingScrollPhysics(),
                                    itemCount: filtrados.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final juego = filtrados[index];
                                      return _tarjetaEntrada(
                                        index: index,
                                        child: _JuegoTile(
                                          titulo: juego.titulo,
                                          subtitulo: juego.subtitulo,
                                          accent: juego.accent,
                                          enabled: juego.enabled,
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
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSeleccionar(cat),
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: activa
                  ? accentActiva.withValues(alpha: 0.18)
                  : AppColors.carta.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(999),
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
  });

  final String titulo;
  final String subtitulo;
  final Color accent;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<_JuegoTile> createState() => _JuegoTileState();
}

class _JuegoTileState extends State<_JuegoTile> {
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    final activo = widget.enabled && widget.onTap != null;
    return AnimatedScale(
      scale: _presionado && activo ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: activo && _presionado
              ? neonGlow(widget.accent, blur: 14)
              : (widget.enabled
                  ? [
                      BoxShadow(
                        color: widget.accent.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: activo ? widget.onTap : null,
            onTapDown:
                activo ? (_) => setState(() => _presionado = true) : null,
            onTapCancel: () => setState(() => _presionado = false),
            onTapUp: (_) => setState(() => _presionado = false),
            borderRadius: BorderRadius.circular(18),
            splashColor: widget.accent.withValues(alpha: 0.25),
            highlightColor: widget.accent.withValues(alpha: 0.12),
            child: Ink(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.carta
                    .withValues(alpha: widget.enabled ? 0.95 : 0.45),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: widget.enabled
                      ? widget.accent
                      : widget.accent.withValues(alpha: 0.25),
                  width: widget.enabled ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.titulo,
                          style: TextStyle(
                            color: widget.enabled
                                ? AppColors.texto
                                : AppColors.textoSuave,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitulo,
                          style: TextStyle(
                            color: widget.enabled
                                ? widget.accent
                                : AppColors.textoSuave,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
                      color: widget.enabled
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
  }
}
