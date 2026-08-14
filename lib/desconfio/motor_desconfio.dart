import 'dart:math' as math;

/// Desconfío — mazo español de 48 (1–12 × 4 palos).
/// Se reparte todo el mazo. Un jugador declara un palo; cada uno tira
/// una carta boca abajo al pozo. Alguien puede decir «desconfío» y se
/// revela la última: si no es del palo, el que tiró se lleva el pozo;
/// si sí lo es, se lo lleva quien desconfió. Gana quien se queda sin cartas.

enum PaloDesconfio { oro, copa, espada, basto }

enum FaseDesconfio {
  /// El jugador de turno elige oro / copa / espada / basto.
  elegirPalo,
  /// Tirar una carta de la mano al pozo (boca abajo).
  jugando,
  /// Tras tirar: otros pueden desconfiar o seguir.
  esperandoReaccion,
  /// Se mostró la carta revelada (UI); luego se reparte el pozo.
  revelando,
  terminada,
}

class CartaDesconfio {
  const CartaDesconfio({required this.numero, required this.palo});

  /// 1–12.
  final int numero;
  final PaloDesconfio palo;

  String get nombrePalo => switch (palo) {
        PaloDesconfio.oro => 'oro',
        PaloDesconfio.copa => 'copa',
        PaloDesconfio.espada => 'espada',
        PaloDesconfio.basto => 'basto',
      };

  String get etiqueta => '$numero de $nombrePalo';

  @override
  bool operator ==(Object other) =>
      other is CartaDesconfio && other.numero == numero && other.palo == palo;

  @override
  int get hashCode => Object.hash(numero, palo);

  @override
  String toString() => etiqueta;
}

class JugadorDesconfio {
  JugadorDesconfio(this.nombre);

  String nombre;
  final List<CartaDesconfio> mano = [];
  bool rendido = false;

  int get cartasEnMano => mano.length;
  bool get sinCartas => mano.isEmpty;
}

class CartaEnPozoDesconfio {
  CartaEnPozoDesconfio({required this.carta, required this.jugador});

  final CartaDesconfio carta;
  final String jugador;
}

class ResultadoDesconfio {
  ResultadoDesconfio({
    required this.desconfiador,
    required this.tirador,
    required this.carta,
    required this.eraDelPalo,
    required this.quienSeLleva,
    required this.cartasLlevadas,
  });

  final String desconfiador;
  final String tirador;
  final CartaDesconfio carta;
  final bool eraDelPalo;
  final String quienSeLleva;
  final int cartasLlevadas;
}

/// Una tirada registrada (carta que jugó alguien al pozo).
class EntradaHistorialDesconfio {
  EntradaHistorialDesconfio({
    required this.jugador,
    required this.carta,
    required this.paloDeclarado,
    this.desconfiador,
    this.eraDelPalo,
    this.quienSeLleva,
    this.cartasLlevadas,
  });

  final String jugador;
  final CartaDesconfio carta;
  final PaloDesconfio paloDeclarado;
  final String? desconfiador;
  final bool? eraDelPalo;
  final String? quienSeLleva;
  final int? cartasLlevadas;

  bool get huboDesconfio => desconfiador != null;

  EntradaHistorialDesconfio conDesconfio({
    required String desconfiador,
    required bool eraDelPalo,
    required String quienSeLleva,
    required int cartasLlevadas,
  }) {
    return EntradaHistorialDesconfio(
      jugador: jugador,
      carta: carta,
      paloDeclarado: paloDeclarado,
      desconfiador: desconfiador,
      eraDelPalo: eraDelPalo,
      quienSeLleva: quienSeLleva,
      cartasLlevadas: cartasLlevadas,
    );
  }
}

class PartidaDesconfio {
  PartidaDesconfio({
    required this.jugadores,
    this.indiceTurno = 0,
    this.fase = FaseDesconfio.elegirPalo,
    this.contraPc = false,
    this.paloDeclarado,
    this.ganador,
    this.mensajeFin,
    this.ultimoMensaje,
    this.ultimoResultado,
    List<EntradaHistorialDesconfio>? historial,
  }) : historial = historial ?? <EntradaHistorialDesconfio>[];

  final List<JugadorDesconfio> jugadores;
  final List<CartaEnPozoDesconfio> pozo = [];
  final List<EntradaHistorialDesconfio> historial;
  int indiceTurno;
  FaseDesconfio fase;
  final bool contraPc;
  PaloDesconfio? paloDeclarado;
  String? ganador;
  String? mensajeFin;
  String? ultimoMensaje;
  ResultadoDesconfio? ultimoResultado;

  bool get terminada => fase == FaseDesconfio.terminada;

  List<JugadorDesconfio> get activos => [
        for (final j in jugadores)
          if (!j.rendido) j,
      ];

  JugadorDesconfio get jugadorActual => jugadores[indiceTurno];

  CartaEnPozoDesconfio? get ultimaDelPozo =>
      pozo.isEmpty ? null : pozo.last;
}

List<CartaDesconfio> crearMazoDesconfio([math.Random? rng]) {
  const numeros = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
  final mazo = <CartaDesconfio>[
    for (final palo in PaloDesconfio.values)
      for (final n in numeros) CartaDesconfio(numero: n, palo: palo),
  ];
  assert(mazo.length == 48);
  mazo.shuffle(rng ?? math.Random());
  return mazo;
}

String nombrePaloDesconfio(PaloDesconfio palo) => switch (palo) {
      PaloDesconfio.oro => 'oro',
      PaloDesconfio.copa => 'copa',
      PaloDesconfio.espada => 'espada',
      PaloDesconfio.basto => 'basto',
    };

PartidaDesconfio nuevaPartidaDesconfio({
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
  final jugadores = [for (final n in lista) JugadorDesconfio(n)];
  final mazo = crearMazoDesconfio(rng);
  // Reparto circular: una carta a cada uno hasta agotar el mazo.
  var i = 0;
  while (mazo.isNotEmpty) {
    jugadores[i % jugadores.length].mano.add(mazo.removeLast());
    i++;
  }
  return PartidaDesconfio(
    jugadores: jugadores,
    contraPc: contraPc,
    fase: FaseDesconfio.elegirPalo,
    ultimoMensaje: '${jugadores.first.nombre} elige el palo de la mesa',
  );
}

void _irATurno(PartidaDesconfio p, int indice) {
  final n = p.jugadores.length;
  var i = indice % n;
  for (var k = 0; k < n; k++) {
    final j = p.jugadores[i];
    if (!j.rendido) {
      p.indiceTurno = i;
      return;
    }
    i = (i + 1) % n;
  }
}

void _siguienteTurno(PartidaDesconfio p) {
  _irATurno(p, p.indiceTurno + 1);
}

void _chequearVictoriaPorManoVacia(PartidaDesconfio p, JugadorDesconfio j) {
  if (j.rendido || !j.sinCartas) return;
  p.fase = FaseDesconfio.terminada;
  p.ganador = j.nombre;
  p.mensajeFin = '¡${j.nombre} se quedó sin cartas!';
  p.ultimoMensaje = p.mensajeFin;
}

/// El jugador de turno declara el palo.
String? elegirPaloDesconfio(PartidaDesconfio p, PaloDesconfio palo) {
  if (p.terminada) return 'La partida ya terminó.';
  if (p.fase != FaseDesconfio.elegirPalo) {
    return 'Ahora no se elige palo.';
  }
  final j = p.jugadorActual;
  if (j.sinCartas) {
    _chequearVictoriaPorManoVacia(p, j);
    return null;
  }
  p.paloDeclarado = palo;
  p.fase = FaseDesconfio.jugando;
  p.ultimoMensaje =
      '${j.nombre} declaró ${nombrePaloDesconfio(palo)}. Tirás una carta boca abajo.';
  p.ultimoResultado = null;
  return null;
}

/// Tira una carta de la mano al pozo (boca abajo).
///
/// Si el jugador se queda sin cartas, gana de inmediato (sin fase de
/// desconfiar / seguir).
String? tirarCartaDesconfio(PartidaDesconfio p, int indiceMano) {
  if (p.terminada) return 'La partida ya terminó.';
  if (p.fase != FaseDesconfio.jugando) {
    return 'No es momento de tirar.';
  }
  if (p.paloDeclarado == null) return 'Falta declarar un palo.';
  final j = p.jugadorActual;
  if (indiceMano < 0 || indiceMano >= j.mano.length) {
    return 'Carta inválida.';
  }
  final carta = j.mano.removeAt(indiceMano);
  p.pozo.add(CartaEnPozoDesconfio(carta: carta, jugador: j.nombre));
  p.historial.add(
    EntradaHistorialDesconfio(
      jugador: j.nombre,
      carta: carta,
      paloDeclarado: p.paloDeclarado!,
    ),
  );
  // Última carta: victoria automática (no hay reacción del rival).
  if (j.sinCartas) {
    _chequearVictoriaPorManoVacia(p, j);
    return null;
  }
  p.fase = FaseDesconfio.esperandoReaccion;
  p.ultimoMensaje =
      '${j.nombre} tiró una carta. ¿Desconfío o tirás?';
  p.ultimoResultado = null;
  return null;
}

/// Nadie desconfía: si el que tiró se quedó sin cartas, gana; si no, sigue el siguiente.
String? seguirTrasTiradaDesconfio(PartidaDesconfio p) {
  if (p.terminada) return 'La partida ya terminó.';
  if (p.fase != FaseDesconfio.esperandoReaccion) {
    return 'No hay tirada pendiente.';
  }
  final tirador = p.ultimaDelPozo?.jugador;
  if (tirador == null) return 'Pozo vacío.';

  JugadorDesconfio? quienTiro;
  for (final j in p.jugadores) {
    if (j.nombre == tirador) {
      quienTiro = j;
      break;
    }
  }
  if (quienTiro != null && quienTiro.sinCartas) {
    _chequearVictoriaPorManoVacia(p, quienTiro);
    return null;
  }

  p.fase = FaseDesconfio.jugando;
  _siguienteTurno(p);
  final next = p.jugadorActual;
  if (next.sinCartas) {
    _chequearVictoriaPorManoVacia(p, next);
    return null;
  }
  p.ultimoMensaje =
      'Sigue ${next.nombre} (palo: ${nombrePaloDesconfio(p.paloDeclarado!)}).';
  return null;
}

/// Alguien desconfía de la última carta del pozo.
String? desconfiarDesconfio(PartidaDesconfio p, String nombreDesconfiador) {
  if (p.terminada) return 'La partida ya terminó.';
  if (p.fase != FaseDesconfio.esperandoReaccion) {
    return 'Solo se puede desconfiar justo después de una tirada.';
  }
  final ultima = p.ultimaDelPozo;
  if (ultima == null) return 'No hay carta para revelar.';
  if (ultima.jugador == nombreDesconfiador) {
    return 'No podés desconfiar de tu propia carta.';
  }

  JugadorDesconfio? desconfiador;
  JugadorDesconfio? tirador;
  for (final j in p.jugadores) {
    if (j.nombre == nombreDesconfiador && !j.rendido) desconfiador = j;
    if (j.nombre == ultima.jugador) tirador = j;
  }
  if (desconfiador == null) return 'Jugador inválido.';
  if (tirador == null) return 'No se encontró al que tiró.';
  // Por si la UI quedó en reacción tras una última carta: no se puede
  // desconfiar de quien ya ganó quedándose sin cartas.
  if (tirador.sinCartas) {
    _chequearVictoriaPorManoVacia(p, tirador);
    return null;
  }

  final palo = p.paloDeclarado!;
  final eraDelPalo = ultima.carta.palo == palo;
  final cartas = p.pozo.length;
  // Quien se equivoca se lleva el pozo; quien acierta abre eligiendo palo.
  final quienSeLleva = eraDelPalo ? desconfiador : tirador;
  final quienAbre = eraDelPalo ? tirador : desconfiador;
  final llevadas = List<CartaEnPozoDesconfio>.of(p.pozo);
  p.pozo.clear();
  for (final c in llevadas) {
    quienSeLleva.mano.add(c.carta);
  }

  p.ultimoResultado = ResultadoDesconfio(
    desconfiador: desconfiador.nombre,
    tirador: tirador.nombre,
    carta: ultima.carta,
    eraDelPalo: eraDelPalo,
    quienSeLleva: quienSeLleva.nombre,
    cartasLlevadas: cartas,
  );
  if (p.historial.isNotEmpty) {
    final last = p.historial.last;
    if (last.jugador == tirador.nombre && last.carta == ultima.carta) {
      p.historial[p.historial.length - 1] = last.conDesconfio(
        desconfiador: desconfiador.nombre,
        eraDelPalo: eraDelPalo,
        quienSeLleva: quienSeLleva.nombre,
        cartasLlevadas: cartas,
      );
    }
  }

  if (eraDelPalo) {
    p.ultimoMensaje =
        '¡Era ${ultima.carta.etiqueta}! ${desconfiador.nombre} se lleva $cartas carta(s). '
        '${quienAbre.nombre} elige el próximo palo.';
  } else {
    p.ultimoMensaje =
        '¡Mentira! Era ${ultima.carta.etiqueta}. ${tirador.nombre} se lleva '
        '$cartas carta(s). ${quienAbre.nombre} elige el próximo palo.';
  }

  // Quien acertó la confrontación abre eligiendo palo.
  final idx = p.jugadores.indexOf(quienAbre);
  _irATurno(p, idx);
  p.paloDeclarado = null;
  p.fase = FaseDesconfio.revelando;
  return null;
}

/// Cierra el cartel de revelación y pasa a elegir palo.
String? continuarTrasRevelacionDesconfio(PartidaDesconfio p) {
  if (p.terminada) return 'La partida ya terminó.';
  if (p.fase != FaseDesconfio.revelando) return null;
  p.fase = FaseDesconfio.elegirPalo;
  p.ultimoMensaje =
      '${p.jugadorActual.nombre} elige el palo de la mesa';
  return null;
}

String? rendirseDesconfio(PartidaDesconfio p, String nombre) {
  if (p.terminada) return null;
  JugadorDesconfio? j;
  for (final x in p.jugadores) {
    if (x.nombre == nombre && !x.rendido) {
      j = x;
      break;
    }
  }
  if (j == null) return null;
  j.rendido = true;
  j.mano.clear();

  final activos = p.activos;
  if (activos.length <= 1) {
    p.fase = FaseDesconfio.terminada;
    if (activos.isEmpty) {
      p.ganador = null;
      p.mensajeFin = '$nombre se rindió.';
    } else {
      p.ganador = activos.first.nombre;
      p.mensajeFin = '$nombre se rindió. ¡${p.ganador} gana!';
    }
    return p.ganador;
  }

  if (p.jugadorActual.rendido) {
    _siguienteTurno(p);
    if (p.fase == FaseDesconfio.esperandoReaccion ||
        p.fase == FaseDesconfio.revelando) {
      p.fase = FaseDesconfio.elegirPalo;
      p.paloDeclarado = null;
    } else if (p.fase == FaseDesconfio.jugando && p.paloDeclarado == null) {
      p.fase = FaseDesconfio.elegirPalo;
    }
  }
  p.ultimoMensaje = '$nombre se rindió.';
  return null;
}
