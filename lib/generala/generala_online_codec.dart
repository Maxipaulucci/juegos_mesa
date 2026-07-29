/// Serialización del estado de Generala para multijugador online.
library;

import 'package:app_juegos_mesa/generala/motor_generala.dart';

Map<String, dynamic> encodeGeneralaGameState({
  required PartidaGenerala partida,
  required int version,
  required bool modoAnotar,
  required bool mostrarVictoria,
  String? subtituloVictoria,
}) {
  return {
    'version': version,
    'juego': 'generala',
    'indiceTurno': partida.indiceTurno,
    'ganador': partida.ganador,
    'jugadores': [
      for (final j in partida.jugadores)
        {
          'nombre': j.nombre,
          'rendido': j.rendido,
          'casillas': {
            for (final e in j.casillas.entries) e.key.etiqueta: e.value,
          },
        },
    ],
    'turno': {
      'dados': List<int>.of(partida.turno.dados),
      'guardados': List<bool>.of(partida.turno.guardados),
      'tiradasHechas': partida.turno.tiradasHechas,
    },
    'modoAnotar': modoAnotar,
    'mostrarVictoria': mostrarVictoria,
    'subtituloVictoria': subtituloVictoria,
  };
}

/// Aplica [raw] sobre [partida] (mutándola). Devuelve flags de UI.
({bool modoAnotar, bool mostrarVictoria, String? subtituloVictoria})
    applyGeneralaGameState(PartidaGenerala partida, Map<String, dynamic> raw) {
  partida.indiceTurno = (raw['indiceTurno'] as num?)?.toInt() ?? 0;
  partida.ganador = raw['ganador']?.toString();

  final jugadoresRaw = raw['jugadores'];
  if (jugadoresRaw is List) {
    for (var i = 0; i < jugadoresRaw.length && i < partida.jugadores.length; i++) {
      final m = Map<String, dynamic>.from(jugadoresRaw[i] as Map);
      final j = partida.jugadores[i];
      j.nombre = m['nombre']?.toString() ?? j.nombre;
      j.rendido = m['rendido'] == true;
      final casillas = m['casillas'];
      if (casillas is Map) {
        for (final c in CategoriaGenerala.values) {
          final v = casillas[c.etiqueta];
          if (v == null) {
            j.casillas[c] = null;
          } else if (v is num) {
            j.casillas[c] = v.toInt();
          }
        }
      }
    }
  }

  final turnoRaw = raw['turno'];
  if (turnoRaw is Map) {
    final t = Map<String, dynamic>.from(turnoRaw);
    partida.turno = EstadoTurnoGenerala()
      ..dados = [
        for (final d in (t['dados'] as List? ?? const []))
          if (d is num) d.toInt(),
      ]
      ..guardados = [
        for (var i = 0; i < dadosGenerala; i++)
          (t['guardados'] is List && i < (t['guardados'] as List).length)
              ? (t['guardados'] as List)[i] == true
              : false,
      ]
      ..tiradasHechas = (t['tiradasHechas'] as num?)?.toInt() ?? 0;
  }

  return (
    modoAnotar: raw['modoAnotar'] == true,
    mostrarVictoria: raw['mostrarVictoria'] == true,
    subtituloVictoria: raw['subtituloVictoria']?.toString(),
  );
}

Map<String, dynamic> estadoInicialGenerala(List<String> nombres) {
  final partida = nuevaPartidaGenerala(nombres);
  iniciarTurnoGenerala(partida);
  return encodeGeneralaGameState(
    partida: partida,
    version: 1,
    modoAnotar: false,
    mostrarVictoria: false,
  );
}
