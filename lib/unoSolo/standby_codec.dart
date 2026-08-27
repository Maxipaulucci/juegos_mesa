import 'package:app_juegos_mesa/shared/persistencia/persistencia_comun.dart';
import 'package:app_juegos_mesa/unoSolo/motor_uno_solo.dart';
import 'package:app_juegos_mesa/unoSolo/opciones_uno_solo.dart';
import 'package:app_juegos_mesa/unoSolo/standby_store.dart';
import 'package:app_juegos_mesa/unoSolo/uno_solo_online_codec.dart';

Map<String, dynamic> encodeUnoSoloStandby(PartidaUnoSoloResume r) {
  return {
    'v': 1,
    'nombres': r.nombres,
    'modoDios': r.modoDios,
    'ajustes': encodeAjustes(r.ajustesIniciales),
    'opciones': {'modoPractica': r.opciones.modoPractica},
    'gameState': encodeUnoSoloGameState(
      partida: r.partida,
      version: 1,
      historial: r.historial,
    ),
  };
}

OpcionesUnoSolo _decodeOpciones(Object? raw) {
  if (raw is! Map) return const OpcionesUnoSolo();
  final m = Map<String, dynamic>.from(raw);
  return OpcionesUnoSolo(
    modoPractica: m['modoPractica'] != false,
  );
}

PartidaUnoSoloResume? decodeUnoSoloStandby(Map<String, dynamic> raw) {
  if ((raw['v'] as num?)?.toInt() != 1) return null;
  final nombres = (raw['nombres'] as List?)?.map((e) => e.toString()).toList();
  if (nombres == null || nombres.isEmpty) return null;

  final opciones = _decodeOpciones(raw['opciones']);
  final partida = nuevaPartidaUnoSolo(nombres: nombres);
  final historial = <MovimientoUnoSolo>[];

  final gs = raw['gameState'];
  if (gs is Map) {
    applyUnoSoloGameState(
      partida,
      Map<String, dynamic>.from(gs),
      historialOut: historial,
    );
  }

  return PartidaUnoSoloResume(
    partida: partida,
    nombres: nombres,
    ajustesIniciales: decodeAjustes(raw['ajustes']),
    modoDios: raw['modoDios'] == true,
    opciones: opciones,
    historial: historial,
  );
}
