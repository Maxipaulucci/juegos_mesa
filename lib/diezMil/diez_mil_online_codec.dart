/// Serialización del estado de Diez Mil para multijugador online.
library;

import 'motor.dart';

Map<String, dynamic> encodeDiezMilGameState({
  required Partida partida,
  required int version,
  required bool mostrarVictoria,
  String? subtituloVictoria,
  String? mensaje,
  ResultadoTirada? ultimaTirada,
  ResumenTirada? ultimoResumen,
}) {
  return {
    'version': version,
    'juego': 'diezMil',
    'modo': partida.modo.dados,
    'combosEspeciales': partida.combosEspeciales,
    'escalera': partida.escalera,
    'escaleraCircular': partida.escaleraCircular,
    'indiceTurno': partida.indiceTurno,
    'ganador': partida.ganador,
    'jugadores': [
      for (final j in partida.jugadores)
        {
          'nombre': j.nombre,
          'puntos': j.puntos,
          'abierto': j.abierto,
          'rendido': j.rendido,
        },
    ],
    'turno': {
      'dadosEnMano': partida.turno.dadosEnMano,
      'puntosTurno': partida.turno.puntosTurno,
      'tiradaNro': partida.turno.tiradaNro,
      'abiertoEstaRonda': partida.turno.abiertoEstaRonda,
    },
    'mostrarVictoria': mostrarVictoria,
    'subtituloVictoria': subtituloVictoria,
    'mensaje': mensaje,
    'ultimaTirada': ultimaTirada == null
        ? null
        : {
            'dados': List<int>.of(ultimaTirada.dados),
          },
    'ultimoResumen': ultimoResumen == null
        ? null
        : {
            'puntosTirada': ultimoResumen.puntosTirada,
            'puntosTurno': ultimoResumen.puntosTurno,
            'dadosRestantes': ultimoResumen.dadosRestantes,
            'bust': ultimoResumen.bust,
            'hotDice': ultimoResumen.hotDice,
            'victoria': ultimoResumen.victoria,
            'puntosPerdidos': ultimoResumen.puntosPerdidos,
            'pasado': ultimoResumen.pasado,
            'intentoTotal': ultimoResumen.intentoTotal,
            'combos': [
              for (final c in ultimoResumen.combos) _encodeCombo(c),
            ],
          },
  };
}

/// Aplica [raw] sobre [partida] (mutándola). Devuelve flags de UI y tirada.
({
  bool mostrarVictoria,
  String? subtituloVictoria,
  String? mensaje,
  ResultadoTirada? ultimaTirada,
  ResumenTirada? ultimoResumen,
}) applyDiezMilGameState(Partida partida, Map raw) {
  partida.indiceTurno = (raw['indiceTurno'] as num?)?.toInt() ?? 0;
  partida.ganador = raw['ganador']?.toString();
  if (raw.containsKey('combosEspeciales')) {
    partida.combosEspeciales = raw['combosEspeciales'] == true;
  }
  if (raw.containsKey('escalera')) {
    partida.escalera = raw['escalera'] == true;
  }
  if (raw.containsKey('escaleraCircular')) {
    partida.escaleraCircular = raw['escaleraCircular'] == true;
  }

  final jugadoresRaw = raw['jugadores'];
  if (jugadoresRaw is List) {
    for (var i = 0; i < jugadoresRaw.length && i < partida.jugadores.length; i++) {
      final m = Map<String, dynamic>.from(jugadoresRaw[i] as Map);
      final j = partida.jugadores[i];
      j.nombre = m['nombre']?.toString() ?? j.nombre;
      j.puntos = (m['puntos'] as num?)?.toInt() ?? j.puntos;
      j.abierto = m['abierto'] == true;
      j.rendido = m['rendido'] == true;
    }
  }

  final turnoRaw = raw['turno'];
  if (turnoRaw is Map) {
    final t = Map<String, dynamic>.from(turnoRaw);
    partida.turno = EstadoTurno(
      dadosEnMano: (t['dadosEnMano'] as num?)?.toInt() ?? partida.modo.dados,
    )
      ..puntosTurno = (t['puntosTurno'] as num?)?.toInt() ?? 0
      ..tiradaNro = (t['tiradaNro'] as num?)?.toInt() ?? 0
      ..abiertoEstaRonda = t['abiertoEstaRonda'] == true;
  }

  ResultadoTirada? ultimaTirada;
  final tiradaRaw = raw['ultimaTirada'];
  if (tiradaRaw is Map) {
    final dados = [
      for (final d in (tiradaRaw['dados'] as List? ?? const []))
        if (d is num) d.toInt(),
    ];
    if (dados.isNotEmpty) {
      ultimaTirada = filtrarEspecialesQuePasanMeta(
        partida,
        analizarTirada(
          dados,
          partida.modo,
          combosEspeciales: partida.combosEspeciales,
          escalera: partida.escalera,
          escaleraCircular: partida.escaleraCircular,
        ),
      );
    }
  }

  ResumenTirada? ultimoResumen;
  final resumenRaw = raw['ultimoResumen'];
  if (resumenRaw is Map) {
    final m = Map<String, dynamic>.from(resumenRaw);
    ultimoResumen = ResumenTirada(
      puntosTirada: (m['puntosTirada'] as num?)?.toInt() ?? 0,
      puntosTurno: (m['puntosTurno'] as num?)?.toInt() ?? 0,
      dadosRestantes: (m['dadosRestantes'] as num?)?.toInt() ?? 0,
      bust: m['bust'] == true,
      hotDice: m['hotDice'] == true,
      victoria: m['victoria'] == true,
      puntosPerdidos: (m['puntosPerdidos'] as num?)?.toInt() ?? 0,
      pasado: m['pasado'] == true,
      intentoTotal: (m['intentoTotal'] as num?)?.toInt(),
      combos: [
        for (final c in (m['combos'] as List? ?? const []))
          if (c is Map) _decodeCombo(Map<String, dynamic>.from(c)),
      ],
    );
  }

  return (
    mostrarVictoria: raw['mostrarVictoria'] == true,
    subtituloVictoria: raw['subtituloVictoria']?.toString(),
    mensaje: raw['mensaje']?.toString(),
    ultimaTirada: ultimaTirada,
    ultimoResumen: ultimoResumen,
  );
}

Map<String, dynamic> estadoInicialDiezMil(
  List<String> nombres,
  Modo modo, {
  bool combosEspeciales = true,
  bool escalera = true,
  bool escaleraCircular = false,
}) {
  final partida = nuevaPartida(
    nombres,
    modo,
    combosEspeciales: combosEspeciales,
    escalera: escalera,
    escaleraCircular: escaleraCircular,
  );
  iniciarTurno(partida);
  return encodeDiezMilGameState(
    partida: partida,
    version: 1,
    mostrarVictoria: false,
  );
}

Map<String, dynamic> _encodeCombo(Combo c) => {
      'nombre': c.nombre,
      'puntos': c.puntos,
      'dadosUsados': List<int>.of(c.dadosUsados),
      'especial': c.especial?.name,
    };

Combo _decodeCombo(Map<String, dynamic> m) => Combo(
      nombre: m['nombre']?.toString() ?? '',
      puntos: (m['puntos'] as num?)?.toInt() ?? 0,
      dadosUsados: [
        for (final d in (m['dadosUsados'] as List? ?? const []))
          if (d is num) d.toInt(),
      ],
      especial: _decodeEspecial(m['especial']?.toString()),
    );

Especial? _decodeEspecial(String? name) {
  if (name == null) return null;
  for (final e in Especial.values) {
    if (e.name == name) return e;
  }
  return null;
}
