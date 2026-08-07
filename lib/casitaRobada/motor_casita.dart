import 'dart:math' as math;

/// Casita robada — mazo español de 48 (1–12 en 4 palos; sin comodines).
/// Pares por número: mesa o robo de casita (cima del pozo rival).

enum PaloCasita { oro, copa, espada, basto }

enum FaseCasita { jugando, terminada }

class CartaCasita {
  const CartaCasita({required this.numero, required this.palo});

  /// 1–12 (incluye 8 y 9; sin comodines).
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

  String nombre;
  final List<CartaCasita> mano = [];
  /// Casita / pozo: la última carta es la cima (visible).
  final List<CartaCasita> pozo = [];
  /// Se rindió (multijugador local): queda fuera de la partida.
  bool rendido = false;

  CartaCasita? get cimaPozo => pozo.isEmpty ? null : pozo.last;

  int get cartasPozo => pozo.length;
}

enum TipoJugadaCasita { mesa, capturaMesa, roboCasita }

class UltimaJugadaCasita {
  UltimaJugadaCasita({
    required this.jugador,
    required this.carta,
    required this.tipo,
    this.cartasCapturadas = const [],
    this.robadoDe,
  });

  String jugador;
  final CartaCasita carta;
  final TipoJugadaCasita tipo;
  final List<CartaCasita> cartasCapturadas;
  String? robadoDe;

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

  List<JugadorCasita> get jugadoresActivos => [
        for (final j in jugadores)
          if (!j.rendido) j,
      ];

  JugadorCasita get jugadorActual =>
      jugadores[indiceTurno % jugadores.length];

  JugadorCasita get rivalActual {
    final yo = indiceTurno % jugadores.length;
    for (var i = 1; i < jugadores.length; i++) {
      final j = jugadores[(yo + i) % jugadores.length];
      if (!j.rendido) return j;
    }
    return jugadores[(yo + 1) % jugadores.length];
  }
}

List<CartaCasita> crearMazoCasita([math.Random? rng]) {
  const numeros = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
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
  final n = p.jugadores.length;
  for (var i = 0; i < n; i++) {
    p.indiceTurno = (p.indiceTurno + 1) % n;
    if (!p.jugadorActual.rendido) return;
  }
}

void _repartirManosSiCorresponde(PartidaCasita p) {
  if (p.terminada) return;
  final activos = p.jugadoresActivos;
  if (activos.isEmpty) return;
  final todosVacios = activos.every((j) => j.mano.isEmpty);
  if (!todosVacios) return;

  if (p.mazo.isEmpty) {
    _finalizar(p);
    return;
  }

  // Reparte hasta 3 por jugador activo mientras haya mazo.
  for (var ronda = 0; ronda < 3; ronda++) {
    for (final j in activos) {
      if (p.mazo.isEmpty) return;
      j.mano.add(p.mazo.removeLast());
    }
  }
}

void _finalizar(PartidaCasita p) {
  // Cartas que quedan en mesa → último que capturó (si hay y sigue en pie).
  if (p.mesa.isNotEmpty && p.ultimoQueCapturo != null) {
    JugadorCasita? dueno;
    for (final j in p.jugadoresActivos) {
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
  for (final j in p.jugadoresActivos) {
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
  } else if (empatados.isEmpty) {
    p.ganador = null;
    p.mensajeFin = 'Nadie quedó en pie.';
  } else {
    p.ganador = null;
    p.mensajeFin =
        'Empate a $maxCartas cartas: ${empatados.join(' y ')}.';
  }
}

/// Marca [nombre] como rendido. Si queda uno en pie, gana por abandono.
String? rendirseCasita(PartidaCasita p, String nombre) {
  final idx = p.jugadores.indexWhere(
    (j) => j.nombre == nombre && !j.rendido,
  );
  if (idx < 0 || p.terminada) return null;

  final j = p.jugadores[idx];
  j.rendido = true;
  j.mano.clear();
  // Su casita queda fuera de juego.
  j.pozo.clear();

  final activos = p.jugadoresActivos;
  if (activos.length <= 1) {
    p.fase = FaseCasita.terminada;
    if (activos.isEmpty) {
      p.ganador = null;
      p.mensajeFin = '$nombre se rindió.';
      return null;
    }
    final ganador = activos.first.nombre;
    p.ganador = ganador;
    p.mensajeFin = '$nombre se rindió. ¡$ganador gana por abandono!';
    return ganador;
  }

  if (p.jugadorActual.rendido || p.jugadorActual.nombre == nombre) {
    _avanzarTurno(p);
  }
  return null;
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
///
/// - [forzarTirar]: deja la carta en la mesa.
/// - [robarCasita]: roba la casita del rival (la cima debe coincidir).
/// - [mesaElegida]: captura esas cartas de la mesa (mismo número).
String? jugarCartaCasita(
  PartidaCasita p, {
  required int indiceEnMano,
  List<CartaCasita>? mesaElegida,
  bool robarCasita = false,
  bool forzarTirar = false,
}) {
  if (p.terminada) return 'La partida ya terminó.';
  if (p.fase != FaseCasita.jugando) return 'No se puede jugar ahora.';
  final yo = p.jugadorActual;
  if (yo.rendido) return '${yo.nombre} ya se rindió.';
  if (indiceEnMano < 0 || indiceEnMano >= yo.mano.length) {
    return 'Carta inválida.';
  }

  final carta = yo.mano[indiceEnMano];
  final rival = p.rivalActual;

  if (forzarTirar) {
    yo.mano.removeAt(indiceEnMano);
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

  if (robarCasita) {
    if (!puedeRobarCasita(carta, rival)) {
      return 'No podés robar esa casita con esta carta.';
    }
    yo.mano.removeAt(indiceEnMano);
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

  final elegidas = mesaElegida ?? const <CartaCasita>[];
  if (elegidas.isEmpty) {
    return 'Elegí carta(s) de la mesa del mismo número, o tirala.';
  }
  for (final c in elegidas) {
    if (c.numero != carta.numero) {
      return 'Las cartas a capturar deben tener el mismo número.';
    }
    if (!p.mesa.contains(c)) {
      return 'Esa carta ya no está en la mesa.';
    }
  }

  yo.mano.removeAt(indiceEnMano);
  for (final c in elegidas) {
    p.mesa.remove(c);
  }
  yo.pozo.addAll(elegidas);
  yo.pozo.add(carta);
  p.ultimoQueCapturo = yo.nombre;
  p.ultimaJugada = UltimaJugadaCasita(
    jugador: yo.nombre,
    carta: carta,
    tipo: TipoJugadaCasita.capturaMesa,
    cartasCapturadas: List.of(elegidas),
  );
  _avanzarTurno(p);
  _repartirManosSiCorresponde(p);
  return null;
}

/// Plan de jugada de la PC (sin ejecutar).
class JugadaPcCasita {
  const JugadaPcCasita({
    required this.indiceMano,
    this.mesaElegida = const [],
    this.robarCasita = false,
    this.tirar = false,
  });

  final int indiceMano;
  final List<CartaCasita> mesaElegida;
  final bool robarCasita;
  final bool tirar;

  bool get esCaptura => !tirar;
}

/// Elige qué haría la PC sin mutar la partida.
JugadaPcCasita? planificarJugadaPcCasita(PartidaCasita p, [math.Random? rng]) {
  if (p.terminada || !p.contraPc) return null;
  if (p.jugadorActual.nombre != 'PC') return null;
  final r = rng ?? math.Random();
  final yo = p.jugadorActual;
  final rival = p.rivalActual;
  if (yo.mano.isEmpty) return null;

  for (var i = 0; i < yo.mano.length; i++) {
    if (puedeRobarCasita(yo.mano[i], rival)) {
      return JugadaPcCasita(indiceMano: i, robarCasita: true);
    }
  }

  var mejorIdx = -1;
  var mejorCant = 0;
  List<CartaCasita> mejores = const [];
  for (var i = 0; i < yo.mano.length; i++) {
    final n = yo.mano[i].numero;
    final match = [for (final c in p.mesa) if (c.numero == n) c];
    if (match.length > mejorCant) {
      mejorCant = match.length;
      mejorIdx = i;
      mejores = match;
    }
  }
  if (mejorIdx >= 0) {
    return JugadaPcCasita(indiceMano: mejorIdx, mesaElegida: mejores);
  }

  return JugadaPcCasita(
    indiceMano: r.nextInt(yo.mano.length),
    tirar: true,
  );
}

/// IA simple: prioriza robo de casita, luego captura, luego tira.
void jugarTurnoPcCasita(PartidaCasita p, [math.Random? rng]) {
  final plan = planificarJugadaPcCasita(p, rng);
  if (plan == null) return;
  if (plan.tirar) {
    jugarCartaCasita(p, indiceEnMano: plan.indiceMano, forzarTirar: true);
  } else if (plan.robarCasita) {
    jugarCartaCasita(p, indiceEnMano: plan.indiceMano, robarCasita: true);
  } else {
    jugarCartaCasita(
      p,
      indiceEnMano: plan.indiceMano,
      mesaElegida: plan.mesaElegida,
    );
  }
}
