import 'package:app_juegos_mesa/desconfio/motor_desconfio.dart';
import 'package:app_juegos_mesa/desconfio/standby_store.dart';

Map<String, dynamic> _encodeCarta(CartaDesconfio c) => {
      'numero': c.numero,
      'palo': c.palo.name,
    };

CartaDesconfio? _decodeCarta(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final numero = (m['numero'] as num?)?.toInt();
  final paloId = m['palo']?.toString();
  if (numero == null || paloId == null) return null;
  for (final p in PaloDesconfio.values) {
    if (p.name == paloId) return CartaDesconfio(numero: numero, palo: p);
  }
  return null;
}

PaloDesconfio? _paloFromId(String? id) {
  for (final p in PaloDesconfio.values) {
    if (p.name == id) return p;
  }
  return null;
}

FaseDesconfio _faseFromId(String? id) {
  for (final f in FaseDesconfio.values) {
    if (f.name == id) return f;
  }
  return FaseDesconfio.elegirPalo;
}

Map<String, dynamic>? _encodeResultado(ResultadoDesconfio? r) {
  if (r == null) return null;
  return {
    'desconfiador': r.desconfiador,
    'tirador': r.tirador,
    'carta': _encodeCarta(r.carta),
    'eraDelPalo': r.eraDelPalo,
    'quienSeLleva': r.quienSeLleva,
    'cartasLlevadas': r.cartasLlevadas,
  };
}

ResultadoDesconfio? _decodeResultado(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final carta = _decodeCarta(m['carta']);
  final desconfiador = m['desconfiador']?.toString();
  final tirador = m['tirador']?.toString();
  final quienSeLleva = m['quienSeLleva']?.toString();
  if (carta == null ||
      desconfiador == null ||
      tirador == null ||
      quienSeLleva == null) {
    return null;
  }
  return ResultadoDesconfio(
    desconfiador: desconfiador,
    tirador: tirador,
    carta: carta,
    eraDelPalo: m['eraDelPalo'] == true,
    quienSeLleva: quienSeLleva,
    cartasLlevadas: (m['cartasLlevadas'] as num?)?.toInt() ?? 0,
  );
}

Map<String, dynamic> _encodeEntrada(EntradaHistorialDesconfio e) => {
      'jugador': e.jugador,
      'carta': _encodeCarta(e.carta),
      'paloDeclarado': e.paloDeclarado.name,
      'desconfiador': e.desconfiador,
      'eraDelPalo': e.eraDelPalo,
      'quienSeLleva': e.quienSeLleva,
      'cartasLlevadas': e.cartasLlevadas,
    };

EntradaHistorialDesconfio? _decodeEntrada(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final carta = _decodeCarta(m['carta']);
  final jugador = m['jugador']?.toString();
  final palo = _paloFromId(m['paloDeclarado']?.toString());
  if (carta == null || jugador == null || palo == null) return null;
  return EntradaHistorialDesconfio(
    jugador: jugador,
    carta: carta,
    paloDeclarado: palo,
    desconfiador: m['desconfiador']?.toString(),
    eraDelPalo: m['eraDelPalo'] as bool?,
    quienSeLleva: m['quienSeLleva']?.toString(),
    cartasLlevadas: (m['cartasLlevadas'] as num?)?.toInt(),
  );
}

Map<String, dynamic> _encodeGameState(PartidaDesconfio p) => {
      'indiceTurno': p.indiceTurno,
      'fase': p.fase.name,
      'contraPc': p.contraPc,
      'paloDeclarado': p.paloDeclarado?.name,
      'ganador': p.ganador,
      'mensajeFin': p.mensajeFin,
      'ultimoMensaje': p.ultimoMensaje,
      'ultimoResultado': _encodeResultado(p.ultimoResultado),
      'pozo': [
        for (final c in p.pozo)
          {
            'carta': _encodeCarta(c.carta),
            'jugador': c.jugador,
          },
      ],
      'historial': [
        for (final e in p.historial) _encodeEntrada(e),
      ],
      'jugadores': [
        for (final j in p.jugadores)
          {
            'nombre': j.nombre,
            'mano': [
              for (final c in j.mano) _encodeCarta(c),
            ],
            'rendido': j.rendido,
          },
      ],
    };

void _applyGameState(PartidaDesconfio p, Map<String, dynamic> raw) {
  p.indiceTurno = (raw['indiceTurno'] as num?)?.toInt() ?? 0;
  p.fase = _faseFromId(raw['fase']?.toString());
  p.paloDeclarado = _paloFromId(raw['paloDeclarado']?.toString());
  p.ganador = raw['ganador']?.toString();
  p.mensajeFin = raw['mensajeFin']?.toString();
  p.ultimoMensaje = raw['ultimoMensaje']?.toString();
  p.ultimoResultado = _decodeResultado(raw['ultimoResultado']);

  p.pozo.clear();
  final pozoRaw = raw['pozo'];
  if (pozoRaw is List) {
    for (final item in pozoRaw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final carta = _decodeCarta(m['carta']);
      final jugador = m['jugador']?.toString();
      if (carta == null || jugador == null) continue;
      p.pozo.add(CartaEnPozoDesconfio(carta: carta, jugador: jugador));
    }
  }

  p.historial.clear();
  final histRaw = raw['historial'];
  if (histRaw is List) {
    for (final item in histRaw) {
      if (_decodeEntrada(item) case final e?) p.historial.add(e);
    }
  }

  final jugadoresRaw = raw['jugadores'];
  if (jugadoresRaw is List) {
    if (jugadoresRaw.length != p.jugadores.length) {
      p.jugadores
        ..clear()
        ..addAll([
          for (final item in jugadoresRaw)
            if (item is Map)
              JugadorDesconfio(
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
        ..addAll([
          for (final c in (m['mano'] as List? ?? const []))
            if (_decodeCarta(c) case final carta?) carta,
        ]);
      j.rendido = m['rendido'] == true;
    }
  }
}

Map<String, dynamic> encodeDesconfioStandby(PartidaDesconfioResume r) {
  return {
    'v': 1,
    'nombres': r.nombres,
    'modoDios': r.modoDios,
    'gameState': _encodeGameState(r.partida),
  };
}

PartidaDesconfioResume? decodeDesconfioStandby(Map<String, dynamic> raw) {
  if ((raw['v'] as num?)?.toInt() != 1) return null;
  final nombres = (raw['nombres'] as List?)?.map((e) => e.toString()).toList();
  if (nombres == null || nombres.length < 2) return null;

  final partida = PartidaDesconfio(
    jugadores: [for (final n in nombres) JugadorDesconfio(n)],
    contraPc: true,
  );

  final gs = raw['gameState'];
  if (gs is Map) {
    _applyGameState(partida, Map<String, dynamic>.from(gs));
  }

  return PartidaDesconfioResume(
    partida: partida,
    nombres: nombres,
    modoDios: raw['modoDios'] == true,
  );
}
