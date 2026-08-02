/// Serialización del estado de Escoba del 15 para multijugador online.
library;

import 'package:app_juegos_mesa/escobaDel15/motor_escoba.dart';

Map<String, dynamic> _encodeCarta(CartaEscoba c) => {
      'numero': c.numero,
      'palo': c.palo.name,
    };

CartaEscoba? _decodeCarta(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final numero = (m['numero'] as num?)?.toInt();
  final paloId = m['palo']?.toString();
  if (numero == null || paloId == null) return null;
  PaloEscoba? palo;
  for (final p in PaloEscoba.values) {
    if (p.name == paloId) {
      palo = p;
      break;
    }
  }
  if (palo == null) return null;
  return CartaEscoba(numero: numero, palo: palo);
}

List<Map<String, dynamic>> _encodeCartas(List<CartaEscoba> cartas) => [
      for (final c in cartas) _encodeCarta(c),
    ];

List<CartaEscoba> _decodeCartas(dynamic raw) {
  if (raw is! List) return [];
  final out = <CartaEscoba>[];
  for (final item in raw) {
    final c = _decodeCarta(item);
    if (c != null) out.add(c);
  }
  return out;
}

FaseEscoba _faseFromId(String? id) {
  for (final f in FaseEscoba.values) {
    if (f.name == id) return f;
  }
  return FaseEscoba.jugando;
}

Map<String, dynamic>? _encodeCombo(ComboCapturaEscoba c) => {
      'cartas': _encodeCartas(c.cartas),
      'escoba': c.escoba,
      'esPozoFinal': c.esPozoFinal,
    };

ComboCapturaEscoba? _decodeCombo(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  return ComboCapturaEscoba(
    cartas: _decodeCartas(m['cartas']),
    escoba: m['escoba'] == true,
    esPozoFinal: m['esPozoFinal'] == true,
  );
}

Map<String, dynamic>? _encodeResultado(ResultadoRondaEscoba? r) {
  if (r == null) return null;
  return {
    'puntosEscobas': List<int>.from(r.puntosEscobas),
    'idxMasCartas': r.idxMasCartas,
    'idxMasOros': r.idxMasOros,
    'idxSieteOro': r.idxSieteOro,
    'idxMasSietes': r.idxMasSietes,
    'empateMasCartas': r.empateMasCartas,
    'empateMasOros': r.empateMasOros,
    'empateMasSietes': r.empateMasSietes,
    'idxLlevoPozo': r.idxLlevoPozo,
    'cartasPozoFinal': _encodeCartas(r.cartasPozoFinal),
    'detalles': [
      for (final d in r.detalles)
        {
          'nombre': d.nombre,
          'escobas': d.escobas,
          'cartas': _encodeCartas(d.cartas),
          'oros': _encodeCartas(d.oros),
          'sietes': _encodeCartas(d.sietes),
          'puntosTrasRonda': d.puntosTrasRonda,
        },
    ],
  };
}

ResultadoRondaEscoba? _decodeResultado(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final detallesRaw = m['detalles'];
  final detalles = <DetalleJugadorRondaEscoba>[];
  if (detallesRaw is List) {
    for (final item in detallesRaw) {
      if (item is! Map) continue;
      final d = Map<String, dynamic>.from(item);
      detalles.add(
        DetalleJugadorRondaEscoba(
          nombre: d['nombre']?.toString() ?? '',
          escobas: (d['escobas'] as num?)?.toInt() ?? 0,
          cartas: _decodeCartas(d['cartas']),
          oros: _decodeCartas(d['oros']),
          sietes: _decodeCartas(d['sietes']),
          puntosTrasRonda: (d['puntosTrasRonda'] as num?)?.toInt() ?? 0,
        ),
      );
    }
  }
  return ResultadoRondaEscoba(
    puntosEscobas: [
      for (final e in (m['puntosEscobas'] as List? ?? const []))
        if (e is num) e.toInt(),
    ],
    idxMasCartas: (m['idxMasCartas'] as num?)?.toInt(),
    idxMasOros: (m['idxMasOros'] as num?)?.toInt(),
    idxSieteOro: (m['idxSieteOro'] as num?)?.toInt(),
    idxMasSietes: (m['idxMasSietes'] as num?)?.toInt(),
    detalles: detalles,
    empateMasCartas: m['empateMasCartas'] == true,
    empateMasOros: m['empateMasOros'] == true,
    empateMasSietes: m['empateMasSietes'] == true,
    idxLlevoPozo: (m['idxLlevoPozo'] as num?)?.toInt(),
    cartasPozoFinal: _decodeCartas(m['cartasPozoFinal']),
  );
}

/// True cuando el anfitrión ya publicó el mazo repartido.
bool escobaPartidaGenerada(Map<String, dynamic>? raw) {
  if (raw == null) return false;
  if (raw['pendienteMazo'] == true) return false;
  if (raw['juego']?.toString() != 'escobaDel15') return false;
  final jugadores = raw['jugadores'];
  return jugadores is List && jugadores.isNotEmpty && raw['mazo'] is List;
}

Map<String, dynamic> encodeEscobaGameState({
  required PartidaEscoba partida,
  required int version,
  Map<String, dynamic>? ultimaJugada,
}) {
  return {
    'version': version,
    'juego': 'escobaDel15',
    'pendienteMazo': false,
    'objetivo': partida.objetivo,
    'indiceTurno': partida.indiceTurno,
    'fase': partida.fase.name,
    'ultimaCapturaIdx': partida.ultimaCapturaIdx,
    'mensajeFin': partida.mensajeFin,
    'ganador': partida.ganador,
    'reiniciarCombosEnProximaJugada': partida.reiniciarCombosEnProximaJugada,
    'mazo': _encodeCartas(partida.mazo),
    'mesa': _encodeCartas(partida.mesa),
    'jugadores': [
      for (final j in partida.jugadores)
        {
          'nombre': j.nombre,
          'mano': _encodeCartas(j.mano),
          'capturadas': _encodeCartas(j.capturadas),
          'combos': [
            for (final c in j.combos) _encodeCombo(c),
          ],
          'escobasRonda': j.escobasRonda,
          'puntos': j.puntos,
          'rendido': j.rendido,
        },
    ],
    'ultimoResultado': _encodeResultado(partida.ultimoResultado),
    'ultimaJugada': ultimaJugada,
    'mostrarVictoria': partida.terminada,
  };
}

/// Aplica [raw] sobre [destino] (mutándola).
void applyEscobaGameState(PartidaEscoba destino, Map<String, dynamic> raw) {
  destino.indiceTurno = (raw['indiceTurno'] as num?)?.toInt() ?? 0;
  destino.fase = _faseFromId(raw['fase']?.toString());
  destino.ultimaCapturaIdx = (raw['ultimaCapturaIdx'] as num?)?.toInt();
  destino.mensajeFin = raw['mensajeFin']?.toString();
  destino.ganador = raw['ganador']?.toString();
  destino.reiniciarCombosEnProximaJugada =
      raw['reiniciarCombosEnProximaJugada'] == true;

  destino.mazo
    ..clear()
    ..addAll(_decodeCartas(raw['mazo']));
  destino.mesa
    ..clear()
    ..addAll(_decodeCartas(raw['mesa']));

  final jugadoresRaw = raw['jugadores'];
  if (jugadoresRaw is List) {
    // Reconstruir lista si cambió el tamaño / nombres.
    if (jugadoresRaw.length != destino.jugadores.length) {
      destino.jugadores
        ..clear()
        ..addAll([
          for (final item in jugadoresRaw)
            if (item is Map)
              JugadorEscoba(
                Map<String, dynamic>.from(item)['nombre']?.toString() ??
                    'Jugador',
              ),
        ]);
    }
    for (var i = 0; i < jugadoresRaw.length && i < destino.jugadores.length; i++) {
      if (jugadoresRaw[i] is! Map) continue;
      final m = Map<String, dynamic>.from(jugadoresRaw[i] as Map);
      final j = destino.jugadores[i];
      j.nombre = m['nombre']?.toString() ?? j.nombre;
      j.mano
        ..clear()
        ..addAll(_decodeCartas(m['mano']));
      j.capturadas
        ..clear()
        ..addAll(_decodeCartas(m['capturadas']));
      j.combos
        ..clear()
        ..addAll([
          for (final c in (m['combos'] as List? ?? const []))
            if (_decodeCombo(c) case final combo?) combo,
        ]);
      j.escobasRonda = (m['escobasRonda'] as num?)?.toInt() ?? 0;
      j.puntos = (m['puntos'] as num?)?.toInt() ?? 0;
      j.rendido = m['rendido'] == true;
    }
  }

  destino.ultimoResultado = _decodeResultado(raw['ultimoResultado']);
}

/// ¿Hay que esperar a que el anfitrión publique el mazo?
bool escobaEsperaMazo(Map<String, dynamic>? raw) =>
    raw != null &&
    raw['juego']?.toString() == 'escobaDel15' &&
    !escobaPartidaGenerada(raw);

Map<String, dynamic> encodeUltimaJugadaEscoba({
  required String jugador,
  required CartaEscoba carta,
  List<CartaEscoba> mesaElegida = const [],
  required bool tiro,
}) {
  final extras = mesaElegida.isEmpty
      ? ''
      : ' + ${mesaElegida.map((c) => c.etiqueta).join(' + ')}';
  return {
    'jugador': jugador,
    'carta': _encodeCarta(carta),
    'mesaElegida': _encodeCartas(mesaElegida),
    'tiro': tiro,
    'descripcion': tiro
        ? '$jugador tira ${carta.etiqueta}'
        : '$jugador captura ${carta.etiqueta}$extras = 15',
  };
}
