import 'dart:ui';

import 'package:app_juegos_mesa/laPapa/la_papa_online_codec.dart';
import 'package:app_juegos_mesa/laPapa/motor_la_papa.dart';
import 'package:app_juegos_mesa/laPapa/standby_store.dart';
import 'package:app_juegos_mesa/shared/persistencia/persistencia_comun.dart';

Map<String, dynamic> encodePapaStandby(PartidaPapaResume r) {
  return {
    'v': 1,
    'nombres': r.nombres,
    'modoDios': false,
    'ajustes': encodeAjustes(r.ajustesIniciales),
    'opciones': encodePapaOpciones(r.opciones),
    'grosor': r.grosor.name,
    'boardSize': r.boardSize == null
        ? null
        : {'w': r.boardSize!.width, 'h': r.boardSize!.height},
    'gameState': encodePapaGameState(
      partida: r.partida,
      version: 1,
      opciones: r.opciones,
      boardSize: r.boardSize,
      trazoFallido: r.trazoFallido,
    ),
  };
}

GrosorTrazoPapa _grosorFromId(String? id) {
  for (final g in GrosorTrazoPapa.values) {
    if (g.name == id) return g;
  }
  return GrosorTrazoPapa.normal;
}

PartidaPapaResume? decodePapaStandby(Map<String, dynamic> raw) {
  if ((raw['v'] as num?)?.toInt() != 1) return null;
  final nombres = (raw['nombres'] as List?)?.map((e) => e.toString()).toList();
  if (nombres == null || nombres.isEmpty) return null;

  final opciones = decodePapaOpciones(
    raw['opciones'] is Map
        ? Map<String, dynamic>.from(raw['opciones'] as Map)
        : null,
  );
  final partida = nuevaPartidaPapa(nombres: nombres, opciones: opciones);

  Size? boardSize;
  final bs = raw['boardSize'];
  if (bs is Map) {
    final m = Map<String, dynamic>.from(bs);
    final w = (m['w'] as num?)?.toDouble();
    final h = (m['h'] as num?)?.toDouble();
    if (w != null && h != null) boardSize = Size(w, h);
  }

  final trazoFallido = <Offset>[];
  final gs = raw['gameState'];
  if (gs is Map) {
    applyPapaGameState(
      partida,
      Map<String, dynamic>.from(gs),
      boardSize: boardSize ?? const Size(1, 1),
      trazoFallidoOut: trazoFallido,
    );
  }

  return PartidaPapaResume(
    partida: partida,
    nombres: nombres,
    opciones: opciones,
    ajustesIniciales: decodeAjustes(raw['ajustes']),
    grosor: _grosorFromId(raw['grosor']?.toString()),
    boardSize: boardSize,
    trazoFallido: trazoFallido,
  );
}
