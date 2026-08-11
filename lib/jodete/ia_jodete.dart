import 'dart:math' as math;

import 'package:app_juegos_mesa/jodete/motor_jodete.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';

class JugadaPcJodete {
  const JugadaPcJodete.jugar({
    required this.carta,
    this.paloElegido,
  }) : levantar = false;

  const JugadaPcJodete.levantar()
      : carta = null,
        paloElegido = null,
        levantar = true;

  final CartaJodete? carta;
  final PaloJodete? paloElegido;
  final bool levantar;
}

/// Elige jugada de la PC según dificultad.
JugadaPcJodete planificarJugadaPcJodete(
  PartidaJodete p, {
  required DificultadPc dificultad,
  math.Random? rng,
}) {
  final r = rng ?? math.Random();
  final j = p.jugadorActual;
  final jugables = cartasJugablesJodete(p, j);
  if (jugables.isEmpty) {
    return const JugadaPcJodete.levantar();
  }

  // Pendiente de doses: medio/difícil siempre apilan; fácil a veces no.
  if (p.hayPendienteDos) {
    final doses = jugables.where((c) => c.esDos).toList();
    if (doses.isEmpty) {
      return const JugadaPcJodete.levantar();
    }
    if (dificultad == DificultadPc.facil && r.nextDouble() < 0.35) {
      return const JugadaPcJodete.levantar();
    }
    return JugadaPcJodete.jugar(carta: doses[r.nextInt(doses.length)]);
  }

  CartaJodete elegir() {
    switch (dificultad) {
      case DificultadPc.facil:
        return jugables[r.nextInt(jugables.length)];
      case DificultadPc.medio:
        final normales =
            jugables.where((c) => !c.esComodin && !c.esDos).toList();
        if (normales.isNotEmpty) {
          return normales[r.nextInt(normales.length)];
        }
        return jugables[r.nextInt(jugables.length)];
      case DificultadPc.dificil:
        final agresivas = jugables
            .where(
              (c) => c.esComodin || c.esDos || c.saltea || c.invierte,
            )
            .toList();
        if (agresivas.isNotEmpty && r.nextDouble() < 0.65) {
          return agresivas[r.nextInt(agresivas.length)];
        }
        final normales = jugables
            .where((c) => !c.esComodin && !c.pideElegirPalo)
            .toList();
        if (normales.isNotEmpty) {
          return normales[r.nextInt(normales.length)];
        }
        return jugables[r.nextInt(jugables.length)];
    }
  }

  final carta = elegir();
  PaloJodete? palo;
  if (carta.pideElegirPalo) {
    palo = _elegirPaloPc(j, dificultad: dificultad, rng: r);
  }
  return JugadaPcJodete.jugar(carta: carta, paloElegido: palo);
}

PaloJodete _elegirPaloPc(
  JugadorJodete j, {
  required DificultadPc dificultad,
  required math.Random rng,
}) {
  if (dificultad == DificultadPc.facil) {
    return PaloJodete.values[rng.nextInt(PaloJodete.values.length)];
  }
  final conteo = <PaloJodete, int>{
    for (final p in PaloJodete.values) p: 0,
  };
  for (final c in j.mano) {
    if (c.palo != null) {
      conteo[c.palo!] = (conteo[c.palo!] ?? 0) + 1;
    }
  }
  PaloJodete mejor = PaloJodete.oro;
  var max = -1;
  for (final e in conteo.entries) {
    if (e.value > max) {
      max = e.value;
      mejor = e.key;
    }
  }
  if (max <= 0) {
    return PaloJodete.values[rng.nextInt(PaloJodete.values.length)];
  }
  return mejor;
}
