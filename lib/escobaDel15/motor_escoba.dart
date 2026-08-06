import 'dart:math' as math;

/// Escoba del 15 — mazo español de 40 (sin 8, 9 ni comodines).
/// Valores para sumar 15: 10→8, 11→9, 12→10.

enum PaloEscoba { oro, copa, espada, basto }

enum FaseEscoba { jugando, finRonda, ganado }

class CartaEscoba {
  const CartaEscoba({required this.numero, required this.palo});

  /// 1–7, 10, 11 o 12.
  final int numero;
  final PaloEscoba palo;

  /// Valor para sumar 15.
  int get valorSuma => switch (numero) {
        10 => 8,
        11 => 9,
        12 => 10,
        _ => numero,
      };

  String get nombrePalo => switch (palo) {
        PaloEscoba.oro => 'oro',
        PaloEscoba.copa => 'copa',
        PaloEscoba.espada => 'espada',
        PaloEscoba.basto => 'basto',
      };

  /// Texto crudo sin skin: "1 de espada", "12 de copa".
  String get etiqueta => '$numero de $nombrePalo';

  bool get esOro => palo == PaloEscoba.oro;

  @override
  bool operator ==(Object other) =>
      other is CartaEscoba && other.numero == numero && other.palo == palo;

  @override
  int get hashCode => Object.hash(numero, palo);

  @override
  String toString() => etiqueta;
}

class JugadorEscoba {
  JugadorEscoba(this.nombre);

  String nombre;
  final List<CartaEscoba> mano = [];
  final List<CartaEscoba> capturadas = [];
  /// Combos de captura de la ronda (o de la anterior hasta la 1ª jugada).
  final List<ComboCapturaEscoba> combos = [];
  int escobasRonda = 0;
  int puntos = 0;
  bool rendido = false;
}

/// Una captura (o el pozo final) hecha por un jugador.
class ComboCapturaEscoba {
  const ComboCapturaEscoba({
    required this.cartas,
    this.escoba = false,
    this.esPozoFinal = false,
  });

  /// Carta de la mano + cartas de mesa (o solo pozo final).
  final List<CartaEscoba> cartas;
  final bool escoba;
  final bool esPozoFinal;

  String get resumen => cartas.map((c) => c.etiqueta).join(' + ');
}

class PartidaEscoba {
  PartidaEscoba({
    required this.jugadores,
    this.objetivo = 15,
    this.indiceTurno = 0,
    this.fase = FaseEscoba.jugando,
    List<CartaEscoba>? mazo,
    List<CartaEscoba>? mesa,
    this.ultimaCapturaIdx,
    this.mensajeFin,
    this.ganador,
    this.reiniciarCombosEnProximaJugada = false,
  })  : mazo = mazo ?? [],
        mesa = mesa ?? [];

  final List<JugadorEscoba> jugadores;
  final int objetivo;
  final List<CartaEscoba> mazo;
  final List<CartaEscoba> mesa;
  int indiceTurno;
  FaseEscoba fase;
  /// Quién hizo la última captura (cartas restantes de mesa al final).
  int? ultimaCapturaIdx;
  String? mensajeFin;
  String? ganador;
  ResultadoRondaEscoba? ultimoResultado;
  /// Tras repartir una ronda nueva, los combos se ven hasta la 1ª jugada.
  bool reiniciarCombosEnProximaJugada;

  JugadorEscoba get jugadorActual =>
      jugadores[indiceTurno % jugadores.length];

  List<JugadorEscoba> get jugadoresActivos =>
      jugadores.where((j) => !j.rendido).toList();

  bool get terminada => fase == FaseEscoba.ganado;
}

List<CartaEscoba> crearMazoEscoba() {
  const numeros = [1, 2, 3, 4, 5, 6, 7, 10, 11, 12];
  return [
    for (final palo in PaloEscoba.values)
      for (final n in numeros) CartaEscoba(numero: n, palo: palo),
  ];
}

void barajarEscoba(List<CartaEscoba> mazo, [math.Random? rng]) {
  final r = rng ?? math.Random();
  for (var i = mazo.length - 1; i > 0; i--) {
    final j = r.nextInt(i + 1);
    final tmp = mazo[i];
    mazo[i] = mazo[j];
    mazo[j] = tmp;
  }
}

PartidaEscoba nuevaPartidaEscoba({
  required List<String> nombres,
  int objetivo = 15,
  math.Random? rng,
}) {
  assert(nombres.length >= 2 && nombres.length <= 4);
  final jugadores = [for (final n in nombres) JugadorEscoba(n)];
  final mazo = crearMazoEscoba();
  barajarEscoba(mazo, rng);
  final p = PartidaEscoba(jugadores: jugadores, objetivo: objetivo, mazo: mazo);
  _repartirInicio(p);
  return p;
}

/// Quita [carta] de mazo, mesa y manos (no de capturadas: ya salieron de juego).
bool extraerCartaEscoba(PartidaEscoba p, CartaEscoba carta) {
  if (p.mazo.remove(carta)) return true;
  if (p.mesa.remove(carta)) return true;
  for (final j in p.jugadores) {
    if (j.mano.remove(carta)) return true;
  }
  return false;
}

/// Completa [elegidas] hasta [cupo] con cartas al azar no usadas en [ocupadas].
List<CartaEscoba> completarCartasEscobaConAzar(
  List<CartaEscoba> elegidas,
  int cupo, {
  Set<CartaEscoba> ocupadas = const {},
  math.Random? rng,
}) {
  final out = <CartaEscoba>[];
  for (final c in elegidas) {
    if (out.length >= cupo) break;
    if (!out.contains(c)) out.add(c);
  }
  if (out.length >= cupo) return out;

  final r = rng ?? math.Random();
  final pool = [
    for (final c in crearMazoEscoba())
      if (!out.contains(c) && !ocupadas.contains(c)) c,
  ];
  for (var i = pool.length - 1; i > 0; i--) {
    final j = r.nextInt(i + 1);
    final tmp = pool[i];
    pool[i] = pool[j];
    pool[j] = tmp;
  }
  for (final c in pool) {
    if (out.length >= cupo) break;
    out.add(c);
  }
  return out;
}

/// Reemplaza la mesa. Las cartas anteriores vuelven al mazo.
void forzarMesaEscoba(PartidaEscoba p, List<CartaEscoba> cartas) {
  p.mazo.addAll(p.mesa);
  p.mesa.clear();
  for (final c in cartas) {
    extraerCartaEscoba(p, c);
    p.mesa.add(c);
  }
}

/// Reemplaza la mano del jugador [idx].
void forzarManoEscoba(PartidaEscoba p, int idx, List<CartaEscoba> cartas) {
  assert(idx >= 0 && idx < p.jugadores.length);
  final j = p.jugadores[idx];
  p.mazo.addAll(j.mano);
  j.mano.clear();
  for (final c in cartas) {
    extraerCartaEscoba(p, c);
    j.mano.add(c);
  }
}

void _repartirInicio(PartidaEscoba p) {
  final esNuevaRondaTrasFin = p.fase == FaseEscoba.finRonda;
  for (final j in p.jugadores) {
    j.mano.clear();
    j.capturadas.clear();
    j.escobasRonda = 0;
    // Los combos se conservan hasta la primera jugada de la nueva ronda.
    if (!esNuevaRondaTrasFin) {
      j.combos.clear();
    }
  }
  p.mesa.clear();
  p.ultimaCapturaIdx = null;
  p.reiniciarCombosEnProximaJugada = esNuevaRondaTrasFin;
  for (var i = 0; i < 3; i++) {
    for (final j in p.jugadores) {
      if (j.rendido) continue;
      if (p.mazo.isEmpty) break;
      j.mano.add(p.mazo.removeLast());
    }
  }
  for (var i = 0; i < 4; i++) {
    if (p.mazo.isEmpty) break;
    p.mesa.add(p.mazo.removeLast());
  }
  p.fase = FaseEscoba.jugando;
}

/// Resultado de las escobas automáticas al revelar la mesa inicial.
class ResultadoEscobasInicioEscoba {
  const ResultadoEscobasInicioEscoba({
    required this.dosParesEscoba,
    required this.mesaSuma15,
    required this.nombreBeneficiario,
    required this.escobasOtorgadas,
  });

  /// Par izquierdo y par derecho suman 15 cada uno → 2 escobas y mesa vacía.
  final bool dosParesEscoba;

  /// Las 4 cartas suman 15 → +1 escoba (quedan en la mesa).
  final bool mesaSuma15;
  final String nombreBeneficiario;
  final int escobasOtorgadas;
}

/// Aplica escobas automáticas sobre la mesa ya repartida (4 cartas).
///
/// - Izquierda (0+1) y derecha (2+3) = 15 → el jugador de turno se lleva
///   ambos pares como escobas.
/// - Las 4 suman 15 → ese jugador suma 1 escoba (cartas quedan).
ResultadoEscobasInicioEscoba? aplicarEscobasAutomaticasInicio(PartidaEscoba p) {
  if (p.mesa.length != 4) return null;
  final m = List<CartaEscoba>.from(p.mesa);
  final izq = m[0].valorSuma + m[1].valorSuma;
  final der = m[2].valorSuma + m[3].valorSuma;
  final total = m.fold<int>(0, (s, c) => s + c.valorSuma);
  final idx = p.indiceTurno % p.jugadores.length;
  final j = p.jugadores[idx];

  if (izq == 15 && der == 15) {
    j.capturadas.addAll(m);
    j.combos.add(ComboCapturaEscoba(cartas: [m[0], m[1]], escoba: true));
    j.combos.add(ComboCapturaEscoba(cartas: [m[2], m[3]], escoba: true));
    j.escobasRonda += 2;
    p.mesa.clear();
    p.ultimaCapturaIdx = idx;
    return ResultadoEscobasInicioEscoba(
      dosParesEscoba: true,
      mesaSuma15: false,
      nombreBeneficiario: j.nombre,
      escobasOtorgadas: 2,
    );
  }

  if (total == 15) {
    j.escobasRonda += 1;
    return ResultadoEscobasInicioEscoba(
      dosParesEscoba: false,
      mesaSuma15: true,
      nombreBeneficiario: j.nombre,
      escobasOtorgadas: 1,
    );
  }

  return null;
}

/// Indica si el par izquierdo / derecho de la mesa suma 15 (con 4 cartas).
bool mesaParIzquierdoEsEscoba(List<CartaEscoba> mesa) {
  if (mesa.length < 2) return false;
  return mesa[0].valorSuma + mesa[1].valorSuma == 15;
}

bool mesaParDerechoEsEscoba(List<CartaEscoba> mesa) {
  if (mesa.length < 4) return false;
  return mesa[2].valorSuma + mesa[3].valorSuma == 15;
}

/// Subconjuntos de [mesa] que, sumados a [jugada], dan 15.
List<List<CartaEscoba>> capturasPosiblesEscoba(
  CartaEscoba jugada,
  List<CartaEscoba> mesa,
) {
  final objetivo = 15 - jugada.valorSuma;
  if (objetivo < 0) return const [];
  if (objetivo == 0) {
    // Carta sola vale 15 (no existe en el mazo estándar).
    return const [];
  }
  final out = <List<CartaEscoba>>[];
  final n = mesa.length;
  final total = 1 << n;
  for (var mask = 1; mask < total; mask++) {
    var suma = 0;
    final sub = <CartaEscoba>[];
    for (var i = 0; i < n; i++) {
      if ((mask & (1 << i)) == 0) continue;
      suma += mesa[i].valorSuma;
      if (suma > objetivo) break;
      sub.add(mesa[i]);
    }
    if (suma == objetivo) out.add(sub);
  }
  return out;
}

/// Juega [carta] de la mano. Si hay capturas, [mesaElegida] indica cuáles
/// (null = la única posible, o tira a la mesa si no hay captura).
String? jugarCartaEscoba(
  PartidaEscoba p,
  CartaEscoba carta, {
  List<CartaEscoba>? mesaElegida,
  bool forzarTirar = false,
}) {
  if (p.fase != FaseEscoba.jugando) return 'La partida no está en juego.';
  final j = p.jugadorActual;
  if (j.rendido) return 'Ese jugador ya se rindió.';
  final idx = j.mano.indexOf(carta);
  if (idx < 0) return 'Esa carta no está en tu mano.';

  if (p.reiniciarCombosEnProximaJugada) {
    for (final jug in p.jugadores) {
      jug.combos.clear();
    }
    p.reiniciarCombosEnProximaJugada = false;
  }

  final opciones = capturasPosiblesEscoba(carta, p.mesa);
  if (forzarTirar || opciones.isEmpty) {
    j.mano.removeAt(idx);
    p.mesa.add(carta);
  } else {
    List<CartaEscoba> tomadas;
    if (mesaElegida != null) {
      final ok = opciones.any(
        (o) => _mismasCartas(o, mesaElegida),
      );
      if (!ok) return 'Esa captura no suma 15.';
      tomadas = List.of(mesaElegida);
    } else if (opciones.length == 1) {
      tomadas = List.of(opciones.first);
    } else {
      return 'Elegí qué cartas de la mesa capturar.';
    }
    j.mano.removeAt(idx);
    for (final c in tomadas) {
      p.mesa.remove(c);
      j.capturadas.add(c);
    }
    j.capturadas.add(carta);
    final escoba = p.mesa.isEmpty;
    j.combos.add(
      ComboCapturaEscoba(
        cartas: [carta, ...tomadas],
        escoba: escoba,
      ),
    );
    p.ultimaCapturaIdx = p.indiceTurno % p.jugadores.length;
    if (escoba) {
      j.escobasRonda++;
    }
  }

  _avanzarTrasJugada(p);
  return null;
}

bool _mismasCartas(List<CartaEscoba> a, List<CartaEscoba> b) {
  if (a.length != b.length) return false;
  final ca = List.of(a)..sort((x, y) => x.hashCode.compareTo(y.hashCode));
  final cb = List.of(b)..sort((x, y) => x.hashCode.compareTo(y.hashCode));
  for (var i = 0; i < ca.length; i++) {
    if (ca[i] != cb[i]) return false;
  }
  return true;
}

void _pasarASiguienteActivoEscoba(PartidaEscoba p) {
  final n = p.jugadores.length;
  if (n == 0) return;
  for (var i = 0; i < n; i++) {
    p.indiceTurno = (p.indiceTurno + 1) % n;
    if (!p.jugadores[p.indiceTurno].rendido) return;
  }
}

void _avanzarTrasJugada(PartidaEscoba p) {
  final activos = p.jugadoresActivos;
  final todosVacios = activos.every((j) => j.mano.isEmpty);
  if (!todosVacios) {
    _pasarASiguienteActivoEscoba(p);
    return;
  }

  if (p.mazo.isNotEmpty) {
    // Reparto lo que quede (hasta 3 por jugador activo).
    for (var i = 0; i < 3; i++) {
      for (final j in p.jugadores) {
        if (j.rendido) continue;
        if (p.mazo.isEmpty) break;
        j.mano.add(p.mazo.removeLast());
      }
    }
    if (activos.any((j) => j.mano.isNotEmpty)) {
      _pasarASiguienteActivoEscoba(p);
      return;
    }
  }

  // Fin de ronda: cartas de mesa al último que capturó.
  List<CartaEscoba> cartasPozoFinal = const [];
  int? idxLlevoPozo;
  if (p.mesa.isNotEmpty && p.ultimaCapturaIdx != null) {
    idxLlevoPozo = p.ultimaCapturaIdx;
    cartasPozoFinal = List.of(p.mesa);
    final j = p.jugadores[idxLlevoPozo!];
    j.capturadas.addAll(cartasPozoFinal);
    j.combos.add(
      ComboCapturaEscoba(
        cartas: List.of(cartasPozoFinal),
        esPozoFinal: true,
      ),
    );
    p.mesa.clear();
  }

  puntuarRondaEscoba(
    p,
    cartasPozoFinal: cartasPozoFinal,
    idxLlevoPozo: idxLlevoPozo,
  );
}

/// Marca [nombre] como rendido. Devuelve el ganador si solo queda uno activo.
String? rendirseEscoba(PartidaEscoba p, String nombre) {
  final idx = p.jugadores.indexWhere((j) => j.nombre == nombre && !j.rendido);
  if (idx < 0) return null;
  final j = p.jugadores[idx];
  j.rendido = true;
  // Sus cartas de mano salen de juego (no van a la mesa).
  j.mano.clear();

  final activos = p.jugadoresActivos;
  if (activos.length <= 1) {
    if (activos.isEmpty) {
      p.fase = FaseEscoba.ganado;
      p.ganador = null;
      p.mensajeFin = '$nombre se rindió.';
      return null;
    }
    final ganador = activos.first.nombre;
    p.fase = FaseEscoba.ganado;
    p.ganador = ganador;
    p.mensajeFin = '$nombre se rindió. ¡$ganador gana por abandono!';
    return ganador;
  }

  if (p.jugadorActual.nombre == nombre || p.jugadorActual.rendido) {
    _pasarASiguienteActivoEscoba(p);
  }
  return null;
}

class DetalleJugadorRondaEscoba {
  DetalleJugadorRondaEscoba({
    required this.nombre,
    required this.escobas,
    required this.cartas,
    required this.oros,
    required this.sietes,
    required this.puntosTrasRonda,
  });

  final String nombre;
  final int escobas;
  final List<CartaEscoba> cartas;
  final List<CartaEscoba> oros;
  final List<CartaEscoba> sietes;
  final int puntosTrasRonda;

  int get cantidadCartas => cartas.length;
  int get cantidadOros => oros.length;
  int get cantidadSietes => sietes.length;
  bool get tieneSieteOro =>
      sietes.any((c) => c.palo == PaloEscoba.oro);
}

class ResultadoRondaEscoba {
  ResultadoRondaEscoba({
    required this.puntosEscobas,
    required this.idxMasCartas,
    required this.idxMasOros,
    required this.idxSieteOro,
    required this.idxMasSietes,
    required this.detalles,
    this.empateMasCartas = false,
    this.empateMasOros = false,
    this.empateMasSietes = false,
    this.desempateSietesLineas = const [],
    this.idxLlevoPozo,
    this.cartasPozoFinal = const [],
  });

  final List<int> puntosEscobas;
  final int? idxMasCartas;
  final int? idxMasOros;
  final int? idxSieteOro;
  final int? idxMasSietes;
  final List<DetalleJugadorRondaEscoba> detalles;
  final bool empateMasCartas;
  final bool empateMasOros;
  final bool empateMasSietes;
  /// Texto del desempate de 7s (cartas ≤6 por palo del rival y suma).
  final List<String> desempateSietesLineas;
  /// Quién se llevó las cartas que quedaban en el pozo al cerrar la ronda.
  final int? idxLlevoPozo;
  final List<CartaEscoba> cartasPozoFinal;
}

/// Mejor carta de [capturadas] del [palo] con número 1–6 (debajo del 7).
CartaEscoba? _mejorCartaBajoSiete(
  List<CartaEscoba> capturadas,
  PaloEscoba palo,
) {
  CartaEscoba? mejor;
  for (final c in capturadas) {
    if (c.palo != palo || c.numero >= 7) continue;
    if (mejor == null || c.numero > mejor.numero) mejor = c;
  }
  return mejor;
}

/// Cartas usadas en el desempate de 7s (mejor ≤6 por cada palo del rival).
List<CartaEscoba> _cartasDesempateSietes(
  JugadorEscoba yo,
  Iterable<PaloEscoba> palosRivales,
) {
  final out = <CartaEscoba>[];
  for (final palo in palosRivales) {
    final c = _mejorCartaBajoSiete(yo.capturadas, palo);
    if (c != null) out.add(c);
  }
  return out;
}

Set<PaloEscoba> _palosDeSietes(List<CartaEscoba> capturadas) {
  return {
    for (final c in capturadas)
      if (c.numero == 7) c.palo,
  };
}

int _cantidadSietes(List<CartaEscoba> capturadas) =>
    capturadas.where((c) => c.numero == 7).length;

ResultadoRondaEscoba puntuarRondaEscoba(
  PartidaEscoba p, {
  List<CartaEscoba> cartasPozoFinal = const [],
  int? idxLlevoPozo,
}) {
  final n = p.jugadores.length;
  final escobas = [for (final j in p.jugadores) j.escobasRonda];
  for (var i = 0; i < n; i++) {
    p.jugadores[i].puntos += escobas[i];
  }

  int? idxCartas;
  var maxC = -1;
  var empateC = false;
  for (var i = 0; i < n; i++) {
    final c = p.jugadores[i].capturadas.length;
    if (c > maxC) {
      maxC = c;
      idxCartas = i;
      empateC = false;
    } else if (c == maxC) {
      empateC = true;
    }
  }
  final empateMasCartas = empateC && maxC > 0;
  if (empateC || maxC <= 0) {
    idxCartas = null;
  } else {
    p.jugadores[idxCartas!].puntos += 1;
  }

  int? idxOros;
  var maxO = -1;
  var empateO = false;
  for (var i = 0; i < n; i++) {
    final o = p.jugadores[i].capturadas.where((c) => c.esOro).length;
    if (o > maxO) {
      maxO = o;
      idxOros = i;
      empateO = false;
    } else if (o == maxO) {
      empateO = true;
    }
  }
  final empateMasOros = empateO && maxO > 0;
  if (empateO || maxO <= 0) {
    idxOros = null;
  } else {
    p.jugadores[idxOros!].puntos += 1;
  }

  // 7 de oro.
  int? idxSieteOro;
  for (var i = 0; i < n; i++) {
    if (p.jugadores[i].capturadas.any(
          (c) => c.numero == 7 && c.palo == PaloEscoba.oro,
        )) {
      idxSieteOro = i;
      p.jugadores[i].puntos += 1;
      break;
    }
  }

  // Más 7s (con desempate por cartas ≤6 de los palos del rival).
  int? idxMasSietes;
  var maxS = -1;
  final empatadosS = <int>[];
  for (var i = 0; i < n; i++) {
    final s = _cantidadSietes(p.jugadores[i].capturadas);
    if (s > maxS) {
      maxS = s;
      empatadosS
        ..clear()
        ..add(i);
    } else if (s == maxS) {
      empatadosS.add(i);
    }
  }
  var empateMasSietes = false;
  final desempateSietesLineas = <String>[];
  if (maxS <= 0) {
    idxMasSietes = null;
  } else if (empatadosS.length == 1) {
    idxMasSietes = empatadosS.first;
    p.jugadores[idxMasSietes].puntos += 1;
  } else {
    empateMasSietes = true;
    var mejorDes = -1;
    var idxDes = -1;
    var empateDes = false;
    for (final i in empatadosS) {
      final palosRivales = <PaloEscoba>{
        for (final j in empatadosS)
          if (j != i) ..._palosDeSietes(p.jugadores[j].capturadas),
      };
      final cartas = _cartasDesempateSietes(p.jugadores[i], palosRivales);
      final score = cartas.fold<int>(0, (a, c) => a + c.valorSuma);
      final cartasTxt = cartas.isEmpty
          ? 'sin cartas bajo 7'
          : cartas.map((c) => c.etiqueta).join(' · ');
      desempateSietesLineas.add(
        '${p.jugadores[i].nombre}: $cartasTxt (suma $score)',
      );
      if (score > mejorDes) {
        mejorDes = score;
        idxDes = i;
        empateDes = false;
      } else if (score == mejorDes) {
        empateDes = true;
      }
    }
    if (!empateDes && idxDes >= 0 && mejorDes > 0) {
      idxMasSietes = idxDes;
      empateMasSietes = false;
      p.jugadores[idxMasSietes].puntos += 1;
    } else {
      idxMasSietes = null;
    }
  }

  final detalles = [
    for (final j in p.jugadores)
      DetalleJugadorRondaEscoba(
        nombre: j.nombre,
        escobas: j.escobasRonda,
        cartas: List.of(j.capturadas),
        oros: [for (final c in j.capturadas) if (c.esOro) c],
        sietes: [for (final c in j.capturadas) if (c.numero == 7) c],
        puntosTrasRonda: j.puntos,
      ),
  ];

  final resultado = ResultadoRondaEscoba(
    puntosEscobas: escobas,
    idxMasCartas: idxCartas,
    idxMasOros: idxOros,
    idxSieteOro: idxSieteOro,
    idxMasSietes: idxMasSietes,
    detalles: detalles,
    empateMasCartas: empateMasCartas,
    empateMasOros: empateMasOros,
    empateMasSietes: empateMasSietes,
    desempateSietesLineas: desempateSietesLineas,
    idxLlevoPozo: idxLlevoPozo,
    cartasPozoFinal: cartasPozoFinal,
  );
  p.ultimoResultado = resultado;

  // ¿Alguien activo llegó al objetivo?
  var mejor = -1;
  var idxGanador = -1;
  var empate = false;
  for (var i = 0; i < n; i++) {
    if (p.jugadores[i].rendido) continue;
    final pts = p.jugadores[i].puntos;
    if (pts >= p.objetivo && pts > mejor) {
      mejor = pts;
      idxGanador = i;
      empate = false;
    } else if (pts >= p.objetivo && pts == mejor) {
      empate = true;
    }
  }
  if (idxGanador >= 0 && !empate) {
    p.fase = FaseEscoba.ganado;
    p.ganador = p.jugadores[idxGanador].nombre;
    p.mensajeFin =
        '${p.ganador} llegó a ${p.jugadores[idxGanador].puntos} puntos.';
  } else {
    p.fase = FaseEscoba.finRonda;
  }
  return resultado;
}

/// Empieza una nueva ronda (mismo marcador).
void siguienteRondaEscoba(PartidaEscoba p, [math.Random? rng]) {
  if (p.fase == FaseEscoba.ganado) return;
  final mazo = crearMazoEscoba();
  barajarEscoba(mazo, rng);
  p.mazo
    ..clear()
    ..addAll(mazo);
  _repartirInicio(p);
}

/// Jugada decidida por la PC (para mostrarla antes de ejecutarla).
class JugadaPcEscoba {
  const JugadaPcEscoba({
    required this.carta,
    this.mesaElegida,
  });

  final CartaEscoba carta;
  /// null = tira a la mesa; no vacío = captura esas cartas.
  final List<CartaEscoba>? mesaElegida;

  bool get esCaptura => mesaElegida != null && mesaElegida!.isNotEmpty;

  String get descripcion {
    if (!esCaptura) return 'PC tira ${carta.etiqueta} a la mesa';
    final tomadas = mesaElegida!.map((c) => c.etiqueta).join(' + ');
    return 'PC captura ${carta.etiqueta} + $tomadas = 15';
  }
}

/// Puntúa una captura para la IA: prioriza oros (sobre todo el 7 de oro),
/// escobas, sietes y cantidad de cartas.
int _puntajeCapturaPc(
  CartaEscoba jugada,
  List<CartaEscoba> tomadas,
  List<CartaEscoba> mesa,
) {
  var score = 0;

  void sumarCarta(CartaEscoba c) {
    if (c.esOro) {
      score += 100;
      if (c.numero == 7) score += 500; // 7 de oro vale un punto fijo.
    }
    if (c.numero == 7) score += 50;
    // Cartas de oro “buenas” (no solo el 7).
    if (c.esOro && c.numero != 7) score += 20;
  }

  for (final c in tomadas) {
    sumarCarta(c);
  }
  // La carta jugada también va a capturadas.
  sumarCarta(jugada);

  // Escoba: limpia la mesa.
  if (tomadas.length == mesa.length) score += 200;

  // Preferir llevarse más cartas (ayuda a “más cartas”).
  score += tomadas.length * 10;

  return score;
}

/// Elige qué haría la PC sin modificar la partida.
JugadaPcEscoba? planificarTurnoPcEscoba(PartidaEscoba p) {
  if (p.fase != FaseEscoba.jugando) return null;
  final j = p.jugadorActual;
  if (j.mano.isEmpty) return null;

  JugadaPcEscoba? mejor;
  var mejorScore = -1;

  for (final carta in j.mano) {
    final caps = capturasPosiblesEscoba(carta, p.mesa);
    for (final cap in caps) {
      final score = _puntajeCapturaPc(carta, cap, p.mesa);
      if (mejor == null || score > mejorScore) {
        mejorScore = score;
        mejor = JugadaPcEscoba(carta: carta, mesaElegida: List.of(cap));
      }
    }
  }
  if (mejor != null) return mejor;

  // Sin captura: tira la de menor valor, evitando soltar oros si puede.
  final orden = List.of(j.mano)
    ..sort((a, b) {
      final porOro = (a.esOro ? 1 : 0).compareTo(b.esOro ? 1 : 0);
      if (porOro != 0) return porOro;
      final porSiete = (a.numero == 7 ? 1 : 0).compareTo(b.numero == 7 ? 1 : 0);
      if (porSiete != 0) return porSiete;
      return a.valorSuma.compareTo(b.valorSuma);
    });
  return JugadaPcEscoba(carta: orden.first);
}

/// Jugada de PC: mejor captura (prioriza oros) o tira la carta menos valiosa.
void jugarTurnoPcEscoba(PartidaEscoba p) {
  final jugada = planificarTurnoPcEscoba(p);
  if (jugada == null) return;
  ejecutarJugadaPcEscoba(p, jugada);
}

void ejecutarJugadaPcEscoba(PartidaEscoba p, JugadaPcEscoba jugada) {
  if (jugada.esCaptura) {
    jugarCartaEscoba(p, jugada.carta, mesaElegida: jugada.mesaElegida);
  } else {
    jugarCartaEscoba(p, jugada.carta, forzarTirar: true);
  }
}
