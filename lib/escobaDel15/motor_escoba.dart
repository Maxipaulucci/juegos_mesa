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

  final String nombre;
  final List<CartaEscoba> mano = [];
  final List<CartaEscoba> capturadas = [];
  int escobasRonda = 0;
  int puntos = 0;
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

  JugadorEscoba get jugadorActual =>
      jugadores[indiceTurno % jugadores.length];

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

void _repartirInicio(PartidaEscoba p) {
  for (final j in p.jugadores) {
    j.mano.clear();
    j.capturadas.clear();
    j.escobasRonda = 0;
  }
  p.mesa.clear();
  p.ultimaCapturaIdx = null;
  for (var i = 0; i < 3; i++) {
    for (final j in p.jugadores) {
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
}) {
  if (p.fase != FaseEscoba.jugando) return 'La partida no está en juego.';
  final j = p.jugadorActual;
  final idx = j.mano.indexOf(carta);
  if (idx < 0) return 'Esa carta no está en tu mano.';

  final opciones = capturasPosiblesEscoba(carta, p.mesa);
  if (opciones.isEmpty) {
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
    p.ultimaCapturaIdx = p.indiceTurno % p.jugadores.length;
    if (p.mesa.isEmpty) {
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

void _avanzarTrasJugada(PartidaEscoba p) {
  final todosVacios = p.jugadores.every((j) => j.mano.isEmpty);
  if (!todosVacios) {
    p.indiceTurno = (p.indiceTurno + 1) % p.jugadores.length;
    return;
  }

  if (p.mazo.isNotEmpty) {
    // Reparto lo que quede (hasta 3 por jugador).
    for (var i = 0; i < 3; i++) {
      for (final j in p.jugadores) {
        if (p.mazo.isEmpty) break;
        j.mano.add(p.mazo.removeLast());
      }
    }
    if (p.jugadores.any((j) => j.mano.isNotEmpty)) {
      p.indiceTurno = (p.indiceTurno + 1) % p.jugadores.length;
      return;
    }
  }

  // Fin de ronda: cartas de mesa al último que capturó.
  if (p.mesa.isNotEmpty && p.ultimaCapturaIdx != null) {
    final j = p.jugadores[p.ultimaCapturaIdx!];
    j.capturadas.addAll(p.mesa);
    p.mesa.clear();
  }

  puntuarRondaEscoba(p);
}

class ResultadoRondaEscoba {
  ResultadoRondaEscoba({
    required this.puntosEscobas,
    required this.idxMasCartas,
    required this.idxMasOros,
    required this.idxSieteOro,
    required this.idxMasSietes,
  });

  final List<int> puntosEscobas;
  final int? idxMasCartas;
  final int? idxMasOros;
  final int? idxSieteOro;
  final int? idxMasSietes;
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

/// Desempate de 7s: sumá tu mejor carta ≤6 en cada palo de los 7 del rival.
int _puntajeDesempateSietes(
  JugadorEscoba yo,
  Iterable<PaloEscoba> palosRivales,
) {
  var suma = 0;
  for (final palo in palosRivales) {
    final c = _mejorCartaBajoSiete(yo.capturadas, palo);
    if (c != null) suma += c.valorSuma;
  }
  return suma;
}

Set<PaloEscoba> _palosDeSietes(List<CartaEscoba> capturadas) {
  return {
    for (final c in capturadas)
      if (c.numero == 7) c.palo,
  };
}

int _cantidadSietes(List<CartaEscoba> capturadas) =>
    capturadas.where((c) => c.numero == 7).length;

ResultadoRondaEscoba puntuarRondaEscoba(PartidaEscoba p) {
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
  if (maxS <= 0) {
    idxMasSietes = null;
  } else if (empatadosS.length == 1) {
    idxMasSietes = empatadosS.first;
    p.jugadores[idxMasSietes].puntos += 1;
  } else {
    // Desempate: cada uno mira los palos de los 7 de los demás empatados.
    var mejorDes = -1;
    var idxDes = -1;
    var empateDes = false;
    for (final i in empatadosS) {
      final palosRivales = <PaloEscoba>{
        for (final j in empatadosS)
          if (j != i) ..._palosDeSietes(p.jugadores[j].capturadas),
      };
      final score = _puntajeDesempateSietes(p.jugadores[i], palosRivales);
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
      p.jugadores[idxMasSietes].puntos += 1;
    } else if (!empateDes && idxDes >= 0 && mejorDes == 0) {
      // Todos en 0: nadie (o el primero con 0 único — mejor nadie).
      idxMasSietes = null;
    } else {
      idxMasSietes = null;
    }
  }

  final resultado = ResultadoRondaEscoba(
    puntosEscobas: escobas,
    idxMasCartas: idxCartas,
    idxMasOros: idxOros,
    idxSieteOro: idxSieteOro,
    idxMasSietes: idxMasSietes,
  );
  p.ultimoResultado = resultado;

  // ¿Alguien llegó al objetivo?
  var mejor = -1;
  var idxGanador = -1;
  var empate = false;
  for (var i = 0; i < n; i++) {
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

/// Jugada simple de PC: primera captura posible o tira la carta de menor valor.
void jugarTurnoPcEscoba(PartidaEscoba p) {
  if (p.fase != FaseEscoba.jugando) return;
  final j = p.jugadorActual;
  if (j.mano.isEmpty) return;

  for (final carta in List.of(j.mano)) {
    final caps = capturasPosiblesEscoba(carta, p.mesa);
    if (caps.isNotEmpty) {
      jugarCartaEscoba(p, carta, mesaElegida: caps.first);
      return;
    }
  }
  final orden = List.of(j.mano)
    ..sort((a, b) => a.valorSuma.compareTo(b.valorSuma));
  jugarCartaEscoba(p, orden.first);
}
