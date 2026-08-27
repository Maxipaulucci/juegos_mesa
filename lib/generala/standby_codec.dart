import 'package:app_juegos_mesa/generala/generala_online_codec.dart';
import 'package:app_juegos_mesa/generala/motor_generala.dart';
import 'package:app_juegos_mesa/generala/standby_store.dart';
import 'package:app_juegos_mesa/shared/persistencia/persistencia_comun.dart';

Map<String, dynamic> encodeGeneralaStandby(PartidaGeneralaResume r) {
  return {
    'v': 1,
    'nombres': r.nombres,
    'modoDios': r.modoDios,
    'contraPc': r.contraPc,
    'ajustes': encodeAjustes(r.ajustesIniciales),
    'dificultad': encodeDificultad(r.dificultadPc),
    'gameState': encodeGeneralaGameState(
      partida: r.partida,
      version: 1,
      modoAnotar: false,
      mostrarVictoria: false,
    ),
  };
}

PartidaGeneralaResume? decodeGeneralaStandby(Map<String, dynamic> raw) {
  if ((raw['v'] as num?)?.toInt() != 1) return null;
  final nombres = (raw['nombres'] as List?)?.map((e) => e.toString()).toList();
  if (nombres == null || nombres.isEmpty) return null;

  final partida = nuevaPartidaGenerala(nombres);
  iniciarTurnoGenerala(partida);

  final gs = raw['gameState'];
  if (gs is Map) {
    applyGeneralaGameState(partida, Map<String, dynamic>.from(gs));
  }

  return PartidaGeneralaResume(
    partida: partida,
    nombres: nombres,
    contraPc: raw['contraPc'] != false,
    dificultadPc: decodeDificultad(raw['dificultad']),
    modoDios: raw['modoDios'] == true,
    ajustesIniciales: decodeAjustes(raw['ajustes']),
  );
}
