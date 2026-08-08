/// Serialización del estado de La Papa para multijugador online.
library;

import 'dart:ui';

import 'package:app_juegos_mesa/laPapa/motor_la_papa.dart';
import 'package:app_juegos_mesa/laPapa/opciones_la_papa.dart';

Map<String, dynamic> encodePapaOpciones(OpcionesPapa o) => {
      'conVidas': o.conVidas,
      'numerosAleatorios': o.numerosAleatorios,
      'cantidadNumeros': o.cantidadNumeros,
      'modoFantasma': o.modoFantasma,
      'mostrarCuadricula': o.mostrarCuadricula,
      'permitirTrazoSobreNumeros': o.permitirTrazoSobreNumeros,
      'mostrarLupa': o.mostrarLupa,
      'modificarGrosorTrazo': o.modificarGrosorTrazo,
      'excepcionGeneracionNumeros': o.excepcionGeneracionNumeros,
    };

OpcionesPapa decodePapaOpciones(Map? raw) {
  if (raw == null) return const OpcionesPapa();
  return OpcionesPapa(
    conVidas: raw['conVidas'] == true,
    numerosAleatorios: raw['numerosAleatorios'] != false,
    cantidadNumeros: (raw['cantidadNumeros'] as num?)?.toInt() ??
        OpcionesPapa.maxNumeroPapaDefault,
    modoFantasma: raw['modoFantasma'] == true,
    mostrarCuadricula: raw['mostrarCuadricula'] != false,
    permitirTrazoSobreNumeros: raw['permitirTrazoSobreNumeros'] != false,
    mostrarLupa: raw['mostrarLupa'] != false,
    modificarGrosorTrazo: raw['modificarGrosorTrazo'] != false,
    excepcionGeneracionNumeros: raw['excepcionGeneracionNumeros'] == true,
  );
}

List<Map<String, double>> _encodePuntos(List<Offset> pts, Size board) {
  // Si ya están normalizados (0..1), se publican tal cual.
  if (puntosParecenNormalizadosPapa(pts)) {
    return [for (final p in pts) {'x': p.dx, 'y': p.dy}];
  }
  final w = board.width <= 0 ? 1.0 : board.width;
  final h = board.height <= 0 ? 1.0 : board.height;
  return [
    for (final p in pts) {'x': p.dx / w, 'y': p.dy / h},
  ];
}

List<Offset> _decodePuntos(dynamic raw, Size board) {
  if (raw is! List) return [];
  // Guardamos normalizado en PartidaPapa; [board] se ignora a propósito.
  final out = <Offset>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final m = Map<String, dynamic>.from(item);
    final x = (m['x'] as num?)?.toDouble();
    final y = (m['y'] as num?)?.toDouble();
    if (x == null || y == null) continue;
    out.add(Offset(x, y));
  }
  return out;
}

GrosorTrazoPapa _grosorFromId(String? id) {
  for (final g in GrosorTrazoPapa.values) {
    if (g.name == id) return g;
  }
  return GrosorTrazoPapa.normal;
}

FasePapa _faseFromId(String? id) {
  for (final f in FasePapa.values) {
    if (f.name == id) return f;
  }
  return FasePapa.jugando;
}

Map<String, dynamic> encodePapaGameState({
  required PartidaPapa partida,
  required int version,
  required OpcionesPapa opciones,
  Size? boardSize,
  List<Offset>? trazoFallido,
}) {
  final board = boardSize ?? const Size(1, 1);
  return {
    'version': version,
    'juego': 'laPapa',
    'nombres': List<String>.from(partida.nombres),
    'casillas': [
      for (final c in partida.casillas) c,
    ],
    'maxNumero': partida.maxNumero,
    'indiceTurno': partida.indiceTurno,
    'siguienteConectar': partida.siguienteConectar,
    'siguienteAColocar': partida.siguienteAColocar,
    'fase': partida.fase.name,
    'mensajeFin': partida.mensajeFin,
    'ganador': partida.ganador,
    'conVidas': partida.conVidas,
    'modoFantasma': partida.modoFantasma,
    'vidas': List<int>.from(partida.vidas),
    'rendidos': List<String>.from(partida.rendidos),
    'trazos': [
      for (final t in partida.trazos)
        {
          'de': t.de,
          'a': t.a,
          'jugador': t.jugador,
          'grosor': t.grosor.name,
          'puntos': _encodePuntos(t.puntos, board),
        },
    ],
    'trazoFallido': _encodePuntos(trazoFallido ?? const [], board),
    'opciones': encodePapaOpciones(opciones),
    'mostrarVictoria': partida.terminada,
  };
}

/// Aplica [raw] sobre [destino]. [boardSize] convierte trazos normalizados.
void applyPapaGameState(
  PartidaPapa destino,
  Map<String, dynamic> raw, {
  required Size boardSize,
  List<Offset>? trazoFallidoOut,
}) {
  final nombres = (raw['nombres'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
      destino.nombres;
  if (nombres.isNotEmpty) {
    destino.nombres
      ..clear()
      ..addAll(nombres);
  }

  final casillasRaw = raw['casillas'];
  if (casillasRaw is List && casillasRaw.length == totalCasillasPapa) {
    for (var i = 0; i < totalCasillasPapa; i++) {
      final v = casillasRaw[i];
      destino.casillas[i] = v == null ? null : (v as num).toInt();
    }
  }

  destino.indiceTurno =
      (raw['indiceTurno'] as num?)?.toInt() ?? destino.indiceTurno;
  destino.siguienteConectar =
      (raw['siguienteConectar'] as num?)?.toInt() ?? destino.siguienteConectar;
  destino.siguienteAColocar =
      (raw['siguienteAColocar'] as num?)?.toInt() ?? destino.siguienteAColocar;
  destino.fase = _faseFromId(raw['fase']?.toString());
  destino.mensajeFin = raw['mensajeFin']?.toString();
  destino.ganador = raw['ganador']?.toString();
  // conVidas / modoFantasma son final en PartidaPapa — se fijan al crear.
  // Solo sincronizamos vidas mutables.
  final vidasRaw = raw['vidas'];
  if (vidasRaw is List) {
    destino.vidas
      ..clear()
      ..addAll(vidasRaw.map((e) => (e as num).toInt()));
  }

  final rendidosRaw = raw['rendidos'];
  destino.rendidos
    ..clear()
    ..addAll(
      rendidosRaw is List
          ? rendidosRaw.map((e) => e.toString())
          : const <String>[],
    );

  destino.trazos.clear();
  final trazosRaw = raw['trazos'];
  if (trazosRaw is List) {
    for (final item in trazosRaw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      destino.trazos.add(
        TrazoPapa(
          puntos: _decodePuntos(m['puntos'], boardSize),
          de: (m['de'] as num?)?.toInt() ?? 0,
          a: (m['a'] as num?)?.toInt() ?? 0,
          jugador: m['jugador']?.toString() ?? '',
          grosor: _grosorFromId(m['grosor']?.toString()),
        ),
      );
    }
  }

  if (trazoFallidoOut != null) {
    trazoFallidoOut
      ..clear()
      ..addAll(_decodePuntos(raw['trazoFallido'], boardSize));
  }
}

bool papaGameStateTieneTablero(Map<String, dynamic>? raw) {
  final casillas = raw?['casillas'];
  if (casillas is! List || casillas.length != totalCasillasPapa) return false;
  // Tablero listo si hay algún número o está en colocación con lista válida.
  return true;
}

bool papaTableroGenerado(Map<String, dynamic>? raw) {
  final casillas = raw?['casillas'];
  if (casillas is! List || casillas.length != totalCasillasPapa) return false;
  final fase = raw?['fase']?.toString();
  if (fase == FasePapa.colocando.name) return true;
  return casillas.any((c) => c != null);
}
