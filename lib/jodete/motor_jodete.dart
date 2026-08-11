import 'dart:math' as math;

/// Jodete — mazo español de 50 (48 + 2 comodines).

enum PaloJodete { oro, copa, espada, basto }

enum FaseJodete { jugando, terminada }

enum SentidoJodete { horario, antihorario }

class CartaJodete {
  const CartaJodete({
    required this.numero,
    this.palo,
    this.esComodin = false,
    this.id = 0,
  });

  /// 1–12; null si es comodín.
  final int? numero;
  final PaloJodete? palo;
  final bool esComodin;
  /// Distingue los dos comodines (y cartas iguales en igualdad de valor).
  final int id;

  bool get esEspecialInicio {
    if (esComodin) return true;
    final n = numero;
    return n == 2 || n == 10 || n == 11 || n == 12;
  }

  bool get pideElegirPalo => esComodin || numero == 10;

  bool get esDos => !esComodin && numero == 2;

  int get cartasALevantar {
    if (esComodin) return 5;
    if (esDos) return 2;
    return 0;
  }

  bool get saltea => !esComodin && numero == 11;

  bool get invierte => !esComodin && numero == 12;

  String get nombrePalo => switch (palo) {
        PaloJodete.oro => 'oro',
        PaloJodete.copa => 'copa',
        PaloJodete.espada => 'espada',
        PaloJodete.basto => 'basto',
        null => '',
      };

  String get etiqueta {
    if (esComodin) return 'Comodín';
    return '$numero de $nombrePalo';
  }

  @override
  bool operator ==(Object other) =>
      other is CartaJodete &&
      other.numero == numero &&
      other.palo == palo &&
      other.esComodin == esComodin &&
      other.id == id;

  @override
  int get hashCode => Object.hash(numero, palo, esComodin, id);

  @override
  String toString() => etiqueta;
}

class JugadorJodete {
  JugadorJodete(this.nombre);

  String nombre;
  final List<CartaJodete> mano = [];
  bool rendido = false;

  bool get activo => !rendido;
}

class PartidaJodete {
  PartidaJodete({
    required this.jugadores,
    required this.mazo,
    required this.descarte,
    required this.paloVigente,
    this.indiceTurno = 0,
    this.sentido = SentidoJodete.horario,
    this.fase = FaseJodete.jugando,
    this.ganador,
    this.mensajeFin,
    this.contraPc = false,
    this.ultimaJugada,
    this.pendienteDos = 0,
  });

  final List<JugadorJodete> jugadores;
  final List<CartaJodete> mazo;
  final List<CartaJodete> descarte;
  PaloJodete paloVigente;
  int indiceTurno;
  SentidoJodete sentido;
  FaseJodete fase;
  String? ganador;
  String? mensajeFin;
  final bool contraPc;
  String? ultimaJugada;
  /// Cartas acumuladas por doses apilados; el turno actual debe tirar un 2 o levantarlas.
  int pendienteDos;

  bool get terminada => fase == FaseJodete.terminada;

  bool get hayPendienteDos => pendienteDos > 0;

  CartaJodete? get cimaDescarte =>
      descarte.isEmpty ? null : descarte.last;

  JugadorJodete get jugadorActual => jugadores[indiceTurno];

  List<JugadorJodete> get activos =>
      jugadores.where((j) => j.activo).toList();
}

List<CartaJodete> crearMazoJodete({math.Random? rng}) {
  final r = rng ?? math.Random();
  final mazo = <CartaJodete>[
    for (final palo in PaloJodete.values)
      for (var n = 1; n <= 12; n++)
        CartaJodete(numero: n, palo: palo, id: palo.index * 20 + n),
    const CartaJodete(numero: null, palo: null, esComodin: true, id: 1001),
    const CartaJodete(numero: null, palo: null, esComodin: true, id: 1002),
  ];
  mazo.shuffle(r);
  return mazo;
}

bool cartaEspecialParaInicio(CartaJodete c) => c.esEspecialInicio;

PartidaJodete nuevaPartidaJodete({
  required List<String> nombres,
  bool contraPc = false,
  math.Random? rng,
  int cartasIniciales = 7,
}) {
  final r = rng ?? math.Random();
  final lista = nombres.isEmpty
      ? <String>['Jugador 1', 'Jugador 2']
      : List<String>.from(nombres);
  while (lista.length < 2) {
    lista.add('Jugador ${lista.length + 1}');
  }

  final jugadores = [for (final n in lista) JugadorJodete(n)];
  final mazo = crearMazoJodete(rng: r);

  for (var i = 0; i < cartasIniciales; i++) {
    for (final j in jugadores) {
      if (mazo.isEmpty) break;
      j.mano.add(mazo.removeLast());
    }
  }

  // Primera carta del descarte: no especial.
  CartaJodete? inicio;
  final reservadas = <CartaJodete>[];
  while (mazo.isNotEmpty) {
    final c = mazo.removeLast();
    if (!cartaEspecialParaInicio(c)) {
      inicio = c;
      break;
    }
    reservadas.add(c);
  }
  mazo.addAll(reservadas);
  mazo.shuffle(r);

  // Si todo fue especial (casi imposible), forzar la primera no-comodín.
  inicio ??= () {
    for (var i = mazo.length - 1; i >= 0; i--) {
      if (!mazo[i].esComodin) {
        return mazo.removeAt(i);
      }
    }
    return mazo.removeLast();
  }();

  final descarte = <CartaJodete>[inicio];
  final palo = inicio.palo ?? PaloJodete.oro;

  return PartidaJodete(
    jugadores: jugadores,
    mazo: mazo,
    descarte: descarte,
    paloVigente: palo,
    contraPc: contraPc,
    ultimaJugada: 'Inicio: ${inicio.etiqueta}',
  );
}

bool puedeJugarCartaJodete(PartidaJodete p, CartaJodete c) {
  if (p.terminada) return false;
  // Con doses pendientes solo se puede responder con otro 2.
  if (p.hayPendienteDos) return c.esDos;
  if (c.esComodin) return true;
  final cima = p.cimaDescarte;
  if (cima == null) return true;
  if (!cima.esComodin && c.numero != null && c.numero == cima.numero) {
    return true;
  }
  return c.palo == p.paloVigente;
}

List<CartaJodete> cartasJugablesJodete(PartidaJodete p, JugadorJodete j) {
  return [for (final c in j.mano) if (puedeJugarCartaJodete(p, c)) c];
}

void _reciclarMazoSiHaceFalta(PartidaJodete p, math.Random rng) {
  if (p.mazo.isNotEmpty) return;
  if (p.descarte.length <= 1) return;
  final cima = p.descarte.removeLast();
  p.mazo.addAll(p.descarte);
  p.descarte
    ..clear()
    ..add(cima);
  p.mazo.shuffle(rng);
}

List<CartaJodete> _robar(PartidaJodete p, JugadorJodete j, int n, math.Random rng) {
  final robadas = <CartaJodete>[];
  for (var i = 0; i < n; i++) {
    _reciclarMazoSiHaceFalta(p, rng);
    if (p.mazo.isEmpty) break;
    final c = p.mazo.removeLast();
    j.mano.add(c);
    robadas.add(c);
  }
  return robadas;
}

int _indiceSiguienteActivo(PartidaJodete p, {int desde = -1, int saltos = 1}) {
  final n = p.jugadores.length;
  if (n == 0) return 0;
  var idx = desde < 0 ? p.indiceTurno : desde;
  final dir = p.sentido == SentidoJodete.horario ? 1 : -1;
  var hechos = 0;
  var guard = 0;
  while (hechos < saltos && guard < n * 4) {
    guard++;
    idx = (idx + dir) % n;
    if (idx < 0) idx += n;
    if (p.jugadores[idx].activo) hechos++;
  }
  return idx;
}

void _avanzarTurno(PartidaJodete p, {int saltos = 1}) {
  p.indiceTurno = _indiceSiguienteActivo(p, saltos: saltos);
}

void _chequearVictoria(PartidaJodete p, JugadorJodete j) {
  if (j.mano.isEmpty && j.activo) {
    p.fase = FaseJodete.terminada;
    p.ganador = j.nombre;
    p.mensajeFin = '¡${j.nombre} se quedó sin cartas!';
    return;
  }
  final vivos = p.activos;
  if (vivos.length == 1) {
    p.fase = FaseJodete.terminada;
    p.ganador = vivos.first.nombre;
    p.mensajeFin = '¡${vivos.first.nombre} gana por rendición!';
  }
}

/// [paloElegido] obligatorio si la carta pide elegir palo (10 / comodín).
String? jugarCartaJodete(
  PartidaJodete p,
  CartaJodete carta, {
  PaloJodete? paloElegido,
  math.Random? rng,
}) {
  if (p.terminada) return 'La partida ya terminó.';
  final j = p.jugadorActual;
  if (!j.activo) return 'Este jugador no está activo.';
  if (!j.mano.contains(carta)) return 'Esa carta no está en tu mano.';
  if (!puedeJugarCartaJodete(p, carta)) {
    if (p.hayPendienteDos) {
      return 'Hay un ${p.pendienteDos} pendiente: tirás un 2 o levantás.';
    }
    return 'Debés tirar del mismo palo (${p.paloVigente.name}) o el mismo número.';
  }
  if (carta.pideElegirPalo && paloElegido == null) {
    return 'Elegí un palo.';
  }

  final r = rng ?? math.Random();
  j.mano.remove(carta);
  p.descarte.add(carta);

  if (carta.esComodin) {
    p.paloVigente = paloElegido!;
  } else if (carta.numero == 10) {
    p.paloVigente = paloElegido!;
  } else if (carta.palo != null) {
    p.paloVigente = carta.palo!;
  }

  var msg = '${j.nombre} tiró ${carta.etiqueta}';
  if (carta.pideElegirPalo) {
    msg += ' → palo ${paloElegido!.name}';
  }

  _chequearVictoria(p, j);
  if (p.terminada) {
    p.ultimaJugada = msg;
    return null;
  }

  // Una carta por turno (salvo apilar doses).
  final nActivos = p.activos.length;
  if (carta.esDos) {
    p.pendienteDos += 2;
    msg += ' · pendiente ${p.pendienteDos}';
    _avanzarTurno(p);
  } else if (carta.invierte) {
    p.sentido = p.sentido == SentidoJodete.horario
        ? SentidoJodete.antihorario
        : SentidoJodete.horario;
    msg += nActivos == 2 ? ' (salteo)' : ' (sentido invertido)';
    if (nActivos == 2) {
      _avanzarTurno(p, saltos: 2);
    } else {
      _avanzarTurno(p);
    }
  } else if (carta.saltea) {
    msg += ' · saltea';
    _avanzarTurno(p, saltos: 2);
  } else if (carta.esComodin) {
    final victimaIdx = _indiceSiguienteActivo(p);
    final victima = p.jugadores[victimaIdx];
    final robadas = _robar(p, victima, 5, r);
    msg += ' · ${victima.nombre} levanta ${robadas.length}';
    p.indiceTurno = victimaIdx;
    _avanzarTurno(p);
  } else {
    _avanzarTurno(p);
  }

  p.ultimaJugada = msg;
  return null;
}

/// Si hay doses pendientes, levanta esa cantidad; si no, 1 carta. Luego pasa.
String? levantarPorNoJugarJodete(PartidaJodete p, {math.Random? rng}) {
  if (p.terminada) return 'La partida ya terminó.';
  final j = p.jugadorActual;
  if (!j.activo) return 'Este jugador no está activo.';
  final r = rng ?? math.Random();
  final n = p.hayPendienteDos ? p.pendienteDos : 1;
  final robadas = _robar(p, j, n, r);
  if (p.hayPendienteDos) {
    p.pendienteDos = 0;
  }
  if (robadas.isEmpty) {
    p.ultimaJugada = '${j.nombre} no pudo levantar (mazo vacío)';
  } else {
    p.ultimaJugada = '${j.nombre} levantó ${robadas.length} carta(s)';
  }
  _avanzarTurno(p);
  return null;
}

void rendirseJodete(PartidaJodete p, String nombre) {
  if (p.terminada) return;
  JugadorJodete? j;
  for (final x in p.jugadores) {
    if (x.nombre == nombre) {
      j = x;
      break;
    }
  }
  if (j == null || j.rendido) return;
  j.rendido = true;
  j.mano.clear();
  p.ultimaJugada = '$nombre se rindió';

  final vivos = p.activos;
  if (vivos.length <= 1) {
    p.fase = FaseJodete.terminada;
    p.ganador = vivos.isEmpty ? null : vivos.first.nombre;
    p.mensajeFin = vivos.isEmpty
        ? 'Todos se rindieron'
        : '¡${vivos.first.nombre} gana por rendición!';
    return;
  }

  if (!p.jugadorActual.activo) {
    _avanzarTurno(p);
  }
}

String nombrePaloJodete(PaloJodete p) => switch (p) {
      PaloJodete.oro => 'Oro',
      PaloJodete.copa => 'Copa',
      PaloJodete.espada => 'Espada',
      PaloJodete.basto => 'Basto',
    };
