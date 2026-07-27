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

const int ptsFull = 30;
const int ptsPoker = 40;
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

  bool get generalaAnotada {
    final v = casillas[CategoriaGenerala.generala];
    return v != null && v > 0;
  }

  bool get tableroCompleto =>
      casillas.values.every((v) => v != null);

  int get total =>
      casillas.values.fold(0, (acc, v) => acc + (v ?? 0));
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

bool esPoker(List<int> dados) {
  if (dados.length != dadosGenerala) return false;
  return contarCaras(dados).values.any((n) => n >= 4);
}

bool esGenerala(List<int> dados) {
  if (dados.length != dadosGenerala) return false;
  return contarCaras(dados).values.any((n) => n == 5);
}

/// Puntos que darían [dados] si se anotan en [categoria].
/// Para especiales sin combo válido → 0 (tachado).
int puntosCategoria(
  CategoriaGenerala categoria,
  List<int> dados, {
  required bool yaTieneGenerala,
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
    case CategoriaGenerala.full:
      return esFull(dados) ? ptsFull : 0;
    case CategoriaGenerala.poker:
      return esPoker(dados) ? ptsPoker : 0;
    case CategoriaGenerala.generala:
      return esGenerala(dados) ? ptsGenerala : 0;
    case CategoriaGenerala.generalaDoble:
      if (!yaTieneGenerala) return 0;
      return esGenerala(dados) ? ptsGeneralaDoble : 0;
  }
}

/// Si la casilla se puede elegir para anotar (vacía y, en doble, con generala previa).
bool puedeElegirCategoria(
  JugadorGenerala jugador,
  CategoriaGenerala categoria,
) {
  if (jugador.casillas[categoria] != null) return false;
  if (categoria == CategoriaGenerala.generalaDoble &&
      !jugador.generalaAnotada) {
    return false;
  }
  return true;
}

void toggleDadoGuardado(EstadoTurnoGenerala t, int index) {
  if (!t.hayDados || t.debeAnotar) return;
  if (t.tiradasHechas == 0) return;
  t.guardados[index] = !t.guardados[index];
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
