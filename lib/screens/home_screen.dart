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
          'Cartas españolas, sumas a 15 y esa escoba que te saca una sonrisa '
          'malvada. Ideal para pelear la mesa con amigos o en familia y '
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
          'Pares, el 1 de oro y esa tensión de no querer quedar “sucio”. '
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
          'La versión clásica: el 1 de oro te hunde y nadie te tiene piedad. '
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
          'Armás casitas, robás la del otro y mirás inocente. Ideal para '
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
          'Cuartetos, manos rápidas y el grito sagrado: ¡CHANCHO VA! Ideal '
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
          'Bluff, cara de póker y ese “desconfío” que te salva… o te hunde. '
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
          '50 cartas españolas y el placer de decir “jodete” con la jugada '
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
      eslogan:
          'Cinco dados, una tablita traicionera y ese “¡casi generala!” '
          'que duele más que perder. Escalera, full, póker… o tachás con cara '
          'de póker. Ideal para pelear el puntaje con amigos o en familia, '
          'culpar a los dados y jurar que “la próxima sale”. '
          '¿Estás listo para jugar?',
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
          'Melés, canastas y puntos que se acumulan con paciencia… o con '
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
          'Una letra, mil categorías y el reloj que no perdona. Pensás '
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
          'Una ficha en el centro y un tablero que pide estrategia (o suerte '
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

  int _columnasPara(double ancho) {
    const gap = 20.0;
    const alto = 400.0;
    const chromeMin = 218.0;
    final anchoTarjeta =
        math.max(120.0, (alto - chromeMin) * _JuegoHome.aspectPortadaHome);
    if (ancho >= 3 * anchoTarjeta + 2 * gap) return 3;
    if (ancho >= 2 * anchoTarjeta + gap) return 2;
    return 1;
  }

  double _anchoTarjetaDe(_JuegoHome j, double alto) {
    const chromeMin = 218.0;
    final aspect = j.aspectPortada ?? _JuegoHome.aspectPortadaHome;
    return math.max(120.0, (alto - chromeMin) * aspect);
  }

  Widget _tileDeJuego(_JuegoHome j, {required int index, required double alto}) {
    return _tarjetaEntrada(
      index: index,
      child: SizedBox(
        height: alto,
        width: _anchoTarjetaDe(j, alto),
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
    setState(() => _categoria = cat);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _centrarSeccion(cat);
    });
  }

  Future<void> _centrarSeccion(_CategoriaHome cat) async {
    final ctx = _claveSeccion[cat]?.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final token = ++_scrollAnimToken;
    _ruedaAnimando = true;
    final dur = _ajustes.animaciones
        ? const Duration(milliseconds: 620)
        : Duration.zero;
    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      duration: dur == Duration.zero
          ? const Duration(milliseconds: 1)
          : dur,
      curve: Curves.easeInOutCubic,
    );
    if (!mounted || token != _scrollAnimToken) return;
    _ruedaAnimando = false;
    if (_scrollController.hasClients) {
      _scrollObjetivo = _scrollController.offset;
    }
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
                                        final columnas =
                                            _columnasPara(constraints.maxWidth);
                                        const altoCompacta = 132.0;
                                        const altoCuadradaConEslogan = 400.0;
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

                                        return ListView.builder(
                                          controller: _scrollController,
                                          padding: EdgeInsets.zero,
                                          physics:
                                              const ClampingScrollPhysics(),
                                          itemCount: secciones.length,
                                          itemBuilder: (context, i) {
                                            final seccion = secciones[i];
                                            var base = 0;
                                            for (var s = 0; s < i; s++) {
                                              base +=
                                                  secciones[s].juegos.length;
                                            }
                                            final fondoSeccion = i.isEven
                                                ? AppColors.carta.withValues(
                                                    alpha: 0.38,
                                                  )
                                                : AppColors.fondo;

                                            return ColoredBox(
                                              key: _claveSeccion[seccion.cat],
                                              color: fondoSeccion,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                  16,
                                                  12,
                                                  16,
                                                  16,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    Text(
                                                      seccion.cat.label,
                                                      style: const TextStyle(
                                                        color: AppColors.texto,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        fontSize: 16,
                                                        letterSpacing: 0.4,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    _CarruselCategoria(
                                                      key: ValueKey(
                                                        seccion.cat,
                                                      ),
                                                      juegos: seccion.juegos,
                                                      visibles: columnas,
                                                      gap: gap,
                                                      anchoFila: () {
                                                        final v = math.min(
                                                          columnas,
                                                          seccion.juegos.length,
                                                        );
                                                        if (v <= 0) return 0.0;
                                                        var w = 0.0;
                                                        for (var c = 0;
                                                            c < v;
                                                            c++) {
                                                          if (c > 0) w += gap;
                                                          w += _anchoTarjetaDe(
                                                            seccion.juegos[c],
                                                            altoDe(
                                                              seccion.juegos[c],
                                                            ),
                                                          );
                                                        }
                                                        return w;
                                                      }(),
                                                      altoFila: altoFilaDe(
                                                        seccion.juegos,
                                                      ),
                                                      animaciones: _ajustes
                                                          .animaciones,
                                                      buildTile:
                                                          (juego, index) =>
                                                              _tileDeJuego(
                                                        juego,
                                                        index: base + index,
                                                        alto: altoDe(juego),
                                                      ),
                                                    ),
                                                  ],
                                                ),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FadeTransition(
                      opacity: _tituloOpacidad,
                      child: const Text(
                        'Elegí un juego para crear o unirte a una sala',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textoSuave, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
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
        ],
      ),
    );
  }
}

class _CarruselCategoria extends StatefulWidget {
  const _CarruselCategoria({
    super.key,
    required this.juegos,
    required this.visibles,
    required this.gap,
    required this.anchoFila,
    required this.altoFila,
    required this.buildTile,
    required this.animaciones,
  });

  final List<_JuegoHome> juegos;
  final int visibles;
  final double gap;
  final double anchoFila;
  final double altoFila;
  final bool animaciones;
  final Widget Function(_JuegoHome juego, int index) buildTile;

  @override
  State<_CarruselCategoria> createState() => _CarruselCategoriaState();
}

class _CarruselCategoriaState extends State<_CarruselCategoria> {
  static const _ciclo = 400;
  late final PageController _paginas;
  bool _enMovimiento = false;

  int get _porPagina => widget.visibles.clamp(1, 99);

  Duration get _duracion => widget.animaciones
      ? const Duration(milliseconds: 780)
      : Duration.zero;

  int get _totalPaginas {
    if (widget.juegos.isEmpty) return 1;
    return (widget.juegos.length / _porPagina).ceil();
  }

  bool get _hayMas => widget.juegos.length > _porPagina;

  int get _paginaInicial =>
      _hayMas ? _totalPaginas * _ciclo : 0;

  int _mod(int i, int m) {
    if (m <= 0) return 0;
    return (i % m + m) % m;
  }

  @override
  void initState() {
    super.initState();
    _paginas = PageController(initialPage: _paginaInicial);
  }

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  Future<void> _ir(int delta) async {
    if (!_hayMas || _enMovimiento || !_paginas.hasClients) return;
    setState(() => _enMovimiento = true);
    final actual = _paginas.page?.round() ?? _paginaInicial;
    if (!widget.animaciones) {
      _paginas.jumpToPage(actual + delta);
    } else {
      await _paginas.animateToPage(
        actual + delta,
        duration: _duracion,
        curve: Curves.easeInOutSine,
      );
    }
    if (mounted) setState(() => _enMovimiento = false);
  }

  List<({_JuegoHome juego, int index})> _cartasDe(int pagina) {
    final n = widget.juegos.length;
    if (n == 0) return const [];
    if (!_hayMas) {
      return [
        for (var i = 0; i < n; i++) (juego: widget.juegos[i], index: i),
      ];
    }
    final v = _porPagina;
    var inicio = pagina * v;
    if (inicio + v > n) {
      inicio = n - v;
    }
    return [
      for (var c = 0; c < v; c++)
        (
          juego: widget.juegos[inicio + c],
          index: inicio + c,
        ),
    ];
  }

  Widget _flecha({
    required IconData icono,
    required VoidCallback onTap,
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

  Widget _filaDe(int pagina) {
    final cartas = _cartasDe(pagina);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = 0; c < cartas.length; c++) ...[
          if (c > 0) SizedBox(width: widget.gap),
          widget.buildTile(cartas[c].juego, cartas[c].index),
        ],
      ],
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
              width: widget.anchoFila +
                  (_hayMas ? widget.gap : 0),
              height: widget.altoFila,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.stylus,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (!_hayMas) return false;
                    if (n.depth != 0) return false;
                    if (n is ScrollStartNotification) {
                      if (!_enMovimiento) {
                        setState(() => _enMovimiento = true);
                      }
                    } else if (n is ScrollEndNotification) {
                      if (_enMovimiento) {
                        setState(() => _enMovimiento = false);
                      }
                    }
                    return false;
                  },
                  child: PageView.builder(
                    controller: _paginas,
                    physics: _hayMas
                        ? const BouncingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    itemCount: _hayMas ? null : 1,
                    itemBuilder: (context, index) {
                      final pagina =
                          _hayMas ? _mod(index, _totalPaginas) : 0;
                      if (!_hayMas) return _filaDe(pagina);
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.gap / 2,
                        ),
                        child: _filaDe(pagina),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          if (_hayMas)
            Positioned(
              left: 4,
              child: _flecha(
                icono: Icons.chevron_left_rounded,
                onTap: () => _ir(-1),
              ),
            ),
          if (_hayMas)
            Positioned(
              right: 4,
              child: _flecha(
                icono: Icons.chevron_right_rounded,
                onTap: () => _ir(1),
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
      final estiloEslogan = TextStyle(
        color: AppColors.textoSuave.withValues(alpha: 0.98),
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        height: 1.3,
        fontStyle: FontStyle.italic,
      );
      final durEslogan = widget.animaciones
          ? const Duration(milliseconds: 280)
          : Duration.zero;

      final botonesArcade = Column(
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
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onToggleEslogan,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final tp = TextPainter(
                                text: TextSpan(
                                  text: eslogan,
                                  style: estiloEslogan,
                                ),
                                maxLines: 1,
                                ellipsis: '…',
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.ltr,
                              )..layout(maxWidth: constraints.maxWidth);
                              final altoUnaLinea = tp.height;
                              return AnimatedSize(
                                duration: durEslogan,
                                curve: Curves.easeInOutCubic,
                                alignment: Alignment.topCenter,
                                clipBehavior: Clip.hardEdge,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: widget.esloganExpandido
                                        ? double.infinity
                                        : altoUnaLinea,
                                  ),
                                  child: SizedBox(
                                    width: constraints.maxWidth,
                                    child: Text(
                                      eslogan,
                                      textAlign: TextAlign.center,
                                      style: estiloEslogan,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Icon(
                            widget.esloganExpandido
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: AppColors.textoSuave,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
