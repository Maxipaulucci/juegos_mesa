/// Serialización de Uno solo para multijugador online.
library;

import 'package:app_juegos_mesa/unoSolo/motor_uno_solo.dart';

String _celdaId(CeldaUnoSolo c) => switch (c) {
      CeldaUnoSolo.invalida => 'x',
      CeldaUnoSolo.vacia => '0',
      CeldaUnoSolo.ocupada => '1',
    };

CeldaUnoSolo _celdaFromId(String? id) => switch (id) {
      '1' => CeldaUnoSolo.ocupada,
      '0' => CeldaUnoSolo.vacia,
      _ => CeldaUnoSolo.invalida,
    };

FaseUnoSolo _faseFromId(String? id) {
  for (final f in FaseUnoSolo.values) {
    if (f.name == id) return f;
  }
  return FaseUnoSolo.jugando;
}

bool unoSoloPartidaGenerada(Map<String, dynamic>? raw) {
  if (raw == null) return false;
  if (raw['pendienteTablero'] == true) return false;
  if (raw['juego']?.toString() != 'unoSolo') return false;
  final celdas = raw['celdas'];
  return celdas is List && celdas.length == PartidaUnoSolo.total;
}

Map<String, dynamic> encodeUnoSoloGameState({
  required PartidaUnoSolo partida,
  required int version,
}) {
  return {
    'version': version,
    'juego': 'unoSolo',
    'pendienteTablero': false,
    'nombres': List<String>.from(partida.nombres),
    'celdas': [for (final c in partida.celdas) _celdaId(c)],
    'indiceTurno': partida.indiceTurno,
    'fase': partida.fase.name,
    'mensajeFin': partida.mensajeFin,
    'ganador': partida.ganador,
    'calificacion': partida.calificacion,
    'solo': partida.solo,
    'mostrarVictoria': partida.terminada,
  };
}

void applyUnoSoloGameState(PartidaUnoSolo destino, Map<String, dynamic> raw) {
  destino.indiceTurno = (raw['indiceTurno'] as num?)?.toInt() ?? 0;
  destino.fase = _faseFromId(raw['fase']?.toString());
  destino.mensajeFin = raw['mensajeFin']?.toString();
  destino.ganador = raw['ganador']?.toString();
  destino.calificacion = raw['calificacion']?.toString();

  final nombres = (raw['nombres'] as List?)
      ?.map((e) => e.toString())
      .toList();
  if (nombres != null && nombres.isNotEmpty) {
    destino.nombres
      ..clear()
      ..addAll(nombres);
  }

  final celdasRaw = raw['celdas'];
  if (celdasRaw is List && celdasRaw.length == PartidaUnoSolo.total) {
    for (var i = 0; i < PartidaUnoSolo.total; i++) {
      destino.celdas[i] = _celdaFromId(celdasRaw[i]?.toString());
    }
  }
}
