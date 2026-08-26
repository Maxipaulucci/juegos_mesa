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
import '../shared/ajustes/ajustes_overlay.dart';
import '../shared/carga/pantalla_carga.dart';
import '../shared/cuenta/cuenta_overlay.dart';
import '../services/usuario_mongo_service.dart';
import '../theme/app_theme.dart';
import '../tutiFruti/menu_tuti_fruti_screen.dart';
import '../tutiFruti/motor_tuti_fruti.dart';
import '../unoSolo/menu_uno_solo_screen.dart';
import '../unoSolo/textos.dart';

enum _CategoriaHome {
  cartasEspanolas('Cartas españolas'),
  dados('Dados'),
  cartasInglesas('Cartas inglesas'),
  papel('Tablero');

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
    this.tarjetaCuadrada = true,
    this.eslogan,
    this.esloganExpandible = true,
    this.aspectPortada = aspectPortadaHome,
  });

  /// Misma proporción de tarjeta que Diez Mil (todas iguales).
  static const double aspectPortadaHome = 1448 / 1086;

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
  /// Eslogan en 1 línea + flecha para expandir.
  final bool esloganExpandible;
  /// Ancho/alto de la portada: la tarjeta se estrecha al ancho de la foto.
  final double? aspectPortada;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Precarga portadas, tipografía y un primer layout del menú.
  static Future<void> precargar(BuildContext context) =>
      _HomeScreenState.precargar(context);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  static const _portadaDiezMil = 'assets/img/portadas/portadaDiezMil.png';
  static const _portadaGenerala = 'assets/img/portadas/portadaGenerala.png';
  static const _portadaLaPapa = 'assets/img/portadas/portadaLaPapa.jpeg';
  static const _portadaEscoba = 'assets/img/portadas/portadaEscoba.png';
  static const _portadaTuttiFrutti =
      'assets/img/portadas/portadaTuttiFrutti.png';
  static const _portadaUnoSolo = 'assets/img/portadas/portadaUnoSolo.png';
  static const _portadaCuloSucioV2 =
      'assets/img/portadas/portadaCuloSucioV2.png';
  static const _portadaCuloSucioV1 =
      'assets/img/portadas/portadaCuloSucioV1.png';
  static const _portadaCasitaRobada =
      'assets/img/portadas/portadaCasitaRobada.png';
  static const _portadaChanchoVa = 'assets/img/portadas/portadaChanchoVa.png';
  static const _portadaGuerraDeCartas =
      'assets/img/portadas/portadaGuerraDeCartas.png';
  static const _portadaDesconfio = 'assets/img/portadas/portadaDesconfio.png';
  static const _portadaJodete = 'assets/img/portadas/portadaJodete.png';
  static const _portadaCanasta = 'assets/img/portadas/portadaCanasta.png';

  static Future<void> precargar(BuildContext context) async {
    final paths = <String>{
      for (final j in _juegos) j.portadaAsset,
      'assets/img/logo.png',
      'assets/img/portadas/portadaProximamente.png',
    };
    await Future.wait<void>([
      for (final path in paths) _precacheAsset(context, path),
    ]);
    if (context.mounted) {
      Theme.of(context);
      DefaultTextStyle.of(context);
    }
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
  }

  static Future<void> _precacheAsset(
    BuildContext context,
    String path,
  ) async {
    try {
      await precacheImage(AssetImage(path), context);
    } catch (_) {}
  }

  bool _navegando = false;
  _CategoriaHome? _categoria;
  bool _mostrarAjustes = false;
  bool _mostrarCuenta = false;
  String? _avisoExito;
  int _avisoToken = 0;
  AjustesEstado _ajustes = const AjustesEstado();
  _TipoJuegoHome? _esloganAbierto;
  late final AnimationController _entrada;
  late final AnimationController _listaEntrada;
  late final Animation<double> _tituloOpacidad;
  late final Animation<Offset> _tituloDesliz;
  final ScrollController _scrollController = ScrollController();
  final Map<_CategoriaHome, GlobalKey> _claveSeccion = {
    for (final c in _CategoriaHome.values) c: GlobalKey(),
  };
  double _scrollObjetivo = 0;
  int _scrollAnimToken = 0;
  bool _ruedaAnimando = false;

  static const _juegos = <_JuegoHome>[
    _JuegoHome(
      tipo: _TipoJuegoHome.escobaDel15,
      titulo: 'Escoba del 15',
      subtitulo: 'Cartas españolas · a 15',
      accent: AppColors.azul,
      categoria: _CategoriaHome.cartasEspanolas,
      portadaAsset: _portadaEscoba,
      eslogan:
          'Cartas españolas, cara de concentrado para sumar 15' 
          'y esa escoba que te saca una sonrisa malvada.'
          'Ideal para pelear en la mesa con amigos o en familia y '
          'fingir que “sabías la cuenta”. ¿Estás listo para jugar?',
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.culoSucioV2,
      titulo: 'Culo sucio v2',
      subtitulo: 'Cartas · pares y el 1 de oro',
      accent: AppColors.acentoSuave,
      categoria: _CategoriaHome.cartasEspanolas,
      portadaAsset: _portadaCuloSucioV2,
      destacadoFuego: true,
      eslogan:
          'Eliminar pares, el 1 de oro y esa tensión de no querer quedar “con el c... sucio”. '
          'Ideal para pelear con amigos, reírse del que pierde y pedir '
          'revancha al toque. ¿Estás listo para jugar?',
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.culoSucioV1,
      titulo: 'Culo sucio v1',
      subtitulo: 'Cartas españolas · el 1 de oro pierde',
      accent: AppColors.peligro,
      categoria: _CategoriaHome.cartasEspanolas,
      portadaAsset: _portadaCuloSucioV1,
      eslogan:
          'La versión clásica: el 1 de oro\n'
          'te hunde y nadie te tiene piedad. '
          'Ideal para mesa rápida, insultos cariñosos y “una más”. '
          '¿Estás listo para jugar?',
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.casitaRobada,
      titulo: 'Casita robada',
      subtitulo: 'Cartas · pares y casitas',
      accent: AppColors.mint,
      categoria: _CategoriaHome.cartasEspanolas,
      portadaAsset: _portadaCasitaRobada,
      eslogan:
          'Armás casitas, robás la del otro\n'
          'y mirás inocente. Ideal para '
          'pelear el montoncito con amigos o en familia y decir “era mía”. '
          '¿Estás listo para jugar?',
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.chanchoVa,
      titulo: 'Chancho va',
      subtitulo: 'Cartas · cuartetos y CHANCHO VA',
      accent: AppColors.acentoSuave,
      categoria: _CategoriaHome.cartasEspanolas,
      portadaAsset: _portadaChanchoVa,
      eslogan:
          'Cuartetos, manos rápidas y el\n'
          'grito sagrado: ¡CHANCHO VA! Ideal '
          'para el caos controlado con amigos y quedar como el más lento '
          'de la mesa. ¿Estás listo para jugar?',
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.desconfio,
      titulo: 'Desconfío',
      subtitulo: 'Cartas españolas · bluff',
      accent: AppColors.azulSuave,
      categoria: _CategoriaHome.cartasEspanolas,
      portadaAsset: _portadaDesconfio,
      eslogan:
          'Chamuyo, cara de póker y ese “desconfío” que te salva… o te hunde. '
          'Ideal para mentir con estilo y pelear la mesa con amigos. '
          '¿Estás listo para jugar?',
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.jodete,
      titulo: 'Jodete',
      subtitulo: 'Españolas · 50 cartas',
      accent: AppColors.peligro,
      categoria: _CategoriaHome.cartasEspanolas,
      portadaAsset: _portadaJodete,
      eslogan:
          '50 cartas españolas y el placer\n'
          'de decir “jodete” con la jugada '
          'justa. Ideal para pelear turnos, reírse del rival y no soltar '
          'la mesa. ¿Estás listo para jugar?',
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.diezMil,
      titulo: 'Diez Mil',
      subtitulo: 'Dados · 5 o 6',
      accent: AppColors.acento,
      categoria: _CategoriaHome.dados,
      portadaAsset: _portadaDiezMil,
      eslogan:
          'Seis dados, una meta imposible\n'
          'de 10.000 y esa vocecita que te dice “una tirada más”. '
          'Arriesgás de más y… ¡fuiste, todo al piso! '
          '¿Estás listo para jugar?',
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.generala,
      titulo: 'Generala',
      subtitulo: 'Dados · tabla de anotación',
      accent: AppColors.violeta,
      categoria: _CategoriaHome.dados,
      portadaAsset: _portadaGenerala,
      eslogan:
          'Cinco dados, la malvada tablita traicionera y ese “casi generala” '
          'que duele más que perder. Culpás a los dados y jurás que “la próxima sale”. '
          '¿Estás listo?',
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.guerraDeCartas,
      titulo: 'Guerra de cartas',
      subtitulo: 'Cartas inglesas · AS alto',
      accent: AppColors.azul,
      categoria: _CategoriaHome.cartasInglesas,
      portadaAsset: _portadaGuerraDeCartas,
      eslogan:
          'Carta contra carta, el AS manda y la suerte decide. Ideal para '
          'partidas cortas, dramas innecesarios y “¡guerra!”. '
          '¿Estás listo para jugar?',
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.canasta,
      titulo: 'Canasta',
      subtitulo: 'Próximamente',
      accent: AppColors.violeta,
      categoria: _CategoriaHome.cartasInglesas,
      portadaAsset: _portadaCanasta,
      enabled: false,
      eslogan:
          'Combinaciones, canastas y puntos que '
          'se acumulan con paciencia… o con '
          'suerte. Estamos barajando esta mesa: pronto vas a poder jugar. '
          '¿Estás listo para cuando llegue?',
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.tuttiFrutti,
      titulo: 'Tutti Frutti',
      subtitulo: 'Letras · categorías online',
      accent: AppColors.rosa,
      categoria: _CategoriaHome.papel,
      portadaAsset: _portadaTuttiFrutti,
      eslogan:
          'Una letra, mil categorías y el\n'
          'reloj que no perdona. Pensás '
          '“fruta con M…” y se te va la mente. Ideal para pelear en familia, '
          'inventar palabras dudosas y pelear el punto hasta el final. '
          '¿Estás listo para jugar?',
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.unoSolo,
      titulo: 'Uno solo',
      subtitulo: 'Tablero · una ficha en el centro',
      accent: AppColors.mint,
      categoria: _CategoriaHome.papel,
      portadaAsset: _portadaUnoSolo,
      eslogan:
          'Una ficha en el centro y un\n'
          'tablero que pide estrategia (o suerte '
          'disfrazada). Ideal para pensar dos jugadas… o improvisar y '
          'culpar al destino. ¿Estás listo para jugar?',
    ),
    _JuegoHome(
      tipo: _TipoJuegoHome.laPapa,
      titulo: 'La papa',
      subtitulo: 'Hoja · uní los números',
      accent: AppColors.mint,
      categoria: _CategoriaHome.papel,
      portadaAsset: _portadaLaPapa,
      eslogan:
          'Una hoja llena de números, un lápiz tembloroso y esa línea que '
          'jurás no va a tocar… hasta que toca. Unís del 1 en adelante sin '
          'cruzarte, pedís puente si hace falta y, si te animás, modo infernal. '
          'Ideal para pelear la hoja con amigos o en familia, culpar al dedo '
          'y decir “era imposible”. ¿Estás listo para jugar?',
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

  void _mostrarAvisoExito(String texto) {
    final token = ++_avisoToken;
    setState(() => _avisoExito = texto);
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted || token != _avisoToken) return;
      setState(() => _avisoExito = null);
    });
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

  List<_JuegoHome> get _juegosFiltrados => _juegos;

  /// Padding horizontal de cada sección (16+16).
  static const _paddingSeccionH = 32.0;

  bool _esCelular(double ancho) {
    const gap = 20.0;
    const alto = 400.0;
    const chromeMin = 218.0;
    final anchoUtil = math.max(0.0, ancho - _paddingSeccionH);
    final anchoTarjeta =
        math.max(120.0, (alto - chromeMin) * _JuegoHome.aspectPortadaHome);
    return anchoUtil < 2 * anchoTarjeta + gap;
  }

  int _columnasPara(double ancho) {
    const gap = 20.0;
    const alto = 400.0;
    const chromeMin = 218.0;
    final anchoUtil = math.max(0.0, ancho - _paddingSeccionH);
    final anchoTarjeta =
        math.max(120.0, (alto - chromeMin) * _JuegoHome.aspectPortadaHome);
    if (anchoUtil >= 3 * anchoTarjeta + 2 * gap) return 3;
    if (anchoUtil >= 2 * anchoTarjeta + gap) return 2;
    // Celulares: siempre 2 (el alto se achica para que entren).
    return 2;
  }

  /// En celular: las 2 tarjetas llenan el ancho útil de la sección.
  double _anchoTarjetaCelular(double ancho) {
    const gap = 20.0;
    final anchoUtil = math.max(0.0, ancho - _paddingSeccionH);
    return math.max(120.0, (anchoUtil - gap) / 2);
  }

  /// Alto de tarjeta cuadrada según columnas y ancho disponible.
  double _altoCuadradaPara({
    required double ancho,
    required int columnas,
    required bool esCelular,
  }) {
    const altoMax = 400.0;
    const gap = 20.0;
    // Celular: flecha del eslogan va debajo → un poco más de chrome.
    final chromeMin = esCelular ? 236.0 : 218.0;
    if (columnas < 2) return altoMax;
    final anchoUtil = math.max(0.0, ancho - _paddingSeccionH);
    final anchoTarjeta = esCelular
        ? (anchoUtil - gap) / 2
        : (anchoUtil - gap * (columnas - 1)) / columnas;
    final altoNecesario =
        chromeMin + anchoTarjeta / _JuegoHome.aspectPortadaHome;
    return math.min(altoMax, math.max(260.0, altoNecesario));
  }

  double _anchoTarjetaDe(_JuegoHome j, double alto, {double? anchoFijo}) {
    if (anchoFijo != null) return anchoFijo;
    const chromeMin = 218.0;
    final aspect = j.aspectPortada ?? _JuegoHome.aspectPortadaHome;
    return math.max(120.0, (alto - chromeMin) * aspect);
  }

  Widget _tileDeJuego(
    _JuegoHome j, {
    required int index,
    required double alto,
    double? anchoFijo,
    bool layoutCelular = false,
  }) {
    final tile = RepaintBoundary(
      child: SizedBox(
        height: alto,
        width: _anchoTarjetaDe(j, alto, anchoFijo: anchoFijo),
        child: _JuegoTile(
          titulo: j.titulo,
          accent: j.accent,
          enabled: j.enabled,
          destacadoFuego: j.destacadoFuego,
          portadaAsset: j.portadaAsset,
          tarjetaCuadrada: j.tarjetaCuadrada,
          eslogan: j.eslogan,
          esloganExpandible: j.esloganExpandible,
          esloganExpandido: _esloganAbierto == j.tipo,
          layoutCelular: layoutCelular,
          onToggleEslogan: () {
            setState(() {
              _esloganAbierto = _esloganAbierto == j.tipo ? null : j.tipo;
            });
          },
          animaciones: _ajustes.animaciones,
          aspectPortada: j.aspectPortada,
          onJugar: _onJugarDe(j),
          onReglas: _onReglasDe(j),
        ),
      ),
    );
    if (_listaEntrada.value >= 0.999) return tile;
    return _tarjetaEntrada(index: index, child: tile);
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
    _categoria = cat;
    _centrarSeccion(cat);
  }

  Future<void> _centrarSeccion(
    _CategoriaHome cat, {
    Duration? duracion,
  }) async {
    if (!_scrollController.hasClients) return;
    final token = ++_scrollAnimToken;
    _ruedaAnimando = true;
    final dur = duracion ??
        (_ajustes.animaciones
            ? const Duration(milliseconds: 200)
            : Duration.zero);

    final ctx = _claveSeccion[cat]?.currentContext;
    if (ctx == null || !ctx.mounted) {
      _ruedaAnimando = false;
      return;
    }
    final seccion = ctx.findRenderObject();
    final vista = _scrollController.position.context.notificationContext
        ?.findRenderObject();
    if (seccion is! RenderBox ||
        vista is! RenderBox ||
        !seccion.hasSize ||
        !vista.hasSize) {
      _ruedaAnimando = false;
      return;
    }

    final pos = _scrollController.position;
    final seccionY = seccion.localToGlobal(Offset.zero).dy;
    final vistaY = vista.localToGlobal(Offset.zero).dy;
    var destino = pos.pixels + (seccionY - vistaY);
    destino = destino.clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if ((destino - pos.pixels).abs() < 2) {
      _ruedaAnimando = false;
      _scrollObjetivo = pos.pixels;
      return;
    }

    if (dur == Duration.zero) {
      _scrollController.jumpTo(destino);
    } else {
      await _scrollController.animateTo(
        destino,
        duration: dur,
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted || token != _scrollAnimToken) return;
    _ruedaAnimando = false;
    if (_scrollController.hasClients) {
      _scrollObjetivo = _scrollController.offset;
    }
  }

  void _irAlInicio() {
    if (!_scrollController.hasClients) return;
    final token = ++_scrollAnimToken;
    _ruedaAnimando = true;
    final dur = _ajustes.animaciones
        ? const Duration(milliseconds: 900)
        : Duration.zero;
    if (dur == Duration.zero) {
      _scrollController.jumpTo(0);
      _ruedaAnimando = false;
      _scrollObjetivo = 0;
      return;
    }
    _scrollObjetivo = 0;
    _scrollController
        .animateTo(
      0,
      duration: dur,
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

  Widget _seccionCategoria({
    required int i,
    required ({_CategoriaHome cat, List<_JuegoHome> juegos}) seccion,
    required List<({_CategoriaHome cat, List<_JuegoHome> juegos})> secciones,
    required int columnas,
    required bool esCelular,
    required double gap,
    required double Function(_JuegoHome j) altoDe,
    required double Function(List<_JuegoHome> juegos) altoFilaDe,
    double? anchoFijoCelular,
  }) {
    var base = 0;
    for (var s = 0; s < i; s++) {
      base += secciones[s].juegos.length;
    }
    final fondoSeccion = i.isEven
        ? AppColors.carta.withValues(alpha: 0.38)
        : AppColors.fondo;

    // Celular: si hay más de 2 juegos, mismas reglas que Cartas españolas
    // (2 visibles + flechas + swipe + Ver más).
    final visibles = esCelular
        ? math.min(2, seccion.juegos.length)
        : math.min(columnas, seccion.juegos.length);

    return ColoredBox(
      key: _claveSeccion[seccion.cat],
      color: fondoSeccion,
      child: RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                seccion.cat.label,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              _CategoriaExpandible(
                key: ValueKey('exp-${seccion.cat}'),
                animaciones: _ajustes.animaciones,
                visibles: visibles,
                gap: gap,
                esCelular: esCelular,
                juegos: seccion.juegos,
                buildExtra: (juego, index) => _tileDeJuego(
                  juego,
                  index: base + visibles + index,
                  alto: altoDe(juego),
                  anchoFijo: anchoFijoCelular,
                  layoutCelular: esCelular,
                ),
                colorBoton: i.isEven
                    ? AppColors.fondo
                    : AppColors.carta.withValues(alpha: 0.38),
                onColapsar: () {
                  // Celular: volver al inicio de esta sección (no al tope de la lista).
                  if (esCelular) {
                    _centrarSeccion(
                      seccion.cat,
                      duracion: _ajustes.animaciones
                          ? const Duration(milliseconds: 900)
                          : Duration.zero,
                    );
                  } else {
                    _irAlInicio();
                  }
                },
                buildCarousel: (expandida, onPrimerVisible, carruselKey) =>
                    _CarruselCategoria(
                  key: carruselKey,
                  juegos: seccion.juegos,
                  visibles: visibles,
                  gap: gap,
                  // En celular las flechas van junto a Ver más; el swipe sigue.
                  mostrarControles: !expandida,
                  mostrarFlechasLaterales: !expandida && !esCelular,
                  onPrimerVisible: onPrimerVisible,
                  anchos: [
                    for (final j in seccion.juegos)
                      _anchoTarjetaDe(
                        j,
                        altoDe(j),
                        anchoFijo: anchoFijoCelular,
                      ),
                  ],
                  altoFila: altoFilaDe(seccion.juegos),
                  animaciones: _ajustes.animaciones,
                  buildTile: (juego, index) => _tileDeJuego(
                    juego,
                    index: base + index,
                    alto: altoDe(juego),
                    anchoFijo: anchoFijoCelular,
                    layoutCelular: esCelular,
                  ),
                ),
              ),
            ],
          ),
        ),
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
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FadeTransition(
                    opacity: _tituloOpacidad,
                    child: SlideTransition(
                      position: _tituloDesliz,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 48),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                  ShaderMask(
                                        blendMode: BlendMode.srcIn,
                                        shaderCallback: (bounds) =>
                                            const LinearGradient(
                                          colors: [
                                            Colors.white,
                                            AppColors.acento,
                                            AppColors.azul,
                                          ],
                    ).createShader(bounds),
                    child: const Text(
                                          'Juegos de mesa ',
                      style: TextStyle(
                        color: Colors.white,
                                            fontSize: 26,
                        fontWeight: FontWeight.w900,
                                            letterSpacing: 0.4,
                                            height: 1.05,
                      ),
                    ),
                  ),
                                      ShaderMask(
                                        blendMode: BlendMode.srcIn,
                                        shaderCallback: (bounds) =>
                                            const LinearGradient(
                                          colors: [
                                            AppColors.azul,
                                            Colors.white,
                                            AppColors.acento,
                                            Colors.white,
                                            AppColors.azul,
                                          ],
                                          stops: [
                                            0,
                                            0.28,
                                            0.5,
                                            0.72,
                                            1,
                                          ],
                                        ).createShader(bounds),
                                        child: const Text(
                                          'Argentos',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 26,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.4,
                                            height: 1.05,
                                          ),
                                        ),
                                      ),
                                    ],
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
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Tooltip(
                              message: UsuarioMongoService.instance.haySesion
                                  ? 'Perfil'
                                  : 'Cuenta',
                              child: Material(
                                color: AppColors.carta,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () =>
                                      setState(() => _mostrarCuenta = true),
                                  child: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.azul
                                            .withValues(alpha: 0.85),
                                        width: 1.6,
                                      ),
                                      boxShadow: neonGlow(
                                        AppColors.azul,
                                        blur: 10,
                                      ),
                                    ),
                                    child: Center(
                                      child: Builder(
                                        builder: (context) {
                                          final nick = UsuarioMongoService
                                                  .instance
                                                  .usuario
                                                  ?.nombreUsuario ??
                                              '';
                                          if (!UsuarioMongoService
                                              .instance.haySesion) {
                                            return const Icon(
                                              Icons.person_rounded,
                                              color: AppColors.texto,
                                              size: 22,
                                            );
                                          }
                                          final letra = nick.isEmpty
                                              ? '?'
                                              : nick.substring(0, 1).toUpperCase();
                                          return Text(
                                            letra,
                                            style: const TextStyle(
                                              color: AppColors.texto,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                        ),
                      );
                    },
                  ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Tooltip(
                              message: 'Ajustes',
                              child: Material(
                                color: AppColors.carta,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () =>
                                      setState(() => _mostrarAjustes = true),
                                  child: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.rosa
                                            .withValues(alpha: 0.85),
                                        width: 1.6,
                                      ),
                                      boxShadow: neonGlow(
                                        AppColors.rosa,
                                        blur: 10,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.settings,
                                      color: AppColors.texto,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FadeTransition(
                      opacity: _tituloOpacidad,
                      child: _BarraCategorias(
                        seleccionada: _categoria,
                        onSeleccionar: _seleccionarCategoria,
                      ),
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
                                        final esCelular =
                                            _esCelular(constraints.maxWidth);
                                        final columnas =
                                            _columnasPara(constraints.maxWidth);
                                        final anchoFijoCelular = esCelular
                                            ? _anchoTarjetaCelular(
                                                constraints.maxWidth,
                                              )
                                            : null;
                                        const altoCompacta = 132.0;
                                        final altoCuadradaConEslogan =
                                            _altoCuadradaPara(
                                          ancho: constraints.maxWidth,
                                          columnas: columnas,
                                          esCelular: esCelular,
                                        );
                                        const gap = 20.0;
                                        const categoriasOrden = [
                                          _CategoriaHome.cartasEspanolas,
                                          _CategoriaHome.dados,
                                          _CategoriaHome.cartasInglesas,
                                          _CategoriaHome.papel,
                                        ];

                                        double altoDe(_JuegoHome j) {
                                          if (!j.tarjetaCuadrada) {
                                            return altoCompacta;
                                          }
                                          return altoCuadradaConEslogan;
                                        }

                                        double altoFilaDe(List<_JuegoHome> juegos) {
                                          if (juegos.isEmpty) {
                                            return altoCuadradaConEslogan;
                                          }
                                          return juegos
                                              .map(altoDe)
                                              .fold<double>(
                                                altoCompacta,
                                                (a, b) => a > b ? a : b,
                                              );
                                        }

                                        final secciones =
                                            <({
                                          _CategoriaHome cat,
                                          List<_JuegoHome> juegos
                                        })>[];
                                        for (final cat in categoriasOrden) {
                                          final juegos = [
                                            for (final j in filtrados)
                                              if (j.categoria == cat) j,
                                          ];
                                          if (juegos.isEmpty) continue;
                                          secciones.add(
                                            (cat: cat, juegos: juegos),
                                          );
                                        }

                                        return SingleChildScrollView(
                                          controller: _scrollController,
                                          padding: EdgeInsets.zero,
                                          physics:
                                              const ClampingScrollPhysics(),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              for (var i = 0;
                                                  i < secciones.length;
                                                  i++)
                                                _seccionCategoria(
                                                  i: i,
                                                  seccion: secciones[i],
                                                  secciones: secciones,
                                                  columnas: columnas,
                                                  esCelular: esCelular,
                                                  gap: gap,
                                                  altoDe: altoDe,
                                                  altoFilaDe: altoFilaDe,
                                                  anchoFijoCelular:
                                                      anchoFijoCelular,
                                                ),
                                            ],
                                          ),
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
                ],
              ),
            ),
          ),
          if (_mostrarAjustes)
            Positioned.fill(
              child: AjustesOverlay(
                ajustes: _ajustes,
                onChanged: (a) => setState(() => _ajustes = a),
                onCerrar: () => setState(() => _mostrarAjustes = false),
              ),
            ),
          if (_mostrarCuenta)
            Positioned.fill(
              child: CuentaOverlay(
                onCerrar: () => setState(() => _mostrarCuenta = false),
                onSesion: () => setState(() {}),
                onExito: _mostrarAvisoExito,
              ),
            ),
          if (_avisoExito != null)
            Positioned(
              top: 0,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Material(
                  color: const Color(0xFF22C55E),
                  elevation: 10,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Text(
                      _avisoExito!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoriaExpandible extends StatefulWidget {
  const _CategoriaExpandible({
    super.key,
    required this.animaciones,
    required this.visibles,
    required this.gap,
    required this.buildCarousel,
    required this.juegos,
    required this.buildExtra,
    required this.colorBoton,
    required this.onColapsar,
    this.esCelular = false,
  });

  final bool animaciones;
  final int visibles;
  final double gap;
  final bool esCelular;
  final Widget Function(
    bool expandida,
    ValueChanged<int> onPrimerVisible,
    GlobalKey<_CarruselCategoriaState> carruselKey,
  ) buildCarousel;
  final List<_JuegoHome> juegos;
  final Widget Function(_JuegoHome juego, int index) buildExtra;
  final Color colorBoton;
  final VoidCallback onColapsar;

  @override
  State<_CategoriaExpandible> createState() => _CategoriaExpandibleState();
}

class _CategoriaExpandibleState extends State<_CategoriaExpandible>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrada;
  late final Animation<double> _factor;
  final _carruselKey = GlobalKey<_CarruselCategoriaState>();
  bool _mostrarExtras = false;
  bool _abierta = false;
  bool _toggling = false;
  int _primerVisible = 0;
  List<_JuegoHome> _extrasEnPantalla = const [];

  Duration get _duracion => widget.animaciones
      ? const Duration(milliseconds: 360)
      : Duration.zero;

  Duration get _duracionCierre => widget.animaciones
      ? const Duration(milliseconds: 900)
      : Duration.zero;

  @override
  void initState() {
    super.initState();
    _entrada = AnimationController(
      vsync: this,
      duration: _duracion,
      reverseDuration: _duracionCierre,
    );
    _factor = CurvedAnimation(
      parent: _entrada,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _CategoriaExpandible oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entrada.duration = _duracion;
    _entrada.reverseDuration = _duracionCierre;
  }

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_toggling) return;
    _toggling = true;
    try {
      if (_abierta) {
        widget.onColapsar();
        if (widget.animaciones) {
          await _entrada.reverse();
        } else {
          _entrada.value = 0;
        }
        if (!mounted) return;
        setState(() {
          _abierta = false;
          _mostrarExtras = false;
          _extrasEnPantalla = const [];
        });
      } else {
        _entrada.value = 0;
        _extrasEnPantalla = _extrasDesde(_primerVisible);
        setState(() {
          _abierta = true;
          _mostrarExtras = true;
        });
        if (widget.animaciones) {
          // Montar las cartas en altura 0 y recién ahí animar;
          // si no, el primer layout las muestra ya abiertas.
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted || !_abierta) return;
          await _entrada.forward();
        } else {
          _entrada.value = 1;
        }
      }
    } finally {
      _toggling = false;
    }
  }

  int get _porFila => math.min(3, math.max(1, widget.visibles));

  bool get _hayExtras => widget.juegos.length > widget.visibles;

  void _onPrimerVisible(int i) {
    _primerVisible = i;
  }

  List<_JuegoHome> _extrasDesde(int primerVisible) {
    final n = widget.juegos.length;
    final v = math.min(widget.visibles, n);
    if (n <= v) return const [];
    final start = n == 0 ? 0 : primerVisible % n;
    return [
      for (var i = 0; i < n - v; i++)
        widget.juegos[(start + v + i) % n],
    ];
  }

  Widget _grillaExtras() {
    final extras = _extrasEnPantalla;
    final tiles = [
      for (var i = 0; i < extras.length; i++)
        widget.buildExtra(extras[i], i),
    ];
    final filas = <Widget>[];
    for (var i = 0; i < tiles.length; i += _porFila) {
      final fin = math.min(i + _porFila, tiles.length);
      filas.add(SizedBox(height: widget.gap));
      filas.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var j = i; j < fin; j++) ...[
              if (j > i) SizedBox(width: widget.gap),
              tiles[j],
            ],
          ],
        ),
      );
    }
    return Column(children: filas);
  }

  Widget _flechaNav({
    required IconData icono,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.carta,
      shape: const CircleBorder(),
      elevation: 6,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.azul.withValues(alpha: 0.85),
              width: 1.6,
            ),
            boxShadow: neonGlow(AppColors.azul, blur: 8),
          ),
          child: Icon(icono, color: AppColors.texto, size: 26),
        ),
      ),
    );
  }

  Widget _filaVerMas() {
    final mostrarFlechas = widget.esCelular && _hayExtras && !_abierta;
    final boton = _BotonVerMas(
      abierto: _abierta,
      fondo: widget.colorBoton,
      onTap: _toggle,
    );
    if (!mostrarFlechas) {
      return Center(child: boton);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _flechaNav(
          icono: Icons.chevron_left_rounded,
          onTap: () => _carruselKey.currentState?.irAnterior(),
        ),
        const SizedBox(width: 14),
        boton,
        const SizedBox(width: 14),
        _flechaNav(
          icono: Icons.chevron_right_rounded,
          onTap: () => _carruselKey.currentState?.irSiguiente(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        widget.buildCarousel(_abierta, _onPrimerVisible, _carruselKey),
        if (_mostrarExtras)
          ClipRect(
            child: SizeTransition(
              sizeFactor: _factor,
              alignment: Alignment.topCenter,
              child: _grillaExtras(),
            ),
          ),
        if (_hayExtras) ...[
          const SizedBox(height: 14),
          _filaVerMas(),
        ],
      ],
    );
  }
}

class _BotonVerMas extends StatelessWidget {
  const _BotonVerMas({
    required this.abierto,
    required this.fondo,
    required this.onTap,
  });

  final bool abierto;
  final Color fondo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Ink(
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.azul, width: 1.6),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            child: Text(
              abierto ? 'Ver menos' : 'Ver más',
              style: const TextStyle(
                color: AppColors.azul,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FisicaSnapCarrusel extends ScrollPhysics {
  const _FisicaSnapCarrusel({
    required this.destino,
    super.parent,
  });

  final double Function(double pixels, double velocity) destino;

  @override
  _FisicaSnapCarrusel applyTo(ScrollPhysics? ancestor) {
    return _FisicaSnapCarrusel(
      destino: destino,
      parent: buildParent(ancestor),
    );
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 1.15,
        stiffness: 140,
        damping: 24,
      );

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final target = destino(position.pixels, velocity).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final tol = toleranceFor(position);
    if ((target - position.pixels).abs() < math.max(tol.distance, 0.5) &&
        velocity.abs() < math.max(tol.velocity, 40)) {
      return null;
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tol,
    );
  }
}

class _CarruselCategoria extends StatefulWidget {
  const _CarruselCategoria({
    super.key,
    required this.juegos,
    required this.visibles,
    required this.gap,
    required this.anchos,
    required this.altoFila,
    required this.buildTile,
    required this.animaciones,
    this.mostrarControles = true,
    this.mostrarFlechasLaterales = true,
    this.onPrimerVisible,
  });

  final List<_JuegoHome> juegos;
  final int visibles;
  final double gap;
  final List<double> anchos;
  final double altoFila;
  final bool animaciones;
  /// Swipe / snap del carrusel.
  final bool mostrarControles;
  /// Flechas encima de las tarjetas (desktop). En celular van junto a Ver más.
  final bool mostrarFlechasLaterales;
  final ValueChanged<int>? onPrimerVisible;
  final Widget Function(_JuegoHome juego, int index) buildTile;

  @override
  State<_CarruselCategoria> createState() => _CarruselCategoriaState();
}

class _CarruselCategoriaState extends State<_CarruselCategoria> {
  static const _copias = 6;
  late final ScrollController _scroll;
  int _indice = 0;
  bool _enMovimiento = false;
  bool _ajustando = false;

  int get _n => widget.juegos.length;

  int get _porPagina => widget.visibles.clamp(1, 99);

  bool get _hayMas => _n > _porPagina;

  int get _pasoFlecha => math.max(1, _porPagina - 1);

  int get _indiceBase => _n * (_copias ~/ 2);

  int get _itemCount => _hayMas ? _n * _copias : _n;

  Duration get _duracion => widget.animaciones
      ? const Duration(milliseconds: 450)
      : Duration.zero;

  double get _anchoVista {
    final v = math.min(_porPagina, _n);
    if (v <= 0) return 0;
    var w = 0.0;
    for (var i = 0; i < v; i++) {
      if (i > 0) w += widget.gap;
      w += _anchoDe(i);
    }
    return w;
  }

  double get _largoCiclo {
    var x = 0.0;
    for (var i = 0; i < _n; i++) {
      x += _anchoDe(i) + widget.gap;
    }
    return x;
  }

  double _anchoDe(int i) {
    if (widget.anchos.isEmpty) return 0;
    return widget.anchos[i % widget.anchos.length];
  }

  double _offsetDe(int indice) {
    if (indice <= 0 || _n == 0) return 0;
    final ciclos = indice ~/ _n;
    final resto = indice % _n;
    var x = ciclos * _largoCiclo;
    for (var i = 0; i < resto; i++) {
      x += _anchoDe(i) + widget.gap;
    }
    return x;
  }

  int _indiceCercano(double offset) {
    if (_n == 0) return 0;
    final ciclo = _largoCiclo;
    if (ciclo <= 0) return 0;
    var ciclosPasados = (offset / ciclo).floor();
    var resto = offset - ciclosPasados * ciclo;
    if (resto < 0) {
      ciclosPasados--;
      resto += ciclo;
    }
    var mejor = 0;
    var dist = resto.abs();
    var x = 0.0;
    for (var i = 0; i < _n; i++) {
      final d = (resto - x).abs();
      if (d < dist) {
        dist = d;
        mejor = i;
      }
      x += _anchoDe(i) + widget.gap;
    }
    if ((resto - ciclo).abs() < dist) {
      ciclosPasados++;
      mejor = 0;
    }
    return (ciclosPasados * _n + mejor)
        .clamp(0, math.max(0, _itemCount - 1))
        .toInt();
  }

  int get _indiceMaximo => math.max(0, _itemCount - _porPagina);

  double _destinoSnap(double pixels, double velocity) {
    var i = _indiceCercano(pixels);
    const umbral = 420.0;
    if (velocity.abs() > umbral) {
      i += velocity > 0 ? 1 : -1;
    }
    return _offsetDe(i.clamp(0, _indiceMaximo).toInt());
  }

  void _irAlMedio() {
    if (!_hayMas) return;
    _indice = _indiceBase;
    _saltarA(_offsetDe(_indice));
    _avisarPrimerVisible();
  }

  void _avisarPrimerVisible() {
    if (_n == 0) return;
    widget.onPrimerVisible?.call(_indice % _n);
  }

  void _saltarA(double target) {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final clamped = target.clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if ((_scroll.offset - clamped).abs() < 1.5) return;
    _ajustando = true;
    _scroll.jumpTo(clamped);
    _ajustando = false;
  }

  void _recentrarSiHaceFalta() {
    if (!_hayMas || !_scroll.hasClients || _n == 0) return;
    final ciclo = _largoCiclo;
    if (ciclo <= 0) return;
    final pos = _scroll.position;
    var offset = pos.pixels;
    final minOK = ciclo;
    final maxOK = math.max(minOK, pos.maxScrollExtent - ciclo);
    if (offset < minOK || offset > maxOK) {
      var destino = offset;
      while (destino < minOK) {
        destino += ciclo;
      }
      while (destino > maxOK) {
        destino -= ciclo;
      }
      _saltarA(destino);
      offset = _scroll.hasClients ? _scroll.offset : destino;
    }
    _indice = _indiceCercano(offset).clamp(0, _indiceMaximo).toInt();
    _avisarPrimerVisible();
  }

  @override
  void initState() {
    super.initState();
    _indice = _hayMas ? _indiceBase : 0;
    _scroll = ScrollController(
      initialScrollOffset: _hayMas ? _offsetDe(_indice) : 0,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hayMas || !_scroll.hasClients) return;
      _irAlMedio();
    });
    _avisarPrimerVisible();
  }

  @override
  void didUpdateWidget(covariant _CarruselCategoria oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.juegos.length != widget.juegos.length ||
        oldWidget.visibles != widget.visibles) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _irAlMedio();
      });
    } else if (oldWidget.mostrarControles && !widget.mostrarControles) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        _saltarA(_offsetDe(_indice));
        _recentrarSiHaceFalta();
        _avisarPrimerVisible();
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _irA(int indice, {bool animar = true}) async {
    if (!_scroll.hasClients || _n == 0) return;
    _recentrarSiHaceFalta();
    var actual = _indice;
    var destino = indice;
    if (_hayMas) {
      final minS = _n;
      final maxS = _n * (_copias - 2) - _porPagina;
      if (actual < minS ||
          actual > maxS ||
          destino < minS ||
          destino > maxS) {
        final medio = _indiceBase + (actual % _n);
        final delta = destino - actual;
        if (medio != actual) {
          _indice = medio;
          _saltarA(_offsetDe(medio));
        }
        destino = medio + delta;
      }
    }
    destino = destino.clamp(0, _indiceMaximo).toInt();
    final target = _offsetDe(destino);
    if ((_scroll.offset - target).abs() < 1.5) {
      _indice = destino;
      _avisarPrimerVisible();
      if (_enMovimiento || _ajustando) {
        setState(() {
          _enMovimiento = false;
          _ajustando = false;
        });
      }
      _recentrarSiHaceFalta();
      return;
    }
    setState(() {
      _indice = destino;
      _enMovimiento = true;
      _ajustando = true;
    });
    _avisarPrimerVisible();
    if (!animar || !widget.animaciones) {
      _scroll.jumpTo(target.clamp(
        _scroll.position.minScrollExtent,
        _scroll.position.maxScrollExtent,
      ));
    } else {
      await _scroll.animateTo(
        target.clamp(
          _scroll.position.minScrollExtent,
          _scroll.position.maxScrollExtent,
        ),
        duration: _duracion,
        curve: Curves.easeInOutCubic,
      );
    }
    if (!mounted) return;
    setState(() {
      _enMovimiento = false;
      _ajustando = false;
    });
    _recentrarSiHaceFalta();
  }

  Future<void> _ir(int delta) async {
    if (!_hayMas || _enMovimiento || !widget.mostrarControles) return;
    await _irA(_indice + delta);
  }

  /// Navegación externa (flechas junto a Ver más en celular).
  Future<void> irAnterior() async {
    if (!_hayMas || _enMovimiento) return;
    await _irA(_indice - _pasoFlecha);
  }

  Future<void> irSiguiente() async {
    if (!_hayMas || _enMovimiento) return;
    await _irA(_indice + _pasoFlecha);
  }

  Widget _flecha({
    required IconData icono,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.carta,
      shape: const CircleBorder(),
      elevation: 6,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.azul.withValues(alpha: 0.85),
              width: 1.6,
            ),
            boxShadow: neonGlow(AppColors.azul, blur: 8),
          ),
          child: Icon(icono, color: AppColors.texto, size: 26),
        ),
      ),
    );
  }

  Widget _filaFija() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < widget.juegos.length; i++) ...[
          if (i > 0) SizedBox(width: widget.gap),
          widget.buildTile(widget.juegos[i], i),
        ],
      ],
    );
  }

  Widget _lista() {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: widget.mostrarControles
            ? {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.stylus,
                PointerDeviceKind.trackpad,
              }
            : {},
      ),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (!_hayMas ||
              n.depth != 0 ||
              !widget.mostrarControles ||
              _ajustando) {
            return false;
          }
          if (n is ScrollStartNotification && n.dragDetails != null) {
            _ajustando = false;
            _enMovimiento = true;
          } else if (n is ScrollUpdateNotification && !_ajustando) {
            _indice = _indiceCercano(_scroll.offset);
            _avisarPrimerVisible();
          } else if (n is ScrollEndNotification) {
            if (_ajustando || !_scroll.hasClients) return false;
            final i = _indiceCercano(_scroll.offset);
            if (_indice != i || _enMovimiento) {
              setState(() {
                _indice = i;
                _enMovimiento = false;
              });
            }
            _avisarPrimerVisible();
            _recentrarSiHaceFalta();
          }
          return false;
        },
        child: ListView.separated(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          primary: false,
          padding: EdgeInsets.zero,
          addAutomaticKeepAlives: false,
          physics: widget.mostrarControles
              ? _FisicaSnapCarrusel(
                  destino: _destinoSnap,
                  parent: const ClampingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                )
              : const NeverScrollableScrollPhysics(),
          itemCount: _itemCount,
          separatorBuilder: (_, __) => SizedBox(width: widget.gap),
          itemBuilder: (context, i) {
            final j = i % _n;
            return widget.buildTile(widget.juegos[j], j);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.altoFila,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: SizedBox(
              width: _anchoVista,
              height: widget.altoFila,
              child: _hayMas ? ClipRect(child: _lista()) : _filaFija(),
            ),
          ),
          if (_hayMas && widget.mostrarFlechasLaterales)
            Positioned(
              left: 4,
              child: _flecha(
                icono: Icons.chevron_left_rounded,
                onTap: _enMovimiento ? null : () => _ir(-_pasoFlecha),
              ),
            ),
          if (_hayMas && widget.mostrarFlechasLaterales)
            Positioned(
              right: 4,
              child: _flecha(
                icono: Icons.chevron_right_rounded,
                onTap: _enMovimiento ? null : () => _ir(_pasoFlecha),
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

  final _CategoriaHome? seleccionada;
  final ValueChanged<_CategoriaHome> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    Widget chip(_CategoriaHome cat) {
      return Semantics(
        button: true,
        selected: cat == seleccionada,
        child: Material(
          color: Colors.transparent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onSeleccionar(cat),
            customBorder: const StadiumBorder(),
            child: Ink(
              decoration: BoxDecoration(
                color: AppColors.fondo,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.azul, width: 1.6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 10,
                ),
                child: Text(
                  cat.label,
                  style: const TextStyle(
                    color: AppColors.azul,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
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

class _EsloganExpandible extends StatelessWidget {
  const _EsloganExpandible({
    required this.texto,
    required this.estilo,
    required this.expandido,
    required this.animaciones,
    required this.onTap,
    this.layoutCelular = false,
  });

  final String texto;
  final TextStyle estilo;
  final bool expandido;
  final bool animaciones;
  final VoidCallback? onTap;
  final bool layoutCelular;

  @override
  Widget build(BuildContext context) {
    final dur = animaciones
        ? const Duration(milliseconds: 280)
        : Duration.zero;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (layoutCelular) {
                return _layoutCelular(constraints, dur);
              }
              return _layoutDesktop(constraints, dur);
            },
          ),
        ),
      ),
    );
  }

  Widget _layoutCelular(BoxConstraints constraints, Duration dur) {
    final tamFuente = estilo.fontSize ?? 10.5;
    final radioPunto = math.max(1.1, tamFuente * 0.105);
    final pasoPuntos = radioPunto * 2.9;
    final puntosW = radioPunto * 2 + pasoPuntos * 2 + 2;
    final anchoTexto = math.max(0.0, constraints.maxWidth);
    final tp = TextPainter(
      text: TextSpan(text: texto, style: estilo),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: anchoTexto);
    final lineas = tp.computeLineMetrics();
    final altoLinea = lineas.isEmpty
        ? (estilo.fontSize ?? 10.5) * (estilo.height ?? 1.3)
        : lineas.first.height;
    final baseTexto = lineas.isEmpty ? altoLinea : lineas.first.baseline;
    final desborda = lineas.length > 1;

    var finPrimera = 0.0;
    if (texto.isNotEmpty && desborda) {
      final rango = tp.getLineBoundary(const TextPosition(offset: 0));
      var fin = rango.end.clamp(0, texto.length);
      while (fin > rango.start &&
          fin > 0 &&
          (texto[fin - 1] == ' ' || texto[fin - 1] == '\n')) {
        fin--;
      }
      if (fin > rango.start) {
        final cajas = tp.getBoxesForSelection(
          TextSelection(
            baseOffset: fin - 1,
            extentOffset: fin,
          ),
        );
        if (cajas.isNotEmpty) {
          finPrimera = math.max(cajas.first.left, cajas.first.right);
        } else {
          finPrimera = tp.getOffsetForCaret(
            TextPosition(
              offset: fin,
              affinity: TextAffinity.upstream,
            ),
            Rect.zero,
          ).dx;
        }
      }
    }

    final extraItalica =
        estilo.fontStyle == FontStyle.italic ? tamFuente * 0.42 : 1.5;
    final xPuntos = finPrimera + extraItalica;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedSize(
              duration: dur,
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.hardEdge,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: expandido ? tp.height : altoLinea,
                ),
                child: ClipRect(
                  child: SizedBox(
                    width: anchoTexto,
                    child: Text(
                      texto,
                      textAlign: TextAlign.center,
                      style: estilo,
                    ),
                  ),
                ),
              ),
            ),
            if (!expandido && desborda)
              Positioned(
                left: xPuntos.clamp(0.0, math.max(0.0, anchoTexto - puntosW)),
                top: 0,
                height: altoLinea,
                width: puntosW,
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _TresPuntosPainter(
                      color: estilo.color ?? AppColors.textoSuave,
                      radio: radioPunto,
                      paso: pasoPuntos,
                      baseline: baseTexto,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (desborda || expandido)
          IgnorePointer(
            child: Icon(
              expandido
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.textoSuave,
            ),
          ),
      ],
    );
  }

  Widget _layoutDesktop(BoxConstraints constraints, Duration dur) {
              const icono = 16.0;
              final tamFuente = estilo.fontSize ?? 10.5;
              final radioPunto = math.max(1.1, tamFuente * 0.105);
              final pasoPuntos = radioPunto * 2.9;
              final puntosW = radioPunto * 2 + pasoPuntos * 2 + 2;
              final margen = icono + puntosW + 2;
              final anchoTexto =
                  math.max(0.0, constraints.maxWidth - margen * 2);
              final tp = TextPainter(
                text: TextSpan(text: texto, style: estilo),
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
              )..layout(maxWidth: anchoTexto);
              final lineas = tp.computeLineMetrics();
              final altoLinea = lineas.isEmpty
                  ? (estilo.fontSize ?? 10.5) * (estilo.height ?? 1.3)
                  : lineas.first.height;
              final baseTexto = lineas.isEmpty ? altoLinea : lineas.first.baseline;
              final desborda = lineas.length > 1;

              var finPrimera = 0.0;
              if (texto.isNotEmpty && desborda) {
                final rango = tp.getLineBoundary(const TextPosition(offset: 0));
                var fin = rango.end.clamp(0, texto.length);
                while (fin > rango.start &&
                    fin > 0 &&
                    (texto[fin - 1] == ' ' || texto[fin - 1] == '\n')) {
                  fin--;
                }
                if (fin > rango.start) {
                  final cajas = tp.getBoxesForSelection(
                    TextSelection(
                      baseOffset: fin - 1,
                      extentOffset: fin,
                    ),
                  );
                  if (cajas.isNotEmpty) {
                    finPrimera =
                        math.max(cajas.first.left, cajas.first.right);
                  } else {
                    finPrimera = tp.getOffsetForCaret(
                      TextPosition(
                        offset: fin,
                        affinity: TextAffinity.upstream,
                      ),
                      Rect.zero,
                    ).dx;
                  }
                }
              }

              final extraItalica = estilo.fontStyle == FontStyle.italic
                  ? tamFuente * 0.42
                  : 1.5;
              final xPuntos = margen + finPrimera + extraItalica;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: margen),
                    child: AnimatedSize(
                      duration: dur,
                      curve: Curves.easeInOutCubic,
                      alignment: Alignment.topCenter,
                      clipBehavior: Clip.hardEdge,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: expandido ? tp.height : altoLinea,
                        ),
                        child: ClipRect(
                          child: SizedBox(
                            width: anchoTexto,
                            child: Text(
                              texto,
                              textAlign: TextAlign.center,
                              style: estilo,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!expandido && desborda)
                    Positioned(
                      left: xPuntos,
                      top: 0,
                      height: altoLinea,
                      width: puntosW,
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _TresPuntosPainter(
                            color: estilo.color ?? AppColors.textoSuave,
                            radio: radioPunto,
                            paso: pasoPuntos,
                            baseline: baseTexto,
                          ),
                        ),
                      ),
                    ),
                  if (desborda || expandido)
                    Positioned(
                      top: 0,
                      right: 0,
                      height: altoLinea,
                      width: icono,
                      child: IgnorePointer(
                        child: Icon(
                          expandido
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: AppColors.textoSuave,
                        ),
                      ),
                    ),
                ],
              );
  }
}

class _TresPuntosPainter extends CustomPainter {
  const _TresPuntosPainter({
    required this.color,
    required this.radio,
    required this.paso,
    required this.baseline,
  });

  final Color color;
  final double radio;
  final double paso;
  final double baseline;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final y = baseline - radio * 0.25;
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(radio + i * paso, y), radio, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TresPuntosPainter old) =>
      old.color != color ||
      old.radio != radio ||
      old.paso != paso ||
      old.baseline != baseline;
}

class _JuegoTile extends StatefulWidget {
  const _JuegoTile({
    required this.titulo,
    required this.accent,
    required this.portadaAsset,
    this.onJugar,
    this.onReglas,
    this.enabled = true,
    this.destacadoFuego = false,
    this.tarjetaCuadrada = false,
    this.eslogan,
    this.esloganExpandible = true,
    this.esloganExpandido = false,
    this.onToggleEslogan,
    this.animaciones = true,
    this.aspectPortada,
    this.layoutCelular = false,
  });

  final String titulo;
  final Color accent;
  final String portadaAsset;
  final VoidCallback? onJugar;
  final VoidCallback? onReglas;
  final bool enabled;
  final bool destacadoFuego;
  final bool tarjetaCuadrada;
  final String? eslogan;
  final bool esloganExpandible;
  final bool esloganExpandido;
  final VoidCallback? onToggleEslogan;
  final bool animaciones;
  final double? aspectPortada;
  final bool layoutCelular;

  @override
  State<_JuegoTile> createState() => _JuegoTileState();
}

class _JuegoTileState extends State<_JuegoTile> {
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
      final estiloEslogan = TextStyle(
        color: AppColors.textoSuave.withValues(alpha: 0.98),
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        height: 1.3,
        fontStyle: FontStyle.italic,
      );
      final botonesArcade = FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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

      if (widget.eslogan != null && widget.esloganExpandible) {
        final eslogan = widget.eslogan!;
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Column(
            children: [
              Text(
                widget.titulo,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              _EsloganExpandible(
                texto: eslogan,
                estilo: estiloEslogan,
                expandido: widget.esloganExpandido,
                animaciones: widget.animaciones,
                layoutCelular: widget.layoutCelular,
                onTap: widget.onToggleEslogan,
              ),
              Expanded(
                child: Center(child: botonesArcade),
              ),
            ],
          ),
        );
      }

      // Sin eslogan (o no expandible): botones centrados en el pie.
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Column(
          children: [
            Text(
              widget.titulo,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.texto,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            if (widget.eslogan != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.eslogan!,
                textAlign: TextAlign.center,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: estiloEslogan,
              ),
            ],
            Expanded(
              child: Center(child: botonesArcade),
            ),
          ],
        ),
      );
    }

    // La tarjeta mantiene su tamaño; la portada se ve completa (sin recorte).
    final portadaAlAncho = widget.aspectPortada != null;
    final fitPortada = BoxFit.contain;

    Widget tarjeta({
      required double anchoFijo,
      required double altoImg,
      required double altoTotal,
    }) {
    return DecoratedBox(
      decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: fuego
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF6D00).withValues(alpha: 0.35),
                        blurRadius: 12,
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
      return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: fuego
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF6D00).withValues(alpha: 0.35),
                        blurRadius: 12,
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
        // Reserva fija (eslogan + botones) para que todas midan igual que Diez Mil.
        const chromeMin = 218.0;
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
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: glow.withValues(alpha: 0.38),
                      blurRadius: 8,
                    ),
                  ]
                : null,
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
