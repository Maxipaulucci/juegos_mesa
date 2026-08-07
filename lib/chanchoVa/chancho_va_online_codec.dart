/// Serialización del estado de Chancho va para multijugador online.
library;

import 'package:app_juegos_mesa/chanchoVa/motor_chancho_va.dart';
import 'package:app_juegos_mesa/chanchoVa/opciones_chancho_va.dart';

Map<String, dynamic> _encodeCarta(CartaChancho c) => {
      'numero': c.numero,
      'palo': c.palo.name,
    };

CartaChancho? _decodeCarta(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final numero = (m['numero'] as num?)?.toInt();
  final paloId = m['palo']?.toString();
  if (numero == null || paloId == null) return null;
  PaloChancho? palo;
  for (final p in PaloChancho.values) {
    if (p.name == paloId) {
      palo = p;
      break;
    }
  }
  if (palo == null) return null;
  return CartaChancho(numero: numero, palo: palo);
}

List<Map<String, dynamic>> _encodeCartas(List<CartaChancho> cartas) => [
      for (final c in cartas) _encodeCarta(c),
    ];

List<CartaChancho> _decodeCartas(dynamic raw) {
  if (raw is! List) return [];
  final out = <CartaChancho>[];
  for (final item in raw) {
    final c = _decodeCarta(item);
    if (c != null) out.add(c);
  }
  return out;
}

FaseChancho _faseFromId(String? id) {
  for (final f in FaseChancho.values) {
    if (f.name == id) return f;
  }
  return FaseChancho.eligiendoNumeros;
}

DireccionChancho? _dirFromId(String? id) {
  for (final d in DireccionChancho.values) {
    if (d.name == id) return d;
  }
  return null;
}

MotivoPenalizacionChancho? _motivoFromId(String? id) {
  for (final m in MotivoPenalizacionChancho.values) {
    if (m.name == id) return m;
  }
  return null;
}

Map<String, dynamic>? _encodeAnuncio(AnuncioChancho? a) {
  if (a == null) return null;
  return {
    'cantidad': a.cantidad,
    'direccion': a.direccion.name,
  };
}

AnuncioChancho? _decodeAnuncio(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final cant = (m['cantidad'] as num?)?.toInt();
  final dir = _dirFromId(m['direccion']?.toString());
  if (cant == null || dir == null) return null;
  return AnuncioChancho(cantidad: cant, direccion: dir);
}

Map<String, dynamic> _encodeEvento(EventoHistorialChancho e) => {
      'jugador': e.jugador,
      'letrasTras': e.letrasTras,
      'motivo': e.motivo.name,
    };

EventoHistorialChancho? _decodeEvento(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final motivo = _motivoFromId(m['motivo']?.toString());
  final jugador = m['jugador']?.toString();
  final letrasTras = m['letrasTras']?.toString();
  if (motivo == null || jugador == null || letrasTras == null) return null;
  return EventoHistorialChancho(
    jugador: jugador,
    letrasTras: letrasTras,
    motivo: motivo,
  );
}

Map<String, dynamic>? _encodeResumen(ResumenRondaChancho? r) {
  if (r == null) return null;
  return {
    'motivo': r.motivo.name,
    'chanchoDe': r.chanchoDe,
    'chancho': r.chancho,
  };
}

ResumenRondaChancho? _decodeResumen(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final motivo = _motivoFromId(m['motivo']?.toString());
  final chancho = m['chancho']?.toString();
  if (motivo == null || chancho == null) return null;
  return ResumenRondaChancho(
    motivo: motivo,
    chanchoDe: m['chanchoDe']?.toString(),
    chancho: chancho,
  );
}

OpcionesChanchoVa decodeOpcionesChancho(dynamic raw) {
  if (raw is! Map) return const OpcionesChanchoVa();
  final m = Map<String, dynamic>.from(raw);
  return OpcionesChanchoVa(
    chancha: m['chancha'] != false,
    sinEspacio: m['sinEspacio'] == true,
    finAlPrimerPerdedor: m['finAlPrimerPerdedor'] == true,
  );
}

Map<String, dynamic> encodeOpcionesChancho(
  OpcionesChanchoVa o, {
  int? totalJugadores,
}) =>
    {
      'chancha': o.chancha,
      'sinEspacio': o.sinEspacio,
      'finAlPrimerPerdedor': o.finAlPrimerPerdedor,
      if (totalJugadores != null) 'totalJugadores': totalJugadores.clamp(3, 4),
    };

/// Humanos de la sala + PCs (1–2) según total 3–4.
List<String> nombresMesaChanchoOnline({
  required List<String> humanos,
  required int totalJugadores,
}) {
  final total = totalJugadores.clamp(3, 4);
  final pcs = (total - humanos.length).clamp(1, 2);
  return [
    ...humanos,
    for (var i = 1; i <= pcs; i++) 'PC $i',
  ];
}

/// Estado inicial vacío (el anfitrión publica el deal real).
Map<String, dynamic> seedChanchoGameState({
  required List<String> nombres,
  required OpcionesChanchoVa opciones,
}) =>
    {
      'version': 1,
      'juego': 'chanchoVa',
      'pendienteDeal': true,
      'contraPc': true,
      'sinEspacio': opciones.sinEspacio,
      'finAlPrimerPerdedor': opciones.finAlPrimerPerdedor,
      'opciones': encodeOpcionesChancho(opciones),
      'indiceTurno': 0,
      'fase': FaseChancho.eligiendoNumeros.name,
      'numerosEnJuego': <int>[],
      'anuncioActual': null,
      'ultimoAnuncio': null,
      'quienAbrioChancho': null,
      'ordenChancho': <String>[],
      'historialLetras': <Map<String, dynamic>>[],
      'ultimoResumenRonda': null,
      'perdedor': null,
      'ganador': null,
      'mensajeFin': null,
      'quienLanzoChancha': null,
      'objetivoChancha': null,
      'jugadores': [
        for (final n in nombres)
          {
            'nombre': n,
            'mano': <Map<String, dynamic>>[],
            'letras': <String>[],
            'seleccionPase': <Map<String, dynamic>>[],
            'seleccionPaseConfirmada': false,
            'dijoChancho': false,
            'eliminado': false,
          },
      ],
      'mostrarVictoria': false,
    };

bool chanchoPartidaGenerada(Map<String, dynamic> raw) {
  if (raw['pendienteDeal'] == true) return false;
  if (raw['juego']?.toString() != 'chanchoVa') return false;
  final jugadores = raw['jugadores'];
  // Deal publicado aunque aún esté en eligiendoNumeros (manos vacías).
  return jugadores is List && jugadores.isNotEmpty;
}

Map<String, dynamic> encodeChanchoGameState({
  required PartidaChancho partida,
  required int version,
  required OpcionesChanchoVa opciones,
  String? quienLanzoChancha,
  String? objetivoChancha,
  bool mostrarVictoria = false,
}) =>
    {
      'version': version,
      'juego': 'chanchoVa',
      'pendienteDeal': false,
      'contraPc': partida.contraPc,
      'sinEspacio': partida.sinEspacio,
      'finAlPrimerPerdedor': partida.finAlPrimerPerdedor,
      'opciones': encodeOpcionesChancho(
        opciones,
        totalJugadores: partida.jugadores.length,
      ),
      'indiceTurno': partida.indiceTurno,
      'fase': partida.fase.name,
      'numerosEnJuego': List<int>.from(partida.numerosEnJuego),
      'anuncioActual': _encodeAnuncio(partida.anuncioActual),
      'ultimoAnuncio': _encodeAnuncio(partida.ultimoAnuncio),
      'quienAbrioChancho': partida.quienAbrioChancho,
      'ordenChancho': List<String>.from(partida.ordenChancho),
      'historialLetras': [
        for (final e in partida.historialLetras) _encodeEvento(e),
      ],
      'ultimoResumenRonda': _encodeResumen(partida.ultimoResumenRonda),
      'perdedor': partida.perdedor,
      'ganador': partida.ganador,
      'mensajeFin': partida.mensajeFin,
      'quienLanzoChancha': quienLanzoChancha,
      'objetivoChancha': objetivoChancha,
      'jugadores': [
        for (final j in partida.jugadores)
          {
            'nombre': j.nombre,
            'mano': _encodeCartas(j.mano),
            'letras': List<String>.from(j.letras),
            'seleccionPase': _encodeCartas(j.seleccionPase),
            'seleccionPaseConfirmada': j.seleccionPaseConfirmada,
            'dijoChancho': j.dijoChancho,
            'eliminado': j.eliminado,
          },
      ],
      'mostrarVictoria': mostrarVictoria || partida.terminada,
    };

PartidaChancho partidaChanchoDesdeGameState(Map<String, dynamic> raw) {
  final opts = decodeOpcionesChancho(raw['opciones']);
  final jugadoresRaw = raw['jugadores'];
  final nombres = <String>[];
  if (jugadoresRaw is List) {
    for (final item in jugadoresRaw) {
      if (item is Map) {
        nombres.add(
          Map<String, dynamic>.from(item)['nombre']?.toString() ?? 'Jugador',
        );
      }
    }
  }
  if (nombres.length < 3) {
    nombres.addAll([
      for (var i = nombres.length; i < 3; i++) 'Jugador ${i + 1}',
    ]);
  }
  final p = nuevaPartidaChancho(
    nombres: nombres.take(4).toList(),
    contraPc: raw['contraPc'] != false,
    sinEspacio: opts.sinEspacio || raw['sinEspacio'] == true,
    finAlPrimerPerdedor:
        opts.finAlPrimerPerdedor || raw['finAlPrimerPerdedor'] == true,
  );
  applyChanchoGameState(p, raw);
  return p;
}

void applyChanchoGameState(PartidaChancho destino, Map<String, dynamic> raw) {
  destino.indiceTurno = (raw['indiceTurno'] as num?)?.toInt() ?? 0;
  destino.fase = _faseFromId(raw['fase']?.toString());
  destino.numerosEnJuego
    ..clear()
    ..addAll([
      for (final n in (raw['numerosEnJuego'] as List? ?? const []))
        if (n is num) n.toInt(),
    ]);
  destino.anuncioActual = _decodeAnuncio(raw['anuncioActual']);
  destino.ultimoAnuncio = _decodeAnuncio(raw['ultimoAnuncio']);
  destino.quienAbrioChancho = raw['quienAbrioChancho']?.toString();
  destino.ordenChancho
    ..clear()
    ..addAll([
      for (final n in (raw['ordenChancho'] as List? ?? const []))
        if (n != null) n.toString(),
    ]);
  destino.historialLetras
    ..clear()
    ..addAll([
      for (final e in (raw['historialLetras'] as List? ?? const []))
        if (_decodeEvento(e) case final ev?) ev,
    ]);
  destino.ultimoResumenRonda = _decodeResumen(raw['ultimoResumenRonda']);
  destino.perdedor = raw['perdedor']?.toString();
  destino.ganador = raw['ganador']?.toString();
  destino.mensajeFin = raw['mensajeFin']?.toString();

  final jugadoresRaw = raw['jugadores'];
  if (jugadoresRaw is! List) return;

  if (jugadoresRaw.length != destino.jugadores.length) {
    destino.jugadores
      ..clear()
      ..addAll([
        for (final item in jugadoresRaw)
          if (item is Map)
            JugadorChancho(
              Map<String, dynamic>.from(item)['nombre']?.toString() ??
                  'Jugador',
            ),
      ]);
  }

  for (var i = 0; i < jugadoresRaw.length && i < destino.jugadores.length; i++) {
    if (jugadoresRaw[i] is! Map) continue;
    final m = Map<String, dynamic>.from(jugadoresRaw[i] as Map);
    final j = destino.jugadores[i];
    j.mano
      ..clear()
      ..addAll(_decodeCartas(m['mano']));
    j.letras
      ..clear()
      ..addAll([
        for (final l in (m['letras'] as List? ?? const []))
          if (l != null) l.toString(),
      ]);
    j.seleccionPase
      ..clear()
      ..addAll(_decodeCartas(m['seleccionPase']));
    j.seleccionPaseConfirmada = m['seleccionPaseConfirmada'] == true;
    j.dijoChancho = m['dijoChancho'] == true;
    j.eliminado = m['eliminado'] == true;
  }
}
