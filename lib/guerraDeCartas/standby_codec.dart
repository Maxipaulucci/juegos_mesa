import 'package:app_juegos_mesa/guerraDeCartas/motor_guerra.dart';
import 'package:app_juegos_mesa/guerraDeCartas/opciones_guerra.dart';
import 'package:app_juegos_mesa/guerraDeCartas/standby_store.dart';

Map<String, dynamic> _encodeCarta(CartaGuerra c) => {
      'valor': c.valor,
      'palo': c.palo.name,
    };

CartaGuerra? _decodeCarta(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final valor = (m['valor'] as num?)?.toInt();
  final paloId = m['palo']?.toString();
  if (valor == null || paloId == null) return null;
  for (final p in PaloGuerra.values) {
    if (p.name == paloId) return CartaGuerra(valor: valor, palo: p);
  }
  return null;
}

List<Map<String, dynamic>> _encodeCartas(List<CartaGuerra> cartas) => [
      for (final c in cartas) _encodeCarta(c),
    ];

List<CartaGuerra> _decodeCartas(dynamic raw) {
  if (raw is! List) return [];
  return [
    for (final item in raw)
      if (_decodeCarta(item) case final c?) c,
  ];
}

FaseGuerra _faseFromId(String? id) {
  for (final f in FaseGuerra.values) {
    if (f.name == id) return f;
  }
  return FaseGuerra.jugando;
}

Map<String, dynamic>? _encodeResultadoRonda(ResultadoRondaGuerra? r) {
  if (r == null) return null;
  return {
    'cartasJugadas': {
      for (final e in r.cartasJugadas.entries)
        e.key: _encodeCarta(e.value),
    },
    'pozoMesa': _encodeCartas(r.pozoMesa),
    'ganadorNombre': r.ganadorNombre,
    'huboGuerra': r.huboGuerra,
    'mensaje': r.mensaje,
    'mezclaronPozo': List<String>.from(r.mezclaronPozo),
  };
}

ResultadoRondaGuerra? _decodeResultadoRonda(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final cartasJugadas = <String, CartaGuerra>{};
  final cj = m['cartasJugadas'];
  if (cj is Map) {
    for (final e in cj.entries) {
      final carta = _decodeCarta(e.value);
      if (carta != null) cartasJugadas[e.key.toString()] = carta;
    }
  }
  final ganador = m['ganadorNombre']?.toString();
  if (ganador == null) return null;
  return ResultadoRondaGuerra(
    cartasJugadas: cartasJugadas,
    pozoMesa: _decodeCartas(m['pozoMesa']),
    ganadorNombre: ganador,
    huboGuerra: m['huboGuerra'] == true,
    mensaje: m['mensaje']?.toString(),
    mezclaronPozo: [
      for (final e in (m['mezclaronPozo'] as List? ?? const []))
        e.toString(),
    ],
  );
}

Map<String, dynamic>? _encodeGuerraPendiente(GuerraPendiente? g) {
  if (g == null) return null;
  return {
    'pot': _encodeCartas(g.pot),
    'visibles': {
      for (final e in g.visibles.entries) e.key: _encodeCarta(e.value),
    },
    'montones': {
      for (final e in g.montones.entries)
        e.key: _encodeCartas(e.value),
    },
    'nombresEnGuerra': List<String>.from(g.nombresEnGuerra),
    'mezclaron': List<String>.from(g.mezclaron),
  };
}

GuerraPendiente? _decodeGuerraPendiente(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final visibles = <String, CartaGuerra>{};
  final visRaw = m['visibles'];
  if (visRaw is Map) {
    for (final e in visRaw.entries) {
      final carta = _decodeCarta(e.value);
      if (carta != null) visibles[e.key.toString()] = carta;
    }
  }
  final montones = <String, List<CartaGuerra>>{};
  final monRaw = m['montones'];
  if (monRaw is Map) {
    for (final e in monRaw.entries) {
      montones[e.key.toString()] = _decodeCartas(e.value);
    }
  }
  return GuerraPendiente(
    pot: _decodeCartas(m['pot']),
    visibles: visibles,
    montones: montones,
    nombresEnGuerra: [
      for (final e in (m['nombresEnGuerra'] as List? ?? const []))
        e.toString(),
    ],
    mezclaron: [
      for (final e in (m['mezclaron'] as List? ?? const [])) e.toString(),
    ],
  );
}

Map<String, dynamic> _encodeGameState(PartidaGuerra p) => {
      'fase': p.fase.name,
      'contraPc': p.contraPc,
      'opciones': {'vidasActivas': p.opciones.vidasActivas},
      'ganador': p.ganador,
      'mensajeFin': p.mensajeFin,
      'ultimaRonda': _encodeResultadoRonda(p.ultimaRonda),
      'guerraPendiente': _encodeGuerraPendiente(p.guerraPendiente),
      'historialRondas': [
        for (final r in p.historialRondas) _encodeResultadoRonda(r)!,
      ],
      'jugadores': [
        for (final j in p.jugadores)
          {
            'nombre': j.nombre,
            'mazo': _encodeCartas(j.mazo),
            'pozo': _encodeCartas(j.pozo),
            'vidas': j.vidas,
            'rendido': j.rendido,
          },
      ],
    };

PartidaGuerra _decodeGameState(Map<String, dynamic> raw) {
  final opcionesRaw = raw['opciones'];
  final opciones = opcionesRaw is Map
      ? OpcionesGuerra(
          vidasActivas:
              Map<String, dynamic>.from(opcionesRaw)['vidasActivas'] != false,
        )
      : const OpcionesGuerra();

  final jugadoresRaw = raw['jugadores'];
  final jugadores = <JugadorGuerra>[];
  if (jugadoresRaw is List) {
    for (final item in jugadoresRaw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final j = JugadorGuerra(
        m['nombre']?.toString() ?? 'Jugador',
        vidas: (m['vidas'] as num?)?.toInt() ?? vidasInicialesGuerra,
      );
      j.mazo.addAll(_decodeCartas(m['mazo']));
      j.pozo.addAll(_decodeCartas(m['pozo']));
      j.rendido = m['rendido'] == true;
      jugadores.add(j);
    }
  }

  final historial = <ResultadoRondaGuerra>[];
  final histRaw = raw['historialRondas'];
  if (histRaw is List) {
    for (final item in histRaw) {
      if (_decodeResultadoRonda(item) case final r?) historial.add(r);
    }
  }

  final p = PartidaGuerra(
    jugadores: jugadores,
    contraPc: raw['contraPc'] != false,
    opciones: opciones,
    fase: _faseFromId(raw['fase']?.toString()),
    ganador: raw['ganador']?.toString(),
    mensajeFin: raw['mensajeFin']?.toString(),
    ultimaRonda: _decodeResultadoRonda(raw['ultimaRonda']),
    guerraPendiente: _decodeGuerraPendiente(raw['guerraPendiente']),
    historialRondas: historial,
  );
  return p;
}

Map<String, dynamic> encodeGuerraStandby(PartidaGuerraResume r) {
  return {
    'v': 1,
    'nombres': r.nombres,
    'modoDios': r.modoDios,
    'opciones': {'vidasActivas': r.opciones.vidasActivas},
    'gameState': _encodeGameState(r.partida),
  };
}

OpcionesGuerra _decodeOpciones(Object? raw) {
  if (raw is! Map) return const OpcionesGuerra();
  final m = Map<String, dynamic>.from(raw);
  return OpcionesGuerra(
    vidasActivas: m['vidasActivas'] != false,
  );
}

PartidaGuerraResume? decodeGuerraStandby(Map<String, dynamic> raw) {
  if ((raw['v'] as num?)?.toInt() != 1) return null;
  final nombres = (raw['nombres'] as List?)?.map((e) => e.toString()).toList();
  if (nombres == null || nombres.length < 2) return null;

  final gs = raw['gameState'];
  if (gs is! Map) return null;

  final partida = _decodeGameState(Map<String, dynamic>.from(gs));
  final opciones = _decodeOpciones(raw['opciones']);

  return PartidaGuerraResume(
    partida: partida,
    nombres: nombres,
    modoDios: raw['modoDios'] == true,
    opciones: opciones,
  );
}
