import 'dart:math' as math;

import 'package:app_juegos_mesa/guerraDeCartas/opciones_guerra.dart';

/// Guerra de cartas — mazo inglés de 52 (sin comodines).
/// AS alto, 2 bajo. Gana quien se queda con todas las cartas.

const int vidasInicialesGuerra = 15;

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
  JugadorGuerra(this.nombre, {this.vidas = vidasInicialesGuerra});

  String nombre;
  /// Pila boca abajo (próxima a jugar = última).
  final List<CartaGuerra> mazo = [];
  /// Cartas ganadas en la ronda (pozo).
  final List<CartaGuerra> pozo = [];
  /// Vidas: al vaciarse el mazo se resta 1.
  int vidas;
  bool rendido = false;

  int get totalCartas => mazo.length + pozo.length;
  bool get sinCartas => totalCartas == 0;
  bool get sinVidas => vidas <= 0;
}

class ResultadoRondaGuerra {
  ResultadoRondaGuerra({
    required this.cartasJugadas,
    required this.pozoMesa,
    required this.ganadorNombre,
    required this.huboGuerra,
    this.mensaje,
    this.mezclaronPozo = const [],
  });

  /// Última carta visible de cada jugador que participó (nombre → carta).
  final Map<String, CartaGuerra> cartasJugadas;
  final List<CartaGuerra> pozoMesa;
  final String ganadorNombre;
  final bool huboGuerra;
  final String? mensaje;
  /// Jugadores que, al quedarse sin mazo, mezclaron su pozo para seguir.
  final List<String> mezclaronPozo;
}

class PartidaGuerra {
  PartidaGuerra({
    required this.jugadores,
    this.contraPc = false,
    this.opciones = const OpcionesGuerra(),
    this.fase = FaseGuerra.jugando,
    this.ganador,
    this.mensajeFin,
    this.ultimaRonda,
    List<ResultadoRondaGuerra>? historialRondas,
  }) : historialRondas = historialRondas ?? <ResultadoRondaGuerra>[];

  final List<JugadorGuerra> jugadores;
  final bool contraPc;
  OpcionesGuerra opciones;
  FaseGuerra fase;
  String? ganador;
  String? mensajeFin;
  ResultadoRondaGuerra? ultimaRonda;
  /// Todas las tiradas de la partida (para el historial de victoria).
  final List<ResultadoRondaGuerra> historialRondas;

  bool get terminada => fase == FaseGuerra.terminada;
  bool get vidasActivas => opciones.vidasActivas;

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
  OpcionesGuerra opciones = const OpcionesGuerra(),
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
  return PartidaGuerra(
    jugadores: jugadores,
    contraPc: contraPc,
    opciones: opciones,
  );
}

/// Si el mazo está vacío y hay pozo: mezcla el pozo y recién ahí lo pone
/// como mazo jugable. Devuelve true si recicló.
bool _mezclarPozoEnMazo(JugadorGuerra j, math.Random r) {
  if (j.mazo.isNotEmpty) return false;
  if (j.pozo.isEmpty) return false;
  final cartas = List<CartaGuerra>.from(j.pozo);
  j.pozo.clear();
  cartas.shuffle(r);
  j.mazo.addAll(cartas);
  return true;
}

/// Mezcla pozos de quienes ya no tienen mazo (antes de poder tirar).
List<String> _reciclarPozosSinMazo(Iterable<JugadorGuerra> jugadores, math.Random r) {
  final mezclaron = <String>[];
  for (final j in jugadores) {
    if (_mezclarPozoEnMazo(j, r)) mezclaron.add(j.nombre);
  }
  return mezclaron;
}

bool _puedeSacar(
  PartidaGuerra p,
  JugadorGuerra j,
  math.Random r,
  List<String> mezclaron,
) {
  if (j.rendido) return false;
  if (p.vidasActivas && j.sinVidas) return false;
  if (_mezclarPozoEnMazo(j, r) && !mezclaron.contains(j.nombre)) {
    mezclaron.add(j.nombre);
  }
  return j.mazo.isNotEmpty;
}

CartaGuerra? _sacar(
  PartidaGuerra p,
  JugadorGuerra j,
  math.Random r,
  List<String> mezclaron,
) {
  if (!_puedeSacar(p, j, r, mezclaron)) return null;
  final c = j.mazo.removeLast();
  if (j.mazo.isEmpty && p.vidasActivas) _restarVidaPorMazoVacio(j);
  return c;
}

void _restarVidaPorMazoVacio(JugadorGuerra j) {
  if (j.rendido || j.sinVidas) return;
  j.vidas -= 1;
  if (j.sinVidas) j.rendido = true;
}

/// Sin cartas = fuera, aunque todavía tenga vidas.
void _aplicarDerrotaPorSinCartas(PartidaGuerra p) {
  for (final j in p.jugadores) {
    if (j.rendido || !j.sinCartas) continue;
    j.rendido = true;
  }
}

void _aplicarDerrotaPorVidas(PartidaGuerra p) {
  if (!p.vidasActivas) return;
  for (final j in p.jugadores) {
    if (j.rendido || !j.sinVidas) continue;
    j.rendido = true;
    j.mazo.clear();
    j.pozo.clear();
  }
}

void _chequearFin(PartidaGuerra p) {
  if (p.terminada) return;
  _aplicarDerrotaPorSinCartas(p);
  _aplicarDerrotaPorVidas(p);

  final vivos = [
    for (final j in p.jugadoresActivos)
      if (!j.sinCartas && (!p.vidasActivas || !j.sinVidas)) j,
  ];
  if (vivos.length <= 1) {
    p.fase = FaseGuerra.terminada;
    if (vivos.isEmpty) {
      p.ganador = null;
      p.mensajeFin = 'Nadie quedó en juego.';
    } else {
      p.ganador = vivos.first.nombre;
      final perdedores = [
        for (final j in p.jugadores)
          if (j.nombre != p.ganador) j,
      ];
      final porVidas = p.vidasActivas && perdedores.any((j) => j.sinVidas);
      final porCartas = perdedores.any((j) => j.sinCartas);
      if (porCartas && !porVidas) {
        p.mensajeFin =
            '¡${p.ganador} gana! El rival se quedó sin cartas.';
      } else if (porVidas && !porCartas) {
        p.mensajeFin = '¡${p.ganador} gana!';
      } else {
        p.mensajeFin =
            '¡${p.ganador} se quedó con todas las cartas!';
      }
    }
  }
}

/// Fuerza el chequeo de fin (p. ej. si alguien ya no tiene cartas).
void chequearFinGuerra(PartidaGuerra p) => _chequearFin(p);

void _agregarAlPozoGanador(
  JugadorGuerra ganador,
  List<CartaGuerra> pot,
  Map<String, CartaGuerra> visibles,
) {
  if (pot.isEmpty) return;
  final ganadora = visibles[ganador.nombre];
  if (ganadora == null || pot.length == 1) {
    ganador.pozo.addAll(pot);
    return;
  }
  // Deja la carta que ganó justo debajo de la cima, para el abanico del pozo.
  final resto = <CartaGuerra>[
    for (final c in pot)
      if (c != ganadora) c,
  ];
  if (resto.isEmpty) {
    ganador.pozo.add(ganadora);
    return;
  }
  final cima = resto.removeLast();
  ganador.pozo
    ..addAll(resto)
    ..add(ganadora)
    ..add(cima);
}

void _cerrarRonda({
  required PartidaGuerra p,
  required math.Random r,
  required Map<String, CartaGuerra> visibles,
  required List<CartaGuerra> pot,
  required JugadorGuerra ganador,
  required bool huboGuerra,
  required String? mensaje,
  required List<String> mezclaron,
}) {
  _agregarAlPozoGanador(ganador, pot, visibles);
  // Quienes se quedaron sin mazo mezclan el pozo antes de la próxima tirada.
  mezclaron.addAll(
    _reciclarPozosSinMazo(p.jugadoresActivos, r)
        .where((n) => !mezclaron.contains(n)),
  );
  p.ultimaRonda = ResultadoRondaGuerra(
    cartasJugadas: Map.of(visibles),
    pozoMesa: List.of(pot),
    ganadorNombre: ganador.nombre,
    huboGuerra: huboGuerra,
    mensaje: mensaje,
    mezclaronPozo: List.of(mezclaron),
  );
  p.historialRondas.add(p.ultimaRonda!);
  _chequearFin(p);
}

/// Una ronda completa (incluye guerras por empate).
String? jugarRondaGuerra(PartidaGuerra p, [math.Random? rng]) {
  if (p.terminada) return 'La partida ya terminó.';
  final r = rng ?? math.Random();
  final mezclaron = <String>[];

  // Antes de tirar: si alguien no tiene mazo, mezcla su pozo y recién ahí juega.
  mezclaron.addAll(_reciclarPozosSinMazo(p.jugadoresActivos, r));
  _chequearFin(p);
  if (p.terminada) return null;

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
      final c = _sacar(p, j, r, mezclaron);
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
      _cerrarRonda(
        p: p,
        r: r,
        visibles: visibles,
        pot: pot,
        ganador: empatados.first,
        huboGuerra: huboGuerra,
        mensaje: mensaje,
        mezclaron: mezclaron,
      );
      return null;
    }

    // Empate: guerra. Solo siguen quienes puedan sacar otra carta.
    huboGuerra = true;
    final pueden = <JugadorGuerra>[];
    for (final j in empatados) {
      if (_puedeSacar(p, j, r, mezclaron)) pueden.add(j);
    }

    if (pueden.length == 1) {
      mensaje =
          'Empate: ${pueden.first.nombre} gana porque el rival no tiene más cartas';
      _cerrarRonda(
        p: p,
        r: r,
        visibles: visibles,
        pot: pot,
        ganador: pueden.first,
        huboGuerra: true,
        mensaje: mensaje,
        mezclaron: mezclaron,
      );
      return null;
    }

    if (pueden.isEmpty) {
      // Nadie puede seguir: se lleva el primero de los empatados.
      final ganador = empatados.first;
      mensaje = 'Empate sin cartas extra: gana ${ganador.nombre}';
      _cerrarRonda(
        p: p,
        r: r,
        visibles: visibles,
        pot: pot,
        ganador: ganador,
        huboGuerra: true,
        mensaje: mensaje,
        mezclaron: mezclaron,
      );
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
