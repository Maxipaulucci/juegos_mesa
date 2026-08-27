import 'package:app_juegos_mesa/shared/persistencia/persistencia_comun.dart';

import 'diez_mil_online_codec.dart';
import 'estadisticas.dart';
import 'motor.dart';
import 'opciones_diez_mil.dart';
import 'standby_store.dart';

Map<String, dynamic> encodeDiezMilStandby(PartidaDiezMilResume r) {
  return {
    'v': 1,
    'nombres': r.nombres,
    'modoDios': r.modoDios,
    'contraPc': r.contraPc,
    'ajustes': encodeAjustes(r.ajustesIniciales),
    'dificultad': encodeDificultad(r.dificultadPc),
    'modo': r.modo.name,
    'opciones': {
      'seisDados': r.opciones.seisDados,
      'escalera': r.opciones.escalera,
      'combosEspeciales': r.opciones.combosEspeciales,
      'escaleraCircular': r.opciones.escaleraCircular,
    },
    'gameState': encodeDiezMilGameState(
      partida: r.partida,
      version: 1,
      mostrarVictoria: false,
      mensaje: r.mensaje,
      ultimaTirada: r.ultimaTirada,
      ultimoResumen: r.ultimoResumen,
    ),
    'estadisticas': {
      for (final e in r.estadisticas.porJugador.entries)
        e.key: [
          for (final t in e.value.tiradas)
            {'numero': t.numero, 'puntos': t.puntos},
        ],
    },
    'mejorTiradaPartida': r.mejorTiradaPartida,
    'mejorTiradaJugador': r.mejorTiradaJugador,
    'ultimoTurnoHumano': r.ultimoTurnoHumano,
  };
}

Modo _modoFromId(String? id) {
  for (final m in Modo.values) {
    if (m.name == id) return m;
  }
  return Modo.seis;
}

OpcionesDiezMil _decodeOpciones(Object? raw) {
  if (raw is! Map) return const OpcionesDiezMil();
  final m = Map<String, dynamic>.from(raw);
  return OpcionesDiezMil(
    seisDados: m['seisDados'] != false,
    escalera: m['escalera'] != false,
    combosEspeciales: m['combosEspeciales'] != false,
    escaleraCircular: m['escaleraCircular'] == true,
  );
}

EstadisticasPartida _decodeEstadisticas(
  List<String> nombres,
  Object? raw,
) {
  final stats = EstadisticasPartida(nombres);
  if (raw is! Map) return stats;
  for (final e in raw.entries) {
    final nombre = e.key.toString();
    final jugador = stats.porJugador[nombre];
    if (jugador == null || e.value is! List) continue;
    jugador.tiradas.clear();
    for (final item in e.value as List) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      jugador.tiradas.add(
        RegistroTirada(
          numero: (m['numero'] as num?)?.toInt() ?? jugador.tiradas.length + 1,
          puntos: (m['puntos'] as num?)?.toInt() ?? 0,
        ),
      );
    }
  }
  return stats;
}

PartidaDiezMilResume? decodeDiezMilStandby(Map<String, dynamic> raw) {
  if ((raw['v'] as num?)?.toInt() != 1) return null;
  final nombres = (raw['nombres'] as List?)?.map((e) => e.toString()).toList();
  if (nombres == null || nombres.length < 2) return null;

  final opciones = _decodeOpciones(raw['opciones']);
  final modo = _modoFromId(raw['modo']?.toString());
  final partida = nuevaPartida(
    nombres,
    modo,
    combosEspeciales: opciones.combosEspeciales,
    escalera: opciones.escalera,
    escaleraCircular: opciones.escaleraCircular,
  );
  iniciarTurno(partida);

  final gs = raw['gameState'];
  late final ({
    bool mostrarVictoria,
    String? subtituloVictoria,
    String? mensaje,
    ResultadoTirada? ultimaTirada,
    ResumenTirada? ultimoResumen,
  }) ui;
  if (gs is Map) {
    ui = applyDiezMilGameState(partida, Map<String, dynamic>.from(gs));
  } else {
    ui = (
      mostrarVictoria: false,
      subtituloVictoria: null,
      mensaje: null,
      ultimaTirada: null,
      ultimoResumen: null,
    );
  }

  return PartidaDiezMilResume(
    partida: partida,
    estadisticas: _decodeEstadisticas(nombres, raw['estadisticas']),
    nombres: nombres,
    modo: modo,
    opciones: opciones,
    contraPc: raw['contraPc'] != false,
    dificultadPc: decodeDificultad(raw['dificultad']),
    modoDios: raw['modoDios'] == true,
    ajustesIniciales: decodeAjustes(raw['ajustes']),
    ultimaTirada: ui.ultimaTirada,
    ultimoResumen: ui.ultimoResumen,
    mensaje: ui.mensaje,
    mejorTiradaPartida: (raw['mejorTiradaPartida'] as num?)?.toInt() ?? 0,
    mejorTiradaJugador: raw['mejorTiradaJugador']?.toString(),
    ultimoTurnoHumano: (raw['ultimoTurnoHumano'] as num?)?.toInt() ?? 0,
  );
}
