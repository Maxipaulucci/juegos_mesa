import 'dart:math' as math;

/// Guerra de cartas — mazo inglés de 52 (sin comodines).
/// AS alto, 2 bajo. Gana quien se queda con todas las cartas.

enum PaloGuerra { corazones, diamantes, treboles, picas }

enum FaseGuerra { jugando, terminada }

class CartaGuerra {
  const CartaGuerra({required this.valor, required this.palo});

  /// 1 = AS (más alto), 2..10, 11 = J, 12 = Q, 13 = K.
  final int valor;
  final PaloGuerra palo;

  /// Orden de comparación: 2 < … < 10 < J < Q < K < A.
  int get rango => valor == 1 ? 14 : valor;

  String get etiqueta {
    final n = switch (valor) {
      1 => 'A',
      11 => 'J',
      12 => 'Q',
      13 => 'K',
      _ => '$valor',
    };
    final p = switch (palo) {
      PaloGuerra.corazones => '♥',
      PaloGuerra.diamantes => '♦',
      PaloGuerra.treboles => '♣',
      PaloGuerra.picas => '♠',
    };
    return '$n$p';
  }

  String get nombrePalo => switch (palo) {
        PaloGuerra.corazones => 'corazones',
        PaloGuerra.diamantes => 'diamantes',
        PaloGuerra.treboles => 'tréboles',
        PaloGuerra.picas => 'picas',
      };

  bool get esRoja =>
      palo == PaloGuerra.corazones || palo == PaloGuerra.diamantes;

  @override
  bool operator ==(Object other) =>
      other is CartaGuerra && other.valor == valor && other.palo == palo;

  @override
  int get hashCode => Object.hash(valor, palo);

  @override
  String toString() => etiqueta;
}

class JugadorGuerra {
  JugadorGuerra(this.nombre);

  String nombre;
  /// Pila boca abajo (próxima a jugar = última).
  final List<CartaGuerra> mazo = [];
  /// Cartas ganadas en la ronda (pozo).
  final List<CartaGuerra> pozo = [];
  bool rendido = false;

  int get totalCartas => mazo.length + pozo.length;
  bool get sinCartas => totalCartas == 0;
}

class ResultadoRondaGuerra {
  ResultadoRondaGuerra({
    required this.cartasJugadas,
    required this.pozoMesa,
    required this.ganadorNombre,
    required this.huboGuerra,
    this.mensaje,
  });

  /// Última carta visible de cada jugador que participó (nombre → carta).
  final Map<String, CartaGuerra> cartasJugadas;
  final List<CartaGuerra> pozoMesa;
  final String ganadorNombre;
  final bool huboGuerra;
  final String? mensaje;
}

class PartidaGuerra {
  PartidaGuerra({
    required this.jugadores,
    this.contraPc = false,
    this.fase = FaseGuerra.jugando,
    this.ganador,
    this.mensajeFin,
    this.ultimaRonda,
  });

  final List<JugadorGuerra> jugadores;
  final bool contraPc;
  FaseGuerra fase;
  String? ganador;
  String? mensajeFin;
  ResultadoRondaGuerra? ultimaRonda;

  bool get terminada => fase == FaseGuerra.terminada;

  List<JugadorGuerra> get jugadoresActivos => [
        for (final j in jugadores)
          if (!j.rendido) j,
      ];

  List<JugadorGuerra> get conCartas => [
        for (final j in jugadoresActivos)
          if (!j.sinCartas) j,
      ];
}

List<CartaGuerra> crearMazoGuerra([math.Random? rng]) {
  final mazo = <CartaGuerra>[
    for (final palo in PaloGuerra.values)
      for (var v = 1; v <= 13; v++) CartaGuerra(valor: v, palo: palo),
  ];
  assert(mazo.length == 52);
  mazo.shuffle(rng ?? math.Random());
  return mazo;
}

PartidaGuerra nuevaPartidaGuerra({
  required List<String> nombres,
  bool contraPc = false,
  math.Random? rng,
}) {
  final lista = nombres.isEmpty
      ? <String>['Jugador 1', 'Jugador 2']
      : List<String>.from(nombres.take(4));
  while (lista.length < 2) {
    lista.add('Jugador ${lista.length + 1}');
  }
  final jugadores = [for (final n in lista) JugadorGuerra(n)];
  final mazo = crearMazoGuerra(rng);
  final porJugador = 52 ~/ jugadores.length;
  for (final j in jugadores) {
    for (var k = 0; k < porJugador; k++) {
      j.mazo.add(mazo.removeLast());
    }
  }
  return PartidaGuerra(jugadores: jugadores, contraPc: contraPc);
}

void _asegurarMazo(JugadorGuerra j, math.Random r) {
  if (j.mazo.isNotEmpty) return;
  if (j.pozo.isEmpty) return;
  j.mazo.addAll(j.pozo);
  j.pozo.clear();
  j.mazo.shuffle(r);
}

bool _puedeSacar(JugadorGuerra j, math.Random r) {
  _asegurarMazo(j, r);
  return j.mazo.isNotEmpty;
}

CartaGuerra? _sacar(JugadorGuerra j, math.Random r) {
  if (!_puedeSacar(j, r)) return null;
  return j.mazo.removeLast();
}

void _chequearFin(PartidaGuerra p) {
  final vivos = p.conCartas;
  if (vivos.length <= 1) {
    p.fase = FaseGuerra.terminada;
    if (vivos.isEmpty) {
      p.ganador = null;
      p.mensajeFin = 'Nadie quedó con cartas.';
    } else {
      p.ganador = vivos.first.nombre;
      p.mensajeFin =
          '¡${p.ganador} se quedó con todas las cartas!';
    }
  }
}

/// Una ronda completa (incluye guerras por empate).
String? jugarRondaGuerra(PartidaGuerra p, [math.Random? rng]) {
  if (p.terminada) return 'La partida ya terminó.';
  final r = rng ?? math.Random();
  final participantes = p.conCartas;
  if (participantes.length < 2) {
    _chequearFin(p);
    return null;
  }

  final pot = <CartaGuerra>[];
  final visibles = <String, CartaGuerra>{};
  var enGuerra = participantes;
  var huboGuerra = false;
  String? mensaje;

  while (true) {
    final jugadas = <({JugadorGuerra j, CartaGuerra c})>[];
    for (final j in enGuerra) {
      final c = _sacar(j, r);
      if (c == null) continue;
      jugadas.add((j: j, c: c));
      pot.add(c);
      visibles[j.nombre] = c;
    }

    if (jugadas.isEmpty) {
      _chequearFin(p);
      return 'No había cartas para jugar.';
    }

    var maxR = -1;
    for (final x in jugadas) {
      if (x.c.rango > maxR) maxR = x.c.rango;
    }
    final empatados = [
      for (final x in jugadas)
        if (x.c.rango == maxR) x.j,
    ];

    if (empatados.length == 1) {
      final ganador = empatados.first;
      ganador.pozo.addAll(pot);
      p.ultimaRonda = ResultadoRondaGuerra(
        cartasJugadas: Map.of(visibles),
        pozoMesa: List.of(pot),
        ganadorNombre: ganador.nombre,
        huboGuerra: huboGuerra,
        mensaje: mensaje,
      );
      _chequearFin(p);
      return null;
    }

    // Empate: guerra. Solo siguen quienes puedan sacar otra carta.
    huboGuerra = true;
    final pueden = <JugadorGuerra>[];
    for (final j in empatados) {
      if (_puedeSacar(j, r)) pueden.add(j);
    }

    if (pueden.length == 1) {
      mensaje =
          'Empate: ${pueden.first.nombre} gana porque el rival no tiene más cartas';
      pueden.first.pozo.addAll(pot);
      p.ultimaRonda = ResultadoRondaGuerra(
        cartasJugadas: Map.of(visibles),
        pozoMesa: List.of(pot),
        ganadorNombre: pueden.first.nombre,
        huboGuerra: true,
        mensaje: mensaje,
      );
      _chequearFin(p);
      return null;
    }

    if (pueden.isEmpty) {
      // Nadie puede seguir: se lleva el primero de los empatados.
      final ganador = empatados.first;
      mensaje = 'Empate sin cartas extra: gana ${ganador.nombre}';
      ganador.pozo.addAll(pot);
      p.ultimaRonda = ResultadoRondaGuerra(
        cartasJugadas: Map.of(visibles),
        pozoMesa: List.of(pot),
        ganadorNombre: ganador.nombre,
        huboGuerra: true,
        mensaje: mensaje,
      );
      _chequearFin(p);
      return null;
    }

    enGuerra = pueden;
  }
}

/// Marca rendición. Si queda uno con cartas / activo, gana.
String? rendirseGuerra(PartidaGuerra p, String nombre) {
  if (p.terminada) return null;
  JugadorGuerra? j;
  for (final x in p.jugadores) {
    if (x.nombre == nombre && !x.rendido) {
      j = x;
      break;
    }
  }
  if (j == null) return null;
  j.rendido = true;
  j.mazo.clear();
  j.pozo.clear();

  final activos = p.jugadoresActivos;
  if (activos.length <= 1) {
    p.fase = FaseGuerra.terminada;
    if (activos.isEmpty) {
      p.ganador = null;
      p.mensajeFin = '$nombre se rindió.';
    } else {
      p.ganador = activos.first.nombre;
      p.mensajeFin = '$nombre se rindió. ¡${p.ganador} gana!';
    }
    return p.ganador;
  }

  final con = p.conCartas;
  if (con.length <= 1) {
    p.fase = FaseGuerra.terminada;
    if (con.isEmpty) {
      p.ganador = null;
      p.mensajeFin = '$nombre se rindió.';
    } else {
      p.ganador = con.first.nombre;
      p.mensajeFin = '$nombre se rindió. ¡${p.ganador} gana!';
    }
    return p.ganador;
  }
  return null;
}
