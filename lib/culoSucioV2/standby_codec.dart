import 'package:app_juegos_mesa/culoSucioV2/culo_sucio_v2_online_codec.dart';
import 'package:app_juegos_mesa/culoSucioV2/motor_culo_sucio_v2.dart';
import 'package:app_juegos_mesa/culoSucioV2/opciones_culo_sucio_v2.dart';
import 'package:app_juegos_mesa/culoSucioV2/standby_store.dart';
import 'package:app_juegos_mesa/shared/persistencia/persistencia_comun.dart';

Map<String, dynamic> encodeCuloSucioV2Standby(PartidaCuloSucioV2Resume r) {
  return {
    'v': 1,
    'nombres': r.nombres,
    'modoDios': r.modoDios,
    'ajustes': encodeAjustes(r.ajustesIniciales),
    'opciones': {
      'eliminarParesAuto': r.opciones.eliminarParesAuto,
      'detectarParTrasRobo': r.opciones.detectarParTrasRobo,
      'moverCuloSucio': r.opciones.moverCuloSucio,
    },
    'gameState': encodeCuloSucioV2GameState(
      partida: r.partida,
      version: 1,
      opciones: r.opciones,
    ),
  };
}

OpcionesCuloSucioV2 _decodeOpciones(Object? raw) {
  if (raw is! Map) return const OpcionesCuloSucioV2();
  final m = Map<String, dynamic>.from(raw);
  return OpcionesCuloSucioV2(
    eliminarParesAuto: m['eliminarParesAuto'] != false,
    detectarParTrasRobo: m['detectarParTrasRobo'] != false,
    moverCuloSucio: m['moverCuloSucio'] == true,
  );
}

PartidaCuloSucioV2Resume? decodeCuloSucioV2Standby(Map<String, dynamic> raw) {
  if ((raw['v'] as num?)?.toInt() != 1) return null;
  final nombres = (raw['nombres'] as List?)?.map((e) => e.toString()).toList();
  if (nombres == null || nombres.length < 2) return null;

  final opciones = _decodeOpciones(raw['opciones']);
  final partida = PartidaCuloSucioV2(
    jugadores: [for (final n in nombres) JugadorCuloSucioV2(n)],
    contraPc: true,
  );

  final gs = raw['gameState'];
  if (gs is Map) {
    applyCuloSucioV2GameState(partida, Map<String, dynamic>.from(gs));
  }

  return PartidaCuloSucioV2Resume(
    partida: partida,
    nombres: nombres,
    modoDios: raw['modoDios'] == true,
    opciones: opciones,
    ajustesIniciales: decodeAjustes(raw['ajustes']),
  );
}
