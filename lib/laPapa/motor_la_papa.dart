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

  /// Radio efectivo para choques (~mitad del trazo).
  double get radioChoque => math.max(1.2, ancho * 0.55);
}

class TrazoPapa {
  TrazoPapa({
    required this.puntos,
    required this.de,
    required this.a,
    required this.jugador,
    this.grosor = GrosorTrazoPapa.normal,
  });

  final List<Offset> puntos;
  final int de;
  final int a;
  final String jugador;
  final GrosorTrazoPapa grosor;
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
  })  : trazos = trazos ?? [],
        vidas = vidas ?? [];

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

  String get jugadorActual =>
      nombres.isEmpty ? '' : nombres[indiceTurno % nombres.length];

  bool get terminada =>
      fase == FasePapa.ganado || fase == FasePapa.perdido;

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

List<int?>? _generarCasillasPapa(math.Random rng, int maxNumero) {
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
  final vidas = _vidasIniciales(nombresCopy, opciones.conVidas);

  if (!opciones.numerosAleatorios) {
    return PartidaPapa(
      nombres: nombresCopy,
      casillas: List<int?>.filled(totalCasillasPapa, null),
      maxNumero: maxN,
      fase: FasePapa.colocando,
      siguienteAColocar: 1,
      conVidas: opciones.conVidas,
      modoFantasma: opciones.modoFantasma,
      vidas: vidas,
    );
  }

  final rng = math.Random(semilla);
  List<int?>? casillas;
  for (var intento = 0; intento < 80; intento++) {
    casillas = _generarCasillasPapa(rng, maxN);
    if (casillas != null) break;
  }
  if (casillas == null) {
    for (var intento = 0; intento < 200; intento++) {
      casillas = _generarCasillasPapa(math.Random(rng.nextInt(1 << 30)), maxN);
      if (casillas != null) break;
    }
  }
  if (casillas == null) {
    throw StateError('No se pudo armar una hoja válida de La papa.');
  }
  return PartidaPapa(
    nombres: nombresCopy,
    casillas: casillas,
    maxNumero: maxN,
    conVidas: opciones.conVidas,
    modoFantasma: opciones.modoFantasma,
    vidas: vidas,
  );
}

/// Coloca el siguiente número en [index]. Devuelve error o null si ok.
String? colocarNumeroEnCasillaPapa(PartidaPapa p, int index) {
  if (p.fase != FasePapa.colocando) return 'La hoja ya está armada.';
  if (index < 0 || index >= p.casillas.length) return 'Casilla inválida.';
  if (p.casillas[index] != null) return 'Esa casilla ya tiene número.';
  final n = p.siguienteAColocar;
  if (n > 1) {
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
    return null;
  }
  p.siguienteAColocar = n + 1;
  if (p.nombres.length > 1) {
    p.indiceTurno = (p.indiceTurno + 1) % p.nombres.length;
  }
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
  // Zona chica: solo para salir del número, no para “atravesar” la hoja.
  final radioIgnorar = cell * 0.14;

  bool enZonaInicio(Offset pt) =>
      centroInicio != null && (pt - centroInicio).distance <= radioIgnorar;

  // Segmentos previos a evaluar (sin la punta que llega al número de salida).
  final segsPrev = <(Offset, Offset, double)>[];
  for (final t in p.trazos) {
    final pts = t.puntos;
    // Suma de radios: si se tocan visualmente los trazos gruesos, cuenta.
    final umbral = math.max(
      2.0,
      grosorActual.radioChoque + t.grosor.radioChoque,
    );
    for (var j = 1; j < pts.length; j++) {
      final p1 = pts[j - 1];
      final p2 = pts[j];
      // Solo la punta inmediata del trazo de llegada (ambos extremos cerca).
      if (t.a == p.siguienteConectar &&
          enZonaInicio(p1) &&
          enZonaInicio(p2)) {
        continue;
      }
      segsPrev.add((p1, p2, umbral));
    }
  }
  if (segsPrev.isEmpty) return false;

  for (var i = 1; i < trazoActual.length; i++) {
    final a = trazoActual[i - 1];
    final b = trazoActual[i];
    final segLen = (b - a).distance;
    if (segLen < 1e-6) continue;

    // Al despegar del número solo cuenta cruce geométrico (no el roce con la
    // punta del trazo que llegó). Fuera de esa zona, cruce o roce = pierde.
    final saliendo = enZonaInicio(a) || enZonaInicio(b);

    for (final (p1, p2, umbral) in segsPrev) {
      if (saliendo) {
        if (_cruzan(a, b, p1, p2)) return true;
      } else if (_segmentosCercanos(a, b, p1, p2, umbral)) {
        return true;
      }
    }

    if (saliendo) continue;

    final muestras = math.max(3, (segLen / 0.9).ceil());
    for (var s = 0; s <= muestras; s++) {
      final pt = Offset.lerp(a, b, s / muestras)!;
      if (enZonaInicio(pt)) continue;
      for (final (p1, p2, umbral) in segsPrev) {
        if (_distPuntoSegmento(pt, p1, p2) <= umbral) return true;
      }
    }
  }
  return false;
}

/// True si el trazo actual se cruza o se roza a sí mismo.
/// Ignora un tramo reciente de la punta para no falsear en curvas normales.
bool trazoSeTocaASiMismoPapa(
  List<Offset> trazoActual, {
  required Size boardSize,
  GrosorTrazoPapa grosor = GrosorTrazoPapa.normal,
}) {
  if (trazoActual.length < 4) return false;
  final cell = math.min(
    boardSize.width / columnasPapa,
    boardSize.height / filasPapa,
  );
  final umbral = math.max(
    2.0,
    grosor.radioChoque * 2, // equivalente a chocarse con un trazo igual
  );
  // Un poco más de cola para curvas normales, sin dejar pasar un cruce claro.
  final colaIgnorar = math.max(14.0, cell * 0.38);

  // Retrocede desde la punta: esa “cola” no se compara consigo misma.
  var acum = 0.0;
  var inicioCola = trazoActual.length - 1;
  for (var i = trazoActual.length - 1; i >= 1; i--) {
    acum += (trazoActual[i] - trazoActual[i - 1]).distance;
    inicioCola = i;
    if (acum >= colaIgnorar) break;
  }

  // Segmentos viejos: terminan antes de la cola y no son adyacentes al último.
  final jMax = math.min(inicioCola, trazoActual.length - 2);
  if (jMax < 1) return false;

  final a = trazoActual[trazoActual.length - 2];
  final b = trazoActual[trazoActual.length - 1];

  for (var j = 1; j < jMax; j++) {
    final p1 = trazoActual[j - 1];
    final p2 = trazoActual[j];
    if (_cruzan(a, b, p1, p2)) return true;
    if (_distPuntoSegmento(b, p1, p2) <= umbral) return true;
    if (_segmentosCercanos(a, b, p1, p2, umbral)) return true;
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

/// True si el punto de entrada cae encima de tinta previa en el borde.
/// Una línea que pasa por la casilla solo tapa donde realmente roza el
/// círculo del número; el resto de lados siguen libres.
bool llegadaPorLadoBloqueadoPapa(
  PartidaPapa p,
  int numero,
  List<Offset> trazoActual,
  Size boardSize, {
  double factorRadio = 0.32,
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

  // ~grosor del trazo: hay que tocar la tinta, no un arco enorme.
  var umbralTinta = math.max(2.6, cell * 0.04);
  for (final t in p.trazos) {
    umbralTinta = math.max(umbralTinta, t.grosor.radioChoque);
  }
  return _puntoCercaDeTrazos(entrada, p.trazos, umbralTinta);
}

/// Acepta el trazo si une el par actual y no chocó.
void aceptarTrazoPapa(
  PartidaPapa p,
  List<Offset> puntos, {
  GrosorTrazoPapa grosor = GrosorTrazoPapa.normal,
}) {
  if (p.terminada || p.fase != FasePapa.jugando || puntos.length < 2) return;
  final de = p.siguienteConectar;
  final a = de + 1;
  p.trazos.add(
    TrazoPapa(
      puntos: List<Offset>.from(puntos),
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
  if (p.nombres.length > 1) {
    p.indiceTurno = (p.indiceTurno + 1) % p.nombres.length;
  }
}

void perderPapa(PartidaPapa p, {String? motivo}) {
  if (p.terminada) return;
  final perdedor = p.jugadorActual;
  final idx = p.nombres.isEmpty ? 0 : p.indiceTurno % p.nombres.length;
  final otros = [
    for (var i = 0; i < p.nombres.length; i++)
      if (i != idx) p.nombres[i],
  ];

  if (otros.isNotEmpty) {
    // Quien falla pierde: gana el rival (o el primero de los que quedan).
    p.fase = FasePapa.ganado;
    p.ganador = otros.first;
    p.mensajeFin = motivo ??
        (otros.length == 1
            ? '$perdedor falló. ¡${otros.first} gana!'
            : '$perdedor falló. Ganan: ${otros.join(', ')}');
  } else {
    p.fase = FasePapa.perdido;
    p.ganador = null;
    p.mensajeFin = motivo ?? '$perdedor tocó una línea. Fin de la partida.';
  }
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
  return true;
}

/// Reescala trazos guardados en píxeles cuando cambia el tamaño de la hoja.
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
      desde == hacia) {
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
