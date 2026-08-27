import 'package:app_juegos_mesa/culoSucio/culo_sucio_online_codec.dart';
import 'package:app_juegos_mesa/culoSucio/motor_culo_sucio.dart';
import 'package:app_juegos_mesa/culoSucio/opciones_culo_sucio.dart';
import 'package:app_juegos_mesa/culoSucio/standby_store.dart';

Map<String, dynamic> encodeCuloSucioStandby(PartidaCuloSucioResume r) {
  return {
    'v': 1,
    'nombres': r.nombres,
    'modoDios': r.modoDios,
    'opciones': {'comodines': r.opciones.comodines},
    'gameState': encodeCuloSucioGameState(
      partida: r.partida,
      version: 1,
      comodines: r.opciones.comodines,
    ),
  };
}

OpcionesCuloSucio _decodeOpciones(Object? raw) {
  if (raw is! Map) return const OpcionesCuloSucio();
  final m = Map<String, dynamic>.from(raw);
  return OpcionesCuloSucio(
    comodines: m['comodines'] == true,
  );
}

PartidaCuloSucioResume? decodeCuloSucioStandby(Map<String, dynamic> raw) {
  if ((raw['v'] as num?)?.toInt() != 1) return null;
  final nombres = (raw['nombres'] as List?)?.map((e) => e.toString()).toList();
  if (nombres == null || nombres.length < 2) return null;

  final opciones = _decodeOpciones(raw['opciones']);
  final partida = PartidaCuloSucio(
    nombres: nombres,
    mazo: [],
    contraPc: true,
  );

  final gs = raw['gameState'];
  if (gs is Map) {
    applyCuloSucioGameState(partida, Map<String, dynamic>.from(gs));
  }

  return PartidaCuloSucioResume(
    partida: partida,
    nombres: nombres,
    opciones: opciones,
    modoDios: raw['modoDios'] == true,
  );
}
