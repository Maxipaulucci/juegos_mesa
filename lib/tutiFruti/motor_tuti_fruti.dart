/// Motor de Tutti Frutti (online por fases).
library;

const int minCategoriasTuti = 3;
const int maxCategoriasTuti = 6;
const int maxCharsCategoriaTuti = 25;
const Duration duracionContadorTuti = Duration(seconds: 3);
/// Gracia tras BASTA: se puede seguir escribiendo hasta que termine.
const Duration duracionBastaTuti = Duration(seconds: 2);

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
    this.version = 1,
  })  : letrasUsadas = letrasUsadas ?? [],
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

  /// Aviso de basta activo (animación de 2s en curso o pendiente de cierre).
  bool get bastaEnCurso =>
      fase == FaseTuti.escritura && bastaTodos && bastaInicioMs != null;

  /// Margen extra para que el aviso llegue a los demás y cumplan sus 2s locales.
  static const Duration margenCierreBasta = Duration(milliseconds: 2000);

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
    return ((resto + 999) ~/ 1000).clamp(0, 3);
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

/// Anuncia BASTA: arranca gracia (los demás ven el aviso 2s desde que les llega).
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

/// Continuar revisión (anfitrión): siguiente categoría o nueva ronda.
void continuarRevisionTuti(PartidaTuti p) {
  if (p.fase != FaseTuti.revision) return;
  if (!todosVotaronCategoriaTuti(p)) return;
  final now = DateTime.now().millisecondsSinceEpoch;
  if (p.categoriaRevision + 1 < p.categorias.length) {
    p.categoriaRevision++;
    return;
  }
  // Fin de la ronda de categorías.
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
  p.fase = FaseTuti.countdownRuleta;
  p.faseInicioMs = now;
}

bool esUltimaCategoriaRevisionTuti(PartidaTuti p) =>
    p.categoriaRevision >= p.categorias.length - 1;

bool quedanRondasTuti(PartidaTuti p) => p.ronda < p.maxRondas;

void acabarPartidaTuti(PartidaTuti p) {
  p.fase = FaseTuti.fin;
  p.faseInicioMs = DateTime.now().millisecondsSinceEpoch;
}

List<MapEntry<String, int>> rankingTuti(PartidaTuti p) {
  final entries = p.totales.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries;
}
