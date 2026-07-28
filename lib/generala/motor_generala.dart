/// Motor puro de Generala (sin UI).
library;

import 'dart:math';

enum CategoriaGenerala {
  uno('1'),
  dos('2'),
  tres('3'),
  cuatro('4'),
  cinco('5'),
  seis('6'),
  escalera('ESCALERA'),
  full('FULL'),
  poker('POKER'),
  generala('GENERALA'),
  generalaDoble('GENERALA DOBLE');

  const CategoriaGenerala(this.etiqueta);
  final String etiqueta;

  static CategoriaGenerala? desdeEtiqueta(String e) {
    for (final c in values) {
      if (c.etiqueta == e) return c;
    }
    return null;
  }

  bool get esNumero => index <= CategoriaGenerala.seis.index;

  int? get cara => esNumero ? index + 1 : null;
}

const int dadosGenerala = 5;
const int maxTiradasGenerala = 3;

const int ptsEscalera = 20;
const int ptsEscaleraServida = 25;
const int ptsFull = 30;
const int ptsFullServida = 35;
const int ptsPoker = 40;
const int ptsPokerServida = 45;
const int ptsGenerala = 50;
const int ptsGeneralaDoble = 100;

class JugadorGenerala {
  JugadorGenerala(this.nombre);

  String nombre;
  /// Se rindió y ya no juega turnos.
  bool rendido = false;
  final Map<CategoriaGenerala, int?> casillas = {
    for (final c in CategoriaGenerala.values) c: null,
  };
  /// Historial de turnos anotados (para estadísticas).
  final List<RegistroTurnoGenerala> historial = [];

  bool get generalaAnotada {
    final v = casillas[CategoriaGenerala.generala];
    return v != null && v > 0;
  }

  bool get tableroCompleto =>
      casillas.values.every((v) => v != null);

  int get total =>
      casillas.values.fold(0, (acc, v) => acc + (v ?? 0));
}

/// Un turno completo: cuántas tiradas usó y qué anotó.
class RegistroTurnoGenerala {
  RegistroTurnoGenerala({
    required this.numero,
    required this.tiradasUsadas,
    required this.dadosFinales,
    required this.categoria,
    required this.puntos,
  });

  final int numero;
  final int tiradasUsadas;
  final List<int> dadosFinales;
  final CategoriaGenerala categoria;
  final int puntos;
}

class EstadoTurnoGenerala {
  EstadoTurnoGenerala();

  /// Valores actuales de los 5 dados (1–6). Vacío antes de la 1.ª tirada.
  List<int> dados = [];

  /// Dados que el jugador eligió guardar para la próxima tirada.
  List<bool> guardados = List.filled(dadosGenerala, false);

  /// Tiradas hechas en este turno (0..3).
  int tiradasHechas = 0;

  bool get hayDados => dados.length == dadosGenerala;
  bool get puedeTirar => tiradasHechas < maxTiradasGenerala;
  bool get debeAnotar => tiradasHechas >= maxTiradasGenerala;
  bool get puedeAnotar => tiradasHechas >= 1;
}

class PartidaGenerala {
  PartidaGenerala({required this.jugadores})
      : turno = EstadoTurnoGenerala();

  final List<JugadorGenerala> jugadores;
  int indiceTurno = 0;
  EstadoTurnoGenerala turno;
  String? ganador;

  JugadorGenerala get jugadorActual => jugadores[indiceTurno];

  List<JugadorGenerala> get jugadoresActivos =>
      jugadores.where((j) => !j.rendido).toList();
}

PartidaGenerala nuevaPartidaGenerala(List<String> nombres) {
  assert(nombres.length >= 2);
  return PartidaGenerala(
    jugadores: [for (final n in nombres) JugadorGenerala(n)],
  );
}

void iniciarTurnoGenerala(PartidaGenerala partida) {
  partida.turno = EstadoTurnoGenerala();
}

Map<int, int> contarCaras(List<int> dados) {
  final c = <int, int>{};
  for (final d in dados) {
    c[d] = (c[d] ?? 0) + 1;
  }
  return c;
}

bool esFull(List<int> dados) {
  if (dados.length != dadosGenerala) return false;
  final vals = contarCaras(dados).values.toList()..sort();
  return vals.length == 2 && vals[0] == 2 && vals[1] == 3;
}

/// Poker: exactamente 4 dados iguales (la Generala de 5 no cuenta acá).
bool esPoker(List<int> dados) {
  if (dados.length != dadosGenerala) return false;
  return contarCaras(dados).values.any((n) => n == 4);
}

bool esGenerala(List<int> dados) {
  if (dados.length != dadosGenerala) return false;
  return contarCaras(dados).values.any((n) => n == 5);
}

/// Escalera: 1-2-3-4-5 o 2-3-4-5-6 (en cualquier orden).
bool esEscalera(List<int> dados) {
  if (dados.length != dadosGenerala) return false;
  final set = dados.toSet();
  if (set.length != 5) return false;
  final sorted = set.toList()..sort();
  return (sorted[0] == 1 &&
          sorted[1] == 2 &&
          sorted[2] == 3 &&
          sorted[3] == 4 &&
          sorted[4] == 5) ||
      (sorted[0] == 2 &&
          sorted[1] == 3 &&
          sorted[2] == 4 &&
          sorted[3] == 5 &&
          sorted[4] == 6);
}

/// Puntos que darían [dados] si se anotan en [categoria].
/// [servida] = true si salió en la 1.ª tirada del turno.
/// Para especiales sin combo válido → 0 (tachado).
int puntosCategoria(
  CategoriaGenerala categoria,
  List<int> dados, {
  required bool yaTieneGenerala,
  bool servida = false,
}) {
  if (dados.length != dadosGenerala) return 0;
  final counts = contarCaras(dados);

  switch (categoria) {
    case CategoriaGenerala.uno:
    case CategoriaGenerala.dos:
    case CategoriaGenerala.tres:
    case CategoriaGenerala.cuatro:
    case CategoriaGenerala.cinco:
    case CategoriaGenerala.seis:
      final cara = categoria.cara!;
      return cara * (counts[cara] ?? 0);
    case CategoriaGenerala.escalera:
      if (!esEscalera(dados)) return 0;
      return servida ? ptsEscaleraServida : ptsEscalera;
    case CategoriaGenerala.full:
      if (!esFull(dados)) return 0;
      return servida ? ptsFullServida : ptsFull;
    case CategoriaGenerala.poker:
      if (!esPoker(dados)) return 0;
      return servida ? ptsPokerServida : ptsPoker;
    case CategoriaGenerala.generala:
      return esGenerala(dados) ? ptsGenerala : 0;
    case CategoriaGenerala.generalaDoble:
      if (!yaTieneGenerala) return 0;
      return esGenerala(dados) ? ptsGeneralaDoble : 0;
  }
}

/// Especiales que, si salen y la casilla sigue libre, permiten anotar antes
/// de agotar las 3 tiradas (Escalera, FULL, GENERALA / DOBLE).
/// El póker no: con 4 iguales conviene seguir tirando por la generala.
bool puedeAnotarTemprano(
  JugadorGenerala jugador,
  List<int> dados,
) {
  if (dados.length != dadosGenerala) return false;

  if (esEscalera(dados) &&
      puedeElegirCategoria(jugador, CategoriaGenerala.escalera)) {
    return true;
  }
  if (esFull(dados) &&
      puedeElegirCategoria(jugador, CategoriaGenerala.full)) {
    return true;
  }
  if (esGenerala(dados)) {
    if (puedeElegirCategoria(jugador, CategoriaGenerala.generala)) {
      return true;
    }
    if (puedeElegirCategoria(jugador, CategoriaGenerala.generalaDoble)) {
      return true;
    }
  }
  return false;
}

/// True si esa casilla del jugador ya tiene un valor anotado (incluye 0/tachado).
bool casillaOcupada(JugadorGenerala jugador, CategoriaGenerala categoria) =>
    jugador.casillas[categoria] != null;

/// Si la casilla se puede elegir para anotar (vacía).
/// Generala doble se puede tachar con 0 aunque no haya generala previa;
/// los 100 pts solo aplican si ya tenía generala (ver [puntosCategoria]).
bool puedeElegirCategoria(
  JugadorGenerala jugador,
  CategoriaGenerala categoria,
) {
  return !casillaOcupada(jugador, categoria);
}

/// Orden al tachar con 0: doble → generala → números (1…6) → especiales.
const List<CategoriaGenerala> ordenTacharPc = [
  CategoriaGenerala.generalaDoble,
  CategoriaGenerala.generala,
  CategoriaGenerala.uno,
  CategoriaGenerala.dos,
  CategoriaGenerala.tres,
  CategoriaGenerala.cuatro,
  CategoriaGenerala.cinco,
  CategoriaGenerala.seis,
  CategoriaGenerala.escalera,
  CategoriaGenerala.full,
  CategoriaGenerala.poker,
];

/// Elige qué anotar la PC: máxima puntuación positiva; si no, tacha según [ordenTacharPc].
CategoriaGenerala? elegirCategoriaPc(
  JugadorGenerala jugador,
  List<int> dados, {
  required bool servida,
}) {
  final disponibles = [
    for (final c in CategoriaGenerala.values)
      if (puedeElegirCategoria(jugador, c)) c,
  ];
  if (disponibles.isEmpty) return null;

  CategoriaGenerala? mejorPositiva;
  var mejorPts = 0;
  for (final cat in disponibles) {
    final pts = puntosCategoria(
      cat,
      dados,
      yaTieneGenerala: jugador.generalaAnotada,
      servida: servida,
    );
    if (pts > mejorPts) {
      mejorPts = pts;
      mejorPositiva = cat;
    }
  }
  if (mejorPositiva != null) return mejorPositiva;

  for (final cat in ordenTacharPc) {
    if (disponibles.contains(cat)) return cat;
  }
  return disponibles.first;
}

void toggleDadoGuardado(EstadoTurnoGenerala t, int index) {
  if (!t.hayDados || t.debeAnotar) return;
  if (t.tiradasHechas == 0) return;
  t.guardados[index] = !t.guardados[index];
}

/// Tras una tirada, pinta de dorado los dados que sirven según el tablero
/// del jugador (casillas libres). Misma lógica para humano y PC.
void autoSeleccionarDadosUtiles(JugadorGenerala j, EstadoTurnoGenerala t) {
  elegirGuardadosPc(j, t);
}

void _marcarCaras(EstadoTurnoGenerala t, Set<int> caras) {
  for (var i = 0; i < dadosGenerala; i++) {
    t.guardados[i] = caras.contains(t.dados[i]);
  }
  compactarDadosGuardados(t);
}

void _marcarSoloCara(EstadoTurnoGenerala t, int cara) =>
    _marcarCaras(t, {cara});

void _marcarTodos(EstadoTurnoGenerala t) {
  t.guardados = List.filled(dadosGenerala, true);
}

/// Guarda dados útiles para escalera (una de cada cara hacia 12345 o 23456).
void _marcarParaEscalera(EstadoTurnoGenerala t) {
  final targets = [
    {1, 2, 3, 4, 5},
    {2, 3, 4, 5, 6},
  ];
  var mejorKept = <int>[];
  for (final target in targets) {
    final pool = List<int>.of(t.dados);
    final kept = <int>[];
    for (final face in target) {
      final idx = pool.indexOf(face);
      if (idx >= 0) {
        kept.add(face);
        pool.removeAt(idx);
      }
    }
    if (kept.length > mejorKept.length) mejorKept = kept;
  }
  final usados = <int>{};
  for (var i = 0; i < dadosGenerala; i++) {
    final d = t.dados[i];
    if (mejorKept.contains(d) && !usados.contains(d)) {
      t.guardados[i] = true;
      usados.add(d);
    } else {
      t.guardados[i] = false;
    }
  }
  compactarDadosGuardados(t);
}

/// Caras con ≥2, orden: más cantidad, luego cara más alta.
List<int> _carasConParOrdenadas(Map<int, int> counts) {
  final caras = [
    for (final e in counts.entries)
      if (e.value >= 2) e.key,
  ];
  caras.sort((a, b) {
    final cmp = counts[b]!.compareTo(counts[a]!);
    return cmp != 0 ? cmp : b.compareTo(a);
  });
  return caras;
}

/// La PC elige qué guardar mirando casillas aún libres del tablero.
void elegirGuardadosPc(JugadorGenerala j, EstadoTurnoGenerala t) {
  if (!t.hayDados) return;

  final buscaGenerala = puedeElegirCategoria(j, CategoriaGenerala.generala) ||
      puedeElegirCategoria(j, CategoriaGenerala.generalaDoble);
  final buscaEscalera =
      puedeElegirCategoria(j, CategoriaGenerala.escalera);
  final buscaFull = puedeElegirCategoria(j, CategoriaGenerala.full);
  final buscaPoker = puedeElegirCategoria(j, CategoriaGenerala.poker);
  final numerosLibres = <int>{
    for (final c in CategoriaGenerala.values)
      if (c.esNumero && puedeElegirCategoria(j, c)) c.cara!,
  };

  // Manos ya armadas que todavía se pueden anotar.
  if (esGenerala(t.dados) && buscaGenerala) {
    _marcarTodos(t);
    return;
  }
  if (esEscalera(t.dados) && buscaEscalera) {
    _marcarTodos(t);
    return;
  }
  if (esFull(t.dados) && buscaFull) {
    _marcarTodos(t);
    return;
  }
  if (esPoker(t.dados) && (buscaPoker || buscaGenerala)) {
    final counts = contarCaras(t.dados);
    final cara = counts.entries.firstWhere((e) => e.value >= 4).key;
    _marcarSoloCara(t, cara);
    return;
  }

  final counts = contarCaras(t.dados);
  final pares = _carasConParOrdenadas(counts);

  // FULL libre y hay material (dos pares o trío).
  if (buscaFull) {
    if (pares.length >= 2) {
      _marcarCaras(t, pares.take(2).toSet());
      return;
    }
    if (pares.isNotEmpty && (counts[pares.first] ?? 0) >= 3) {
      _marcarSoloCara(t, pares.first);
      return;
    }
  }

  // Generala o póker: un grupo útil (trío+, o par de un número aún libre).
  // No se queda con pares de números ya tachados si hay otra estrategia (p. ej. escalera).
  if (buscaGenerala || buscaPoker) {
    final paresUtiles = pares
        .where((c) => (counts[c] ?? 0) >= 3 || numerosLibres.contains(c))
        .toList(growable: false);
    if (paresUtiles.isNotEmpty) {
      _marcarSoloCara(t, paresUtiles.first);
      return;
    }
    if (!buscaEscalera && pares.isNotEmpty) {
      _marcarSoloCara(t, pares.first);
      return;
    }
    if (buscaGenerala && !buscaEscalera && pares.isEmpty) {
      final cara = t.dados.reduce((a, b) => a > b ? a : b);
      _marcarSoloCara(t, cara);
      return;
    }
  }

  // Pares cuyos números todavía están libres en el tablero.
  final paresDeNumeroLibre =
      pares.where(numerosLibres.contains).toList(growable: false);
  if (paresDeNumeroLibre.isNotEmpty) {
    _marcarCaras(t, paresDeNumeroLibre.toSet());
    return;
  }

  // Escalera libre.
  if (buscaEscalera) {
    _marcarParaEscalera(t);
    return;
  }

  // Si solo queda buscar generala/póker y había pares “débiles”, ahora sí.
  if ((buscaGenerala || buscaPoker) && pares.isNotEmpty) {
    _marcarSoloCara(t, pares.first);
    return;
  }

  // Mejor número libre presente en los dados.
  var mejorCara = 0;
  var mejorPts = 0;
  for (final cara in numerosLibres) {
    final n = counts[cara] ?? 0;
    if (n == 0) continue;
    final pts = cara * n;
    if (pts > mejorPts) {
      mejorPts = pts;
      mejorCara = cara;
    }
  }
  if (mejorCara > 0) {
    _marcarSoloCara(t, mejorCara);
    return;
  }

  // Nada útil: soltar todo y volver a tirar.
  t.guardados = List.filled(dadosGenerala, false);
}

/// Agrupa a la izquierda los dados guardados (amarillos) y a la derecha el resto.
void compactarDadosGuardados(EstadoTurnoGenerala t) {
  if (!t.hayDados) return;
  final kept = <int>[];
  final free = <int>[];
  for (var i = 0; i < dadosGenerala; i++) {
    if (t.guardados[i]) {
      kept.add(t.dados[i]);
    } else {
      free.add(t.dados[i]);
    }
  }
  t.dados = [...kept, ...free];
  t.guardados = [
    ...List.filled(kept.length, true),
    ...List.filled(free.length, false),
  ];
}

/// Tira los dados no guardados. En la 1.ª tirada tira los 5.
/// Los guardados quedan a la izquierda y siguen marcados (amarillos).
List<int> tirarDadosGenerala(
  EstadoTurnoGenerala t, {
  List<int>? dadosForzados,
  Random? rng,
}) {
  if (!t.puedeTirar) {
    throw StateError('Ya se usaron las $maxTiradasGenerala tiradas');
  }
  final r = rng ?? Random();

  if (!t.hayDados) {
    t.dados = dadosForzados ??
        List.generate(dadosGenerala, (_) => r.nextInt(6) + 1);
    t.guardados = List.filled(dadosGenerala, false);
  } else {
    // Primero alinea los guardados a la izquierda.
    compactarDadosGuardados(t);
    final forzados = dadosForzados;
    var fi = 0;
    for (var i = 0; i < dadosGenerala; i++) {
      if (t.guardados[i]) continue;
      if (forzados != null && fi < forzados.length) {
        t.dados[i] = forzados[fi++];
      } else {
        t.dados[i] = r.nextInt(6) + 1;
      }
    }
    // Los guardados siguen a la izquierda y en amarillo.
    compactarDadosGuardados(t);
  }

  t.tiradasHechas++;
  return List.of(t.dados);
}

/// Avanza al próximo jugador que no se haya rendido.
void pasarTurnoGenerala(PartidaGenerala partida) {
  final n = partida.jugadores.length;
  for (var i = 0; i < n; i++) {
    partida.indiceTurno = (partida.indiceTurno + 1) % n;
    if (!partida.jugadorActual.rendido) {
      iniciarTurnoGenerala(partida);
      return;
    }
  }
}

/// Anota la categoría y pasa al siguiente jugador (o define ganador).
void anotarCategoria(
  PartidaGenerala partida,
  CategoriaGenerala categoria,
) {
  final j = partida.jugadorActual;
  final t = partida.turno;
  if (j.rendido) {
    throw StateError('El jugador ya se rindió');
  }
  if (!t.puedeAnotar) {
    throw StateError('Todavía no hay tirada para anotar');
  }
  if (!puedeElegirCategoria(j, categoria)) {
    throw StateError('No se puede anotar en ${categoria.etiqueta}');
  }

  final pts = puntosCategoria(
    categoria,
    t.dados,
    yaTieneGenerala: j.generalaAnotada,
    servida: t.tiradasHechas == 1,
  );
  j.historial.add(
    RegistroTurnoGenerala(
      numero: j.historial.length + 1,
      tiradasUsadas: t.tiradasHechas,
      dadosFinales: List<int>.of(t.dados),
      categoria: categoria,
      puntos: pts,
    ),
  );
  j.casillas[categoria] = pts;

  final activos = partida.jugadoresActivos;
  if (activos.every((x) => x.tableroCompleto)) {
    final mejor = activos.reduce(
      (a, b) => a.total >= b.total ? a : b,
    );
    partida.ganador = mejor.nombre;
    return;
  }

  pasarTurnoGenerala(partida);
}
