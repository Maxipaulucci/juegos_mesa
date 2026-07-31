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

int filaPapa(int index) => index ~/ columnasPapa;
int colPapa(int index) => index % columnasPapa;

/// Consecutivos: no misma fila/columna y no vecinos (queda al menos 1 casilla).
bool posicionesConsecutivasValidasPapa(int a, int b) {
  final fa = filaPapa(a);
  final fb = filaPapa(b);
  final ca = colPapa(a);
  final cb = colPapa(b);
  if (fa == fb || ca == cb) return false;
  final dr = (fa - fb).abs();
  final dc = (ca - cb).abs();
  // Vecinos en las 8 direcciones → no hay casilla blanca en el medio.
  if (dr <= 1 && dc <= 1) return false;
  return true;
}

List<int?>? _generarCasillasPapa(math.Random rng) {
  final casillas = List<int?>.filled(totalCasillasPapa, null);
  final libres = List<int>.generate(totalCasillasPapa, (i) => i);

  bool colocar(int numero, int? prevIdx) {
    if (numero > maxNumeroPapa) return true;
    final orden = List<int>.of(libres)..shuffle(rng);
    for (final i in orden) {
      if (prevIdx != null && !posicionesConsecutivasValidasPapa(prevIdx, i)) {
        continue;
      }
      casillas[i] = numero;
      libres.remove(i);
      if (colocar(numero + 1, i)) return true;
      libres.add(i);
      casillas[i] = null;
    }
    return false;
  }

  if (!colocar(1, null)) return null;
  return casillas;
}

/// Genera 30 números (1..30) en 50 casillas al azar, con reglas de separación.
PartidaPapa nuevaPartidaPapa({
  required List<String> nombres,
  int? semilla,
}) {
  final rng = math.Random(semilla);
  List<int?>? casillas;
  for (var intento = 0; intento < 80; intento++) {
    casillas = _generarCasillasPapa(rng);
    if (casillas != null) break;
  }
  if (casillas == null) {
    // Último recurso: reintentos extra (en la práctica casi no hace falta).
    for (var intento = 0; intento < 200; intento++) {
      casillas = _generarCasillasPapa(math.Random(rng.nextInt(1 << 30)));
      if (casillas != null) break;
    }
  }
  if (casillas == null) {
    throw StateError('No se pudo armar una hoja válida de La papa.');
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
  // Cruce propio: signos estrictamente opuestos.
  return (o1 > 0) != (o2 > 0) &&
      o1 != 0 &&
      o2 != 0 &&
      (o3 > 0) != (o4 > 0) &&
      o3 != 0 &&
      o4 != 0;
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

bool _puntoCercaDeTrazos(Offset p, List<TrazoPapa> trazos, double umbral) {
  for (final t in trazos) {
    final pts = t.puntos;
    for (var i = 1; i < pts.length; i++) {
      if (_distPuntoSegmento(p, pts[i - 1], pts[i]) <= umbral) return true;
    }
  }
  return false;
}

/// True si el trazo actual cruza o roza una línea previa.
/// Pierde al toque inmediato; solo se ignora un entorno chico del número
/// de salida (para poder despegar sin chocar con la punta del trazo anterior).
bool trazoChocaConPreviosPapa(
  PartidaPapa p,
  List<Offset> trazoActual, {
  required Size boardSize,
}) {
  if (trazoActual.length < 2 || p.trazos.isEmpty) return false;
  final cell = math.min(
    boardSize.width / columnasPapa,
    boardSize.height / filasPapa,
  );
  // ~mitad del grosor visual del trazo (+ un poco): rozar la línea cuenta.
  final umbral = math.max(3.0, cell * 0.05);
  final idxInicio = p.indiceDeNumero(p.siguienteConectar);
  final centroInicio =
      idxInicio != null ? centroCasillaPapa(idxInicio, boardSize) : null;
  // Zona chica: solo para salir del número, no para “atravesar” la hoja.
  final radioIgnorar = cell * 0.2;

  bool enZonaInicio(Offset pt) =>
      centroInicio != null && (pt - centroInicio).distance <= radioIgnorar;

  // Segmentos previos a evaluar (sin la punta que llega al número de salida).
  final segsPrev = <(Offset, Offset)>[];
  for (final t in p.trazos) {
    final pts = t.puntos;
    for (var j = 1; j < pts.length; j++) {
      final p1 = pts[j - 1];
      final p2 = pts[j];
      if (t.a == p.siguienteConectar && enZonaInicio(p1) && enZonaInicio(p2)) {
        continue;
      }
      segsPrev.add((p1, p2));
    }
  }
  if (segsPrev.isEmpty) return false;

  for (var i = 1; i < trazoActual.length; i++) {
    final a = trazoActual[i - 1];
    final b = trazoActual[i];
    final segLen = (b - a).distance;
    if (segLen < 1e-6) continue;

    for (final (p1, p2) in segsPrev) {
      if (_cruzan(a, b, p1, p2)) return true;
    }

    // Muestreo denso: detecta roce aunque el cruce no caiga en un extremo.
    final muestras = math.max(2, (segLen / 1.5).ceil());
    for (var s = 0; s <= muestras; s++) {
      final pt = Offset.lerp(a, b, s / muestras)!;
      if (enZonaInicio(pt)) continue;
      for (final (p1, p2) in segsPrev) {
        if (_distPuntoSegmento(pt, p1, p2) <= umbral) return true;
      }
    }
  }
  return false;
}

bool cercaDeNumeroPapa(
  PartidaPapa p,
  int numero,
  Offset pos,
  Size boardSize, {
  double factorRadio = 0.32,
}) {
  final idx = p.indiceDeNumero(numero);
  if (idx == null) return false;
  final cellW = boardSize.width / columnasPapa;
  final cellH = boardSize.height / filasPapa;
  final radio = math.min(cellW, cellH) * factorRadio;
  final c = centroCasillaPapa(idx, boardSize);
  return (pos - c).distance <= radio;
}

double _anguloDiff(double a, double b) {
  var d = (a - b) % (2 * math.pi);
  if (d < 0) d += 2 * math.pi;
  if (d > math.pi) d = 2 * math.pi - d;
  return d;
}

/// Intersecciones del segmento [a,b] con la circunferencia (c,r).
List<Offset> _interseccionesSegmentoCirculo(
  Offset c,
  double r,
  Offset a,
  Offset b,
) {
  final d = b - a;
  final f = a - c;
  final A = d.dx * d.dx + d.dy * d.dy;
  if (A < 1e-10) return const [];
  final B = 2 * (f.dx * d.dx + f.dy * d.dy);
  final C = f.dx * f.dx + f.dy * f.dy - r * r;
  var disc = B * B - 4 * A * C;
  if (disc < 0) return const [];
  disc = math.sqrt(disc);
  final out = <Offset>[];
  for (final sign in [-1.0, 1.0]) {
    final t = (-B + sign * disc) / (2 * A);
    if (t >= 0 && t <= 1) {
      out.add(Offset(a.dx + d.dx * t, a.dy + d.dy * t));
    }
  }
  return out;
}

/// Primer punto donde el trazo entra al círculo del número.
Offset? puntoEntradaAlCirculoPapa(
  List<Offset> trazo,
  Offset centro,
  double radio,
) {
  if (trazo.isEmpty) return null;
  for (var i = 1; i < trazo.length; i++) {
    final a = trazo[i - 1];
    final b = trazo[i];
    final da = (a - centro).distance;
    final db = (b - centro).distance;
    final crosses = _interseccionesSegmentoCirculo(centro, radio, a, b);
    if (da >= radio && db <= radio && crosses.isNotEmpty) {
      // Entrada: la intersección más cercana a b (hacia adentro).
      crosses.sort(
        (p, q) => (p - b).distanceSquared.compareTo((q - b).distanceSquared),
      );
      return crosses.first;
    }
    if (da > radio && db > radio && crosses.length == 2) {
      // Corta el círculo: primera entrada según el sentido a→b.
      crosses.sort(
        (p, q) => (p - a).distanceSquared.compareTo((q - a).distanceSquared),
      );
      return crosses.first;
    }
  }
  // Si el trazo ya nace dentro, no hay “entrada” clara.
  if ((trazo.first - centro).distance <= radio) return trazo.first;
  return null;
}

/// Ángulos (rad) donde trazos previos cruzan el borde del círculo.
List<double> angulosBloqueadosEnNumeroPapa(
  PartidaPapa p,
  int numero,
  Size boardSize, {
  double factorRadio = 0.32,
}) {
  final idx = p.indiceDeNumero(numero);
  if (idx == null || p.trazos.isEmpty) return const [];
  final cellW = boardSize.width / columnasPapa;
  final cellH = boardSize.height / filasPapa;
  final radio = math.min(cellW, cellH) * factorRadio;
  final c = centroCasillaPapa(idx, boardSize);
  final angs = <double>[];

  for (final t in p.trazos) {
    final pts = t.puntos;
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1];
      final b = pts[i];
      for (final pto in _interseccionesSegmentoCirculo(c, radio, a, b)) {
        angs.add(math.atan2(pto.dy - c.dy, pto.dx - c.dx));
      }
      // Si el segmento pasa adentro sin cortar el borde (casi centro):
      final cerca = _distPuntoSegmento(c, a, b);
      if (cerca < radio * 0.35) {
        final ab = b - a;
        if (ab.distance > 1e-6) {
          final angLinea = math.atan2(ab.dy, ab.dx);
          angs.add(angLinea);
          angs.add(angLinea + math.pi);
        }
      }
    }
  }
  return angs;
}

/// True si se entra al número por un arco ya ocupado por otra línea.
bool llegadaPorLadoBloqueadoPapa(
  PartidaPapa p,
  int numero,
  List<Offset> trazoActual,
  Size boardSize, {
  double factorRadio = 0.32,
  /// Mitad del arco bloqueado alrededor de cada cruce (~70°).
  double margenRad = 70 * math.pi / 180,
}) {
  final idx = p.indiceDeNumero(numero);
  if (idx == null || trazoActual.length < 2) return false;
  final cellW = boardSize.width / columnasPapa;
  final cellH = boardSize.height / filasPapa;
  final radio = math.min(cellW, cellH) * factorRadio;
  final c = centroCasillaPapa(idx, boardSize);

  final bloqueados = angulosBloqueadosEnNumeroPapa(
    p,
    numero,
    boardSize,
    factorRadio: factorRadio,
  );
  if (bloqueados.isEmpty) return false;

  final entrada = puntoEntradaAlCirculoPapa(trazoActual, c, radio);
  if (entrada == null) return false;
  final angEntrada = math.atan2(entrada.dy - c.dy, entrada.dx - c.dx);

  for (final ang in bloqueados) {
    if (_anguloDiff(angEntrada, ang) <= margenRad) return true;
  }

  // Además: el punto de entrada no puede rozar la tinta previa.
  final umbralTinta = math.max(3.5, radio * 0.45);
  if (_puntoCercaDeTrazos(entrada, p.trazos, umbralTinta)) return true;

  return false;
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
