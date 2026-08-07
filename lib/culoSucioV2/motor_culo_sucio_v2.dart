import 'dart:math' as math;

/// Culo sucio v2 — mazo de 45 (sin comodines; solo el 1 de oro entre los ases).
/// Se descartan pares del mismo número; quien se queda con el 1 de oro pierde.

enum PaloCuloSucioV2 { oro, copa, espada, basto }

enum FaseCuloSucioV2 { descartandoPares, jugando, terminada }

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

  String nombre;
  final List<CartaCuloSucioV2> mano = [];
  /// Pares descartados (cartas sueltas, de a pares).
  final List<CartaCuloSucioV2> descartes = [];
  /// Ya terminó de sacar pares al inicio.
  bool paresInicialesListos = false;
  /// Se rindió (multijugador local): queda fuera de la partida.
  bool rendido = false;

  bool get sinCartas => mano.isEmpty;
}

class PartidaCuloSucioV2 {
  PartidaCuloSucioV2({
    required this.jugadores,
    this.indiceTurno = 0,
    this.fase = FaseCuloSucioV2.descartandoPares,
    this.perdedor,
    this.ganador,
    this.mensajeFin,
    this.contraPc = false,
    this.online = false,
    this.ultimaRobada,
    this.ultimaRobadaDe,
    this.ultimaRobadaPor,
    this.ultimoPar,
  });

  final List<JugadorCuloSucioV2> jugadores;
  int indiceTurno;
  FaseCuloSucioV2 fase;
  String? perdedor;
  String? ganador;
  String? mensajeFin;
  final bool contraPc;
  /// Online: los pares iniciales se sacan en paralelo (cada uno en su dispositivo).
  final bool online;
  CartaCuloSucioV2? ultimaRobada;
  /// De quién se robó [ultimaRobada] (nombre).
  String? ultimaRobadaDe;
  /// Quién robó [ultimaRobada] (nombre).
  String? ultimaRobadaPor;
  /// Último par descartado (2 cartas), si hubo.
  List<CartaCuloSucioV2>? ultimoPar;

  bool get terminada => fase == FaseCuloSucioV2.terminada;
  bool get descartandoPares => fase == FaseCuloSucioV2.descartandoPares;
  bool get enJuego => fase == FaseCuloSucioV2.jugando;

  List<JugadorCuloSucioV2> get jugadoresActivos => [
        for (final j in jugadores)
          if (!j.rendido) j,
      ];

  JugadorCuloSucioV2 get jugadorActual =>
      jugadores[indiceTurno % jugadores.length];

  JugadorCuloSucioV2 get rivalActual {
    final yo = indiceTurno % jugadores.length;
    for (var i = 1; i < jugadores.length; i++) {
      final j = jugadores[(yo + i) % jugadores.length];
      if (!j.rendido && !j.sinCartas) return j;
    }
    return jugadores[(yo + 1) % jugadores.length];
  }
}

/// 12×4 − 1 de copa/espada/basto = 45.
List<CartaCuloSucioV2> crearMazoCuloSucioV2([math.Random? rng]) {
  final r = rng ?? math.Random();
  final mazo = <CartaCuloSucioV2>[
    for (final palo in PaloCuloSucioV2.values)
      for (var n = 1; n <= 12; n++)
        if (!(n == 1 && palo != PaloCuloSucioV2.oro))
          CartaCuloSucioV2(numero: n, palo: palo),
  ];
  assert(mazo.length == 45, 'Mazo v2 debe tener 45 cartas, tiene ${mazo.length}');
  // Mezclar y ubicar el 1 de oro en un índice al azar.
  final idxCulo = mazo.indexWhere((c) => c.esCuloSucio);
  assert(idxCulo >= 0, 'El mazo debe incluir el 1 de oro');
  final culoSucio = mazo.removeAt(idxCulo);
  mazo.shuffle(r);
  mazo.insert(r.nextInt(mazo.length + 1), culoSucio);
  return mazo;
}

bool manoTieneParCuloSucioV2(List<CartaCuloSucioV2> mano) {
  final vistos = <int>{};
  for (final c in mano) {
    if (!vistos.add(c.numero)) return true;
  }
  return false;
}

/// Descarta de [mano] todos los pares posibles (mismo número, distinto palo).
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
  if (p.terminada || p.descartandoPares) return;

  final enPie = p.jugadoresActivos;
  if (enPie.length <= 1) {
    p.fase = FaseCuloSucioV2.terminada;
    if (enPie.isEmpty) {
      p.mensajeFin = 'Todos se rindieron.';
      return;
    }
    final ganador = enPie.first;
    p.ganador = ganador.nombre;
    final rendidos = [
      for (final j in p.jugadores)
        if (j.rendido) j.nombre,
    ];
    p.perdedor = rendidos.isEmpty ? null : rendidos.last;
    p.mensajeFin =
        '¡${p.ganador} gana por abandono!';
    return;
  }

  final conCartas = [
    for (final j in enPie)
      if (!j.sinCartas) j,
  ];
  if (conCartas.length > 1) return;

  p.fase = FaseCuloSucioV2.terminada;
  if (conCartas.isEmpty) {
    p.mensajeFin = 'Empate raro: nadie tiene cartas.';
    return;
  }
  final perdedor = conCartas.first;
  p.perdedor = perdedor.nombre;
  final otros = [
    for (final j in enPie)
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
    final actual = p.jugadorActual;
    if (actual.rendido || actual.sinCartas) continue;
    if (!p.rivalActual.sinCartas && !p.rivalActual.rendido) {
      return;
    }
    final conCartas = p.jugadoresActivos.where((j) => !j.sinCartas).length;
    if (conCartas <= 1) {
      _chequearFin(p);
      return;
    }
  }
  _chequearFin(p);
}

/// Marca [nombre] como rendido. Si queda uno en pie, gana por abandono.
String? rendirseCuloSucioV2(PartidaCuloSucioV2 p, String nombre) {
  final idx = p.jugadores.indexWhere(
    (j) => j.nombre == nombre && !j.rendido,
  );
  if (idx < 0 || p.terminada) return null;

  final j = p.jugadores[idx];
  final teniaCulo = j.mano.any((c) => c.esCuloSucio);
  final culo = teniaCulo
      ? j.mano.firstWhere((c) => c.esCuloSucio)
      : null;
  j.rendido = true;
  j.mano.clear();
  j.paresInicialesListos = true;

  final activos = p.jugadoresActivos;
  if (activos.length <= 1) {
    p.fase = FaseCuloSucioV2.terminada;
    if (activos.isEmpty) {
      p.ganador = null;
      p.perdedor = nombre;
      p.mensajeFin = '$nombre se rindió.';
      return null;
    }
    final ganador = activos.first.nombre;
    p.ganador = ganador;
    p.perdedor = nombre;
    p.mensajeFin = '$nombre se rindió. ¡$ganador gana por abandono!';
    return ganador;
  }

  // Si se llevaba el 1 de oro, pasa a otro jugador en pie al azar.
  if (culo != null) {
    final destino = activos[math.Random().nextInt(activos.length)];
    destino.mano.insert(
      math.Random().nextInt(destino.mano.length + 1),
      culo,
    );
  }

  if (p.descartandoPares) {
    _siguienteTrasParesIniciales(p);
  } else if (p.enJuego) {
    if (p.jugadorActual.rendido || p.jugadorActual.nombre == nombre) {
      _avanzarTurno(p);
    }
    _chequearFin(p);
  }
  return null;
}

void _iniciarFaseJuego(PartidaCuloSucioV2 p) {
  p.fase = FaseCuloSucioV2.jugando;
  var maxMano = -1;
  var idxInicio = 0;
  for (var k = 0; k < p.jugadores.length; k++) {
    if (p.jugadores[k].mano.length > maxMano) {
      maxMano = p.jugadores[k].mano.length;
      idxInicio = k;
    }
  }
  p.indiceTurno = idxInicio;
  _chequearFin(p);
}

/// Avanza al siguiente que deba sacar pares, o arranca el juego.
void _siguienteTrasParesIniciales(PartidaCuloSucioV2 p) {
  final pendientes = [
    for (final j in p.jugadores)
      if (!j.rendido && !j.paresInicialesListos) j,
  ];
  if (pendientes.isEmpty) {
    _iniciarFaseJuego(p);
    return;
  }
  // Preferir humanos antes que PC en vs PC.
  JugadorCuloSucioV2? humano;
  for (final j in pendientes) {
    if (j.nombre != 'PC') {
      humano = j;
      break;
    }
  }
  final siguiente = humano ?? pendientes.first;
  p.indiceTurno = p.jugadores.indexOf(siguiente);

  // Si es la PC, descarta sola y sigue.
  if (siguiente.nombre == 'PC' && p.contraPc) {
    siguiente.descartes.addAll(descartarParesDeMano(siguiente.mano));
    siguiente.paresInicialesListos = true;
    p.ultimoPar = null;
    _siguienteTrasParesIniciales(p);
  }
}

PartidaCuloSucioV2 nuevaPartidaCuloSucioV2({
  required List<String> nombres,
  bool contraPc = false,
  bool online = false,
  math.Random? rng,
}) {
  final lista = nombres.isEmpty
      ? <String>['Jugador 1', 'Jugador 2']
      : List<String>.from(nombres);
  while (lista.length < 2) {
    lista.add('Jugador ${lista.length + 1}');
  }
  // Por ahora el UI está pensado para 2; si hay más nombres, todos juegan
  // y el culo sucio se reparte con la misma chance para cada uno.
  final jugadores = [
    for (final n in lista) JugadorCuloSucioV2(n),
  ];
  final r = rng ?? math.Random();
  final mazo = crearMazoCuloSucioV2(r);

  // Separar el 1 de oro y asignarlo con probabilidad 1/N a cada jugador.
  final idxCulo = mazo.indexWhere((c) => c.esCuloSucio);
  assert(idxCulo >= 0, 'El mazo debe incluir el 1 de oro');
  final culoSucio = mazo.removeAt(idxCulo);

  var i = 0;
  while (mazo.isNotEmpty) {
    jugadores[i % jugadores.length].mano.add(mazo.removeLast());
    i++;
  }

  final duenoCulo = r.nextInt(jugadores.length);
  final manoDueno = jugadores[duenoCulo].mano;
  // Insertar en posición aleatoria (no siempre al final).
  manoDueno.insert(r.nextInt(manoDueno.length + 1), culoSucio);
  for (final j in jugadores) {
    j.mano.shuffle(r);
  }

  final p = PartidaCuloSucioV2(
    jugadores: jugadores,
    contraPc: contraPc,
    online: online,
    fase: FaseCuloSucioV2.descartandoPares,
  );
  // Empieza a descartar pares el humano (vs PC) o el jugador 0.
  if (contraPc) {
    final idxHumano = jugadores.indexWhere((j) => j.nombre != 'PC');
    p.indiceTurno = idxHumano >= 0 ? idxHumano : 0;
  } else {
    p.indiceTurno = 0;
  }
  return p;
}

bool _jugadorPuedeDescartarParesIniciales(
  PartidaCuloSucioV2 p,
  JugadorCuloSucioV2 jugador,
) {
  if (p.fase != FaseCuloSucioV2.descartandoPares) return false;
  if (jugador.rendido) return false;
  if (jugador.paresInicialesListos) return false;
  // Online: cada uno en su dispositivo, en paralelo.
  if (p.online) return true;
  // Vs PC y local hot-seat: solo el turno actual.
  return identical(jugador, p.jugadorActual);
}

/// Descarta un par elegido a mano (misma fase inicial o tras robar no aplica).
String? descartarParManualCuloSucioV2(
  PartidaCuloSucioV2 p, {
  required JugadorCuloSucioV2 jugador,
  required int indiceA,
  required int indiceB,
}) {
  if (p.fase != FaseCuloSucioV2.descartandoPares) {
    return 'Ahora no se descartan pares iniciales.';
  }
  if (!_jugadorPuedeDescartarParesIniciales(p, jugador)) {
    return jugador.paresInicialesListos
        ? 'Ya confirmaste tus pares.'
        : 'No es el turno de ${jugador.nombre} para sacar pares.';
  }
  if (indiceA == indiceB) return 'Elegí dos cartas distintas.';
  if (indiceA < 0 ||
      indiceB < 0 ||
      indiceA >= jugador.mano.length ||
      indiceB >= jugador.mano.length) {
    return 'Carta inválida.';
  }
  final a = jugador.mano[indiceA];
  final b = jugador.mano[indiceB];
  if (a.numero != b.numero) {
    return 'Las cartas deben tener el mismo número.';
  }
  final hi = indiceA > indiceB ? indiceA : indiceB;
  final lo = indiceA > indiceB ? indiceB : indiceA;
  final c1 = jugador.mano.removeAt(hi);
  final c2 = jugador.mano.removeAt(lo);
  jugador.descartes.addAll([c1, c2]);
  p.ultimoPar = [c1, c2];
  p.ultimaRobada = null;
  p.ultimaRobadaDe = null;
  p.ultimaRobadaPor = null;
  return null;
}

/// Descarta de golpe todos los pares de la mano (fase inicial).
String? descartarTodosParesInicialesCuloSucioV2(
  PartidaCuloSucioV2 p, {
  JugadorCuloSucioV2? jugador,
}) {
  if (p.fase != FaseCuloSucioV2.descartandoPares) {
    return 'Ahora no se descartan pares iniciales.';
  }
  final j = jugador ?? p.jugadorActual;
  if (!_jugadorPuedeDescartarParesIniciales(p, j)) {
    return j.paresInicialesListos
        ? 'Ya confirmaste tus pares.'
        : 'No es el turno de ${j.nombre} para sacar pares.';
  }
  final sacadas = descartarParesDeMano(j.mano);
  if (sacadas.isEmpty) {
    return 'No hay pares para eliminar.';
  }
  j.descartes.addAll(sacadas);
  p.ultimoPar = [
    sacadas[sacadas.length - 2],
    sacadas[sacadas.length - 1],
  ];
  p.ultimaRobada = null;
  p.ultimaRobadaDe = null;
  p.ultimaRobadaPor = null;
  return null;
}

/// Confirma que el jugador ya no tiene más pares iniciales.
String? confirmarParesInicialesListos(
  PartidaCuloSucioV2 p, {
  JugadorCuloSucioV2? jugador,
}) {
  if (p.fase != FaseCuloSucioV2.descartandoPares) {
    return 'La fase de pares ya terminó.';
  }
  final j = jugador ?? p.jugadorActual;
  if (!_jugadorPuedeDescartarParesIniciales(p, j)) {
    return j.paresInicialesListos
        ? 'Ya confirmaste tus pares.'
        : 'No es el turno de ${j.nombre} para confirmar pares.';
  }
  if (manoTieneParCuloSucioV2(j.mano)) {
    return 'Todavía tenés pares. Tocá dos cartas del mismo número.';
  }
  j.paresInicialesListos = true;
  _siguienteTrasParesIniciales(p);
  return null;
}

/// [hacia] roba la carta en [indiceEnManoDe] de [de].
///
/// Si [autoDescartarPar] es false y se forma un par, no lo saca ni avanza turno;
/// escribe los índices del par en [parPendienteOut] para que el jugador lo confirme.
///
/// Si [dejarParEnMano] es true, no descarta ni pausa por par: la carta queda
/// en la mano y el turno avanza.
String? robarCartaCuloSucioV2(
  PartidaCuloSucioV2 p, {
  required JugadorCuloSucioV2 de,
  required int indiceEnManoDe,
  required JugadorCuloSucioV2 hacia,
  bool autoDescartarPar = true,
  bool dejarParEnMano = false,
  List<int>? parPendienteOut,
}) {
  if (p.terminada) return 'La partida ya terminó.';
  if (p.fase != FaseCuloSucioV2.jugando) {
    return 'Primero descartá los pares de tu mano.';
  }
  if (hacia != p.jugadorActual) return 'No es el turno de ${hacia.nombre}.';
  if (hacia.rendido) return '${hacia.nombre} ya se rindió.';
  if (de.rendido) return '${de.nombre} ya se rindió.';
  if (de.sinCartas) return '${de.nombre} no tiene cartas.';
  if (indiceEnManoDe < 0 || indiceEnManoDe >= de.mano.length) {
    return 'Carta inválida.';
  }
  if (identical(de, hacia)) return 'No podés robarte a vos mismo.';

  final carta = de.mano.removeAt(indiceEnManoDe);
  hacia.mano.add(carta);
  p.ultimaRobada = carta;
  p.ultimaRobadaDe = de.nombre;
  p.ultimaRobadaPor = hacia.nombre;
  p.ultimoPar = null;

  if (!dejarParEnMano) {
    final mismoNumero = [
      for (var i = 0; i < hacia.mano.length; i++)
        if (hacia.mano[i].numero == carta.numero) i,
    ];
    if (mismoNumero.length >= 2) {
      final idxRobada = hacia.mano.indexOf(carta);
      final idxPar = mismoNumero.firstWhere(
        (i) => i != idxRobada,
        orElse: () => -1,
      );
      if (idxPar >= 0) {
        if (!autoDescartarPar) {
          parPendienteOut
            ?..clear()
            ..add(idxRobada)
            ..add(idxPar);
          _chequearFin(p);
          return null;
        }
        final a = idxRobada > idxPar ? idxRobada : idxPar;
        final b = idxRobada > idxPar ? idxPar : idxRobada;
        final c1 = hacia.mano.removeAt(a);
        final c2 = hacia.mano.removeAt(b);
        hacia.descartes.addAll([c1, c2]);
        p.ultimoPar = [c1, c2];
      }
    }
  }

  _chequearFin(p);
  if (!p.terminada) {
    _avanzarTurno(p);
    _chequearFin(p);
  }
  return null;
}

/// Mueve el 1 de oro dentro de la mano del jugador de turno (sin avanzar turno).
/// [hacia] es el índice destino en la mano actual (antes de quitar [desde]).
String? moverCuloSucioEnManoCuloSucioV2(
  PartidaCuloSucioV2 p, {
  required JugadorCuloSucioV2 jugador,
  required int desde,
  required int hacia,
}) {
  if (p.terminada) return 'La partida ya terminó.';
  if (p.fase != FaseCuloSucioV2.jugando) {
    return 'Solo podés mover el 1 de oro durante el juego.';
  }
  if (!identical(jugador, p.jugadorActual)) {
    return 'No es el turno de ${jugador.nombre}.';
  }
  final n = jugador.mano.length;
  if (desde < 0 || desde >= n) return 'Carta inválida.';
  if (!jugador.mano[desde].esCuloSucio) {
    return 'Solo podés mover el 1 de oro.';
  }
  if (hacia < 0 || hacia >= n) return 'Posición inválida.';
  if (desde == hacia) return null;

  final carta = jugador.mano.removeAt(desde);
  var insertAt = hacia;
  if (insertAt > desde) insertAt -= 1;
  jugador.mano.insert(insertAt, carta);
  return null;
}

/// Descarta un par tras un robo (fase de juego) y avanza el turno.
String? descartarParTrasRoboCuloSucioV2(
  PartidaCuloSucioV2 p, {
  required JugadorCuloSucioV2 jugador,
  required int indiceA,
  required int indiceB,
}) {
  if (p.terminada) return 'La partida ya terminó.';
  if (p.fase != FaseCuloSucioV2.jugando) {
    return 'Ahora no se descarta un par de robo.';
  }
  if (!identical(jugador, p.jugadorActual)) {
    return 'No es el turno de ${jugador.nombre}.';
  }
  if (indiceA == indiceB) return 'Elegí dos cartas distintas.';
  if (indiceA < 0 ||
      indiceB < 0 ||
      indiceA >= jugador.mano.length ||
      indiceB >= jugador.mano.length) {
    return 'Carta inválida.';
  }
  final a = jugador.mano[indiceA];
  final b = jugador.mano[indiceB];
  if (a.numero != b.numero) {
    return 'Las cartas deben tener el mismo número.';
  }
  final hi = indiceA > indiceB ? indiceA : indiceB;
  final lo = indiceA > indiceB ? indiceB : indiceA;
  final c1 = jugador.mano.removeAt(hi);
  final c2 = jugador.mano.removeAt(lo);
  jugador.descartes.addAll([c1, c2]);
  p.ultimoPar = [c1, c2];
  p.ultimaRobada = null;
  p.ultimaRobadaDe = null;
  p.ultimaRobadaPor = null;

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
  if (p.fase != FaseCuloSucioV2.jugando) return;
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
