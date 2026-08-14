import 'dart:math' as math;
import 'dart:ui';

import 'package:app_juegos_mesa/laPapa/opciones_la_papa.dart';

/// Motor de La Papa: hoja 5×10 (50 casillas) con números y trazos.

const int columnasPapa = 5;
const int filasPapa = 10;
const int totalCasillasPapa = columnasPapa * filasPapa; // 50
/// Valor por defecto (compat tests / menú).
const int maxNumeroPapa = OpcionesPapa.maxNumeroPapaDefault;

enum FasePapa { colocando, jugando, ganado, perdido }

/// Grosor del lápiz al dibujar.
enum GrosorTrazoPapa {
  fino(1.8, 'Fino'),
  normal(3.2, 'Normal'),
  grueso(5.6, 'Grueso');

  const GrosorTrazoPapa(this.ancho, this.etiqueta);
  final double ancho;
  final String etiqueta;

  /// Radio efectivo para choques.
  ///
  /// Usa ~48% del ancho (un poco menos que la mitad visual) para no marcar
  /// roce cuando todavía se ve un hueco blanco entre las tintas.
  double get radioChoque => math.max(0.85, ancho * 0.48);
}

class TrazoPapa {
  TrazoPapa({
    required this.puntos,
    required this.de,
    required this.a,
    required this.jugador,
    this.grosor = GrosorTrazoPapa.normal,
  });

  /// Puntos en coordenadas normalizadas (0..1 respecto de la hoja).
  final List<Offset> puntos;
  final int de;
  final int a;
  final String jugador;
  final GrosorTrazoPapa grosor;
}

/// Convierte puntos de píxeles de [board] a fracciones 0..1.
List<Offset> normalizarPuntosPapa(List<Offset> pts, Size board) {
  final w = board.width <= 1e-6 ? 1.0 : board.width;
  final h = board.height <= 1e-6 ? 1.0 : board.height;
  return [for (final p in pts) Offset(p.dx / w, p.dy / h)];
}

/// Convierte puntos normalizados (0..1) a píxeles de [board].
List<Offset> desnormalizarPuntosPapa(List<Offset> pts, Size board) {
  return [
    for (final p in pts) Offset(p.dx * board.width, p.dy * board.height),
  ];
}

/// Heurística: trazos nuevos están en 0..1; partidas viejas pueden traer píxeles.
bool puntosParecenNormalizadosPapa(List<Offset> pts) {
  if (pts.isEmpty) return true;
  return pts.every(
    (p) => p.dx >= -0.08 && p.dx <= 1.08 && p.dy >= -0.08 && p.dy <= 1.08,
  );
}

/// Puntos del trazo en píxeles de [hoja] ( Tolera legacy absoluto + [origenLegacy] ).
List<Offset> puntosTrazoEnHojaPapa(
  TrazoPapa t,
  Size hoja, {
  Size? origenLegacy,
}) {
  if (puntosParecenNormalizadosPapa(t.puntos)) {
    return desnormalizarPuntosPapa(t.puntos, hoja);
  }
  if (origenLegacy != null &&
      origenLegacy.width > 1e-6 &&
      origenLegacy.height > 1e-6) {
    final sx = hoja.width / origenLegacy.width;
    final sy = hoja.height / origenLegacy.height;
    return [for (final p in t.puntos) Offset(p.dx * sx, p.dy * sy)];
  }
  return t.puntos;
}

class PartidaPapa {
  PartidaPapa({
    required this.nombres,
    required this.casillas,
    required this.maxNumero,
    this.indiceTurno = 0,
    this.siguienteConectar = 1,
    this.siguienteAColocar = 1,
    List<TrazoPapa>? trazos,
    this.fase = FasePapa.jugando,
    this.mensajeFin,
    this.ganador,
    this.conVidas = false,
    this.modoFantasma = false,
    List<int>? vidas,
    List<String>? rendidos,
  })  : trazos = trazos ?? [],
        vidas = vidas ?? [],
        rendidos = List<String>.from(rendidos ?? const []);

  final List<String> nombres;
  /// Índice 0..49 → número 1..maxNumero o null si vacío.
  final List<int?> casillas;
  final int maxNumero;
  int indiceTurno;
  /// Hay que conectar [siguienteConectar] → [siguienteConectar+1].
  int siguienteConectar;
  /// Durante colocación manual: próximo número a ubicar.
  int siguienteAColocar;
  final List<TrazoPapa> trazos;
  FasePapa fase;
  String? mensajeFin;
  /// Nombre del ganador si [fase] es [FasePapa.ganado].
  String? ganador;
  final bool conVidas;
  final bool modoFantasma;
  /// Vidas restantes por jugador (vacío si [conVidas] es false).
  final List<int> vidas;
  /// Multijugador: nombres fuera de la partida (rendidos / eliminados).
  final List<String> rendidos;

  String get jugadorActual =>
      nombres.isEmpty ? '' : nombres[indiceTurno % nombres.length];

  bool get terminada =>
      fase == FasePapa.ganado || fase == FasePapa.perdido;

  bool estaRendido(String nombre) => rendidos.contains(nombre);

  List<String> get jugadoresActivos => [
        for (final n in nombres)
          if (!estaRendido(n)) n,
      ];

  int? vidasDelActual() {
    if (!conVidas || vidas.isEmpty || nombres.isEmpty) return null;
    return vidas[indiceTurno % vidas.length];
  }

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

List<int?>? _generarCasillasConExcepcionPapa(math.Random rng, int maxNumero) {
  final casillas = List<int?>.filled(totalCasillasPapa, null);
  final libres = List<int>.generate(totalCasillasPapa, (i) => i);

  bool colocar(int numero, int? prevIdx) {
    if (numero > maxNumero) return true;
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

/// Aleatorio libre: cualquier casilla vacía de las 50, sin restricciones.
List<int?> _generarCasillasAleatoriasLibresPapa(
  math.Random rng,
  int maxNumero,
) {
  final casillas = List<int?>.filled(totalCasillasPapa, null);
  final indices = List<int>.generate(totalCasillasPapa, (i) => i)..shuffle(rng);
  final n = maxNumero.clamp(0, totalCasillasPapa);
  for (var i = 0; i < n; i++) {
    casillas[indices[i]] = i + 1;
  }
  return casillas;
}

List<int> _vidasIniciales(List<String> nombres, bool conVidas) {
  if (!conVidas || nombres.isEmpty) return [];
  return List<int>.filled(nombres.length, OpcionesPapa.vidasIniciales);
}

/// Genera la hoja según [opciones] (aleatoria o vacía para colocar a mano).
PartidaPapa nuevaPartidaPapa({
  required List<String> nombres,
  OpcionesPapa opciones = const OpcionesPapa(),
  int? semilla,
}) {
  final maxN = opciones.cantidadNumerosClamped;
  final nombresCopy = List<String>.from(nombres);
  final vidas = _vidasIniciales(nombresCopy, opciones.conVidasEfectivas);

  if (!opciones.numerosAleatoriosEfectivos) {
    return PartidaPapa(
      nombres: nombresCopy,
      casillas: List<int?>.filled(totalCasillasPapa, null),
      maxNumero: maxN,
      fase: FasePapa.colocando,
      siguienteAColocar: 1,
      conVidas: opciones.conVidasEfectivas,
      modoFantasma: opciones.modoFantasma,
      vidas: vidas,
    );
  }

  final rng = math.Random(semilla);
  late final List<int?> casillas;
  if (opciones.excepcionGeneracionNumeros) {
    List<int?>? generadas;
    for (var intento = 0; intento < 80; intento++) {
      generadas = _generarCasillasConExcepcionPapa(rng, maxN);
      if (generadas != null) break;
    }
    if (generadas == null) {
      for (var intento = 0; intento < 200; intento++) {
        generadas = _generarCasillasConExcepcionPapa(
          math.Random(rng.nextInt(1 << 30)),
          maxN,
        );
        if (generadas != null) break;
      }
    }
    if (generadas == null) {
      throw StateError('No se pudo armar una hoja válida de La papa.');
    }
    casillas = generadas;
  } else {
    casillas = _generarCasillasAleatoriasLibresPapa(rng, maxN);
  }

  return PartidaPapa(
    nombres: nombresCopy,
    casillas: casillas,
    maxNumero: maxN,
    conVidas: opciones.conVidasEfectivas,
    modoFantasma: opciones.modoFantasma,
    vidas: vidas,
  );
}

/// Coloca el siguiente número en [index]. Devuelve error o null si ok.
String? colocarNumeroEnCasillaPapa(
  PartidaPapa p,
  int index, {
  bool excepcionGeneracion = false,
}) {
  if (p.fase != FasePapa.colocando) return 'La hoja ya está armada.';
  if (index < 0 || index >= p.casillas.length) return 'Casilla inválida.';
  if (p.casillas[index] != null) return 'Esa casilla ya tiene número.';
  final n = p.siguienteAColocar;
  if (excepcionGeneracion && n > 1) {
    final prev = p.indiceDeNumero(n - 1);
    if (prev == null) return 'Falta el número anterior.';
    if (!posicionesConsecutivasValidasPapa(prev, index)) {
      return 'El $n debe quedar separado del ${n - 1} '
          '(no misma fila/columna ni vecinos).';
    }
  }
  p.casillas[index] = n;
  if (n >= p.maxNumero) {
    p.fase = FasePapa.jugando;
    p.siguienteConectar = 1;
    p.indiceTurno = 0;
    _asegurarTurnoActivoPapa(p);
    return null;
  }
  p.siguienteAColocar = n + 1;
  _pasarTurnoPapa(p);
  return null;
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

Offset _proyeccionEnSegmento(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 < 1e-8) return a;
  var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
  t = t.clamp(0.0, 1.0);
  return Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
}

bool cercaDePuentePapa(Offset p, List<Offset> puentes, double radio) {
  if (puentes.isEmpty || radio <= 0) return false;
  final r2 = radio * radio;
  for (final q in puentes) {
    final dx = p.dx - q.dx;
    final dy = p.dy - q.dy;
    if (dx * dx + dy * dy <= r2) return true;
  }
  return false;
}

double radioPuentePapa(Size boardSize, GrosorTrazoPapa grosor) {
  final cell = math.min(
    boardSize.width / columnasPapa,
    boardSize.height / filasPapa,
  );
  return math.max(grosor.radioChoque * 2.2, cell * 0.2);
}

bool _segmentosCercanos(
  Offset a1,
  Offset a2,
  Offset b1,
  Offset b2,
  double umbral,
) {
  if (_cruzan(a1, a2, b1, b2)) return true;
  if (_distPuntoSegmento(a1, b1, b2) <= umbral) return true;
  if (_distPuntoSegmento(a2, b1, b2) <= umbral) return true;
  if (_distPuntoSegmento(b1, a1, a2) <= umbral) return true;
  if (_distPuntoSegmento(b2, a1, a2) <= umbral) return true;

  // Muestreo denso: atrapa rozamientos en el medio (no solo extremos).
  final lenA = (a2 - a1).distance;
  final lenB = (b2 - b1).distance;
  final nA = math.max(2, (lenA / 1.0).ceil());
  for (var i = 1; i < nA; i++) {
    final p = Offset.lerp(a1, a2, i / nA)!;
    if (_distPuntoSegmento(p, b1, b2) <= umbral) return true;
  }
  final nB = math.max(2, (lenB / 1.0).ceil());
  for (var i = 1; i < nB; i++) {
    final p = Offset.lerp(b1, b2, i / nB)!;
    if (_distPuntoSegmento(p, a1, a2) <= umbral) return true;
  }
  return false;
}

double _orient(Offset a, Offset b, Offset c) {
  return (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
}

bool _cruzan(
  Offset a1,
  Offset a2,
  Offset b1,
  Offset b2, {
  bool colinealesCuentan = true,
}) {
  final o1 = _orient(a1, a2, b1);
  final o2 = _orient(a1, a2, b2);
  final o3 = _orient(b1, b2, a1);
  final o4 = _orient(b1, b2, a2);
  if (o1 == 0 && o2 == 0 && o3 == 0 && o4 == 0) {
    // Colineales: se solapan si proyectan.
    return colinealesCuentan && _proyeccionSolapa(a1, a2, b1, b2);
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
  required Size boardSize,
  double umbral = 7.0,
}) {
  for (final t in trazos) {
    final pts = puntosTrazoEnHojaPapa(t, boardSize);
    for (var i = 1; i < pts.length; i++) {
      if (_segmentosCercanos(a, b, pts[i - 1], pts[i], umbral)) return true;
    }
  }
  return false;
}

bool _puntoCercaDeTrazos(
  Offset p,
  List<TrazoPapa> trazos,
  double umbral, {
  required Size boardSize,
}) {
  for (final t in trazos) {
    final pts = puntosTrazoEnHojaPapa(t, boardSize);
    for (var i = 1; i < pts.length; i++) {
      if (_distPuntoSegmento(p, pts[i - 1], pts[i]) <= umbral) return true;
    }
  }
  return false;
}

/// Primer punto de choque del trazo actual con líneas previas (o null).
/// Si [puentesIgnorar] no está vacío, ignora contactos cerca de esas X.
Offset? primerChoqueConPreviosPapa(
  PartidaPapa p,
  List<Offset> trazoActual, {
  required Size boardSize,
  GrosorTrazoPapa grosorActual = GrosorTrazoPapa.normal,
  List<Offset> puentesIgnorar = const [],
  double radioPuente = 0,
}) {
  if (trazoActual.length < 2 || p.trazos.isEmpty) return null;
  final cell = math.min(
    boardSize.width / columnasPapa,
    boardSize.height / filasPapa,
  );
  final idxInicio = p.indiceDeNumero(p.siguienteConectar);
  final centroInicio =
      idxInicio != null ? centroCasillaPapa(idxInicio, boardSize) : null;
  final radioPunta = cell * 0.14;

  bool enPuntaLibre(Offset pt) =>
      centroInicio != null && (pt - centroInicio).distance <= radioPunta;

  (Offset, Offset)? segmentoFueraPunta(Offset a, Offset b) {
    final aIn = enPuntaLibre(a);
    final bIn = enPuntaLibre(b);
    if (aIn && bIn) return null;
    if (!aIn) return (a, b);
    if (centroInicio == null) return (a, b);
    final crosses = _interseccionesSegmentoCirculo(
      centroInicio,
      radioPunta,
      a,
      b,
    );
    if (crosses.isEmpty) return (a, b);
    crosses.sort(
      (p, q) => (p - a).distanceSquared.compareTo((q - a).distanceSquared),
    );
    return (crosses.first, b);
  }

  final segsPrev = <(Offset, Offset, double)>[];
  for (final t in p.trazos) {
    final pts = puntosTrazoEnHojaPapa(t, boardSize);
    final umbral = math.max(
      2.0,
      grosorActual.radioChoque + t.grosor.radioChoque,
    );
    for (var j = 1; j < pts.length; j++) {
      final p1 = pts[j - 1];
      final p2 = pts[j];
      if (t.a == p.siguienteConectar &&
          enPuntaLibre(p1) &&
          enPuntaLibre(p2)) {
        continue;
      }
      segsPrev.add((p1, p2, umbral));
    }
  }
  if (segsPrev.isEmpty) return null;

  for (var i = 1; i < trazoActual.length; i++) {
    final raw = segmentoFueraPunta(trazoActual[i - 1], trazoActual[i]);
    if (raw == null) continue;
    final (a, b) = raw;
    final segLen = (b - a).distance;
    if (segLen < 1e-6) continue;

    for (final (p1, p2, umbral) in segsPrev) {
      if (!_segmentosCercanos(a, b, p1, p2, umbral)) continue;
      final contacto = _proyeccionEnSegmento(
        Offset.lerp(a, b, 0.5)!,
        p1,
        p2,
      );
      if (cercaDePuentePapa(contacto, puentesIgnorar, radioPuente)) {
        continue;
      }
      return contacto;
    }

    final muestras = math.max(3, (segLen / 0.9).ceil());
    for (var s = 0; s <= muestras; s++) {
      final pt = Offset.lerp(a, b, s / muestras)!;
      if (enPuntaLibre(pt)) continue;
      for (final (p1, p2, umbral) in segsPrev) {
        if (_distPuntoSegmento(pt, p1, p2) > umbral) continue;
        final contacto = _proyeccionEnSegmento(pt, p1, p2);
        if (cercaDePuentePapa(contacto, puentesIgnorar, radioPuente)) {
          continue;
        }
        return contacto;
      }
    }
  }
  return null;
}

/// Primer autochoque del trazo (o null), respetando puentes.
Offset? primerAutochocquePapa(
  List<Offset> trazoActual, {
  required Size boardSize,
  GrosorTrazoPapa grosor = GrosorTrazoPapa.normal,
  List<Offset> puentesIgnorar = const [],
  double radioPuente = 0,
}) {
  if (trazoActual.length < 8) return null;
  final cell = math.min(
    boardSize.width / columnasPapa,
    boardSize.height / filasPapa,
  );
  final umbral = math.max(2.0, grosor.radioChoque * 2);
  final colaIgnorar = math.max(48.0, cell * 0.9);
  const minIndicesDeSeparacion = 12;

  var acumulado = 0.0;
  var desde = trazoActual.length - 1;
  while (desde > 0 && acumulado < colaIgnorar) {
    acumulado += (trazoActual[desde] - trazoActual[desde - 1]).distance;
    desde--;
  }

  for (var i = desde; i >= 1; i--) {
    final a = trazoActual[i - 1];
    final b = trazoActual[i];
    for (var j = 1; j < i - minIndicesDeSeparacion; j++) {
      final p1 = trazoActual[j - 1];
      final p2 = trazoActual[j];
      if (_cruzan(a, b, p1, p2, colinealesCuentan: false)) {
        final contacto = _proyeccionEnSegmento(
          Offset.lerp(a, b, 0.5)!,
          p1,
          p2,
        );
        if (!cercaDePuentePapa(contacto, puentesIgnorar, radioPuente)) {
          return contacto;
        }
      }
      if (_distPuntoSegmento(b, p1, p2) <= umbral) {
        final contacto = _proyeccionEnSegmento(b, p1, p2);
        if (!cercaDePuentePapa(contacto, puentesIgnorar, radioPuente)) {
          return contacto;
        }
      }
      if (_distPuntoSegmento(a, p1, p2) <= umbral * 0.85) {
        final contacto = _proyeccionEnSegmento(a, p1, p2);
        if (!cercaDePuentePapa(contacto, puentesIgnorar, radioPuente)) {
          return contacto;
        }
      }
      final segLen = (b - a).distance;
      final muestras = math.max(2, (segLen / 1.2).ceil());
      for (var s = 1; s < muestras; s++) {
        final pt = Offset.lerp(a, b, s / muestras)!;
        if (_distPuntoSegmento(pt, p1, p2) <= umbral) {
          final contacto = _proyeccionEnSegmento(pt, p1, p2);
          if (!cercaDePuentePapa(contacto, puentesIgnorar, radioPuente)) {
            return contacto;
          }
        }
      }
    }
  }
  return null;
}

/// True si el trazo actual cruza o roza una línea previa.
///
/// En el centro del número de salida hay una punta libre (para poder empezar).
/// Fuera de esa punta, cualquier tinta —incluida la que atraviesa el círculo
/// verde— es límite sólido: se puede seguir trazando hasta chocarla.
bool trazoChocaConPreviosPapa(
  PartidaPapa p,
  List<Offset> trazoActual, {
  required Size boardSize,
  GrosorTrazoPapa grosorActual = GrosorTrazoPapa.normal,
}) {
  if (trazoActual.length < 2 || p.trazos.isEmpty) return false;
  final cell = math.min(
    boardSize.width / columnasPapa,
    boardSize.height / filasPapa,
  );
  final idxInicio = p.indiceDeNumero(p.siguienteConectar);
  final centroInicio =
      idxInicio != null ? centroCasillaPapa(idxInicio, boardSize) : null;
  // Punta libre al despegar; el resto del círculo verde colisiona con la tinta.
  final radioPunta = cell * 0.14;

  bool enPuntaLibre(Offset pt) =>
      centroInicio != null && (pt - centroInicio).distance <= radioPunta;

  /// Recorta el inicio del segmento si nace dentro de la punta libre.
  (Offset, Offset)? segmentoFueraPunta(Offset a, Offset b) {
    final aIn = enPuntaLibre(a);
    final bIn = enPuntaLibre(b);
    if (aIn && bIn) return null;
    if (!aIn) return (a, b);
    if (centroInicio == null) return (a, b);
    final crosses = _interseccionesSegmentoCirculo(
      centroInicio,
      radioPunta,
      a,
      b,
    );
    if (crosses.isEmpty) return (a, b);
    crosses.sort(
      (p, q) => (p - a).distanceSquared.compareTo((q - a).distanceSquared),
    );
    return (crosses.first, b);
  }

  final segsPrev = <(Offset, Offset, double)>[];
  for (final t in p.trazos) {
    final pts = puntosTrazoEnHojaPapa(t, boardSize);
    final umbral = math.max(
      2.0,
      grosorActual.radioChoque + t.grosor.radioChoque,
    );
    for (var j = 1; j < pts.length; j++) {
      final p1 = pts[j - 1];
      final p2 = pts[j];
      // Solo la punta misma de llegada (ambos extremos en la zona libre).
      if (t.a == p.siguienteConectar &&
          enPuntaLibre(p1) &&
          enPuntaLibre(p2)) {
        continue;
      }
      segsPrev.add((p1, p2, umbral));
    }
  }
  if (segsPrev.isEmpty) return false;

  for (var i = 1; i < trazoActual.length; i++) {
    final raw = segmentoFueraPunta(trazoActual[i - 1], trazoActual[i]);
    if (raw == null) continue;
    final (a, b) = raw;
    final segLen = (b - a).distance;
    if (segLen < 1e-6) continue;

    for (final (p1, p2, umbral) in segsPrev) {
      if (_segmentosCercanos(a, b, p1, p2, umbral)) return true;
    }

    final muestras = math.max(3, (segLen / 0.9).ceil());
    for (var s = 0; s <= muestras; s++) {
      final pt = Offset.lerp(a, b, s / muestras)!;
      if (enPuntaLibre(pt)) continue;
      for (final (p1, p2, umbral) in segsPrev) {
        if (_distPuntoSegmento(pt, p1, p2) <= umbral) return true;
      }
    }
  }
  return false;
}

/// True si el trazo actual se cruza o se roza a sí mismo.
/// Ignora un tramo reciente de la punta (por longitud de camino) para no
/// falsear en curvas normales ni en trazos rectos densos.
bool trazoSeTocaASiMismoPapa(
  List<Offset> trazoActual, {
  required Size boardSize,
  GrosorTrazoPapa grosor = GrosorTrazoPapa.normal,
}) {
  if (trazoActual.length < 8) return false;
  final cell = math.min(
    boardSize.width / columnasPapa,
    boardSize.height / filasPapa,
  );
  final umbral = math.max(2.0, grosor.radioChoque * 2);
  final colaIgnorar = math.max(48.0, cell * 0.9);
  const minIndicesDeSeparacion = 12;

  final tipIndex = trazoActual.length - 1;
  final pathLen = List<double>.filled(trazoActual.length, 0);
  for (var i = 1; i < trazoActual.length; i++) {
    pathLen[i] =
        pathLen[i - 1] + (trazoActual[i] - trazoActual[i - 1]).distance;
  }
  final total = pathLen[tipIndex];
  if (total < colaIgnorar + umbral) return false;

  final minGap = math.min(minIndicesDeSeparacion, tipIndex ~/ 2);
  final a = trazoActual[tipIndex - 1];
  final b = trazoActual[tipIndex];

  for (var j = 1; j < tipIndex - 1; j++) {
    if (tipIndex - j < minGap) continue;
    // Distancia de camino desde el fin del segmento j hasta la punta.
    final distCamino = total - pathLen[j];
    if (distCamino < colaIgnorar) continue;

    final p1 = trazoActual[j - 1];
    final p2 = trazoActual[j];
    // Cruce geométrico real (sin colineales por AABB).
    if (_cruzan(a, b, p1, p2, colinealesCuentan: false)) return true;
    if (_distPuntoSegmento(b, p1, p2) <= umbral) return true;
    if (_distPuntoSegmento(a, p1, p2) <= umbral * 0.85) return true;
    final segLen = (b - a).distance;
    if (segLen < 1e-6) continue;
    final muestras = math.max(2, (segLen / 3.0).ceil());
    for (var s = 1; s < muestras; s++) {
      final pt = Offset.lerp(a, b, s / muestras)!;
      if (_distPuntoSegmento(pt, p1, p2) <= umbral) return true;
    }
  }
  return false;
}

/// Radio del círculo de verificación (zona táctil del número).
const double factorRadioVerificacionPapa = 0.32;

bool cercaDeNumeroPapa(
  PartidaPapa p,
  int numero,
  Offset pos,
  Size boardSize, {
  double factorRadio = factorRadioVerificacionPapa,
}) {
  final idx = p.indiceDeNumero(numero);
  if (idx == null) return false;
  final cellW = boardSize.width / columnasPapa;
  final cellH = boardSize.height / filasPapa;
  final radio = math.min(cellW, cellH) * factorRadio;
  final c = centroCasillaPapa(idx, boardSize);
  return (pos - c).distance <= radio;
}

/// True si [pos] está sobre tinta de trazos previos.
bool puntaSobreTintaPreviaPapa(
  PartidaPapa p,
  Offset pos,
  Size boardSize, {
  GrosorTrazoPapa grosorActual = GrosorTrazoPapa.normal,
}) {
  if (p.trazos.isEmpty) return false;
  for (final t in p.trazos) {
    final umbral = math.max(
      2.0,
      grosorActual.radioChoque + t.grosor.radioChoque,
    );
    final pts = puntosTrazoEnHojaPapa(t, boardSize);
    for (var i = 1; i < pts.length; i++) {
      if (_distPuntoSegmento(pos, pts[i - 1], pts[i]) <= umbral) return true;
    }
  }
  return false;
}

double _umbralChoquePuntaPapa(
  PartidaPapa p, {
  GrosorTrazoPapa grosorActual = GrosorTrazoPapa.normal,
}) {
  var umbral = 2.0;
  for (final t in p.trazos) {
    umbral = math.max(
      umbral,
      grosorActual.radioChoque + t.grosor.radioChoque,
    );
  }
  return umbral;
}

/// Zona habilitada del número: el círculo “achicado” por la tinta que lo corta.
/// Cuenta solo si el punto ve el centro sin cruzar ninguna línea previa
/// (como en el croquis: un lado del corte sirve, el otro no).
bool puntoEnZonaHabilitadaPapa(
  PartidaPapa p,
  int numero,
  Offset pos,
  Size boardSize, {
  GrosorTrazoPapa grosorActual = GrosorTrazoPapa.normal,
  double factorRadio = factorRadioVerificacionPapa,
}) {
  final idx = p.indiceDeNumero(numero);
  if (idx == null) return false;
  final cell = math.min(
    boardSize.width / columnasPapa,
    boardSize.height / filasPapa,
  );
  final radio = cell * factorRadio;
  final c = centroCasillaPapa(idx, boardSize);
  final dist = (pos - c).distance;
  if (dist > radio) return false;

  final umbral = _umbralChoquePuntaPapa(p, grosorActual: grosorActual);
  if (puntaSobreTintaPreviaPapa(
    p,
    pos,
    boardSize,
    grosorActual: grosorActual,
  )) {
    return false;
  }

  if (p.trazos.isEmpty) return true;

  // Visión al centro: si hay tinta entre el toque y el centro, zona tapada.
  // Se ignora un entorno mínimo del centro (para no anular todo el círculo
  // cuando una línea solo roza el punto central).
  final ignorarCentro = math.max(umbral, cell * 0.06);
  if (dist <= ignorarCentro) return true;

  final muestras = math.max(4, (dist / 1.2).ceil());
  for (var i = 1; i < muestras; i++) {
    final t = i / muestras;
    final pt = Offset.lerp(pos, c, t)!;
    if ((pt - c).distance <= ignorarCentro) continue;
    if (puntaSobreTintaPreviaPapa(
      p,
      pt,
      boardSize,
      grosorActual: grosorActual,
    )) {
      return false;
    }
  }
  return true;
}

/// True si la punta toca un número que no corresponde (origen/destino OK).
bool trazoTocaNumeroProhibidoPapa(
  PartidaPapa p,
  List<Offset> trazoActual,
  Size boardSize, {
  required bool yaSalioDelInicio,
  double factorRadio = factorRadioVerificacionPapa,
}) {
  if (trazoActual.isEmpty) return false;
  final de = p.siguienteConectar;
  final destino = de + 1;
  final tip = trazoActual.last;

  for (final n in p.casillas) {
    if (n == null) continue;
    if (n == destino) continue;
    if (n == de && !yaSalioDelInicio) continue;
    if (cercaDeNumeroPapa(p, n, tip, boardSize, factorRadio: factorRadio)) {
      return true;
    }
  }

  if (trazoActual.length >= 2) {
    final a = trazoActual[trazoActual.length - 2];
    final b = tip;
    final cell = math.min(
      boardSize.width / columnasPapa,
      boardSize.height / filasPapa,
    );
    final radio = cell * factorRadio;
    for (var i = 0; i < p.casillas.length; i++) {
      final n = p.casillas[i];
      if (n == null || n == destino || n == de) continue;
      final c = centroCasillaPapa(i, boardSize);
      final da = (a - c).distance;
      final db = (b - c).distance;
      if (da <= radio || db <= radio) return true;
      if (_interseccionesSegmentoCirculo(c, radio, a, b).isNotEmpty) {
        return true;
      }
    }
  }
  return false;
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

double _umbralTintaPapa(PartidaPapa p, double cell) {
  var umbral = math.max(2.6, cell * 0.04);
  for (final t in p.trazos) {
    umbral = math.max(umbral, t.grosor.radioChoque);
  }
  return umbral;
}

/// True si el punto de entrada cae encima de tinta previa en el borde.
/// Una línea que pasa por la casilla solo tapa donde realmente roza el
/// círculo del número; el resto de lados siguen libres.
bool llegadaPorLadoBloqueadoPapa(
  PartidaPapa p,
  int numero,
  List<Offset> trazoActual,
  Size boardSize, {
  double factorRadio = factorRadioVerificacionPapa,
}) {
  final idx = p.indiceDeNumero(numero);
  if (idx == null || trazoActual.length < 2) return false;
  final cellW = boardSize.width / columnasPapa;
  final cellH = boardSize.height / filasPapa;
  final cell = math.min(cellW, cellH);
  final radio = cell * factorRadio;
  final c = centroCasillaPapa(idx, boardSize);

  final entrada = puntoEntradaAlCirculoPapa(trazoActual, c, radio);
  if (entrada == null) return false;

  return _puntoCercaDeTrazos(
    entrada,
    p.trazos,
    _umbralTintaPapa(p, cell),
    boardSize: boardSize,
  );
}

/// Acepta el trazo si une el par actual y no chocó.
void aceptarTrazoPapa(
  PartidaPapa p,
  List<Offset> puntos, {
  required Size boardSize,
  GrosorTrazoPapa grosor = GrosorTrazoPapa.normal,
}) {
  if (p.terminada || p.fase != FasePapa.jugando || puntos.length < 2) return;
  final de = p.siguienteConectar;
  final a = de + 1;
  p.trazos.add(
    TrazoPapa(
      puntos: normalizarPuntosPapa(puntos, boardSize),
      de: de,
      a: a,
      jugador: p.jugadorActual,
      grosor: grosor,
    ),
  );
  if (a >= p.maxNumero) {
    p.fase = FasePapa.ganado;
    p.ganador = p.jugadorActual;
    p.mensajeFin = '${p.jugadorActual} conectó hasta ${p.maxNumero}. ¡Ganó!';
    return;
  }
  p.siguienteConectar = a;
  _pasarTurnoPapa(p);
}

void _pasarTurnoPapa(PartidaPapa p) {
  if (p.nombres.length <= 1) return;
  final n = p.nombres.length;
  for (var i = 0; i < n; i++) {
    p.indiceTurno = (p.indiceTurno + 1) % n;
    if (!p.estaRendido(p.jugadorActual)) return;
  }
}

void _asegurarTurnoActivoPapa(PartidaPapa p) {
  if (p.nombres.isEmpty) return;
  final n = p.nombres.length;
  for (var i = 0; i < n; i++) {
    if (!p.estaRendido(p.jugadorActual)) return;
    p.indiceTurno = (p.indiceTurno + 1) % n;
  }
}

/// Marca [nombre] fuera. Si queda ≤1 activo, termina; si no, sigue.
String? rendirsePapa(PartidaPapa p, String nombre) {
  if (p.terminada || nombre.isEmpty) return null;
  if (p.estaRendido(nombre)) return null;
  if (!p.nombres.contains(nombre)) return null;

  p.rendidos.add(nombre);
  final idx = p.nombres.indexOf(nombre);
  if (p.conVidas && idx >= 0 && idx < p.vidas.length) {
    p.vidas[idx] = 0;
  }

  final activos = p.jugadoresActivos;
  if (activos.length <= 1) {
    if (activos.isEmpty) {
      p.fase = FasePapa.perdido;
      p.ganador = null;
      p.mensajeFin = '$nombre se rindió.';
    } else {
      p.fase = FasePapa.ganado;
      p.ganador = activos.first;
      p.mensajeFin = '$nombre se rindió. ¡${activos.first} gana!';
    }
    return p.ganador;
  }

  if (p.jugadorActual == nombre || p.estaRendido(p.jugadorActual)) {
    _asegurarTurnoActivoPapa(p);
  }
  return null;
}

void perderPapa(PartidaPapa p, {String? motivo}) {
  if (p.terminada) return;
  final perdedor = p.jugadorActual;
  if (perdedor.isEmpty) return;

  if (!p.estaRendido(perdedor)) {
    p.rendidos.add(perdedor);
  }
  final idx = p.nombres.isEmpty ? -1 : p.indiceTurno % p.nombres.length;
  if (p.conVidas && idx >= 0 && idx < p.vidas.length) {
    p.vidas[idx] = 0;
  }

  final activos = p.jugadoresActivos;
  if (activos.length <= 1) {
    if (activos.isEmpty) {
      p.fase = FasePapa.perdido;
      p.ganador = null;
      p.mensajeFin =
          motivo ?? '$perdedor tocó una línea. Fin de la partida.';
    } else {
      p.fase = FasePapa.ganado;
      p.ganador = activos.first;
      p.mensajeFin = motivo ?? '$perdedor falló. ¡${activos.first} gana!';
    }
    return;
  }

  // Quedan varios: el perdedor sale y sigue el próximo activo.
  _pasarTurnoPapa(p);
}

/// Números que un jugador unió con trazos exitosos (extremos de cada conexión).
Set<int> numerosConectadosPorPapa(PartidaPapa p, String jugador) {
  final out = <int>{};
  for (final t in p.trazos) {
    if (t.jugador != jugador) continue;
    out.add(t.de);
    out.add(t.a);
  }
  return out;
}

List<TrazoPapa> trazosDeJugadorPapa(PartidaPapa p, String jugador) =>
    [for (final t in p.trazos) if (t.jugador == jugador) t];

/// Registra un fallo. Si hay vidas y quedan, resta una y sigue el mismo turno.
/// Devuelve true si la partida terminó.
bool registrarFalloPapa(PartidaPapa p, {String? motivo}) {
  if (p.terminada) return true;
  if (p.conVidas && p.vidas.isNotEmpty) {
    final i = p.indiceTurno % p.vidas.length;
    if (p.vidas[i] > 1) {
      p.vidas[i]--;
      return false;
    }
    p.vidas[i] = 0;
  }
  perderPapa(p, motivo: motivo);
  return p.terminada;
}

/// Reescala trazos guardados en píxeles cuando cambia el tamaño de la hoja.
/// Reescala trazos legacy en píxeles. Los normalizados (0..1) no cambian.
void reescalarTrazosPapa(PartidaPapa p, Size desde, Size hacia) {
  if (desde.width < 1e-6 ||
      desde.height < 1e-6 ||
      hacia.width < 1e-6 ||
      hacia.height < 1e-6) {
    return;
  }
  if (desde == hacia) return;
  final sx = hacia.width / desde.width;
  final sy = hacia.height / desde.height;
  for (var i = 0; i < p.trazos.length; i++) {
    final t = p.trazos[i];
    if (puntosParecenNormalizadosPapa(t.puntos)) continue;
    p.trazos[i] = TrazoPapa(
      puntos: [
        for (final o in t.puntos) Offset(o.dx * sx, o.dy * sy),
      ],
      de: t.de,
      a: t.a,
      jugador: t.jugador,
      grosor: t.grosor,
    );
  }
}

List<Offset> reescalarPuntosPapa(List<Offset> pts, Size desde, Size hacia) {
  if (pts.isEmpty ||
      desde.width < 1e-6 ||
      desde.height < 1e-6 ||
      hacia.width < 1e-6 ||
      hacia.height < 1e-6 ||
      desde == hacia ||
      puntosParecenNormalizadosPapa(pts)) {
    return pts;
  }
  final sx = hacia.width / desde.width;
  final sy = hacia.height / desde.height;
  for (var i = 0; i < pts.length; i++) {
    final o = pts[i];
    pts[i] = Offset(o.dx * sx, o.dy * sy);
  }
  return pts;
}
