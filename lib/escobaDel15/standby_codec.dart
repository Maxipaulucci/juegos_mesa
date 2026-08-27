import 'package:app_juegos_mesa/escobaDel15/escoba_online_codec.dart';
import 'package:app_juegos_mesa/escobaDel15/motor_escoba.dart';
import 'package:app_juegos_mesa/escobaDel15/opciones_escoba.dart';
import 'package:app_juegos_mesa/escobaDel15/standby_store.dart';
import 'package:app_juegos_mesa/shared/persistencia/persistencia_comun.dart';

Map<String, dynamic> encodeEscobaStandby(PartidaEscobaResume r) {
  return {
    'v': 1,
    'nombres': r.nombres,
    'modoDios': r.modoDios,
    'ajustes': encodeAjustes(r.ajustesIniciales),
    'opciones': {
      'escobasAutomaticasInicio': r.opciones.escobasAutomaticasInicio,
    },
    'gameState': encodeEscobaGameState(
      partida: r.partida,
      version: 1,
      opciones: r.opciones,
    ),
  };
}

OpcionesEscoba _decodeOpciones(Object? raw) {
  if (raw is! Map) return const OpcionesEscoba();
  final m = Map<String, dynamic>.from(raw);
  return OpcionesEscoba(
    escobasAutomaticasInicio: m['escobasAutomaticasInicio'] == true,
  );
}

PartidaEscobaResume? decodeEscobaStandby(Map<String, dynamic> raw) {
  if ((raw['v'] as num?)?.toInt() != 1) return null;
  final nombres = (raw['nombres'] as List?)?.map((e) => e.toString()).toList();
  if (nombres == null || nombres.length < 2) return null;

  final opciones = _decodeOpciones(raw['opciones']);
  final gs = raw['gameState'];
  final objetivo = gs is Map
      ? (gs['objetivo'] as num?)?.toInt() ?? 15
      : 15;
  final partida = PartidaEscoba(
    jugadores: [for (final n in nombres) JugadorEscoba(n)],
    objetivo: objetivo,
  );

  if (gs is Map) {
    applyEscobaGameState(partida, Map<String, dynamic>.from(gs));
  }

  return PartidaEscobaResume(
    partida: partida,
    nombres: nombres,
    ajustesIniciales: decodeAjustes(raw['ajustes']),
    modoDios: raw['modoDios'] == true,
    opciones: opciones,
  );
}
