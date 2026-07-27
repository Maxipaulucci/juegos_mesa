/// Motor puro del 10.000 (sin UI).
/// Port de motor.py — la pantalla solo llama a estas funciones.
library;

import 'dart:math';

const int meta = 10000;

enum Modo {
  cinco(5),
  seis(6);

  const Modo(this.dados);
  final int dados;

  /// Puntos mínimos en un turno para empezar a anotar.
  int get apertura => switch (this) {
        Modo.cinco => 500,
        Modo.seis => 750,
      };
}

enum Especial { tresPares, cuatroYPar, seisIguales }

class Combo {
  const Combo({
    required this.nombre,
    required this.puntos,
    required this.dadosUsados,
    this.especial,
  });

  final String nombre;
  final int puntos;
  final List<int> dadosUsados;
  final Especial? especial;
}

class ResultadoTirada {
  ResultadoTirada({
    required this.dados,
    required this.contadores,
    required this.combosAuto,
    required this.combosOpcionales,
    this.victoriaInmediata = false,
  });

  final List<int> dados;
  final Map<int, int> contadores;
  final List<Combo> combosAuto;
  final List<Combo> combosOpcionales;
  final bool victoriaInmediata;
}

class EstadoTurno {
  EstadoTurno({required this.dadosEnMano});

  int dadosEnMano;
  int puntosTurno = 0;
  int tiradaNro = 0;
  bool abiertoEstaRonda = false;
}

class Jugador {
  Jugador(this.nombre);

  String nombre;
  int puntos = 0;
  bool abierto = false;
  /// Se rindió y ya no juega turnos, pero sigue en la lista/estadísticas.
  bool rendido = false;
}

class Partida {
  Partida({required this.modo, required this.jugadores})
      : turno = EstadoTurno(dadosEnMano: modo.dados);

  final Modo modo;
  final List<Jugador> jugadores;
  int indiceTurno = 0;
  String? ganador;
  EstadoTurno turno;

  Jugador get jugadorActual => jugadores[indiceTurno];

  List<Jugador> get jugadoresActivos =>
      jugadores.where((j) => !j.rendido).toList();
}

class ResumenTirada {
  ResumenTirada({
    required this.puntosTirada,
    required this.puntosTurno,
    required this.dadosRestantes,
    required this.bust,
    required this.hotDice,
    required this.combos,
    required this.victoria,
    this.puntosPerdidos = 0,
    this.pasado = false,
    this.intentoTotal,
  });

  final int puntosTirada;
  final int puntosTurno;
  final int dadosRestantes;
  final bool bust;
  final bool hotDice;
  final List<Combo> combos;
  final bool victoria;
  final int puntosPerdidos;
  /// Si al sumar el turno al total se supera [meta], el turno se anula.
  final bool pasado;
  final int? intentoTotal;
}

class ResumenPlantarse {
  ResumenPlantarse({
    required this.ok,
    required this.motivo,
    required this.puntos,
    this.sumados,
    this.intento,
    this.puntosTurno,
    this.requerido,
  });

  final bool ok;
  final String motivo;
  final int puntos;
  final int? sumados;
  final int? intento;
  final int? puntosTurno;
  final int? requerido;
}

List<int> tirar(int cantidad, [Random? rng]) {
  final r = rng ?? Random();
  return List.generate(cantidad, (_) => r.nextInt(6) + 1);
}

List<int> _dadosDe(int valor, int cantidad) =>
    List.filled(cantidad, valor);

Map<int, int> _contar(List<int> dados) {
  final counts = <int, int>{};
  for (final d in dados) {
    counts[d] = (counts[d] ?? 0) + 1;
  }
  return counts;
}

ResultadoTirada analizarTirada(List<int> dados, Modo modo) {
  final counts = _contar(dados);
  final contadores = {for (var cara = 1; cara <= 6; cara++) cara: counts[cara] ?? 0};
  final n = dados.length;
  final usados = <int, int>{};
  final auto = <Combo>[];
  final opcionales = <Combo>[];

  if (modo == Modo.seis && n == 6) {
    for (final entry in counts.entries) {
      if (entry.value == 6) {
        auto.add(
          Combo(
            nombre: 'seis_${entry.key}',
            puntos: meta,
            dadosUsados: _dadosDe(entry.key, 6),
            especial: Especial.seisIguales,
          ),
        );
        return ResultadoTirada(
          dados: dados,
          contadores: contadores,
          combosAuto: auto,
          combosOpcionales: opcionales,
          victoriaInmediata: true,
        );
      }
    }
  }

  final unicos = dados.toSet();
  if (modo == Modo.cinco && n == 5) {
    final esEscaleraBaja =
        unicos.length == 5 && unicos.containsAll({1, 2, 3, 4, 5});
    final esEscaleraAlta =
        unicos.length == 5 && unicos.containsAll({2, 3, 4, 5, 6});
    if (esEscaleraBaja || esEscaleraAlta) {
      final sorted = [...dados]..sort();
      auto.add(Combo(nombre: 'escalera', puntos: 500, dadosUsados: sorted));
      return ResultadoTirada(
        dados: dados,
        contadores: contadores,
        combosAuto: auto,
        combosOpcionales: opcionales,
      );
    }
  }
  if (modo == Modo.seis && n == 6 && unicos.length == 6) {
    final sorted = [...dados]..sort();
    auto.add(Combo(nombre: 'escalera', puntos: 1500, dadosUsados: sorted));
    return ResultadoTirada(
      dados: dados,
      contadores: contadores,
      combosAuto: auto,
      combosOpcionales: opcionales,
    );
  }

  if (modo == Modo.seis && n == 6) {
    final valores = counts.values.toList()..sort();
    if (valores.length == 3 && valores.every((v) => v == 2)) {
      final sorted = [...dados]..sort();
      opcionales.add(
        Combo(
          nombre: 'tres_pares',
          puntos: 1500,
          dadosUsados: sorted,
          especial: Especial.tresPares,
        ),
      );
    }
    if (valores.length == 2 &&
        ((valores[0] == 2 && valores[1] == 4) ||
            (valores[0] == 4 && valores[1] == 2))) {
      final sorted = [...dados]..sort();
      opcionales.add(
        Combo(
          nombre: 'cuatro_y_par',
          puntos: 1500,
          dadosUsados: sorted,
          especial: Especial.cuatroYPar,
        ),
      );
    }
  }

  for (final entry in counts.entries) {
    final cara = entry.key;
    final cant = entry.value;
    if (cant >= 5 && (usados[cara] ?? 0) == 0) {
      // Cinco 1 = 10.000 = meta → victoria instantánea (como seis iguales).
      if (cara == 1) {
        return ResultadoTirada(
          dados: dados,
          contadores: contadores,
          combosAuto: [
            Combo(nombre: 'cinco_1', puntos: meta, dadosUsados: _dadosDe(1, 5)),
          ],
          combosOpcionales: const [],
          victoriaInmediata: true,
        );
      }
      final pts = cara * 1000;
      auto.add(Combo(nombre: 'cinco_$cara', puntos: pts, dadosUsados: _dadosDe(cara, 5)));
      usados[cara] = (usados[cara] ?? 0) + 5;
    }
  }

  for (var cara = 1; cara <= 6; cara++) {
    final disponibles = (counts[cara] ?? 0) - (usados[cara] ?? 0);
    if (disponibles >= 3) {
      final pts = cara == 1 ? 1000 : cara * 100;
      auto.add(Combo(nombre: 'tres_$cara', puntos: pts, dadosUsados: _dadosDe(cara, 3)));
      usados[cara] = (usados[cara] ?? 0) + 3;
    }
  }

  for (final pair in [(1, 100), (5, 50)]) {
    final cara = pair.$1;
    final ptsUnitario = pair.$2;
    final sobra = (counts[cara] ?? 0) - (usados[cara] ?? 0);
    if (sobra > 0) {
      auto.add(
        Combo(
          nombre: 'sueltos_$cara',
          puntos: ptsUnitario * sobra,
          dadosUsados: _dadosDe(cara, sobra),
        ),
      );
      usados[cara] = (usados[cara] ?? 0) + sobra;
    }
  }

  return ResultadoTirada(
    dados: dados,
    contadores: contadores,
    combosAuto: auto,
    combosOpcionales: opcionales,
  );
}

int puntosDeCombos(List<Combo> combos) =>
    combos.fold(0, (sum, c) => sum + c.puntos);

int dadosRestantes(List<int> dados, List<Combo> combos) {
  var usados = 0;
  for (final c in combos) {
    usados += c.dadosUsados.length;
  }
  return dados.length - usados;
}

({int puntos, int quedan, List<Combo> combos}) resolverTirada(
  ResultadoTirada resultado, [
  Especial? aceptarEspecial,
]) {
  if (resultado.victoriaInmediata) {
    return (puntos: meta, quedan: 0, combos: resultado.combosAuto);
  }

  if (aceptarEspecial != null) {
    for (final c in resultado.combosOpcionales) {
      if (c.especial == aceptarEspecial) {
        return (puntos: c.puntos, quedan: 0, combos: [c]);
      }
    }
  }

  final combos = List<Combo>.from(resultado.combosAuto);
  final pts = puntosDeCombos(combos);
  final quedan = dadosRestantes(resultado.dados, combos);
  return (puntos: pts, quedan: quedan, combos: combos);
}

Partida nuevaPartida(List<String> nombres, Modo modo) {
  if (nombres.length < 2) {
    throw ArgumentError('Se necesitan al menos 2 jugadores');
  }
  return Partida(
    modo: modo,
    jugadores: nombres.map(Jugador.new).toList(),
  );
}

void iniciarTurno(Partida partida) {
  partida.turno = EstadoTurno(dadosEnMano: partida.modo.dados);
}

ResultadoTirada ejecutarTirada(
  Partida partida, {
  Random? rng,
  List<int>? dadosForzados,
}) {
  final t = partida.turno;
  t.tiradaNro += 1;
  final dados = dadosForzados ?? tirar(t.dadosEnMano, rng);
  return analizarTirada(dados, partida.modo);
}

ResumenTirada aplicarPuntosTirada(
  Partida partida,
  ResultadoTirada resultado, [
  Especial? aceptarEspecial,
]) {
  final t = partida.turno;
  final j = partida.jugadorActual;

  if (resultado.victoriaInmediata) {
    j.puntos = meta;
    j.abierto = true;
    partida.ganador = j.nombre;
    return ResumenTirada(
      puntosTirada: meta,
      puntosTurno: meta,
      dadosRestantes: 0,
      bust: false,
      hotDice: true,
      combos: resultado.combosAuto,
      victoria: true,
    );
  }

  final resuelto = resolverTirada(resultado, aceptarEspecial);
  final pts = resuelto.puntos;
  final quedan = resuelto.quedan;
  final combos = resuelto.combos;

  if (pts == 0) {
    final perdidos = t.puntosTurno;
    t.puntosTurno = 0;
    return ResumenTirada(
      puntosTirada: 0,
      puntosTurno: 0,
      dadosRestantes: 0,
      bust: true,
      hotDice: false,
      combos: const [],
      victoria: false,
      puntosPerdidos: perdidos,
    );
  }

  t.puntosTurno += pts;

  // Si con estos puntos ya te pasás de 10.000, el turno se pierde al toque.
  final intento = j.puntos + t.puntosTurno;
  if (intento > meta) {
    final perdidos = t.puntosTurno;
    t.puntosTurno = 0;
    return ResumenTirada(
      puntosTirada: pts,
      puntosTurno: 0,
      dadosRestantes: 0,
      bust: false,
      hotDice: false,
      combos: combos,
      victoria: false,
      pasado: true,
      intentoTotal: intento,
      puntosPerdidos: perdidos,
    );
  }

  // Exacto a 10.000: banca automática y victoria.
  if (intento == meta) {
    j.puntos = meta;
    j.abierto = true;
    partida.ganador = j.nombre;
    final sumados = t.puntosTurno;
    t.puntosTurno = 0;
    return ResumenTirada(
      puntosTirada: pts,
      puntosTurno: sumados,
      dadosRestantes: 0,
      bust: false,
      hotDice: quedan == 0,
      combos: combos,
      victoria: true,
    );
  }

  final bool hot;
  if (quedan == 0) {
    t.dadosEnMano = partida.modo.dados;
    hot = true;
  } else {
    t.dadosEnMano = quedan;
    hot = false;
  }

  return ResumenTirada(
    puntosTirada: pts,
    puntosTurno: t.puntosTurno,
    dadosRestantes: hot ? partida.modo.dados : t.dadosEnMano,
    bust: false,
    hotDice: hot,
    combos: combos,
    victoria: false,
  );
}

/// Si el jugador todavía no abrió, necesita [Modo.apertura] puntos en el turno.
bool puedePlantarse(Partida partida) {
  if (partida.ganador != null) return false;
  final j = partida.jugadorActual;
  final puntosTurno = partida.turno.puntosTurno;
  if (puntosTurno <= 0) return false;
  return j.abierto || puntosTurno >= partida.modo.apertura;
}

ResumenPlantarse plantarse(Partida partida) {
  final j = partida.jugadorActual;
  final t = partida.turno;
  final puntosTurno = t.puntosTurno;
  final anterior = j.puntos;
  final apertura = partida.modo.apertura;

  if (puntosTurno <= 0) {
    return ResumenPlantarse(ok: false, motivo: 'sin_puntos', puntos: j.puntos);
  }

  if (!j.abierto && puntosTurno < apertura) {
    t.puntosTurno = 0;
    return ResumenPlantarse(
      ok: false,
      motivo: 'apertura',
      puntos: j.puntos,
      puntosTurno: puntosTurno,
      requerido: apertura,
    );
  }

  final nuevo = anterior + puntosTurno;

  if (nuevo > meta) {
    t.puntosTurno = 0;
    return ResumenPlantarse(
      ok: false,
      motivo: 'pasado',
      puntos: anterior,
      intento: nuevo,
    );
  }

  j.puntos = nuevo;
  j.abierto = true;
  t.puntosTurno = 0;

  if (j.puntos == meta) {
    partida.ganador = j.nombre;
    return ResumenPlantarse(ok: true, motivo: 'victoria', puntos: j.puntos);
  }

  return ResumenPlantarse(
    ok: true,
    motivo: 'banco',
    puntos: j.puntos,
    sumados: puntosTurno,
  );
}

void pasarTurno(Partida partida) {
  if (partida.ganador != null) return;
  final n = partida.jugadores.length;
  if (n == 0) return;
  for (var i = 0; i < n; i++) {
    partida.indiceTurno = (partida.indiceTurno + 1) % n;
    if (!partida.jugadores[partida.indiceTurno].rendido) {
      iniciarTurno(partida);
      return;
    }
  }
}

bool hayOpcionales(ResultadoTirada resultado) =>
    resultado.combosOpcionales.isNotEmpty;

/// Quita los especiales que harían superar los 10.000 puntos.
///
/// Los combos normales siguen disponibles porque pueden tener un puntaje
/// distinto al especial de la misma tirada.
ResultadoTirada filtrarEspecialesQuePasanMeta(
  Partida partida,
  ResultadoTirada resultado,
) {
  if (resultado.combosOpcionales.isEmpty) return resultado;

  final base = partida.jugadorActual.puntos + partida.turno.puntosTurno;
  final permitidos = resultado.combosOpcionales
      .where((combo) => base + combo.puntos <= meta)
      .toList();

  if (permitidos.length == resultado.combosOpcionales.length) {
    return resultado;
  }

  return ResultadoTirada(
    dados: resultado.dados,
    contadores: resultado.contadores,
    combosAuto: resultado.combosAuto,
    combosOpcionales: permitidos,
    victoriaInmediata: resultado.victoriaInmediata,
  );
}
