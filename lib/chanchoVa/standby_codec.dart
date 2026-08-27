import 'package:app_juegos_mesa/chanchoVa/chancho_va_online_codec.dart';
import 'package:app_juegos_mesa/chanchoVa/standby_store.dart';
import 'package:app_juegos_mesa/shared/persistencia/persistencia_comun.dart';

Map<String, dynamic> encodeChanchoStandby(PartidaChanchoResume r) {
  return {
    'v': 1,
    'nombres': r.nombres,
    'modoDios': r.modoDios,
    'ajustes': encodeAjustes(r.ajustesIniciales),
    'opciones': encodeOpcionesChancho(r.opciones),
    'gameState': encodeChanchoGameState(
      partida: r.partida,
      version: 1,
      opciones: r.opciones,
      mostrarVictoria: false,
    ),
  };
}

PartidaChanchoResume? decodeChanchoStandby(Map<String, dynamic> raw) {
  if ((raw['v'] as num?)?.toInt() != 1) return null;
  final nombres = (raw['nombres'] as List?)?.map((e) => e.toString()).toList();
  if (nombres == null || nombres.length < 3) return null;

  final opciones = decodeOpcionesChancho(raw['opciones']);
  final gs = raw['gameState'];
  if (gs is! Map) return null;

  final partida = partidaChanchoDesdeGameState(
    Map<String, dynamic>.from(gs),
  );

  return PartidaChanchoResume(
    partida: partida,
    nombres: nombres,
    ajustesIniciales: decodeAjustes(raw['ajustes']),
    modoDios: raw['modoDios'] == true,
    opciones: opciones,
  );
}
