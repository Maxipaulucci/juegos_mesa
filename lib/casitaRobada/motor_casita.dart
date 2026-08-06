import 'dart:math' as math;

/// Casita robada — mazo español de 40 (sin 8, 9 ni comodines).
/// Pares por número: mesa o robo de casita (cima del pozo rival).

enum PaloCasita { oro, copa, espada, basto }

enum FaseCasita { jugando, terminada }

class CartaCasita {
  const CartaCasita({required this.numero, required this.palo});

  /// 1–7, 10, 11 o 12.
  final int numero;
  final PaloCasita palo;

  String get nombrePalo => switch (palo) {
        PaloCasita.oro => 'oro',
        PaloCasita.copa => 'copa',
        PaloCasita.espada => 'espada',
        PaloCasita.basto => 'basto',
      };

  String get etiqueta => '$numero de $nombrePalo';

  @override
  bool operator ==(Object other) =>
      other is CartaCasita && other.numero == numero && other.palo == palo;

  @override
  int get hashCode => Object.hash(numero, palo);

  @override
  String toString() => etiqueta;
}

class JugadorCasita {
  JugadorCasita(this.nombre);

  final String nombre;
  final List<CartaCasita> mano = [];
  /// Casita / pozo: la última carta es la cima (visible).
  final List<CartaCasita> pozo = [];

  CartaCasita? get cimaPozo => pozo.isEmpty ? null : pozo.last;

  int get cartasPozo => pozo.length;
}

enum TipoJugadaCasita { mesa, capturaMesa, roboCasita }

class UltimaJugadaCasita {
  const UltimaJugadaCasita({
    required this.jugador,
    required this.carta,
    required this.tipo,
    this.cartasCapturadas = const [],
    this.robadoDe,
  });

  final String jugador;
  final CartaCasita carta;
  final TipoJugadaCasita tipo;
  final List<CartaCasita> cartasCapturadas;
  final String? robadoDe;

  String get descripcion => switch (tipo) {
        TipoJugadaCasita.mesa => '$jugador dejó ${carta.etiqueta} en la mesa',
        TipoJugadaCasita.capturaMesa =>
          '$jugador capturó ${carta.etiqueta}'
              '${cartasCapturadas.isEmpty ? '' : ' + ${cartasCapturadas.map((c) => c.etiqueta).join(', ')}'}',
        TipoJugadaCasita.roboCasita =>
          '$jugador robó la casita de $robadoDe con ${carta.etiqueta}',
      };
}

class PartidaCasita {
  PartidaCasita({
    required this.jugadores,
    this.indiceTurno = 0,
    this.fase = FaseCasita.jugando,
    this.contraPc = false,
    this.ganador,
    this.mensajeFin,
    this.ultimoQueCapturo,
    this.ultimaJugada,
  });

  final List<JugadorCasita> jugadores;
  final List<CartaCasita> mazo = [];
  final List<CartaCasita> mesa = [];
  int indiceTurno;
  FaseCasita fase;
  final bool contraPc;
  String? ganador;
  String? mensajeFin;
  String? ultimoQueCapturo;
  UltimaJugadaCasita? ultimaJugada;

  bool get terminada => fase == FaseCasita.terminada;
  bool get enJuego => fase == FaseCasita.jugando;

  JugadorCasita get jugadorActual =>
      jugadores[indiceTurno % jugadores.length];

  JugadorCasita get rivalActual {
    final yo = indiceTurno % jugadores.length;
    return jugadores[(yo + 1) % jugadores.length];
  }
}

List<CartaCasita> crearMazoCasita([math.Random? rng]) {
  const numeros = [1, 2, 3, 4, 5, 6, 7, 10, 11, 12];
  final mazo = <CartaCasita>[
    for (final palo in PaloCasita.values)
      for (final n in numeros) CartaCasita(numero: n, palo: palo),
  ];
  mazo.shuffle(rng ?? math.Random());
  return mazo;
}

PartidaCasita nuevaPartidaCasita({
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
  // Por ahora UI pensada para 2.
  final jugadores = [
    for (final n in lista.take(2)) JugadorCasita(n),
  ];
  final r = rng ?? math.Random();
  final mazo = crearMazoCasita(r);

  final p = PartidaCasita(
    jugadores: jugadores,
    contraPc: contraPc,
  );
  p.mazo.addAll(mazo);

  // 4 a la mesa, 3 a cada uno.
  for (var i = 0; i < 4 && p.mazo.isNotEmpty; i++) {
    p.mesa.add(p.mazo.removeLast());
  }
  for (var ronda = 0; ronda < 3; ronda++) {
    for (final j in p.jugadores) {
      if (p.mazo.isEmpty) break;
      j.mano.add(p.mazo.removeLast());
    }
  }

  if (contraPc) {
    final idxHumano = p.jugadores.indexWhere((j) => j.nombre != 'PC');
    p.indiceTurno = idxHumano >= 0 ? idxHumano : 0;
  } else {
    p.indiceTurno = r.nextInt(p.jugadores.length);
  }
  return p;
}

void _avanzarTurno(PartidaCasita p) {
  if (p.terminada) return;
  p.indiceTurno = (p.indiceTurno + 1) % p.jugadores.length;
}

void _repartirManosSiCorresponde(PartidaCasita p) {
  if (p.terminada) return;
  final todosVacios = p.jugadores.every((j) => j.mano.isEmpty);
  if (!todosVacios) return;

  if (p.mazo.isEmpty) {
    _finalizar(p);
    return;
  }

  // Reparte hasta 3 por jugador mientras haya mazo.
  for (var ronda = 0; ronda < 3; ronda++) {
    for (final j in p.jugadores) {
      if (p.mazo.isEmpty) return;
      j.mano.add(p.mazo.removeLast());
    }
  }
}

void _finalizar(PartidaCasita p) {
  // Cartas que quedan en mesa → último que capturó (si hay).
  if (p.mesa.isNotEmpty && p.ultimoQueCapturo != null) {
    JugadorCasita? dueno;
    for (final j in p.jugadores) {
      if (j.nombre == p.ultimoQueCapturo) {
        dueno = j;
        break;
      }
    }
    if (dueno != null) {
      dueno.pozo.addAll(p.mesa);
      p.mesa.clear();
    }
  }

  p.fase = FaseCasita.terminada;
  var maxCartas = -1;
  final empatados = <String>[];
  for (final j in p.jugadores) {
    if (j.cartasPozo > maxCartas) {
      maxCartas = j.cartasPozo;
      empatados
        ..clear()
        ..add(j.nombre);
    } else if (j.cartasPozo == maxCartas) {
      empatados.add(j.nombre);
    }
  }
  if (empatados.length == 1) {
    p.ganador = empatados.first;
    p.mensajeFin =
        '¡${p.ganador} gana con $maxCartas cartas en la casita!';
  } else {
    p.ganador = null;
    p.mensajeFin =
        'Empate a $maxCartas cartas: ${empatados.join(' y ')}.';
  }
}

/// True si [carta] puede robar la casita de [rival].
bool puedeRobarCasita(CartaCasita carta, JugadorCasita rival) {
  final cima = rival.cimaPozo;
  return cima != null && cima.numero == carta.numero;
}

/// True si [carta] captura al menos una de la mesa.
bool puedeCapturarMesa(CartaCasita carta, List<CartaCasita> mesa) {
  return mesa.any((c) => c.numero == carta.numero);
}

/// Juega la carta en [indiceEnMano] del jugador actual.
/// Prioridad: robo de casita rival → captura en mesa → deja en mesa.
String? jugarCartaCasita(
  PartidaCasita p, {
  required int indiceEnMano,
}) {
  if (p.terminada) return 'La partida ya terminó.';
  if (p.fase != FaseCasita.jugando) return 'No se puede jugar ahora.';
  final yo = p.jugadorActual;
  if (indiceEnMano < 0 || indiceEnMano >= yo.mano.length) {
    return 'Carta inválida.';
  }

  final carta = yo.mano.removeAt(indiceEnMano);
  final rival = p.rivalActual;

  // 1) Robar casita del rival.
  if (puedeRobarCasita(carta, rival)) {
    final robadas = List<CartaCasita>.from(rival.pozo);
    rival.pozo.clear();
    yo.pozo.addAll(robadas);
    yo.pozo.add(carta);
    p.ultimoQueCapturo = yo.nombre;
    p.ultimaJugada = UltimaJugadaCasita(
      jugador: yo.nombre,
      carta: carta,
      tipo: TipoJugadaCasita.roboCasita,
      cartasCapturadas: robadas,
      robadoDe: rival.nombre,
    );
    _avanzarTurno(p);
    _repartirManosSiCorresponde(p);
    return null;
  }

  // 2) Capturar pares de la mesa.
  final capturadas = <CartaCasita>[
    for (final c in p.mesa)
      if (c.numero == carta.numero) c,
  ];
  if (capturadas.isNotEmpty) {
    p.mesa.removeWhere((c) => c.numero == carta.numero);
    yo.pozo.addAll(capturadas);
    yo.pozo.add(carta);
    p.ultimoQueCapturo = yo.nombre;
    p.ultimaJugada = UltimaJugadaCasita(
      jugador: yo.nombre,
      carta: carta,
      tipo: TipoJugadaCasita.capturaMesa,
      cartasCapturadas: capturadas,
    );
    _avanzarTurno(p);
    _repartirManosSiCorresponde(p);
    return null;
  }

  // 3) Dejar en la mesa.
  p.mesa.add(carta);
  p.ultimaJugada = UltimaJugadaCasita(
    jugador: yo.nombre,
    carta: carta,
    tipo: TipoJugadaCasita.mesa,
  );
  _avanzarTurno(p);
  _repartirManosSiCorresponde(p);
  return null;
}

/// IA simple: prioriza robo de casita, luego captura, luego carta “segura”.
int elegirJugadaPcCasita(PartidaCasita p, [math.Random? rng]) {
  final r = rng ?? math.Random();
  final yo = p.jugadorActual;
  final rival = p.rivalActual;
  if (yo.mano.isEmpty) return -1;

  for (var i = 0; i < yo.mano.length; i++) {
    if (puedeRobarCasita(yo.mano[i], rival)) return i;
  }
  var mejorIdx = -1;
  var mejorCant = 0;
  for (var i = 0; i < yo.mano.length; i++) {
    final n = yo.mano[i].numero;
    final cant = p.mesa.where((c) => c.numero == n).length;
    if (cant > mejorCant) {
      mejorCant = cant;
      mejorIdx = i;
    }
  }
  if (mejorIdx >= 0) return mejorIdx;

  // Evitar dejar una cima que el rival pueda robar fácil si puede.
  final candidatos = <int>[
    for (var i = 0; i < yo.mano.length; i++) i,
  ];
  candidatos.shuffle(r);
  return candidatos.first;
}

void jugarTurnoPcCasita(PartidaCasita p, [math.Random? rng]) {
  if (p.terminada || !p.contraPc) return;
  if (p.jugadorActual.nombre != 'PC') return;
  final idx = elegirJugadaPcCasita(p, rng);
  if (idx < 0) return;
  jugarCartaCasita(p, indiceEnMano: idx);
}
