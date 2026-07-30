/// Motor de Tutti Frutti (online por fases).
library;

const int minCategoriasTuti = 3;
const int maxCategoriasTuti = 6;
const int maxCharsCategoriaTuti = 25;
const Duration duracionContadorTuti = Duration(seconds: 3);

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
}

class PartidaTuti {
  PartidaTuti({
    required this.nombres,
    required this.categorias,
    this.fase = FaseTuti.countdownRuleta,
    this.indiceSpinner = 0,
    this.ronda = 1,
    this.letra,
    this.ruletaInicioMs,
    this.ruletaVelocidad = 8.0,
    this.faseInicioMs,
    Map<String, List<String>>? respuestas,
    Map<String, bool>? listos,
    this.bastaTodos = false,
    this.categoriaRevision = 0,
    Map<String, List<int?>>? puntajes,
    Map<String, int>? totales,
    this.version = 1,
  })  : respuestas = respuestas ??
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
  String? letra;
  int? ruletaInicioMs;
  double ruletaVelocidad;
  int? faseInicioMs;
  Map<String, List<String>> respuestas;
  Map<String, bool> listos;
  bool bastaTodos;
  int categoriaRevision;
  Map<String, List<int?>> puntajes;
  Map<String, int> totales;
  int version;

  int get indiceParador =>
      nombres.isEmpty ? 0 : (indiceSpinner + 1) % nombres.length;

  String get nombreSpinner =>
      nombres.isEmpty ? '' : nombres[indiceSpinner % nombres.length];

  String get nombreParador =>
      nombres.isEmpty ? '' : nombres[indiceParador];

  bool get todosListos =>
      nombres.every((n) => listos[n] == true);

  bool get escrituraTerminada => bastaTodos || todosListos;

  /// Letra actual de la ruleta según reloj compartido.
  String letraActualRuleta({int? ahoraMs}) {
    if (letra != null && letra!.isNotEmpty) return letra!;
    final inicio = ruletaInicioMs;
    if (inicio == null) return abecedarioTuti[0];
    final ahora = ahoraMs ?? DateTime.now().millisecondsSinceEpoch;
    final elapsedSec = ((ahora - inicio) / 1000.0).clamp(0.0, 1e9);
    final idx =
        (elapsedSec * ruletaVelocidad).floor() % abecedarioTuti.length;
    return abecedarioTuti[idx];
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
}) {
  final cats = categorias.map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
  final now = DateTime.now().millisecondsSinceEpoch;
  return PartidaTuti(
    nombres: List<String>.from(nombres),
    categorias: List<String>.from(cats),
    fase: FaseTuti.countdownRuleta,
    indiceSpinner: 0,
    ronda: 1,
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
      break;
    case FaseTuti.countdownEscritura:
      p.fase = FaseTuti.escritura;
      p.faseInicioMs = now;
      p.bastaTodos = false;
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
  p.letra = p.letraActualRuleta(ahoraMs: now);
  p.fase = FaseTuti.countdownEscritura;
  p.faseInicioMs = now;
}

void setRespuestaTuti(PartidaTuti p, String nombre, int catIndex, String texto) {
  if (p.fase != FaseTuti.escritura) return;
  if (p.listos[nombre] == true || p.bastaTodos) return;
  final list = p.respuestas[nombre];
  if (list == null || catIndex < 0 || catIndex >= list.length) return;
  list[catIndex] = texto.length > 40 ? texto.substring(0, 40) : texto;
}

void bastaParaMiTuti(PartidaTuti p, String nombre) {
  if (p.fase != FaseTuti.escritura) return;
  p.listos[nombre] = true;
  if (p.escrituraTerminada) _irACountdownRevision(p);
}

void bastaParaTodosTuti(PartidaTuti p) {
  if (p.fase != FaseTuti.escritura) return;
  p.bastaTodos = true;
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

/// Continuar revisión (anfitrión): siguiente categoría o nueva ronda.
void continuarRevisionTuti(PartidaTuti p) {
  if (p.fase != FaseTuti.revision) return;
  final now = DateTime.now().millisecondsSinceEpoch;
  if (p.categoriaRevision + 1 < p.categorias.length) {
    p.categoriaRevision++;
    return;
  }
  // Nueva ronda: siguiente spinner.
  p.indiceSpinner = (p.indiceSpinner + 1) % p.nombres.length;
  p.ronda++;
  p.letra = null;
  p.categoriaRevision = 0;
  p.bastaTodos = false;
  p.listos = {for (final n in p.nombres) n: false};
  p.fase = FaseTuti.countdownRuleta;
  p.faseInicioMs = now;
}

void acabarPartidaTuti(PartidaTuti p) {
  p.fase = FaseTuti.fin;
  p.faseInicioMs = DateTime.now().millisecondsSinceEpoch;
}

List<MapEntry<String, int>> rankingTuti(PartidaTuti p) {
  final entries = p.totales.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries;
}
