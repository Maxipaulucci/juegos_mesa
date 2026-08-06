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
  }) : historial = historial ?? [];

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

  bool get terminada => fase == FaseCuloSucio.terminada;

  String get jugadorActual =>
      nombres.isEmpty ? '' : nombres[indiceTurno % nombres.length];

  int get cartasRestantes => mazo.length;
}

/// Una carta sacada por un jugador en un turno.
class JugadaHistorialCuloSucio {
  const JugadaHistorialCuloSucio({
    required this.turno,
    required this.jugador,
    required this.carta,
  });

  final int turno;
  final String jugador;
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
    nombres: contraPc ? lista.take(2).toList() : lista,
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
      for (final n in p.nombres)
        if (n != p.perdedor) n,
    ];
    p.ganador = otros.isEmpty ? null : otros.first;
    p.mensajeFin =
        '¡${p.perdedor} sacó el 1 de oro! Es el culo sucio.';
    return null;
  }

  p.indiceTurno = (p.indiceTurno + 1) % p.nombres.length;
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

