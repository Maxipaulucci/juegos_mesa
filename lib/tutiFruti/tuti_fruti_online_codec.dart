import 'motor_tuti_fruti.dart';

Map<String, dynamic> encodeTutiGameState(PartidaTuti p) {
  return {
    'version': p.version,
    'juego': 'tutiFruti',
    'categorias': List<String>.from(p.categorias),
    'nombres': List<String>.from(p.nombres),
    'fase': p.fase.id,
    'indiceSpinner': p.indiceSpinner,
    'ronda': p.ronda,
    'letra': p.letra,
    'ruletaInicioMs': p.ruletaInicioMs,
    'ruletaVelocidad': p.ruletaVelocidad,
    'faseInicioMs': p.faseInicioMs,
    'respuestas': {
      for (final e in p.respuestas.entries) e.key: List<String>.from(e.value),
    },
    'listos': Map<String, bool>.from(p.listos),
    'bastaTodos': p.bastaTodos,
    'categoriaRevision': p.categoriaRevision,
    'puntajes': {
      for (final e in p.puntajes.entries)
        e.key: e.value.map((v) => v).toList(),
    },
    'totales': Map<String, int>.from(p.totales),
    'mostrarVictoria': p.fase == FaseTuti.fin,
  };
}

PartidaTuti decodeTutiGameState(Map<String, dynamic> raw) {
  final nombres = (raw['nombres'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
      <String>[];
  final categorias = (raw['categorias'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
      <String>[];

  Map<String, List<String>> respuestas = {};
  final respRaw = raw['respuestas'];
  if (respRaw is Map) {
    for (final e in respRaw.entries) {
      final list = e.value;
      respuestas[e.key.toString()] = list is List
          ? list.map((x) => x?.toString() ?? '').toList()
          : List.filled(categorias.length, '');
    }
  }

  Map<String, bool> listos = {};
  final listosRaw = raw['listos'];
  if (listosRaw is Map) {
    for (final e in listosRaw.entries) {
      listos[e.key.toString()] = e.value == true;
    }
  }

  Map<String, List<int?>> puntajes = {};
  final punRaw = raw['puntajes'];
  if (punRaw is Map) {
    for (final e in punRaw.entries) {
      final list = e.value;
      puntajes[e.key.toString()] = list is List
          ? list.map((x) => x == null ? null : (x as num).toInt()).toList()
          : List<int?>.filled(categorias.length, null);
    }
  }

  Map<String, int> totales = {};
  final totRaw = raw['totales'];
  if (totRaw is Map) {
    for (final e in totRaw.entries) {
      totales[e.key.toString()] = (e.value as num?)?.toInt() ?? 0;
    }
  }

  // Completar claves faltantes.
  for (final n in nombres) {
    respuestas.putIfAbsent(n, () => List.filled(categorias.length, ''));
    listos.putIfAbsent(n, () => false);
    puntajes.putIfAbsent(
      n,
      () => List<int?>.filled(categorias.length, null),
    );
    totales.putIfAbsent(n, () => 0);
  }

  return PartidaTuti(
    nombres: nombres,
    categorias: categorias,
    fase: FaseTutiX.fromId(raw['fase']?.toString()),
    indiceSpinner: (raw['indiceSpinner'] as num?)?.toInt() ?? 0,
    ronda: (raw['ronda'] as num?)?.toInt() ?? 1,
    letra: raw['letra']?.toString(),
    ruletaInicioMs: (raw['ruletaInicioMs'] as num?)?.toInt(),
    ruletaVelocidad: (raw['ruletaVelocidad'] as num?)?.toDouble() ?? 8.0,
    faseInicioMs: (raw['faseInicioMs'] as num?)?.toInt(),
    respuestas: respuestas,
    listos: listos,
    bastaTodos: raw['bastaTodos'] == true,
    categoriaRevision: (raw['categoriaRevision'] as num?)?.toInt() ?? 0,
    puntajes: puntajes,
    totales: totales,
    version: (raw['version'] as num?)?.toInt() ?? 1,
  );
}

void applyTutiGameState(PartidaTuti destino, Map<String, dynamic> raw) {
  final nuevo = decodeTutiGameState(raw);
  destino.fase = nuevo.fase;
  destino.indiceSpinner = nuevo.indiceSpinner;
  destino.ronda = nuevo.ronda;
  destino.letra = nuevo.letra;
  destino.ruletaInicioMs = nuevo.ruletaInicioMs;
  destino.ruletaVelocidad = nuevo.ruletaVelocidad;
  destino.faseInicioMs = nuevo.faseInicioMs;
  destino.respuestas = nuevo.respuestas;
  destino.listos = nuevo.listos;
  destino.bastaTodos = nuevo.bastaTodos;
  destino.categoriaRevision = nuevo.categoriaRevision;
  destino.puntajes = nuevo.puntajes;
  destino.totales = nuevo.totales;
  destino.version = nuevo.version;
  // categorias/nombres no cambian mid-game; si llegan, respetarlos
  if (nuevo.categorias.isNotEmpty) {
    destino.categorias
      ..clear()
      ..addAll(nuevo.categorias);
  }
  if (nuevo.nombres.isNotEmpty) {
    destino.nombres
      ..clear()
      ..addAll(nuevo.nombres);
  }
}
