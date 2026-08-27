import 'package:app_juegos_mesa/jodete/motor_jodete.dart';
import 'package:app_juegos_mesa/jodete/opciones_jodete.dart';
import 'package:app_juegos_mesa/jodete/standby_store.dart';
import 'package:app_juegos_mesa/shared/persistencia/persistencia_comun.dart';

Map<String, dynamic> _encodeCarta(CartaJodete c) => {
      'numero': c.numero,
      'palo': c.palo?.name,
      'esComodin': c.esComodin,
      'id': c.id,
    };

CartaJodete? _decodeCarta(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final esComodin = m['esComodin'] == true;
  final id = (m['id'] as num?)?.toInt() ?? 0;
  if (esComodin) {
    return CartaJodete(numero: null, palo: null, esComodin: true, id: id);
  }
  final numero = (m['numero'] as num?)?.toInt();
  final paloId = m['palo']?.toString();
  if (numero == null || paloId == null) return null;
  for (final p in PaloJodete.values) {
    if (p.name == paloId) {
      return CartaJodete(numero: numero, palo: p, id: id);
    }
  }
  return null;
}

List<Map<String, dynamic>> _encodeCartas(List<CartaJodete> cartas) => [
      for (final c in cartas) _encodeCarta(c),
    ];

List<CartaJodete> _decodeCartas(dynamic raw) {
  if (raw is! List) return [];
  return [
    for (final item in raw)
      if (_decodeCarta(item) case final c?) c,
  ];
}

PaloJodete _paloFromId(String? id) {
  for (final p in PaloJodete.values) {
    if (p.name == id) return p;
  }
  return PaloJodete.oro;
}

FaseJodete _faseFromId(String? id) {
  for (final f in FaseJodete.values) {
    if (f.name == id) return f;
  }
  return FaseJodete.jugando;
}

SentidoJodete _sentidoFromId(String? id) {
  for (final s in SentidoJodete.values) {
    if (s.name == id) return s;
  }
  return SentidoJodete.horario;
}

Map<String, dynamic>? _encodeDetalleRonda(DetalleJugadorRondaJodete d) => {
      'nombre': d.nombre,
      'puesto': d.puesto,
      'puntosGanados': d.puntosGanados,
      'puntosTrasRonda': d.puntosTrasRonda,
      'detallePuntos': d.detallePuntos,
    };

DetalleJugadorRondaJodete? _decodeDetalleRonda(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final nombre = m['nombre']?.toString();
  if (nombre == null) return null;
  return DetalleJugadorRondaJodete(
    nombre: nombre,
    puesto: (m['puesto'] as num?)?.toInt() ?? 0,
    puntosGanados: (m['puntosGanados'] as num?)?.toInt() ?? 0,
    puntosTrasRonda: (m['puntosTrasRonda'] as num?)?.toInt() ?? 0,
    detallePuntos: m['detallePuntos']?.toString(),
  );
}

Map<String, dynamic>? _encodeResultadoRonda(ResultadoRondaJodete? r) {
  if (r == null) return null;
  return {
    'detalles': [
      for (final d in r.detalles) _encodeDetalleRonda(d)!,
    ],
  };
}

ResultadoRondaJodete? _decodeResultadoRonda(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final detalles = <DetalleJugadorRondaJodete>[];
  final detRaw = m['detalles'];
  if (detRaw is List) {
    for (final item in detRaw) {
      if (_decodeDetalleRonda(item) case final d?) detalles.add(d);
    }
  }
  return ResultadoRondaJodete(detalles: detalles);
}

Map<String, dynamic> _encodeGameState(PartidaJodete p) => {
      'indiceTurno': p.indiceTurno,
      'sentido': p.sentido.name,
      'fase': p.fase.name,
      'contraPc': p.contraPc,
      'paloVigente': p.paloVigente.name,
      'ganador': p.ganador,
      'mensajeFin': p.mensajeFin,
      'ultimaJugada': p.ultimaJugada,
      'pendienteDos': p.pendienteDos,
      'pendienteComodin': p.pendienteComodin,
      'objetivo': p.objetivo,
      'incluirComodines': p.incluirComodines,
      'cartasIniciales': p.cartasIniciales,
      'puntajePorCartas': p.puntajePorCartas,
      'apilarDoses': p.apilarDoses,
      'ganarConEspecial': p.ganarConEspecial,
      'ultimoResultado': _encodeResultadoRonda(p.ultimoResultado),
      'historialRondas': [
        for (final r in p.historialRondas) _encodeResultadoRonda(r)!,
      ],
      'mazo': _encodeCartas(p.mazo),
      'descarte': _encodeCartas(p.descarte),
      'jugadores': [
        for (final j in p.jugadores)
          {
            'nombre': j.nombre,
            'mano': _encodeCartas(j.mano),
            'rendido': j.rendido,
            'puntos': j.puntos,
            'puestoRonda': j.puestoRonda,
          },
      ],
    };

PartidaJodete _decodeGameState(Map<String, dynamic> raw) {
  final jugadoresRaw = raw['jugadores'];
  final jugadores = <JugadorJodete>[];
  if (jugadoresRaw is List) {
    for (final item in jugadoresRaw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final j = JugadorJodete(m['nombre']?.toString() ?? 'Jugador');
      j.mano.addAll(_decodeCartas(m['mano']));
      j.rendido = m['rendido'] == true;
      j.puntos = (m['puntos'] as num?)?.toInt() ?? 0;
      j.puestoRonda = (m['puestoRonda'] as num?)?.toInt();
      jugadores.add(j);
    }
  }

  final historial = <ResultadoRondaJodete>[];
  final histRaw = raw['historialRondas'];
  if (histRaw is List) {
    for (final item in histRaw) {
      if (_decodeResultadoRonda(item) case final r?) historial.add(r);
    }
  }

  return PartidaJodete(
    jugadores: jugadores,
    mazo: _decodeCartas(raw['mazo']),
    descarte: _decodeCartas(raw['descarte']),
    paloVigente: _paloFromId(raw['paloVigente']?.toString()),
    indiceTurno: (raw['indiceTurno'] as num?)?.toInt() ?? 0,
    sentido: _sentidoFromId(raw['sentido']?.toString()),
    fase: _faseFromId(raw['fase']?.toString()),
    ganador: raw['ganador']?.toString(),
    mensajeFin: raw['mensajeFin']?.toString(),
    contraPc: raw['contraPc'] != false,
    ultimaJugada: raw['ultimaJugada']?.toString(),
    pendienteDos: (raw['pendienteDos'] as num?)?.toInt() ?? 0,
    pendienteComodin: (raw['pendienteComodin'] as num?)?.toInt() ?? 0,
    objetivo: (raw['objetivo'] as num?)?.toInt() ?? 30,
    incluirComodines: raw['incluirComodines'] != false,
    cartasIniciales: (raw['cartasIniciales'] as num?)?.toInt() ?? 7,
    puntajePorCartas: raw['puntajePorCartas'] == true,
    apilarDoses: raw['apilarDoses'] != false,
    ganarConEspecial: raw['ganarConEspecial'] != false,
    ultimoResultado: _decodeResultadoRonda(raw['ultimoResultado']),
    historialRondas: historial,
  );
}

Map<String, dynamic> encodeJodeteStandby(PartidaJodeteResume r) {
  return {
    'v': 1,
    'nombres': r.nombres,
    'modoDios': r.modoDios,
    'dificultad': encodeDificultad(r.dificultad),
    'ajustes': r.ajustesIniciales == null
        ? null
        : encodeAjustes(r.ajustesIniciales!),
    'opciones': {
      'comodines': r.opciones.comodines,
      'levantarHastaTirar': r.opciones.levantarHastaTirar,
      'objetivo': r.opciones.objetivo,
      'puntajePorCartas': r.opciones.puntajePorCartas,
      'apilarDoses': r.opciones.apilarDoses,
      'ganarConEspecial': r.opciones.ganarConEspecial,
    },
    'gameState': _encodeGameState(r.partida),
  };
}

OpcionesJodete _decodeOpciones(Object? raw) {
  if (raw is! Map) return const OpcionesJodete();
  final m = Map<String, dynamic>.from(raw);
  return OpcionesJodete(
    comodines: m['comodines'] != false,
    levantarHastaTirar: m['levantarHastaTirar'] == true,
    objetivo: (m['objetivo'] as num?)?.toInt() ?? 30,
    puntajePorCartas: m['puntajePorCartas'] == true,
    apilarDoses: m['apilarDoses'] != false,
    ganarConEspecial: m['ganarConEspecial'] != false,
  );
}

PartidaJodeteResume? decodeJodeteStandby(Map<String, dynamic> raw) {
  if ((raw['v'] as num?)?.toInt() != 1) return null;
  final nombres = (raw['nombres'] as List?)?.map((e) => e.toString()).toList();
  if (nombres == null || nombres.length < 2) return null;

  final gs = raw['gameState'];
  if (gs is! Map) return null;

  final opciones = _decodeOpciones(raw['opciones']);
  final partida = _decodeGameState(Map<String, dynamic>.from(gs));

  return PartidaJodeteResume(
    partida: partida,
    nombres: nombres,
    modoDios: raw['modoDios'] == true,
    dificultad: decodeDificultad(raw['dificultad']),
    opciones: opciones,
    ajustesIniciales: raw['ajustes'] == null
        ? null
        : decodeAjustes(raw['ajustes']),
  );
}
