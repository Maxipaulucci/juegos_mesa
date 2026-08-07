import 'dart:math' as math;

/// Culo sucio v1 — mazo español (48, o 50 con comodines).
/// En cada turno se saca una carta; quien saque el 1 de oro pierde.

enum PaloCuloSucio { oro, copa, espada, basto }

enum FaseCuloSucio { jugando, terminada }

class CartaCuloSucio {
  const CartaCuloSucio({
    required this.numero,
    this.palo,
    this.esComodin = false,
  });

  /// 1–12; null si es comodín.
  final int? numero;
  final PaloCuloSucio? palo;
  final bool esComodin;

  bool get esCuloSucio =>
      !esComodin && numero == 1 && palo == PaloCuloSucio.oro;

  String get nombrePalo => switch (palo) {
        PaloCuloSucio.oro => 'oro',
        PaloCuloSucio.copa => 'copa',
        PaloCuloSucio.espada => 'espada',
        PaloCuloSucio.basto => 'basto',
        null => '',
      };

  String get etiqueta {
    if (esComodin) return 'Comodín';
    return '$numero de $nombrePalo';
  }

  @override
  bool operator ==(Object other) =>
      other is CartaCuloSucio &&
      other.numero == numero &&
      other.palo == palo &&
      other.esComodin == esComodin;

  @override
  int get hashCode => Object.hash(numero, palo, esComodin);

  @override
  String toString() => etiqueta;
}

class PartidaCuloSucio {
  PartidaCuloSucio({
    required this.nombres,
    required this.mazo,
    this.indiceTurno = 0,
    this.fase = FaseCuloSucio.jugando,
    this.ultimaCarta,
    this.cartasSacadas = 0,
    this.perdedor,
    this.ganador,
    this.mensajeFin,
    this.contraPc = false,
    List<JugadaHistorialCuloSucio>? historial,
    List<bool>? rendidos,
  })  : historial = historial ?? [],
        rendidos = List<bool>.from(
          rendidos ?? List.filled(nombres.length, false),
        );

  final List<String> nombres;
  final List<CartaCuloSucio> mazo;
  int indiceTurno;
  FaseCuloSucio fase;
  CartaCuloSucio? ultimaCarta;
  int cartasSacadas;
  String? perdedor;
  String? ganador;
  String? mensajeFin;
  final bool contraPc;
  final List<JugadaHistorialCuloSucio> historial;
  /// Paralelo a [nombres]: true si ese jugador se rindió.
  final List<bool> rendidos;

  bool get terminada => fase == FaseCuloSucio.terminada;

  String get jugadorActual =>
      nombres.isEmpty ? '' : nombres[indiceTurno % nombres.length];

  int get cartasRestantes => mazo.length;

  void asegurarRendidos() {
    while (rendidos.length < nombres.length) {
      rendidos.add(false);
    }
    while (rendidos.length > nombres.length) {
      rendidos.removeLast();
    }
  }

  bool estaRendido(int index) {
    asegurarRendidos();
    if (index < 0 || index >= rendidos.length) return false;
    return rendidos[index];
  }

  List<String> get nombresActivos {
    asegurarRendidos();
    return [
      for (var i = 0; i < nombres.length; i++)
        if (!rendidos[i]) nombres[i],
    ];
  }
}

/// Una carta sacada por un jugador en un turno.
class JugadaHistorialCuloSucio {
  JugadaHistorialCuloSucio({
    required this.turno,
    required this.jugador,
    required this.carta,
  });

  final int turno;
  String jugador;
  final CartaCuloSucio carta;
}

/// 12×4 = 48; con [incluirComodines] suma 2 (50).
List<CartaCuloSucio> crearMazoCuloSucio({
  math.Random? rng,
  bool incluirComodines = false,
}) {
  final r = rng ?? math.Random();
  final mazo = <CartaCuloSucio>[
    for (final palo in PaloCuloSucio.values)
      for (var n = 1; n <= 12; n++)
        CartaCuloSucio(numero: n, palo: palo),
    if (incluirComodines) ...[
      // Sin const: dos instancias distintas para el ReorderableListView.
      CartaCuloSucio(numero: null, palo: null, esComodin: true),
      CartaCuloSucio(numero: null, palo: null, esComodin: true),
    ],
  ];
  // Mezclar y ubicar el 1 de oro en un índice al azar del mazo.
  final idxCulo = mazo.indexWhere((c) => c.esCuloSucio);
  assert(idxCulo >= 0, 'El mazo debe incluir el 1 de oro');
  final culoSucio = mazo.removeAt(idxCulo);
  mazo.shuffle(r);
  mazo.insert(r.nextInt(mazo.length + 1), culoSucio);
  return mazo;
}

PartidaCuloSucio nuevaPartidaCuloSucio({
  required List<String> nombres,
  bool contraPc = false,
  bool incluirComodines = false,
  math.Random? rng,
}) {
  final lista = nombres.isEmpty
      ? <String>['Jugador 1', 'Jugador 2']
      : List<String>.from(nombres);
  while (lista.length < 2) {
    lista.add('Jugador ${lista.length + 1}');
  }
  return PartidaCuloSucio(
    nombres: lista,
    mazo: crearMazoCuloSucio(
      rng: rng,
      incluirComodines: incluirComodines,
    ),
    contraPc: contraPc,
  );
}

/// Saca la carta de arriba del mazo. Devuelve error o null si ok.
String? sacarCartaCuloSucio(PartidaCuloSucio p) {
  if (p.terminada) return 'La partida ya terminó.';
  p.asegurarRendidos();
  if (p.estaRendido(p.indiceTurno % p.nombres.length)) {
    _avanzarTurnoSaltandoRendidos(p);
    return 'Ese jugador ya se rindió.';
  }
  if (p.mazo.isEmpty) {
    p.fase = FaseCuloSucio.terminada;
    p.mensajeFin = 'Se acabó el mazo sin salir el 1 de oro. Empate.';
    return null;
  }

  final carta = p.mazo.removeLast();
  final quien = p.jugadorActual;
  p.ultimaCarta = carta;
  p.cartasSacadas++;
  p.historial.add(
    JugadaHistorialCuloSucio(
      turno: p.cartasSacadas,
      jugador: quien,
      carta: carta,
    ),
  );

  if (carta.esCuloSucio) {
    p.fase = FaseCuloSucio.terminada;
    p.perdedor = quien;
    final otros = [
      for (var i = 0; i < p.nombres.length; i++)
        if (p.nombres[i] != p.perdedor && !p.rendidos[i]) p.nombres[i],
    ];
    p.ganador = otros.isEmpty ? null : otros.first;
    p.mensajeFin =
        '¡${p.perdedor} sacó el 1 de oro! Es el culo sucio.';
    return null;
  }

  _avanzarTurnoSaltandoRendidos(p);
  return null;
}

void _avanzarTurnoSaltandoRendidos(PartidaCuloSucio p) {
  final n = p.nombres.length;
  if (n == 0) return;
  p.asegurarRendidos();
  for (var i = 0; i < n; i++) {
    p.indiceTurno = (p.indiceTurno + 1) % n;
    if (!p.rendidos[p.indiceTurno]) return;
  }
}

/// Marca [nombre] como rendido. Si queda uno en pie, gana por abandono.
String? rendirseCuloSucio(PartidaCuloSucio p, String nombre) {
  if (p.terminada) return null;
  p.asegurarRendidos();
  final idx = p.nombres.indexWhere((n) => n == nombre);
  if (idx < 0 || p.rendidos[idx]) return null;

  p.rendidos[idx] = true;

  final activos = p.nombresActivos;
  if (activos.length <= 1) {
    p.fase = FaseCuloSucio.terminada;
    if (activos.isEmpty) {
      p.ganador = null;
      p.perdedor = nombre;
      p.mensajeFin = '$nombre se rindió.';
      return null;
    }
    final ganador = activos.first;
    p.ganador = ganador;
    p.perdedor = nombre;
    p.mensajeFin = '$nombre se rindió. ¡$ganador gana por abandono!';
    return ganador;
  }

  if (p.indiceTurno % p.nombres.length == idx) {
    _avanzarTurnoSaltandoRendidos(p);
  }
  return null;
}

/// Próxima carta a sacar (arriba del mazo), o null si no queda ninguna.
CartaCuloSucio? proximaCartaCuloSucio(PartidaCuloSucio p) =>
    p.mazo.isEmpty ? null : p.mazo.last;

/// [ordenDesdeProxima]: índice 0 = próxima a salir.
void forzarMazoCuloSucio(
  PartidaCuloSucio p,
  List<CartaCuloSucio> ordenDesdeProxima,
) {
  p.mazo
    ..clear()
    ..addAll(ordenDesdeProxima.reversed);
}

/// Orden de salida actual: índice 0 = próxima.
List<CartaCuloSucio> ordenSalidaMazoCuloSucio(PartidaCuloSucio p) =>
    p.mazo.reversed.toList();

