/// Motor de Tutti Frutti (online por fases).
library;

const int minCategoriasTuti = 3;
const int maxCategoriasTuti = 6;
const int maxCharsCategoriaTuti = 25;
const Duration duracionContadorTuti = Duration(seconds: 5);
/// Gracia tras BASTA: se puede seguir escribiendo hasta que termine.
const Duration duracionBastaTuti = Duration(milliseconds: 1500);

/// Abecedario A–Z (sin Ñ).
const String abecedarioTuti = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

enum FaseTuti {
  countdownRuleta,
  ruleta,
  countdownEscritura,
  escritura,
  countdownRevision,
  revision,
  fin,
}

extension FaseTutiX on FaseTuti {
  String get id => name;

  static FaseTuti fromId(String? s) {
    for (final f in FaseTuti.values) {
      if (f.name == s) return f;
    }
    return FaseTuti.countdownRuleta;
  }

  bool get esContador =>
      this == FaseTuti.countdownRuleta ||
      this == FaseTuti.countdownEscritura ||
      this == FaseTuti.countdownRevision;

  /// Orden de avance de la partida (para descartar syncs viejos).
  int get orden {
    switch (this) {
      case FaseTuti.countdownRuleta:
        return 0;
      case FaseTuti.ruleta:
        return 1;
      case FaseTuti.countdownEscritura:
        return 2;
      case FaseTuti.escritura:
        return 3;
      case FaseTuti.countdownRevision:
        return 4;
      case FaseTuti.revision:
        return 5;
      case FaseTuti.fin:
        return 6;
    }
  }
}

/// Snapshot de una ronda terminada (para el tablero final).
class RondaTutiHistorial {
  RondaTutiHistorial({
    required this.ronda,
    required this.letra,
    required this.respuestas,
    required this.puntajes,
    required this.puntosRonda,
  });

  final int ronda;
  final String letra;
  /// nombre → texto por categoría
  final Map<String, List<String>> respuestas;
  /// nombre → puntos por categoría
  final Map<String, List<int>> puntajes;
  /// nombre → suma de la ronda
  final Map<String, int> puntosRonda;

  Map<String, dynamic> toJson() => {
        'ronda': ronda,
        'letra': letra,
        'respuestas': {
          for (final e in respuestas.entries)
            e.key: List<String>.from(e.value),
        },
        'puntajes': {
          for (final e in puntajes.entries) e.key: List<int>.from(e.value),
        },
        'puntosRonda': Map<String, int>.from(puntosRonda),
      };

  static RondaTutiHistorial fromJson(Map<String, dynamic> raw) {
    Map<String, List<String>> respuestas = {};
    final respRaw = raw['respuestas'];
    if (respRaw is Map) {
      for (final e in respRaw.entries) {
        final list = e.value;
        respuestas[e.key.toString()] = list is List
            ? list.map((x) => x?.toString() ?? '').toList()
            : <String>[];
      }
    }
    Map<String, List<int>> puntajes = {};
    final punRaw = raw['puntajes'];
    if (punRaw is Map) {
      for (final e in punRaw.entries) {
        final list = e.value;
        puntajes[e.key.toString()] = list is List
            ? list.map((x) => (x as num?)?.toInt() ?? 0).toList()
            : <int>[];
      }
    }
    Map<String, int> puntosRonda = {};
    final prRaw = raw['puntosRonda'];
    if (prRaw is Map) {
      for (final e in prRaw.entries) {
        puntosRonda[e.key.toString()] = (e.value as num?)?.toInt() ?? 0;
      }
    }
    return RondaTutiHistorial(
      ronda: (raw['ronda'] as num?)?.toInt() ?? 0,
      letra: raw['letra']?.toString() ?? '?',
      respuestas: respuestas,
      puntajes: puntajes,
      puntosRonda: puntosRonda,
    );
  }
}

class PartidaTuti {
  PartidaTuti({
    required this.nombres,
    required this.categorias,
    this.fase = FaseTuti.countdownRuleta,
    this.indiceSpinner = 0,
    this.ronda = 1,
    this.maxRondas = 5,
    this.letra,
    this.ruletaInicioMs,
    this.ruletaVelocidad = 8.0,
    this.faseInicioMs,
    Map<String, List<String>>? respuestas,
    Map<String, bool>? listos,
    this.bastaTodos = false,
    this.bastaInicioMs,
    this.bastaPor,
    this.categoriaRevision = 0,
    List<String>? letrasUsadas,
    Map<String, List<int?>>? puntajes,
    Map<String, int>? totales,
    List<RondaTutiHistorial>? historial,
    this.version = 1,
  })  : letrasUsadas = letrasUsadas ?? [],
        historial = historial ?? [],
        respuestas = respuestas ??
            {
              for (final n in nombres)
                n: List.filled(categorias.length, ''),
            },
        listos = listos ?? {for (final n in nombres) n: false},
        puntajes = puntajes ??
            {
              for (final n in nombres)
                n: List<int?>.filled(categorias.length, null),
            },
        totales = totales ?? {for (final n in nombres) n: 0};

  List<String> nombres;
  List<String> categorias;
  FaseTuti fase;
  int indiceSpinner;
  int ronda;
  /// Cantidad de rondas definidas por el anfitrión (1..abecedario).
  int maxRondas;
  String? letra;
  int? ruletaInicioMs;
  double ruletaVelocidad;
  int? faseInicioMs;
  Map<String, List<String>> respuestas;
  Map<String, bool> listos;
  bool bastaTodos;
  /// Momento en que alguien apretó BASTA (ms epoch).
  int? bastaInicioMs;
  /// Quién apretó BASTA.
  String? bastaPor;
  int categoriaRevision;
  /// Letras ya salidas (no vuelven a la ruleta).
  List<String> letrasUsadas;
  Map<String, List<int?>> puntajes;
  Map<String, int> totales;
  /// Rondas ya cerradas (respuestas + puntajes).
  List<RondaTutiHistorial> historial;
  int version;

  /// Abecedario sin las letras ya jugadas.
  List<String> get letrasDisponibles {
    final usadas = letrasUsadas.map((l) => l.toUpperCase()).toSet();
    return [
      for (var i = 0; i < abecedarioTuti.length; i++)
        if (!usadas.contains(abecedarioTuti[i])) abecedarioTuti[i],
    ];
  }

  int get indiceParador =>
      nombres.isEmpty ? 0 : (indiceSpinner + 1) % nombres.length;

  String get nombreSpinner =>
      nombres.isEmpty ? '' : nombres[indiceSpinner % nombres.length];

  String get nombreParador =>
      nombres.isEmpty ? '' : nombres[indiceParador];

  bool get todosListos =>
      nombres.every((n) => listos[n] == true);

  /// Aviso de basta activo (animación de gracia en curso o pendiente de cierre).
  bool get bastaEnCurso =>
      fase == FaseTuti.escritura && bastaTodos && bastaInicioMs != null;

  /// Margen extra para latencia de sync (el aviso local de cada rival es independiente).
  static const Duration margenCierreBasta = Duration(milliseconds: 400);

  /// Listo para cerrar escritura y pasar a revisión (reloj del que dijo basta).
  bool listoParaCerrarBasta({int? ahoraMs}) {
    if (!bastaTodos || bastaInicioMs == null) return false;
    if (fase != FaseTuti.escritura) return false;
    final ahora = ahoraMs ?? DateTime.now().millisecondsSinceEpoch;
    final espera =
        duracionBastaTuti.inMilliseconds + margenCierreBasta.inMilliseconds;
    return ahora - bastaInicioMs! >= espera;
  }

  bool get escrituraTerminada =>
      bastaTodos && listoParaCerrarBasta();

  /// Letra actual de la ruleta según reloj compartido (solo letras libres).
  String letraActualRuleta({int? ahoraMs}) {
    if (letra != null && letra!.isNotEmpty) return letra!;
    var pool = letrasDisponibles;
    if (pool.isEmpty) pool = abecedarioTuti.split('');
    final inicio = ruletaInicioMs;
    if (inicio == null) return pool.first;
    final ahora = ahoraMs ?? DateTime.now().millisecondsSinceEpoch;
    final elapsedSec = ((ahora - inicio) / 1000.0).clamp(0.0, 1e9);
    final idx = (elapsedSec * ruletaVelocidad).floor() % pool.length;
    return pool[idx];
  }

  int segundosRestantesContador({int? ahoraMs}) {
    final inicio = faseInicioMs;
    if (inicio == null) return 0;
    final ahora = ahoraMs ?? DateTime.now().millisecondsSinceEpoch;
    final resto = duracionContadorTuti.inMilliseconds - (ahora - inicio);
    if (resto <= 0) return 0;
    return ((resto + 999) ~/ 1000).clamp(0, duracionContadorTuti.inSeconds);
  }

  bool contadorTerminado({int? ahoraMs}) {
    final inicio = faseInicioMs;
    if (inicio == null) return true;
    final ahora = ahoraMs ?? DateTime.now().millisecondsSinceEpoch;
    return ahora - inicio >= duracionContadorTuti.inMilliseconds;
  }
}

String? validarCategoriasTuti(List<String> raw) {
  final cats = raw.map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
  if (cats.length < minCategoriasTuti) {
    return 'Mínimo $minCategoriasTuti categorías.';
  }
  if (cats.length > maxCategoriasTuti) {
    return 'Máximo $maxCategoriasTuti categorías.';
  }
  for (final c in cats) {
    if (c.length > maxCharsCategoriaTuti) {
      return 'Cada categoría: máx. $maxCharsCategoriaTuti caracteres.';
    }
  }
  final vistos = <String>{};
  for (final c in cats) {
    final k = c.toLowerCase();
    if (!vistos.add(k)) return 'No puede haber categorías repetidas.';
  }
  return null;
}

PartidaTuti nuevaPartidaTuti({
  required List<String> nombres,
  required List<String> categorias,
  int maxRondas = 5,
}) {
  final cats = categorias.map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
  final now = DateTime.now().millisecondsSinceEpoch;
  final maxR = maxRondas.clamp(1, abecedarioTuti.length);
  return PartidaTuti(
    nombres: List<String>.from(nombres),
    categorias: List<String>.from(cats),
    fase: FaseTuti.countdownRuleta,
    indiceSpinner: 0,
    ronda: 1,
    maxRondas: maxR,
    faseInicioMs: now,
    version: 1,
  );
}

/// Avance de contador → siguiente fase (lo publica el anfitrión).
void avanzarContadorTuti(PartidaTuti p) {
  final now = DateTime.now().millisecondsSinceEpoch;
  switch (p.fase) {
    case FaseTuti.countdownRuleta:
      p.fase = FaseTuti.ruleta;
      p.letra = null;
      p.ruletaInicioMs = now;
      p.ruletaVelocidad = 8.0;
      p.faseInicioMs = now;
      // Si se agotó el abecedario, reinicia el pool para no softlockear.
      if (p.letrasDisponibles.isEmpty) {
        p.letrasUsadas.clear();
      }
      break;
    case FaseTuti.countdownEscritura:
      p.fase = FaseTuti.escritura;
      p.faseInicioMs = now;
      p.bastaTodos = false;
      p.bastaInicioMs = null;
      p.bastaPor = null;
      p.listos = {for (final n in p.nombres) n: false};
      p.respuestas = {
        for (final n in p.nombres)
          n: List.filled(p.categorias.length, ''),
      };
      break;
    case FaseTuti.countdownRevision:
      p.fase = FaseTuti.revision;
      p.categoriaRevision = 0;
      p.faseInicioMs = now;
      break;
    default:
      break;
  }
}

void acelerarRuletaTuti(PartidaTuti p, {double delta = 4.0}) {
  if (p.fase != FaseTuti.ruleta) return;
  p.ruletaVelocidad = (p.ruletaVelocidad + delta).clamp(8.0, 40.0);
}

void pararRuletaTuti(PartidaTuti p) {
  if (p.fase != FaseTuti.ruleta) return;
  final now = DateTime.now().millisecondsSinceEpoch;
  final elegida = p.letraActualRuleta(ahoraMs: now);
  p.letra = elegida;
  final upper = elegida.toUpperCase();
  if (!p.letrasUsadas.contains(upper)) {
    p.letrasUsadas.add(upper);
  }
  p.fase = FaseTuti.countdownEscritura;
  p.faseInicioMs = now;
}

void setRespuestaTuti(PartidaTuti p, String nombre, int catIndex, String texto) {
  if (p.fase != FaseTuti.escritura) return;
  final list = p.respuestas[nombre];
  if (list == null || catIndex < 0 || catIndex >= list.length) return;
  list[catIndex] = texto.length > 40 ? texto.substring(0, 40) : texto;
}

/// Anuncia BASTA: arranca gracia (los demás ven el aviso desde que les llega).
void bastaTuti(PartidaTuti p, String quien) {
  if (p.fase != FaseTuti.escritura) return;
  if (p.bastaTodos) return;
  final now = DateTime.now().millisecondsSinceEpoch;
  p.bastaTodos = true;
  p.bastaInicioMs = now;
  p.bastaPor = quien;
}

/// Al terminar la gracia global: cierra escritura y va a countdown de revisión.
void cerrarEscrituraTrasBastaTuti(PartidaTuti p) {
  if (p.fase != FaseTuti.escritura) return;
  if (!p.bastaTodos || !p.listoParaCerrarBasta()) return;
  for (final n in p.nombres) {
    p.listos[n] = true;
  }
  _irACountdownRevision(p);
}

void _irACountdownRevision(PartidaTuti p) {
  final now = DateTime.now().millisecondsSinceEpoch;
  p.fase = FaseTuti.countdownRevision;
  p.faseInicioMs = now;
}

void setPuntajePropioTuti(
  PartidaTuti p,
  String nombre,
  int catIndex,
  int puntos,
) {
  if (p.fase != FaseTuti.revision) return;
  if (catIndex != p.categoriaRevision) return;
  if (![0, 5, 10, 20].contains(puntos)) return;
  final list = p.puntajes[nombre];
  if (list == null || catIndex < 0 || catIndex >= list.length) return;
  final prev = list[catIndex];
  list[catIndex] = puntos;
  final total = p.totales[nombre] ?? 0;
  p.totales[nombre] = total - (prev ?? 0) + puntos;
}

/// True si todos eligieron un puntaje (incluido 0) en la categoría actual.
bool todosVotaronCategoriaTuti(PartidaTuti p, [int? catIndex]) {
  final idx = catIndex ?? p.categoriaRevision;
  for (final n in p.nombres) {
    final list = p.puntajes[n];
    if (list == null || idx < 0 || idx >= list.length) return false;
    if (list[idx] == null) return false;
  }
  return true;
}

List<String> pendientesVotoTuti(PartidaTuti p, [int? catIndex]) {
  final idx = catIndex ?? p.categoriaRevision;
  final out = <String>[];
  for (final n in p.nombres) {
    final list = p.puntajes[n];
    if (list == null || idx >= list.length || list[idx] == null) {
      out.add(n);
    }
  }
  return out;
}

/// Guarda la ronda actual en el historial (idempotente por número de ronda).
void guardarRondaEnHistorialTuti(PartidaTuti p) {
  if (p.historial.any((h) => h.ronda == p.ronda)) return;
  final nCats = p.categorias.length;
  final respuestas = <String, List<String>>{
    for (final n in p.nombres)
      n: List<String>.from(
        p.respuestas[n] ?? List.filled(nCats, ''),
      ),
  };
  final puntajes = <String, List<int>>{
    for (final n in p.nombres)
      n: [
        for (var i = 0; i < nCats; i++)
          (p.puntajes[n] != null && i < p.puntajes[n]!.length)
              ? (p.puntajes[n]![i] ?? 0)
              : 0,
      ],
  };
  final puntosRonda = <String, int>{
    for (final n in p.nombres)
      n: puntajes[n]!.fold<int>(0, (a, b) => a + b),
  };
  p.historial.add(
    RondaTutiHistorial(
      ronda: p.ronda,
      letra: (p.letra ?? '?').toUpperCase(),
      respuestas: respuestas,
      puntajes: puntajes,
      puntosRonda: puntosRonda,
    ),
  );
}

/// Continuar revisión (anfitrión): siguiente categoría o nueva ronda.
void continuarRevisionTuti(PartidaTuti p) {
  if (p.fase != FaseTuti.revision) return;
  if (!todosVotaronCategoriaTuti(p)) return;
  final now = DateTime.now().millisecondsSinceEpoch;
  if (p.categoriaRevision + 1 < p.categorias.length) {
    p.categoriaRevision++;
    return;
  }
  // Fin de la ronda de categorías: archivar antes de seguir.
  guardarRondaEnHistorialTuti(p);
  if (p.ronda >= p.maxRondas) {
    acabarPartidaTuti(p);
    return;
  }
  // Nueva ronda: siguiente spinner.
  p.indiceSpinner = (p.indiceSpinner + 1) % p.nombres.length;
  p.ronda++;
  p.letra = null;
  p.categoriaRevision = 0;
  p.bastaTodos = false;
  p.bastaInicioMs = null;
  p.bastaPor = null;
  p.listos = {for (final n in p.nombres) n: false};
  p.puntajes = {
    for (final n in p.nombres) n: List<int?>.filled(p.categorias.length, null),
  };
  p.fase = FaseTuti.countdownRuleta;
  p.faseInicioMs = now;
}

bool esUltimaCategoriaRevisionTuti(PartidaTuti p) =>
    p.categoriaRevision >= p.categorias.length - 1;

bool quedanRondasTuti(PartidaTuti p) => p.ronda < p.maxRondas;

void acabarPartidaTuti(PartidaTuti p) {
  // Si cierran en revisión con la ronda votada, archivar.
  if (p.fase == FaseTuti.revision && todosVotaronCategoriaTuti(p)) {
    guardarRondaEnHistorialTuti(p);
  }
  p.fase = FaseTuti.fin;
  p.faseInicioMs = DateTime.now().millisecondsSinceEpoch;
}

List<MapEntry<String, int>> rankingTuti(PartidaTuti p) {
  final entries = p.totales.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries;
}
