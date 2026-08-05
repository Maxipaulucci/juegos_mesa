import 'dart:math' as math;

/// Culo sucio v1 — mazo español de 50 (48 + 2 comodines).
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
  });

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

  bool get terminada => fase == FaseCuloSucio.terminada;

  String get jugadorActual =>
      nombres.isEmpty ? '' : nombres[indiceTurno % nombres.length];

  int get cartasRestantes => mazo.length;
}

/// 12×4 + 2 comodines = 50.
List<CartaCuloSucio> crearMazoCuloSucio([math.Random? rng]) {
  final mazo = <CartaCuloSucio>[
    for (final palo in PaloCuloSucio.values)
      for (var n = 1; n <= 12; n++)
        CartaCuloSucio(numero: n, palo: palo),
    const CartaCuloSucio(numero: null, palo: null, esComodin: true),
    const CartaCuloSucio(numero: null, palo: null, esComodin: true),
  ];
  mazo.shuffle(rng ?? math.Random());
  return mazo;
}

PartidaCuloSucio nuevaPartidaCuloSucio({
  required List<String> nombres,
  bool contraPc = false,
  math.Random? rng,
}) {
  final lista = nombres.isEmpty
      ? <String>['Jugador 1', 'Jugador 2']
      : List<String>.from(nombres);
  while (lista.length < 2) {
    lista.add('Jugador ${lista.length + 1}');
  }
  return PartidaCuloSucio(
    nombres: lista.take(2).toList(),
    mazo: crearMazoCuloSucio(rng),
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
  p.ultimaCarta = carta;
  p.cartasSacadas++;

  if (carta.esCuloSucio) {
    p.fase = FaseCuloSucio.terminada;
    p.perdedor = p.jugadorActual;
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
