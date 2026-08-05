import 'dart:math' as math;

/// Culo sucio v2 — mazo de 45 (sin comodines; solo el 1 de oro entre los ases).
/// Se descartan pares del mismo número; quien se queda con el 1 de oro pierde.

enum PaloCuloSucioV2 { oro, copa, espada, basto }

enum FaseCuloSucioV2 { jugando, terminada }

class CartaCuloSucioV2 {
  const CartaCuloSucioV2({required this.numero, required this.palo});

  /// 1–12.
  final int numero;
  final PaloCuloSucioV2 palo;

  bool get esCuloSucio =>
      numero == 1 && palo == PaloCuloSucioV2.oro;

  String get nombrePalo => switch (palo) {
        PaloCuloSucioV2.oro => 'oro',
        PaloCuloSucioV2.copa => 'copa',
        PaloCuloSucioV2.espada => 'espada',
        PaloCuloSucioV2.basto => 'basto',
      };

  String get etiqueta => '$numero de $nombrePalo';

  @override
  bool operator ==(Object other) =>
      other is CartaCuloSucioV2 &&
      other.numero == numero &&
      other.palo == palo;

  @override
  int get hashCode => Object.hash(numero, palo);

  @override
  String toString() => etiqueta;
}

class JugadorCuloSucioV2 {
  JugadorCuloSucioV2(this.nombre);

  final String nombre;
  final List<CartaCuloSucioV2> mano = [];
  /// Pares descartados (cartas sueltas, de a pares).
  final List<CartaCuloSucioV2> descartes = [];

  bool get sinCartas => mano.isEmpty;
}

class PartidaCuloSucioV2 {
  PartidaCuloSucioV2({
    required this.jugadores,
    this.indiceTurno = 0,
    this.fase = FaseCuloSucioV2.jugando,
    this.perdedor,
    this.ganador,
    this.mensajeFin,
    this.contraPc = false,
    this.ultimaRobada,
    this.ultimoPar,
  });

  final List<JugadorCuloSucioV2> jugadores;
  int indiceTurno;
  FaseCuloSucioV2 fase;
  String? perdedor;
  String? ganador;
  String? mensajeFin;
  final bool contraPc;
  CartaCuloSucioV2? ultimaRobada;
  /// Último par descartado (2 cartas), si hubo.
  List<CartaCuloSucioV2>? ultimoPar;

  bool get terminada => fase == FaseCuloSucioV2.terminada;

  JugadorCuloSucioV2 get jugadorActual =>
      jugadores[indiceTurno % jugadores.length];

  JugadorCuloSucioV2 get rivalActual {
    final yo = indiceTurno % jugadores.length;
    for (var i = 1; i < jugadores.length; i++) {
      final j = jugadores[(yo + i) % jugadores.length];
      if (!j.sinCartas) return j;
    }
    return jugadores[(yo + 1) % jugadores.length];
  }
}

/// 12×4 − 1 de copa/espada/basto = 45.
List<CartaCuloSucioV2> crearMazoCuloSucioV2([math.Random? rng]) {
  final mazo = <CartaCuloSucioV2>[
    for (final palo in PaloCuloSucioV2.values)
      for (var n = 1; n <= 12; n++)
        if (!(n == 1 && palo != PaloCuloSucioV2.oro))
          CartaCuloSucioV2(numero: n, palo: palo),
  ];
  assert(mazo.length == 45, 'Mazo v2 debe tener 45 cartas, tiene ${mazo.length}');
  mazo.shuffle(rng ?? math.Random());
  return mazo;
}

/// Descarta de [mano] todos los pares posibles (mismo número, distinto palo).
/// Devuelve las cartas descartadas (ordenadas de a pares).
List<CartaCuloSucioV2> descartarParesDeMano(List<CartaCuloSucioV2> mano) {
  final porNumero = <int, List<CartaCuloSucioV2>>{};
  for (final c in mano) {
    porNumero.putIfAbsent(c.numero, () => []).add(c);
  }
  final sacadas = <CartaCuloSucioV2>[];
  for (final entry in porNumero.entries) {
    final lista = entry.value;
    while (lista.length >= 2) {
      sacadas.add(lista.removeLast());
      sacadas.add(lista.removeLast());
    }
  }
  mano
    ..clear()
    ..addAll([
      for (final lista in porNumero.values) ...lista,
    ]);
  return sacadas;
}

void _chequearFin(PartidaCuloSucioV2 p) {
  if (p.terminada) return;
  final activos = [
    for (final j in p.jugadores)
      if (!j.sinCartas) j,
  ];
  if (activos.length > 1) return;

  p.fase = FaseCuloSucioV2.terminada;
  if (activos.isEmpty) {
    p.mensajeFin = 'Empate raro: nadie tiene cartas.';
    return;
  }
  final perdedor = activos.first;
  p.perdedor = perdedor.nombre;
  final otros = [
    for (final j in p.jugadores)
      if (j.nombre != p.perdedor) j.nombre,
  ];
  p.ganador = otros.isEmpty ? null : otros.first;
  p.mensajeFin =
      '¡${p.perdedor} se quedó con el culo sucio (1 de oro)!';
}

void _avanzarTurno(PartidaCuloSucioV2 p) {
  if (p.terminada) return;
  final n = p.jugadores.length;
  for (var i = 0; i < n; i++) {
    p.indiceTurno = (p.indiceTurno + 1) % n;
    if (!p.jugadorActual.sinCartas && !p.rivalActual.sinCartas) {
      return;
    }
    // Si el actual tiene cartas pero el “rival” no, igual hay fin.
    if (!p.jugadorActual.sinCartas) {
      final activos = p.jugadores.where((j) => !j.sinCartas).length;
      if (activos <= 1) {
        _chequearFin(p);
        return;
      }
    }
  }
  _chequearFin(p);
}

PartidaCuloSucioV2 nuevaPartidaCuloSucioV2({
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
  final jugadores = [
    for (final n in lista.take(2)) JugadorCuloSucioV2(n),
  ];
  final mazo = crearMazoCuloSucioV2(rng);
  var i = 0;
  while (mazo.isNotEmpty) {
    jugadores[i % jugadores.length].mano.add(mazo.removeLast());
    i++;
  }
  for (final j in jugadores) {
    j.descartes.addAll(descartarParesDeMano(j.mano));
  }
  final p = PartidaCuloSucioV2(
    jugadores: jugadores,
    contraPc: contraPc,
  );
  // Empieza el que tiene más cartas (o el índice 0 si empatan).
  var maxMano = -1;
  var idxInicio = 0;
  for (var k = 0; k < jugadores.length; k++) {
    if (jugadores[k].mano.length > maxMano) {
      maxMano = jugadores[k].mano.length;
      idxInicio = k;
    }
  }
  p.indiceTurno = idxInicio;
  _chequearFin(p);
  return p;
}

/// [hacia] roba la carta en [indiceEnManoDe] de [de].
String? robarCartaCuloSucioV2(
  PartidaCuloSucioV2 p, {
  required JugadorCuloSucioV2 de,
  required int indiceEnManoDe,
  required JugadorCuloSucioV2 hacia,
}) {
  if (p.terminada) return 'La partida ya terminó.';
  if (hacia != p.jugadorActual) return 'No es el turno de ${hacia.nombre}.';
  if (de.sinCartas) return '${de.nombre} no tiene cartas.';
  if (indiceEnManoDe < 0 || indiceEnManoDe >= de.mano.length) {
    return 'Carta inválida.';
  }
  if (identical(de, hacia)) return 'No podés robarte a vos mismo.';

  final carta = de.mano.removeAt(indiceEnManoDe);
  hacia.mano.add(carta);
  p.ultimaRobada = carta;
  p.ultimoPar = null;

  // ¿Forma par con alguna otra del mismo número?
  final mismoNumero = [
    for (var i = 0; i < hacia.mano.length; i++)
      if (hacia.mano[i].numero == carta.numero) i,
  ];
  if (mismoNumero.length >= 2) {
    // Empareja la robada con otra (no la misma instancia).
    final idxRobada = hacia.mano.indexOf(carta);
    final idxPar = mismoNumero.firstWhere(
      (i) => i != idxRobada,
      orElse: () => -1,
    );
    if (idxPar >= 0) {
      final a = idxRobada > idxPar ? idxRobada : idxPar;
      final b = idxRobada > idxPar ? idxPar : idxRobada;
      final c1 = hacia.mano.removeAt(a);
      final c2 = hacia.mano.removeAt(b);
      hacia.descartes.addAll([c1, c2]);
      p.ultimoPar = [c1, c2];
    }
  }

  _chequearFin(p);
  if (!p.terminada) {
    _avanzarTurno(p);
    _chequearFin(p);
  }
  return null;
}

/// Jugada simple de PC: roba un índice al azar de la mano del rival.
void jugarTurnoPcCuloSucioV2(PartidaCuloSucioV2 p, [math.Random? rng]) {
  if (p.terminada || !p.contraPc) return;
  if (p.jugadorActual.nombre != 'PC') return;
  final de = p.rivalActual;
  if (de.sinCartas) {
    _chequearFin(p);
    return;
  }
  final r = rng ?? math.Random();
  final idx = r.nextInt(de.mano.length);
  robarCartaCuloSucioV2(
    p,
    de: de,
    indiceEnManoDe: idx,
    hacia: p.jugadorActual,
  );
}
