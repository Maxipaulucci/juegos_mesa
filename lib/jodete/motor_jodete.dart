import 'dart:math' as math;

/// Jodete — mazo español de 50 (48 + 2 comodines).

enum PaloJodete { oro, copa, espada, basto }

enum FaseJodete { jugando, finRonda, ganado }

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

  /// 4 y 7: el mismo jugador tira de nuevo.
  bool get juegaDeNuevo => !esComodin && (numero == 4 || numero == 7);

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
  /// Puntos acumulados de la partida.
  int puntos = 0;
  /// Puesto en la ronda actual (1 = primero en quedarse sin cartas).
  int? puestoRonda;

  bool get activo => !rendido;

  /// Sigue jugando esta ronda (no se rindió ni ya se quedó sin cartas).
  bool get enJuego => !rendido && puestoRonda == null;
}

/// Detalle de un jugador al cerrar la ronda (para el overlay).
class DetalleJugadorRondaJodete {
  const DetalleJugadorRondaJodete({
    required this.nombre,
    required this.puesto,
    required this.puntosGanados,
    required this.puntosTrasRonda,
    this.detallePuntos,
  });

  final String nombre;
  final int puesto;
  final int puntosGanados;
  final int puntosTrasRonda;
  /// Texto extra (p. ej. “cartas rivales”).
  final String? detallePuntos;
}

class ResultadoRondaJodete {
  const ResultadoRondaJodete({required this.detalles});

  final List<DetalleJugadorRondaJodete> detalles;
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
    this.pendienteComodin = 0,
    this.objetivo = 30,
    this.incluirComodines = true,
    this.cartasIniciales = 7,
    this.puntajePorCartas = false,
    this.apilarDoses = true,
    this.ultimoResultado,
    List<ResultadoRondaJodete>? historialRondas,
  }) : historialRondas = historialRondas ?? [];

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
  /// Cartas acumuladas por comodines apilados; el turno actual debe tirar un comodín o levantarlas.
  int pendienteComodin;
  /// Primero en llegar a este puntaje gana la partida.
  final int objetivo;
  final bool incluirComodines;
  final int cartasIniciales;
  /// Si true, el 1º suma el valor de las cartas rivales (objetivo 100).
  final bool puntajePorCartas;
  /// Si true, se puede responder un 2 con otro 2 (apila +2)
  /// y un comodín con otro comodín (apila +5).
  final bool apilarDoses;
  ResultadoRondaJodete? ultimoResultado;
  /// Resultados de todas las rondas (para el historial de victoria).
  final List<ResultadoRondaJodete> historialRondas;

  bool get terminada => fase == FaseJodete.ganado;

  bool get enFinRonda => fase == FaseJodete.finRonda;

  bool get jugando => fase == FaseJodete.jugando;

  bool get hayPendienteDos => pendienteDos > 0;

  bool get hayPendienteComodin => pendienteComodin > 0;

  bool get hayPendienteLevantar => hayPendienteDos || hayPendienteComodin;

  int get cantidadPendienteLevantar =>
      hayPendienteDos ? pendienteDos : (hayPendienteComodin ? pendienteComodin : 0);

  /// Con “Tirar 2 sobre 2” también se apilan comodines sobre comodines.
  bool get apilaComodines => apilarDoses && incluirComodines;

  CartaJodete? get cimaDescarte =>
      descarte.isEmpty ? null : descarte.last;

  JugadorJodete get jugadorActual => jugadores[indiceTurno];

  List<JugadorJodete> get activos =>
      jugadores.where((j) => j.activo).toList();

  List<JugadorJodete> get enJuego =>
      jugadores.where((j) => j.enJuego).toList();
}

/// Valor de una carta para el modo “puntaje por cartas”.
int valorCartaJodete(CartaJodete c) {
  if (c.esComodin) return 50;
  final n = c.numero;
  if (n == null) return 0;
  if (n == 2 || n == 10 || n == 11 || n == 12) return 20;
  return n;
}

int valorManoJodete(Iterable<CartaJodete> mano) {
  var t = 0;
  for (final c in mano) {
    t += valorCartaJodete(c);
  }
  return t;
}

/// Puntos según puesto (1º, 2º, …) y cantidad de jugadores de la ronda.
/// 2j: 1-0 · 3j: 2-1-0 · 4j: 3-2-1-0
int puntosPorPuestoJodete(int nJugadores, int puesto) {
  if (puesto < 1 || nJugadores < 2) return 0;
  return math.max(0, nJugadores - puesto);
}

List<CartaJodete> crearMazoJodete({
  math.Random? rng,
  bool incluirComodines = true,
}) {
  final r = rng ?? math.Random();
  final mazo = <CartaJodete>[
    for (final palo in PaloJodete.values)
      for (var n = 1; n <= 12; n++)
        CartaJodete(numero: n, palo: palo, id: palo.index * 20 + n),
    if (incluirComodines) ...const [
      CartaJodete(numero: null, palo: null, esComodin: true, id: 1001),
      CartaJodete(numero: null, palo: null, esComodin: true, id: 1002),
    ],
  ];
  mazo.shuffle(r);
  return mazo;
}

bool cartaEspecialParaInicio(CartaJodete c) => c.esEspecialInicio;

void _repartirInicioJodete(PartidaJodete p, math.Random r) {
  p.mazo
    ..clear()
    ..addAll(
      crearMazoJodete(rng: r, incluirComodines: p.incluirComodines),
    );
  p.descarte.clear();
  p.pendienteDos = 0;
  p.pendienteComodin = 0;
  p.sentido = SentidoJodete.horario;
  p.ganador = null;
  p.mensajeFin = null;

  for (final j in p.jugadores) {
    j.mano.clear();
    j.puestoRonda = null;
    // Rendidos quedan fuera de la partida entera.
  }

  final vivos = p.activos;
  for (var i = 0; i < p.cartasIniciales; i++) {
    for (final j in vivos) {
      if (p.mazo.isEmpty) break;
      j.mano.add(p.mazo.removeLast());
    }
  }

  CartaJodete? inicio;
  final reservadas = <CartaJodete>[];
  while (p.mazo.isNotEmpty) {
    final c = p.mazo.removeLast();
    if (!cartaEspecialParaInicio(c)) {
      inicio = c;
      break;
    }
    reservadas.add(c);
  }
  p.mazo.addAll(reservadas);
  p.mazo.shuffle(r);

  inicio ??= () {
    for (var i = p.mazo.length - 1; i >= 0; i--) {
      if (!p.mazo[i].esComodin) {
        return p.mazo.removeAt(i);
      }
    }
    return p.mazo.removeLast();
  }();

  p.descarte.add(inicio);
  p.paloVigente = inicio.palo ?? PaloJodete.oro;
  p.ultimaJugada = 'Inicio: ${inicio.etiqueta}';
  p.fase = FaseJodete.jugando;

  // Empieza un vivo al azar (o el primero).
  if (vivos.isEmpty) {
    p.indiceTurno = 0;
  } else {
    final idx = p.jugadores.indexOf(vivos[r.nextInt(vivos.length)]);
    p.indiceTurno = idx < 0 ? 0 : idx;
  }
}

PartidaJodete nuevaPartidaJodete({
  required List<String> nombres,
  bool contraPc = false,
  math.Random? rng,
  int cartasIniciales = 7,
  bool incluirComodines = true,
  int objetivo = 30,
  bool puntajePorCartas = false,
  bool apilarDoses = true,
}) {
  final r = rng ?? math.Random();
  final lista = nombres.isEmpty
      ? <String>['Jugador 1', 'Jugador 2']
      : List<String>.from(nombres);
  while (lista.length < 2) {
    lista.add('Jugador ${lista.length + 1}');
  }

  final jugadores = [for (final n in lista) JugadorJodete(n)];
  final p = PartidaJodete(
    jugadores: jugadores,
    mazo: [],
    descarte: [],
    paloVigente: PaloJodete.oro,
    contraPc: contraPc,
    objetivo: objetivo,
    incluirComodines: incluirComodines,
    cartasIniciales: cartasIniciales,
    puntajePorCartas: puntajePorCartas,
    apilarDoses: apilarDoses,
  );
  _repartirInicioJodete(p, r);
  return p;
}

/// Siguiente ronda: conserva puntos; vuelve a repartir.
void siguienteRondaJodete(PartidaJodete p, [math.Random? rng]) {
  if (p.fase == FaseJodete.ganado) return;
  final r = rng ?? math.Random();
  p.ultimoResultado = null;
  _repartirInicioJodete(p, r);
}

bool puedeJugarCartaJodete(PartidaJodete p, CartaJodete c) {
  if (!p.jugando) return false;
  // Con doses pendientes: solo otro 2, y solo si está permitido apilar.
  if (p.hayPendienteDos) return p.apilarDoses && c.esDos;
  // Con comodines pendientes: solo otro comodín, si se puede apilar.
  if (p.hayPendienteComodin) return p.apilaComodines && c.esComodin;
  if (c.esComodin) return true;
  final cima = p.cimaDescarte;
  if (cima == null) return true;
  if (!cima.esComodin && c.numero != null && c.numero == cima.numero) {
    return true;
  }
  return c.palo == p.paloVigente;
}

List<CartaJodete> cartasJugablesJodete(PartidaJodete p, JugadorJodete j) {
  if (!p.jugando || !j.enJuego) return const [];
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

List<CartaJodete> _robar(
  PartidaJodete p,
  JugadorJodete j,
  int n,
  math.Random rng,
) {
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

int _indiceSiguienteEnJuego(PartidaJodete p, {int desde = -1, int saltos = 1}) {
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
    if (p.jugadores[idx].enJuego) hechos++;
  }
  return idx;
}

void _avanzarTurno(PartidaJodete p, {int saltos = 1}) {
  p.indiceTurno = _indiceSiguienteEnJuego(p, saltos: saltos);
}

int _siguientePuesto(PartidaJodete p) {
  var maxP = 0;
  for (final j in p.jugadores) {
    final puesto = j.puestoRonda;
    if (puesto != null && puesto > maxP) maxP = puesto;
  }
  return maxP + 1;
}

void _registrarPuesto(PartidaJodete p, JugadorJodete j) {
  if (j.puestoRonda != null) return;
  j.puestoRonda = _siguientePuesto(p);
}

void puntuarRondaJodete(PartidaJodete p) {
  // Completar puestos faltantes (p. ej. rendidos).
  for (final j in p.jugadores) {
    if (j.puestoRonda == null) {
      _registrarPuesto(p, j);
    }
  }

  final nScore = math.max(2, p.jugadores.length);
  final detalles = <DetalleJugadorRondaJodete>[];

  if (p.puntajePorCartas) {
    // El 1º suma el valor de las cartas que quedan en las demás manos.
    JugadorJodete? primero;
    for (final j in p.jugadores) {
      if (j.puestoRonda == 1) {
        primero = j;
        break;
      }
    }
    var pozoCartas = 0;
    for (final j in p.jugadores) {
      if (identical(j, primero)) continue;
      pozoCartas += valorManoJodete(j.mano);
    }
    for (final j in p.jugadores) {
      final puesto = j.puestoRonda ?? nScore;
      final esPrimero = identical(j, primero);
      final sumar = esPrimero ? pozoCartas : 0;
      j.puntos += sumar;
      detalles.add(
        DetalleJugadorRondaJodete(
          nombre: j.nombre,
          puesto: puesto,
          puntosGanados: sumar,
          puntosTrasRonda: j.puntos,
          detallePuntos: esPrimero && sumar > 0
              ? 'Valor de cartas rivales'
              : (esPrimero ? 'Sin cartas rivales' : null),
        ),
      );
    }
  } else {
    for (final j in p.jugadores) {
      final puesto = j.puestoRonda ?? nScore;
      final sumar = puntosPorPuestoJodete(nScore, puesto);
      j.puntos += sumar;
      detalles.add(
        DetalleJugadorRondaJodete(
          nombre: j.nombre,
          puesto: puesto,
          puntosGanados: sumar,
          puntosTrasRonda: j.puntos,
        ),
      );
    }
  }

  detalles.sort((a, b) => a.puesto.compareTo(b.puesto));
  final resultado = ResultadoRondaJodete(detalles: detalles);
  p.ultimoResultado = resultado;
  p.historialRondas.add(resultado);

  var maxPts = -1;
  for (final j in p.jugadores) {
    if (j.puntos > maxPts) maxPts = j.puntos;
  }
  final lideres = [
    for (final j in p.jugadores)
      if (j.puntos == maxPts && j.puntos >= p.objetivo) j,
  ];
  if (lideres.length == 1) {
    p.fase = FaseJodete.ganado;
    p.ganador = lideres.first.nombre;
    p.mensajeFin =
        '${lideres.first.nombre} llegó a ${lideres.first.puntos} puntos.';
  } else {
    p.fase = FaseJodete.finRonda;
  }
}

void _cerrarRondaSiCorresponde(PartidaJodete p) {
  if (!p.jugando) return;
  final quedan = p.enJuego;
  if (quedan.length > 1) return;

  for (final j in quedan) {
    _registrarPuesto(p, j);
  }
  for (final j in p.jugadores) {
    if (j.puestoRonda == null) {
      _registrarPuesto(p, j);
    }
  }
  puntuarRondaJodete(p);
}

void _alQuedarseSinCartas(PartidaJodete p, JugadorJodete j) {
  if (j.mano.isNotEmpty || j.puestoRonda != null) return;
  _registrarPuesto(p, j);
  p.ultimaJugada =
      '${j.nombre} se quedó sin cartas (${_ordinal(j.puestoRonda!)})';
  _cerrarRondaSiCorresponde(p);
}

String _ordinal(int puesto) {
  return switch (puesto) {
    1 => '1º',
    2 => '2º',
    3 => '3º',
    4 => '4º',
    _ => '$puestoº',
  };
}

/// [paloElegido] obligatorio si la carta pide elegir palo (10 / comodín).
String? jugarCartaJodete(
  PartidaJodete p,
  CartaJodete carta, {
  PaloJodete? paloElegido,
  math.Random? rng,
}) {
  if (!p.jugando) return 'La ronda no está en juego.';
  final j = p.jugadorActual;
  if (!j.enJuego) return 'Este jugador no está en juego.';
  if (!j.mano.contains(carta)) return 'Esa carta no está en tu mano.';
  if (!puedeJugarCartaJodete(p, carta)) {
    if (p.hayPendienteDos) {
      return p.apilarDoses
          ? 'Hay un ${p.pendienteDos} pendiente: tirás un 2 o levantás.'
          : 'Hay un ${p.pendienteDos} pendiente: tenés que levantar.';
    }
    if (p.hayPendienteComodin) {
      return p.apilaComodines
          ? 'Hay un ${p.pendienteComodin} pendiente: tirás un comodín o levantás.'
          : 'Hay un ${p.pendienteComodin} pendiente: tenés que levantar.';
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

  final seFue = j.mano.isEmpty;
  if (seFue) {
    _alQuedarseSinCartas(p, j);
    if (!p.jugando) {
      p.ultimaJugada = msg;
      return null;
    }
    msg += ' · ${_ordinal(j.puestoRonda!)}';
  }

  // Una carta por turno (salvo 4/7: tira de nuevo).
  final nEnJuego = p.enJuego.length;
  if (carta.juegaDeNuevo) {
    msg += ' · tira de nuevo';
  } else if (carta.esDos) {
    p.pendienteDos += 2;
    msg += ' · pendiente ${p.pendienteDos}';
    _avanzarTurno(p);
  } else if (carta.invierte) {
    p.sentido = p.sentido == SentidoJodete.horario
        ? SentidoJodete.antihorario
        : SentidoJodete.horario;
    msg += nEnJuego == 2 ? ' (salteo)' : ' (sentido invertido)';
    if (nEnJuego == 2) {
      _avanzarTurno(p, saltos: 2);
    } else {
      _avanzarTurno(p);
    }
  } else if (carta.saltea) {
    msg += ' · saltea';
    _avanzarTurno(p, saltos: 2);
  } else if (carta.esComodin) {
    if (p.apilaComodines) {
      p.pendienteComodin += 5;
      msg += ' · pendiente ${p.pendienteComodin}';
      _avanzarTurno(p);
    } else {
      final victimaIdx = _indiceSiguienteEnJuego(p);
      final victima = p.jugadores[victimaIdx];
      final robadas = _robar(p, victima, 5, r);
      msg += ' · ${victima.nombre} levanta ${robadas.length}';
      p.indiceTurno = victimaIdx;
      _avanzarTurno(p);
    }
  } else {
    _avanzarTurno(p);
  }

  // Si el turno quedó en alguien fuera, avanzar.
  if (!p.jugadorActual.enJuego && p.jugando) {
    _avanzarTurno(p);
  }

  p.ultimaJugada = msg;
  return null;
}

/// Si hay doses pendientes, levanta esa cantidad y pasa.
/// Si [hastaPoderTirar] y no hay pendiente: levanta hasta tener jugada
/// y **no** avanza el turno (podés tirar). Si no sacás ninguna jugable, pasa.
/// Devuelve `true` si el turno sigue siendo del mismo jugador.
bool levantarPorNoJugarJodete(
  PartidaJodete p, {
  math.Random? rng,
  bool hastaPoderTirar = false,
}) {
  if (!p.jugando) return false;
  final j = p.jugadorActual;
  if (!j.enJuego) return false;
  final r = rng ?? math.Random();

  if (p.hayPendienteLevantar) {
    final n = p.cantidadPendienteLevantar;
    final robadas = _robar(p, j, n, r);
    p.pendienteDos = 0;
    p.pendienteComodin = 0;
    if (robadas.isEmpty) {
      p.ultimaJugada = '${j.nombre} no pudo levantar (mazo vacío)';
    } else {
      p.ultimaJugada = '${j.nombre} levantó ${robadas.length} carta(s)';
    }
    _avanzarTurno(p);
    return false;
  }

  if (!hastaPoderTirar) {
    final robadas = _robar(p, j, 1, r);
    if (robadas.isEmpty) {
      p.ultimaJugada = '${j.nombre} no pudo levantar (mazo vacío)';
    } else {
      p.ultimaJugada = '${j.nombre} levantó 1 carta';
    }
    _avanzarTurno(p);
    return false;
  }

  // Levantar hasta poder tirar.
  // Si ya tenías jugada y igual elegiste levantar, es “paso”: 1 carta y listo.
  if (cartasJugablesJodete(p, j).isNotEmpty) {
    final robadas = _robar(p, j, 1, r);
    if (robadas.isEmpty) {
      p.ultimaJugada = '${j.nombre} no pudo levantar (mazo vacío)';
    } else {
      p.ultimaJugada = '${j.nombre} levantó 1 carta';
    }
    _avanzarTurno(p);
    return false;
  }

  var total = 0;
  while (cartasJugablesJodete(p, j).isEmpty) {
    final robadas = _robar(p, j, 1, r);
    if (robadas.isEmpty) break;
    total++;
    if (total > 80) break;
  }

  if (cartasJugablesJodete(p, j).isNotEmpty) {
    p.ultimaJugada = '${j.nombre} levantó $total hasta poder tirar';
    return true; // Sigue el mismo turno.
  }

  p.ultimaJugada = total == 0
      ? '${j.nombre} no pudo levantar (mazo vacío)'
      : '${j.nombre} levantó $total y no pudo tirar';
  _avanzarTurno(p);
  return false;
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
    // Fin de partida por rendición (sin puntuar ronda a medias).
    if (vivos.length == 1) {
      p.fase = FaseJodete.ganado;
      p.ganador = vivos.first.nombre;
      p.mensajeFin = '¡${vivos.first.nombre} gana por rendición!';
    } else {
      p.fase = FaseJodete.ganado;
      p.ganador = null;
      p.mensajeFin = 'Todos se rindieron';
    }
    return;
  }

  if (p.jugando) {
    _cerrarRondaSiCorresponde(p);
  }

  if (p.jugando && !p.jugadorActual.enJuego) {
    _avanzarTurno(p);
  }
}

/// Cartas que se pueden forzar (mazo, manos y descarte, incluida la cima).
List<CartaJodete> cartasDisponiblesForzarJodete(PartidaJodete p) {
  final out = <CartaJodete>[
    ...p.mazo,
    for (final j in p.jugadores) ...j.mano,
    ...p.descarte,
  ];
  final seen = <int>{};
  out.retainWhere((c) => seen.add(c.id));
  out.sort((a, b) {
    if (a.esComodin != b.esComodin) return a.esComodin ? 1 : -1;
    final pa = a.palo?.index ?? 99;
    final pb = b.palo?.index ?? 99;
    if (pa != pb) return pa.compareTo(pb);
    return (a.numero ?? 99).compareTo(b.numero ?? 99);
  });
  return out;
}

bool extraerCartaJodete(
  PartidaJodete p,
  CartaJodete carta, {
  bool incluirCima = false,
}) {
  if (p.mazo.remove(carta)) return true;
  for (final j in p.jugadores) {
    if (j.mano.remove(carta)) return true;
  }
  if (p.descarte.isEmpty) return false;
  final hasta = incluirCima ? p.descarte.length : p.descarte.length - 1;
  for (var i = 0; i < hasta; i++) {
    if (p.descarte[i] == carta) {
      p.descarte.removeAt(i);
      return true;
    }
  }
  return false;
}

/// Reemplaza la cima del pozo (descarte) y actualiza el palo vigente.
void forzarCimaDescarteJodete(PartidaJodete p, CartaJodete carta) {
  if (p.cimaDescarte == carta) {
    if (carta.palo != null) p.paloVigente = carta.palo!;
    return;
  }
  if (p.descarte.isNotEmpty) {
    p.mazo.add(p.descarte.removeLast());
  }
  extraerCartaJodete(p, carta);
  p.descarte.add(carta);
  if (carta.palo != null) p.paloVigente = carta.palo!;
  p.ultimaJugada = 'Modo Dios: pozo ${carta.etiqueta}';
  for (final jugador in p.jugadores) {
    _alQuedarseSinCartas(p, jugador);
  }
  if (p.jugando && !p.jugadorActual.enJuego) {
    _avanzarTurno(p);
  }
}

/// Reemplaza la mano del jugador [idx] por [cartas] (sin cupo).
void forzarManoJodete(PartidaJodete p, int idx, List<CartaJodete> cartas) {
  assert(idx >= 0 && idx < p.jugadores.length);
  final j = p.jugadores[idx];
  final cima = p.cimaDescarte;
  p.mazo.addAll(j.mano);
  j.mano.clear();
  for (final c in cartas) {
    if (c == cima) continue;
    extraerCartaJodete(p, c);
    j.mano.add(c);
  }
  p.ultimaJugada = 'Modo Dios: mano de ${j.nombre} (${j.mano.length})';
  for (final jugador in p.jugadores) {
    _alQuedarseSinCartas(p, jugador);
  }
  if (p.jugando && !p.jugadorActual.enJuego) {
    _avanzarTurno(p);
  }
}

String nombrePaloJodete(PaloJodete p) => switch (p) {
      PaloJodete.oro => 'Oro',
      PaloJodete.copa => 'Copa',
      PaloJodete.espada => 'Espada',
      PaloJodete.basto => 'Basto',
    };
