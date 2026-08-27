import 'package:app_juegos_mesa/casitaRobada/motor_casita.dart';
import 'package:app_juegos_mesa/casitaRobada/standby_store.dart';

Map<String, dynamic> _encodeCarta(CartaCasita c) => {
      'numero': c.numero,
      'palo': c.palo.name,
    };

CartaCasita? _decodeCarta(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final numero = (m['numero'] as num?)?.toInt();
  final paloId = m['palo']?.toString();
  if (numero == null || paloId == null) return null;
  for (final p in PaloCasita.values) {
    if (p.name == paloId) return CartaCasita(numero: numero, palo: p);
  }
  return null;
}

List<Map<String, dynamic>> _encodeCartas(List<CartaCasita> cartas) => [
      for (final c in cartas) _encodeCarta(c),
    ];

List<CartaCasita> _decodeCartas(dynamic raw) {
  if (raw is! List) return [];
  return [
    for (final item in raw)
      if (_decodeCarta(item) case final c?) c,
  ];
}

FaseCasita _faseFromId(String? id) {
  for (final f in FaseCasita.values) {
    if (f.name == id) return f;
  }
  return FaseCasita.jugando;
}

TipoJugadaCasita _tipoFromId(String? id) {
  for (final t in TipoJugadaCasita.values) {
    if (t.name == id) return t;
  }
  return TipoJugadaCasita.mesa;
}

Map<String, dynamic>? _encodeUltimaJugada(UltimaJugadaCasita? u) {
  if (u == null) return null;
  return {
    'jugador': u.jugador,
    'carta': _encodeCarta(u.carta),
    'tipo': u.tipo.name,
    'cartasCapturadas': _encodeCartas(u.cartasCapturadas),
    'robadoDe': u.robadoDe,
  };
}

UltimaJugadaCasita? _decodeUltimaJugada(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final carta = _decodeCarta(m['carta']);
  final jugador = m['jugador']?.toString();
  if (carta == null || jugador == null) return null;
  return UltimaJugadaCasita(
    jugador: jugador,
    carta: carta,
    tipo: _tipoFromId(m['tipo']?.toString()),
    cartasCapturadas: _decodeCartas(m['cartasCapturadas']),
    robadoDe: m['robadoDe']?.toString(),
  );
}

Map<String, dynamic> _encodeGameState(PartidaCasita p) => {
      'indiceTurno': p.indiceTurno,
      'fase': p.fase.name,
      'contraPc': p.contraPc,
      'ganador': p.ganador,
      'mensajeFin': p.mensajeFin,
      'ultimoQueCapturo': p.ultimoQueCapturo,
      'ultimaJugada': _encodeUltimaJugada(p.ultimaJugada),
      'mazo': _encodeCartas(p.mazo),
      'mesa': _encodeCartas(p.mesa),
      'jugadores': [
        for (final j in p.jugadores)
          {
            'nombre': j.nombre,
            'mano': _encodeCartas(j.mano),
            'pozo': _encodeCartas(j.pozo),
            'rendido': j.rendido,
          },
      ],
    };

void _applyGameState(PartidaCasita p, Map<String, dynamic> raw) {
  p.indiceTurno = (raw['indiceTurno'] as num?)?.toInt() ?? 0;
  p.fase = _faseFromId(raw['fase']?.toString());
  p.ganador = raw['ganador']?.toString();
  p.mensajeFin = raw['mensajeFin']?.toString();
  p.ultimoQueCapturo = raw['ultimoQueCapturo']?.toString();
  p.ultimaJugada = _decodeUltimaJugada(raw['ultimaJugada']);

  p.mazo
    ..clear()
    ..addAll(_decodeCartas(raw['mazo']));
  p.mesa
    ..clear()
    ..addAll(_decodeCartas(raw['mesa']));

  final jugadoresRaw = raw['jugadores'];
  if (jugadoresRaw is List) {
    if (jugadoresRaw.length != p.jugadores.length) {
      p.jugadores
        ..clear()
        ..addAll([
          for (final item in jugadoresRaw)
            if (item is Map)
              JugadorCasita(
                Map<String, dynamic>.from(item)['nombre']?.toString() ??
                    'Jugador',
              ),
        ]);
    }
    for (var i = 0; i < jugadoresRaw.length && i < p.jugadores.length; i++) {
      if (jugadoresRaw[i] is! Map) continue;
      final m = Map<String, dynamic>.from(jugadoresRaw[i] as Map);
      final j = p.jugadores[i];
      j.nombre = m['nombre']?.toString() ?? j.nombre;
      j.mano
        ..clear()
        ..addAll(_decodeCartas(m['mano']));
      j.pozo
        ..clear()
        ..addAll(_decodeCartas(m['pozo']));
      j.rendido = m['rendido'] == true;
    }
  }
}

Map<String, dynamic> encodeCasitaStandby(PartidaCasitaResume r) {
  return {
    'v': 1,
    'nombres': r.nombres,
    'modoDios': r.modoDios,
    'gameState': _encodeGameState(r.partida),
  };
}

PartidaCasitaResume? decodeCasitaStandby(Map<String, dynamic> raw) {
  if ((raw['v'] as num?)?.toInt() != 1) return null;
  final nombres = (raw['nombres'] as List?)?.map((e) => e.toString()).toList();
  if (nombres == null || nombres.length < 2) return null;

  final partida = PartidaCasita(
    jugadores: [for (final n in nombres) JugadorCasita(n)],
    contraPc: true,
  );

  final gs = raw['gameState'];
  if (gs is Map) {
    _applyGameState(partida, Map<String, dynamic>.from(gs));
  }

  return PartidaCasitaResume(
    partida: partida,
    nombres: nombres,
    modoDios: raw['modoDios'] == true,
  );
}
