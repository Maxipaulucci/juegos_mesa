import 'dart:math' as math;

/// Chancho va — sets de 4 cartas del mismo número (distinto palo).

enum PaloChancho { oro, copa, espada, basto }

enum DireccionChancho { izquierda, derecha, centro }

enum FaseChancho {
  eligiendoNumeros,
  anunciando,
  eligiendoCartas,
  carreraChancho,
  terminada,
}

/// Letras del tablero (el espacio cuenta como penalización).
const List<String> letrasChanchoVa = [
  'C',
  'H',
  'A',
  'N',
  'C',
  'H',
  'O',
  ' ',
  'V',
  'A',
];

const List<int> numerosChanchoDisponibles = [
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  10,
  11,
  12,
];

class CartaChancho {
  const CartaChancho({required this.numero, required this.palo});

  final int numero;
  final PaloChancho palo;

  String get nombrePalo => switch (palo) {
        PaloChancho.oro => 'oro',
        PaloChancho.copa => 'copa',
        PaloChancho.espada => 'espada',
        PaloChancho.basto => 'basto',
      };

  String get etiqueta => '$numero de $nombrePalo';

  @override
  bool operator ==(Object other) =>
      other is CartaChancho && other.numero == numero && other.palo == palo;

  @override
  int get hashCode => Object.hash(numero, palo);

  @override
  String toString() => etiqueta;
}

class JugadorChancho {
  JugadorChancho(this.nombre);

  final String nombre;
  final List<CartaChancho> mano = [];
  /// Letras ya recibidas (largo = progreso hacia CHANCHO VA).
  final List<String> letras = [];
  /// En fase de elección de cartas para el pase.
  final List<CartaChancho> seleccionPase = [];
  bool seleccionPaseConfirmada = false;
  bool dijoChancho = false;

  bool get tieneCuarteto {
    if (mano.length != 4) return false;
    final n = mano.first.numero;
    return mano.every((c) => c.numero == n);
  }

  bool get completoChanchoVa => letras.length >= letrasChanchoVa.length;

  String get letrasTexto {
    if (letras.isEmpty) return '—';
    return letras.map((l) => l == ' ' ? '·' : l).join();
  }
}

class AnuncioChancho {
  const AnuncioChancho({
    required this.cantidad,
    required this.direccion,
  });

  final int cantidad;
  final DireccionChancho direccion;
}

class PartidaChancho {
  PartidaChancho({
    required this.jugadores,
    this.indiceTurno = 0,
    this.fase = FaseChancho.eligiendoNumeros,
    this.contraPc = false,
    int? objetivoLetras,
  }) : objetivoLetras = objetivoLetras ?? letrasChanchoVa.length;

  final List<JugadorChancho> jugadores;
  final bool contraPc;
  final int objetivoLetras;
  int indiceTurno;
  FaseChancho fase;
  List<int> numerosEnJuego = [];
  AnuncioChancho? anuncioActual;
  AnuncioChancho? ultimoAnuncio;
  /// Quién abrió la carrera de Chancho (null = no abierta).
  String? quienAbrioChancho;
  /// Orden en que dijeron Chancho en la carrera actual.
  final List<String> ordenChancho = [];
  String? perdedor;
  String? mensajeFin;

  JugadorChancho get jugadorActual =>
      jugadores[indiceTurno % jugadores.length];

  bool get terminada => fase == FaseChancho.terminada;

  int get cantidadJugadores => jugadores.length;
}

List<CartaChancho> crearMazoChanchoConNumeros(List<int> numeros) {
  return [
    for (final n in numeros)
      for (final palo in PaloChancho.values)
        CartaChancho(numero: n, palo: palo),
  ];
}

void barajarChancho(List<CartaChancho> mazo, [math.Random? rng]) {
  final r = rng ?? math.Random();
  for (var i = mazo.length - 1; i > 0; i--) {
    final j = r.nextInt(i + 1);
    final tmp = mazo[i];
    mazo[i] = mazo[j];
    mazo[j] = tmp;
  }
}

PartidaChancho nuevaPartidaChancho({
  required List<String> nombres,
  bool contraPc = false,
}) {
  assert(nombres.length >= 2 && nombres.length <= 4);
  final jugadores = [for (final n in nombres) JugadorChancho(n)];
  return PartidaChancho(
    jugadores: jugadores,
    contraPc: contraPc,
    fase: FaseChancho.eligiendoNumeros,
    indiceTurno: 0,
  );
}

/// Elige exactamente [cantidadJugadores] números y reparte.
String? aplicarNumerosElegidosChancho(
  PartidaChancho p,
  List<int> numeros, [
  math.Random? rng,
]) {
  if (p.fase != FaseChancho.eligiendoNumeros) {
    return 'Los números ya fueron elegidos.';
  }
  final n = p.cantidadJugadores;
  if (numeros.length != n) {
    return 'Elegí exactamente $n números.';
  }
  final unicos = numeros.toSet();
  if (unicos.length != n) return 'Los números deben ser distintos.';
  for (final num in numeros) {
    if (!numerosChanchoDisponibles.contains(num)) {
      return 'Número inválido: $num';
    }
  }

  final r = rng ?? math.Random();
  final mazo = crearMazoChanchoConNumeros(numeros);
  barajarChancho(mazo, r);
  for (final j in p.jugadores) {
    j.mano.clear();
  }
  var i = 0;
  while (mazo.isNotEmpty) {
    p.jugadores[i % p.jugadores.length].mano.add(mazo.removeLast());
    i++;
  }
  for (final j in p.jugadores) {
    if (j.mano.length != 4) {
      return 'Error al repartir.';
    }
  }
  p.numerosEnJuego = List.of(numeros)..sort();
  p.fase = FaseChancho.anunciando;
  return null;
}

void _limpiarSeleccionesPase(PartidaChancho p) {
  for (final j in p.jugadores) {
    j.seleccionPase.clear();
    j.seleccionPaseConfirmada = false;
  }
}

void _limpiarCarreraChancho(PartidaChancho p) {
  p.quienAbrioChancho = null;
  p.ordenChancho.clear();
  for (final j in p.jugadores) {
    j.dijoChancho = false;
  }
}

String? anunciarPaseChancho(
  PartidaChancho p, {
  required int cantidad,
  required DireccionChancho direccion,
  JugadorChancho? anunciante,
}) {
  if (p.fase != FaseChancho.anunciando) {
    return 'Ahora no se anuncia un pase.';
  }
  final quien = anunciante ?? p.jugadorActual;
  if (!identical(quien, p.jugadorActual)) {
    return 'No es el turno de ${quien.nombre}.';
  }
  if (cantidad < 1 || cantidad > 4) {
    return 'La cantidad debe ser entre 1 y 4.';
  }
  final anuncio = AnuncioChancho(cantidad: cantidad, direccion: direccion);
  p.anuncioActual = anuncio;
  p.ultimoAnuncio = anuncio;
  _limpiarSeleccionesPase(p);
  p.fase = FaseChancho.eligiendoCartas;

  // PC confirma sola en el flujo de UI; aquí no auto-elige.
  return null;
}

String? repetirUltimoAnuncioChancho(
  PartidaChancho p, {
  JugadorChancho? anunciante,
}) {
  final u = p.ultimoAnuncio;
  if (u == null) return 'Todavía no hay un anuncio para repetir.';
  return anunciarPaseChancho(
    p,
    cantidad: u.cantidad,
    direccion: u.direccion,
    anunciante: anunciante,
  );
}

String? confirmarSeleccionPaseChancho(
  PartidaChancho p, {
  required JugadorChancho jugador,
  required List<CartaChancho> cartas,
  math.Random? rng,
}) {
  if (p.fase != FaseChancho.eligiendoCartas) {
    return 'Ahora no se eligen cartas para pasar.';
  }
  final anuncio = p.anuncioActual;
  if (anuncio == null) return 'No hay anuncio activo.';
  if (cartas.length != anuncio.cantidad) {
    return 'Debés elegir exactamente ${anuncio.cantidad} carta(s).';
  }
  for (final c in cartas) {
    if (!jugador.mano.contains(c)) {
      return 'Carta no está en tu mano: ${c.etiqueta}';
    }
  }
  if (cartas.toSet().length != cartas.length) {
    return 'No repitas cartas.';
  }

  jugador.seleccionPase
    ..clear()
    ..addAll(cartas);
  jugador.seleccionPaseConfirmada = true;

  if (p.jugadores.every((j) => j.seleccionPaseConfirmada)) {
    return _ejecutarPaseChancho(p, rng: rng);
  }
  return null;
}

String? _ejecutarPaseChancho(PartidaChancho p, {math.Random? rng}) {
  final anuncio = p.anuncioActual;
  if (anuncio == null) return 'Sin anuncio.';

  switch (anuncio.direccion) {
    case DireccionChancho.izquierda:
      _rotarPase(p, sentidoHorario: false);
    case DireccionChancho.derecha:
      _rotarPase(p, sentidoHorario: true);
    case DireccionChancho.centro:
      final err = _paseAlCentro(p, rng: rng);
      if (err != null) return err;
  }

  p.anuncioActual = null;
  _limpiarSeleccionesPase(p);
  p.indiceTurno = (p.indiceTurno + 1) % p.jugadores.length;
  _limpiarCarreraChancho(p);
  p.fase = FaseChancho.anunciando;
  return null;
}

/// Izquierda = hacia índice menor (jugador i recibe de i+1).
/// Derecha = hacia índice mayor (jugador i recibe de i-1).
void _rotarPase(PartidaChancho p, {required bool sentidoHorario}) {
  final n = p.jugadores.length;
  final enviadas = <List<CartaChancho>>[
    for (final j in p.jugadores) List.of(j.seleccionPase),
  ];

  for (var i = 0; i < n; i++) {
    final j = p.jugadores[i];
    for (final c in enviadas[i]) {
      j.mano.remove(c);
    }
  }

  for (var i = 0; i < n; i++) {
    final destino = sentidoHorario ? (i + 1) % n : (i - 1 + n) % n;
    p.jugadores[destino].mano.addAll(enviadas[i]);
  }
}

/// Nadie recibe de vuelta las que aportó (si es posible).
String? _paseAlCentro(PartidaChancho p, {math.Random? rng}) {
  final r = rng ?? math.Random();
  final n = p.jugadores.length;
  final aportes = <List<CartaChancho>>[
    for (final j in p.jugadores) List.of(j.seleccionPase),
  ];

  for (var i = 0; i < n; i++) {
    for (final c in aportes[i]) {
      p.jugadores[i].mano.remove(c);
    }
  }

  final pool = <CartaChancho>[for (final a in aportes) ...a];
  final k = aportes.first.length;
  final aportadasPor = <CartaChancho, int>{};
  for (var i = 0; i < n; i++) {
    for (final c in aportes[i]) {
      aportadasPor[c] = i;
    }
  }

  List<List<CartaChancho>>? mejor;
  for (var intento = 0; intento < 80; intento++) {
    barajarChancho(pool, r);
    final reparto = <List<CartaChancho>>[for (var i = 0; i < n; i++) <CartaChancho>[]];
    var ok = true;
    var idx = 0;
    for (var i = 0; i < n; i++) {
      for (var t = 0; t < k; t++) {
        if (idx >= pool.length) {
          ok = false;
          break;
        }
        final c = pool[idx++];
        final origen = aportadasPor[c];
        if (origen == i && intento < 60) {
          // Preferir no devolver propias en los primeros intentos.
          ok = false;
          break;
        }
        reparto[i].add(c);
      }
      if (!ok) break;
    }
    if (ok && idx == pool.length) {
      mejor = reparto;
      break;
    }
  }

  // Fallback: barajar y repartir en orden (puede devolver propias).
  if (mejor == null) {
    barajarChancho(pool, r);
    mejor = [for (var i = 0; i < n; i++) <CartaChancho>[]];
    var idx = 0;
    for (var t = 0; t < k; t++) {
      for (var i = 0; i < n; i++) {
        mejor[i].add(pool[idx++]);
      }
    }
  }

  for (var i = 0; i < n; i++) {
    p.jugadores[i].mano.addAll(mejor[i]);
  }
  return null;
}

/// Abre o continúa la carrera de Chancho.
String? decirChanchoVa(
  PartidaChancho p, {
  required JugadorChancho jugador,
}) {
  if (p.terminada) return 'La partida ya terminó.';
  if (p.fase == FaseChancho.eligiendoNumeros ||
      p.fase == FaseChancho.eligiendoCartas) {
    return 'Ahora no se puede decir Chancho.';
  }
  if (jugador.dijoChancho) return 'Ya dijiste Chancho.';

  final carreraAbierta = p.quienAbrioChancho != null;
  if (!carreraAbierta) {
    if (!jugador.tieneCuarteto) {
      return 'Solo podés abrir Chancho con 4 cartas iguales.';
    }
    p.quienAbrioChancho = jugador.nombre;
    p.fase = FaseChancho.carreraChancho;
  }

  jugador.dijoChancho = true;
  p.ordenChancho.add(jugador.nombre);

  // Cuando todos dijeron Chancho, el último del orden recibe la letra.
  if (p.ordenChancho.length >= p.jugadores.length) {
    final nombreUltimo = p.ordenChancho.last;
    final ultimo = p.jugadores.firstWhere((j) => j.nombre == nombreUltimo);
    _penalizarUltimo(p, ultimo);
  }
  return null;
}

void _penalizarUltimo(PartidaChancho p, JugadorChancho ultimo) {
  if (ultimo.letras.length < letrasChanchoVa.length) {
    ultimo.letras.add(letrasChanchoVa[ultimo.letras.length]);
  }
  if (ultimo.completoChanchoVa) {
    p.fase = FaseChancho.terminada;
    p.perdedor = ultimo.nombre;
    p.mensajeFin = '${ultimo.nombre} completó CHANCHO VA y pierde.';
    return;
  }
  // Nueva ronda: mismo mazo/números, repartir de nuevo.
  _iniciarNuevaRondaTrasChancho(p);
}

void _iniciarNuevaRondaTrasChancho(PartidaChancho p, [math.Random? rng]) {
  final r = rng ?? math.Random();
  final mazo = crearMazoChanchoConNumeros(p.numerosEnJuego);
  barajarChancho(mazo, r);
  for (final j in p.jugadores) {
    j.mano.clear();
    j.seleccionPase.clear();
    j.seleccionPaseConfirmada = false;
  }
  var i = 0;
  while (mazo.isNotEmpty) {
    p.jugadores[i % p.jugadores.length].mano.add(mazo.removeLast());
    i++;
  }
  _limpiarCarreraChancho(p);
  p.anuncioActual = null;
  p.fase = FaseChancho.anunciando;
  // Sigue el siguiente anunciante.
  p.indiceTurno = (p.indiceTurno + 1) % p.jugadores.length;
}

/// Heurística PC: conserva el número más frecuente; pasa del resto.
List<CartaChancho> elegirCartasPcChancho(
  JugadorChancho pc,
  int cantidad, [
  math.Random? rng,
]) {
  final r = rng ?? math.Random();
  if (cantidad <= 0) return const [];
  if (pc.mano.length <= cantidad) return List.of(pc.mano);

  final porNumero = <int, List<CartaChancho>>{};
  for (final c in pc.mano) {
    porNumero.putIfAbsent(c.numero, () => []).add(c);
  }
  var mejorNumero = pc.mano.first.numero;
  var mejorCount = 0;
  for (final e in porNumero.entries) {
    if (e.value.length > mejorCount) {
      mejorCount = e.value.length;
      mejorNumero = e.key;
    }
  }

  final conservar = porNumero[mejorNumero] ?? const <CartaChancho>[];
  final resto = [
    for (final c in pc.mano)
      if (c.numero != mejorNumero) c,
  ];
  barajarChancho(resto, r);

  final out = <CartaChancho>[];
  for (final c in resto) {
    if (out.length >= cantidad) break;
    out.add(c);
  }
  // Si no alcanza, sacar del grupo conservado (las de menos valor relativo).
  if (out.length < cantidad) {
    final extras = List<CartaChancho>.of(conservar)..shuffle(r);
    for (final c in extras) {
      if (out.length >= cantidad) break;
      out.add(c);
    }
  }
  return out;
}

AnuncioChancho planificarAnuncioPcChancho(
  JugadorChancho pc, [
  AnuncioChancho? ultimo,
  math.Random? rng,
]) {
  final r = rng ?? math.Random();
  final porNumero = <int, int>{};
  for (final c in pc.mano) {
    porNumero[c.numero] = (porNumero[c.numero] ?? 0) + 1;
  }
  final mejor = porNumero.values.fold<int>(0, (a, b) => a > b ? a : b);
  final faltan = 4 - mejor;

  if (ultimo != null && r.nextDouble() < 0.25) {
    return ultimo;
  }

  final cantidad = faltan <= 1
      ? 1
      : (faltan == 2 ? (r.nextBool() ? 1 : 2) : 1 + r.nextInt(2));
  final dirs = DireccionChancho.values;
  final direccion = dirs[r.nextInt(dirs.length)];
  return AnuncioChancho(cantidad: cantidad.clamp(1, 4), direccion: direccion);
}

bool pcDeberiaDecirChancho(PartidaChancho p, JugadorChancho pc) {
  if (pc.dijoChancho) return false;
  if (p.quienAbrioChancho != null) return true;
  return pc.tieneCuarteto;
}
