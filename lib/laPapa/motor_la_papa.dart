import 'dart:math' as math;
import 'dart:ui';

/// Motor de La Papa: hoja 5×10 (50 casillas) con 30 números y trazos.

const int columnasPapa = 5;
const int filasPapa = 10;
const int totalCasillasPapa = columnasPapa * filasPapa; // 50
const int maxNumeroPapa = 30;

enum FasePapa { jugando, ganado, perdido }

class TrazoPapa {
  TrazoPapa({
    required this.puntos,
    required this.de,
    required this.a,
    required this.jugador,
  });

  final List<Offset> puntos;
  final int de;
  final int a;
  final String jugador;
}

class PartidaPapa {
  PartidaPapa({
    required this.nombres,
    required this.casillas,
    this.indiceTurno = 0,
    this.siguienteConectar = 1,
    List<TrazoPapa>? trazos,
    this.fase = FasePapa.jugando,
    this.mensajeFin,
  }) : trazos = trazos ?? [];

  final List<String> nombres;
  /// Índice 0..49 → número 1..30 o null si vacío.
  final List<int?> casillas;
  int indiceTurno;
  /// Hay que conectar [siguienteConectar] → [siguienteConectar+1].
  int siguienteConectar;
  final List<TrazoPapa> trazos;
  FasePapa fase;
  String? mensajeFin;

  String get jugadorActual =>
      nombres.isEmpty ? '' : nombres[indiceTurno % nombres.length];

  bool get terminada =>
      fase == FasePapa.ganado || fase == FasePapa.perdido;

  int? indiceDeNumero(int n) {
    for (var i = 0; i < casillas.length; i++) {
      if (casillas[i] == n) return i;
    }
    return null;
  }
}

/// Genera 30 números (1..30) en 50 casillas al azar.
PartidaPapa nuevaPartidaPapa({
  required List<String> nombres,
  int? semilla,
}) {
  final rng = math.Random(semilla);
  final indices = List<int>.generate(totalCasillasPapa, (i) => i)..shuffle(rng);
  final casillas = List<int?>.filled(totalCasillasPapa, null);
  for (var n = 1; n <= maxNumeroPapa; n++) {
    casillas[indices[n - 1]] = n;
  }
  return PartidaPapa(
    nombres: List<String>.from(nombres),
    casillas: casillas,
  );
}

Offset centroCasillaPapa(int index, Size boardSize) {
  final col = index % columnasPapa;
  final row = index ~/ columnasPapa;
  final cellW = boardSize.width / columnasPapa;
  final cellH = boardSize.height / filasPapa;
  return Offset(col * cellW + cellW / 2, row * cellH + cellH / 2);
}

Rect rectCasillaPapa(int index, Size boardSize) {
  final col = index % columnasPapa;
  final row = index ~/ columnasPapa;
  final cellW = boardSize.width / columnasPapa;
  final cellH = boardSize.height / filasPapa;
  return Rect.fromLTWH(col * cellW, row * cellH, cellW, cellH);
}

double _distPuntoSegmento(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 < 1e-8) return (p - a).distance;
  var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
  t = t.clamp(0.0, 1.0);
  final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
  return (p - proj).distance;
}

bool _segmentosCercanos(
  Offset a1,
  Offset a2,
  Offset b1,
  Offset b2,
  double umbral,
) {
  if (_distPuntoSegmento(a1, b1, b2) <= umbral) return true;
  if (_distPuntoSegmento(a2, b1, b2) <= umbral) return true;
  if (_distPuntoSegmento(b1, a1, a2) <= umbral) return true;
  if (_distPuntoSegmento(b2, a1, a2) <= umbral) return true;
  // Cruce clásico de segmentos.
  return _cruzan(a1, a2, b1, b2);
}

double _orient(Offset a, Offset b, Offset c) {
  return (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
}

bool _cruzan(Offset a1, Offset a2, Offset b1, Offset b2) {
  final o1 = _orient(a1, a2, b1);
  final o2 = _orient(a1, a2, b2);
  final o3 = _orient(b1, b2, a1);
  final o4 = _orient(b1, b2, a2);
  if (o1 == 0 && o2 == 0 && o3 == 0 && o4 == 0) {
    // Colineales: se solapan si proyectan.
    return _proyeccionSolapa(a1, a2, b1, b2);
  }
  return (o1 > 0) != (o2 > 0) && (o3 > 0) != (o4 > 0);
}

bool _proyeccionSolapa(Offset a1, Offset a2, Offset b1, Offset b2) {
  final minAx = math.min(a1.dx, a2.dx);
  final maxAx = math.max(a1.dx, a2.dx);
  final minAy = math.min(a1.dy, a2.dy);
  final maxAy = math.max(a1.dy, a2.dy);
  final minBx = math.min(b1.dx, b2.dx);
  final maxBx = math.max(b1.dx, b2.dx);
  final minBy = math.min(b1.dy, b2.dy);
  final maxBy = math.max(b1.dy, b2.dy);
  return maxAx >= minBx && maxBx >= minAx && maxAy >= minBy && maxBy >= minAy;
}

/// ¿El segmento [a→b] choca con algún trazo ya aceptado?
bool chocaConTrazosPapa(
  List<TrazoPapa> trazos,
  Offset a,
  Offset b, {
  double umbral = 7.0,
}) {
  for (final t in trazos) {
    final pts = t.puntos;
    for (var i = 1; i < pts.length; i++) {
      if (_segmentosCercanos(a, b, pts[i - 1], pts[i], umbral)) return true;
    }
  }
  return false;
}

double longitudPolylinePapa(List<Offset> pts) {
  var L = 0.0;
  for (var i = 1; i < pts.length; i++) {
    L += (pts[i] - pts[i - 1]).distance;
  }
  return L;
}

bool _puntoCercaDeTrazos(Offset p, List<TrazoPapa> trazos, double umbral) {
  for (final t in trazos) {
    final pts = t.puntos;
    for (var i = 1; i < pts.length; i++) {
      if (_distPuntoSegmento(p, pts[i - 1], pts[i]) <= umbral) return true;
    }
  }
  return false;
}

/// Longitud del trazo actual que queda “encima” de trazos previos.
/// Ignora la zona del número de partida (donde nace el trazo anterior).
double longitudSolapadaPapa(
  List<TrazoPapa> trazos,
  List<Offset> trazoActual, {
  Offset? ignorarCercaDe,
  double radioIgnorar = 28,
  double umbral = 3.5,
}) {
  if (trazoActual.length < 2 || trazos.isEmpty) return 0;
  var solapada = 0.0;
  for (var i = 1; i < trazoActual.length; i++) {
    final a = trazoActual[i - 1];
    final b = trazoActual[i];
    final segLen = (b - a).distance;
    if (segLen < 1e-6) continue;
    final muestras = math.max(2, (segLen / 2.5).ceil());
    var chocan = 0;
    var validas = 0;
    for (var s = 0; s <= muestras; s++) {
      final t = s / muestras;
      final p = Offset.lerp(a, b, t)!;
      if (ignorarCercaDe != null &&
          (p - ignorarCercaDe).distance <= radioIgnorar) {
        continue;
      }
      validas++;
      if (_puntoCercaDeTrazos(p, trazos, umbral)) chocan++;
    }
    if (validas == 0) continue;
    solapada += segLen * (chocan / validas);
  }
  return solapada;
}

/// Pierde recién cuando ~10% del trazo actual está encima de otra línea.
bool trazoPierdePorSolapePapa(
  PartidaPapa p,
  List<Offset> trazoActual, {
  required Size boardSize,
  double fraccionMin = 0.10,
}) {
  if (trazoActual.length < 3 || p.trazos.isEmpty) return false;
  final total = longitudPolylinePapa(trazoActual);
  final cell = math.min(
    boardSize.width / columnasPapa,
    boardSize.height / filasPapa,
  );
  // Trazo muy corto: todavía no se juzga.
  if (total < cell * 0.8) return false;

  final idxInicio = p.indiceDeNumero(p.siguienteConectar);
  final centroInicio =
      idxInicio != null ? centroCasillaPapa(idxInicio, boardSize) : null;

  final solape = longitudSolapadaPapa(
    p.trazos,
    trazoActual,
    ignorarCercaDe: centroInicio,
    radioIgnorar: cell * 0.55,
    umbral: math.max(2.8, cell * 0.08),
  );

  // Al menos 10% del trazo, y un mínimo absoluto para no disparar por un roce.
  return solape >= total * fraccionMin && solape >= cell * 0.22;
}

bool cercaDeNumeroPapa(
  PartidaPapa p,
  int numero,
  Offset pos,
  Size boardSize, {
  double factorRadio = 0.42,
}) {
  final idx = p.indiceDeNumero(numero);
  if (idx == null) return false;
  final cellW = boardSize.width / columnasPapa;
  final cellH = boardSize.height / filasPapa;
  final radio = math.min(cellW, cellH) * factorRadio;
  final c = centroCasillaPapa(idx, boardSize);
  return (pos - c).distance <= radio;
}

/// Acepta el trazo si une el par actual y no chocó.
void aceptarTrazoPapa(PartidaPapa p, List<Offset> puntos) {
  if (p.terminada || puntos.length < 2) return;
  final de = p.siguienteConectar;
  final a = de + 1;
  p.trazos.add(
    TrazoPapa(
      puntos: List<Offset>.from(puntos),
      de: de,
      a: a,
      jugador: p.jugadorActual,
    ),
  );
  if (a >= maxNumeroPapa) {
    p.fase = FasePapa.ganado;
    p.mensajeFin = '${p.jugadorActual} conectó hasta $maxNumeroPapa. ¡Ganó!';
    return;
  }
  p.siguienteConectar = a;
  if (p.nombres.length > 1) {
    p.indiceTurno = (p.indiceTurno + 1) % p.nombres.length;
  }
}

void perderPapa(PartidaPapa p, {String? motivo}) {
  if (p.terminada) return;
  p.fase = FasePapa.perdido;
  p.mensajeFin = motivo ??
      '${p.jugadorActual} tocó una línea. Fin de la partida.';
}
