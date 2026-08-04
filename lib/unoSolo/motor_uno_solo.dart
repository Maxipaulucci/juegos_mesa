library;

/// Uno solo — solitario inglés (cruz 33 huecos).
/// Salto ortogonal sobre una ficha vecina hacia un hueco vacío; la saltada sale.

enum FaseUnoSolo { jugando, ganado, perdido }

enum CeldaUnoSolo { invalida, vacia, ocupada }

class MovimientoUnoSolo {
  const MovimientoUnoSolo({
    required this.desde,
    required this.medio,
    required this.hasta,
  });

  final int desde;
  final int medio;
  final int hasta;
}

class PartidaUnoSolo {
  PartidaUnoSolo({
    required this.nombres,
    required this.celdas,
    this.indiceTurno = 0,
    this.fase = FaseUnoSolo.jugando,
    this.mensajeFin,
    this.ganador,
    this.calificacion,
    this.solo = false,
  });

  final List<String> nombres;
  /// 7×7 = 49. Esquinas 2×2 son [CeldaUnoSolo.invalida].
  final List<CeldaUnoSolo> celdas;
  int indiceTurno;
  FaseUnoSolo fase;
  String? mensajeFin;
  String? ganador;
  /// Regular / Mejor / … ya no se usan; solo victoria o “Seguí intentando”.
  String? calificacion;
  final bool solo;

  static const int filas = 7;
  static const int columnas = 7;
  static const int total = filas * columnas;
  static const int centro = 3 * columnas + 3; // (3,3)

  String get jugadorActual =>
      nombres.isEmpty ? '' : nombres[indiceTurno % nombres.length];

  bool get terminada =>
      fase == FaseUnoSolo.ganado || fase == FaseUnoSolo.perdido;

  int get fichasRestantes =>
      celdas.where((c) => c == CeldaUnoSolo.ocupada).length;

  bool get fichaUnicaEnCentro =>
      fichasRestantes == 1 && celdas[centro] == CeldaUnoSolo.ocupada;

  static bool esValida(int fila, int col) {
    if (fila < 0 || fila >= filas || col < 0 || col >= columnas) return false;
    if (fila < 2 && (col < 2 || col > 4)) return false;
    if (fila > 4 && (col < 2 || col > 4)) return false;
    return true;
  }

  static int indexOf(int fila, int col) => fila * columnas + col;

  static (int, int) filaCol(int index) =>
      (index ~/ columnas, index % columnas);
}

bool casillaValidaUnoSolo(int index) {
  if (index < 0 || index >= PartidaUnoSolo.total) return false;
  final (f, c) = PartidaUnoSolo.filaCol(index);
  return PartidaUnoSolo.esValida(f, c);
}

List<CeldaUnoSolo> _tableroInicial() {
  return [
    for (var i = 0; i < PartidaUnoSolo.total; i++)
      if (!casillaValidaUnoSolo(i))
        CeldaUnoSolo.invalida
      else if (i == PartidaUnoSolo.centro)
        CeldaUnoSolo.vacia
      else
        CeldaUnoSolo.ocupada,
  ];
}

PartidaUnoSolo nuevaPartidaUnoSolo({
  required List<String> nombres,
  bool solo = false,
}) {
  final lista = nombres.isEmpty ? <String>['Jugador'] : List<String>.from(nombres);
  return PartidaUnoSolo(
    nombres: lista,
    celdas: _tableroInicial(),
    solo: solo || lista.length == 1,
  );
}

const _dirs = <(int, int)>[
  (-1, 0),
  (1, 0),
  (0, -1),
  (0, 1),
];

List<MovimientoUnoSolo> movimientosDesdeUnoSolo(PartidaUnoSolo p, int desde) {
  if (p.fase != FaseUnoSolo.jugando) return const [];
  if (desde < 0 || desde >= p.celdas.length) return const [];
  if (p.celdas[desde] != CeldaUnoSolo.ocupada) return const [];
  final (f, c) = PartidaUnoSolo.filaCol(desde);
  final out = <MovimientoUnoSolo>[];
  for (final (df, dc) in _dirs) {
    final mf = f + df;
    final mc = c + dc;
    final hf = f + 2 * df;
    final hc = c + 2 * dc;
    if (!PartidaUnoSolo.esValida(mf, mc) || !PartidaUnoSolo.esValida(hf, hc)) {
      continue;
    }
    final medio = PartidaUnoSolo.indexOf(mf, mc);
    final hasta = PartidaUnoSolo.indexOf(hf, hc);
    if (p.celdas[medio] == CeldaUnoSolo.ocupada &&
        p.celdas[hasta] == CeldaUnoSolo.vacia) {
      out.add(MovimientoUnoSolo(desde: desde, medio: medio, hasta: hasta));
    }
  }
  return out;
}

List<MovimientoUnoSolo> todosLosMovimientosUnoSolo(PartidaUnoSolo p) {
  final out = <MovimientoUnoSolo>[];
  for (var i = 0; i < p.celdas.length; i++) {
    out.addAll(movimientosDesdeUnoSolo(p, i));
  }
  return out;
}

bool hayMovimientosUnoSolo(PartidaUnoSolo p) =>
    todosLosMovimientosUnoSolo(p).isNotEmpty;

/// Calificación al cerrar: victoria (1 en centro), derrota (1 fuera o
/// sin movimientos con 2–5), “Seguí intentando” (≥6).
String? calificacionUnoSolo(int fichas, {required bool enCentro}) {
  if (fichas <= 1) {
    return enCentro ? '¡Perfecto!' : 'Derrota';
  }
  if (fichas >= 6) return 'Seguí intentando';
  return 'Derrota';
}

void _cerrarConPuntuacion(PartidaUnoSolo p) {
  final n = p.fichasRestantes;
  final enCentro = p.fichaUnicaEnCentro;
  final cal = calificacionUnoSolo(n, enCentro: enCentro);
  p.calificacion = cal;

  // Una sola ficha: gana solo si está en el centro.
  if (n <= 1) {
    if (enCentro) {
      p.fase = FaseUnoSolo.ganado;
      if (p.solo) {
        p.ganador = p.nombres.isEmpty ? null : p.nombres.first;
        p.mensajeFin = '¡Una sola ficha en el centro!';
      } else {
        p.ganador = p.jugadorActual;
        p.mensajeFin = '¡${p.jugadorActual} dejó una ficha en el centro!';
      }
    } else {
      p.fase = FaseUnoSolo.perdido;
      p.ganador = null;
      p.mensajeFin =
          'Quedó una sola ficha, pero no en el centro. '
          'El juego exige que la última pieza esté en el centro para ganar.';
    }
    return;
  }

  // Sin movimientos y más de una ficha: derrota (solo y multijugador).
  p.fase = FaseUnoSolo.perdido;
  p.ganador = null;
  p.mensajeFin = cal == null
      ? 'No quedan movimientos. Quedaron $n fichas.'
      : 'No quedan movimientos. Quedaron $n fichas · $cal';
}

void _evaluarFinTrasJugada(PartidaUnoSolo p) {
  if (p.fichasRestantes <= 1 || !hayMovimientosUnoSolo(p)) {
    _cerrarConPuntuacion(p);
  }
}

void _pasarTurnoUnoSolo(PartidaUnoSolo p) {
  if (p.solo || p.nombres.length < 2 || p.terminada) return;
  p.indiceTurno = (p.indiceTurno + 1) % p.nombres.length;
}

/// Ejecuta un salto. Devuelve error o null si ok.
String? jugarMovimientoUnoSolo(PartidaUnoSolo p, MovimientoUnoSolo m) {
  if (p.fase != FaseUnoSolo.jugando) return 'La partida ya terminó.';
  final validos = movimientosDesdeUnoSolo(p, m.desde);
  final ok = validos.any(
    (v) => v.desde == m.desde && v.medio == m.medio && v.hasta == m.hasta,
  );
  if (!ok) return 'Ese salto no es válido.';

  p.celdas[m.desde] = CeldaUnoSolo.vacia;
  p.celdas[m.medio] = CeldaUnoSolo.vacia;
  p.celdas[m.hasta] = CeldaUnoSolo.ocupada;

  _evaluarFinTrasJugada(p);
  if (!p.terminada) _pasarTurnoUnoSolo(p);
  return null;
}

MovimientoUnoSolo? buscarSaltoUnoSolo(
  PartidaUnoSolo p,
  int desde,
  int hasta,
) {
  for (final m in movimientosDesdeUnoSolo(p, desde)) {
    if (m.hasta == hasta) return m;
  }
  return null;
}

String? jugarSaltoUnoSolo(PartidaUnoSolo p, int desde, int hasta) {
  final m = buscarSaltoUnoSolo(p, desde, hasta);
  if (m == null) return 'Ese salto no es válido.';
  return jugarMovimientoUnoSolo(p, m);
}

/// Deshace el último salto del [historial] (vacío = ya estás al inicio).
String? deshacerUltimoUnoSolo(
  PartidaUnoSolo p,
  List<MovimientoUnoSolo> historial,
) {
  if (historial.isEmpty) {
    return 'Ya estás al inicio de la partida.';
  }
  final estabaTerminada = p.terminada;
  final m = historial.removeLast();
  p.celdas[m.hasta] = CeldaUnoSolo.vacia;
  p.celdas[m.medio] = CeldaUnoSolo.ocupada;
  p.celdas[m.desde] = CeldaUnoSolo.ocupada;
  p.fase = FaseUnoSolo.jugando;
  p.mensajeFin = null;
  p.calificacion = null;
  p.ganador = null;
  // Solo se había pasado de turno si la partida seguía en juego.
  if (!estabaTerminada && !p.solo && p.nombres.length >= 2) {
    p.indiceTurno =
        (p.indiceTurno - 1 + p.nombres.length) % p.nombres.length;
  }
  return null;
}

/// Casilla → orden en que se comió una ficha ahí (1 = primera comida).
/// Una sola etiqueta por casilla (la primera vez que se come en ese hueco).
Map<int, String> ordenEliminacionDesdeHistorial(
  List<MovimientoUnoSolo> historial,
) {
  final out = <int, String>{};
  for (var i = 0; i < historial.length; i++) {
    out.putIfAbsent(historial[i].medio, () => '${i + 1}');
  }
  return out;
}
