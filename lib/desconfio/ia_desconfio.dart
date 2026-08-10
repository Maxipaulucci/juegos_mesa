import 'dart:math' as math;

import 'package:app_juegos_mesa/desconfio/motor_desconfio.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';

/// Cartas de cada palo en el mazo (48 → 12; si el mazo fuera 40 → 10).
int cartasPorPaloEnMazoDesconfio() {
  const numeros = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
  return numeros.length;
}

int totalCartasMazoDesconfio() =>
    cartasPorPaloEnMazoDesconfio() * PaloDesconfio.values.length;

/// ¿La PC [pc] debería decir desconfío ante la última tirada?
bool pcDebeDesconfiar({
  required PartidaDesconfio partida,
  required JugadorDesconfio pc,
  required DificultadPc dificultad,
  math.Random? rng,
}) {
  final r = rng ?? math.Random();
  final ultima = partida.ultimaDelPozo;
  final palo = partida.paloDeclarado;
  if (ultima == null || palo == null) return false;
  if (ultima.jugador == pc.nombre) return false;

  JugadorDesconfio? tirador;
  for (final j in partida.jugadores) {
    if (j.nombre == ultima.jugador) {
      tirador = j;
      break;
    }
  }
  if (tirador == null || tirador.rendido) return false;

  final nPalo = cartasPorPaloEnMazoDesconfio();
  final totalMazo = totalCartasMazoDesconfio();
  final mias = pc.mano.where((c) => c.palo == palo).length;
  final cartasPFuera = (nPalo - mias).clamp(0, nPalo);
  final manoAntes = tirador.cartasEnMano + 1; // acaba de tirar
  final maxPEnTirador = math.min(cartasPFuera, manoAntes);

  // Imposible que tenga del palo → siempre desconfiar.
  if (maxPEnTirador <= 0) return true;

  final cartasFuera = (totalMazo - pc.mano.length).clamp(1, totalMazo);
  final pozo = partida.pozo.length;
  final cartasRival = tirador.cartasEnMano; // ya sin la jugada

  // Cuántas del palo se esperan en la mano del rival (aprox. hipergeométrica).
  final esperadoEnRival =
      cartasPFuera * (manoAntes / cartasFuera).clamp(0.0, 1.0);

  // Prob. de que el rival no tenga ninguna del palo (entonces miente forzado).
  final pSinNinguna = _probCeroDelPalo(
    cartasFuera: cartasFuera,
    cartasPaloFuera: cartasPFuera,
    manoRival: manoAntes,
  );

  // Tasa de bluff si sí tiene del palo: baja al inicio, sube con el pozo.
  final tasaBluffSiTiene = switch (dificultad) {
    DificultadPc.facil => 0.12 + (pozo - 1).clamp(0, 8) * 0.02,
    DificultadPc.medio => 0.18 + (pozo - 1).clamp(0, 8) * 0.025,
    DificultadPc.dificil => 0.24 + (pozo - 1).clamp(0, 8) * 0.03,
  }.clamp(0.08, 0.55);

  // p(mentira) ≈ P(sin cartas del palo) + P(tiene) * bluff
  var pMentira =
      (pSinNinguna + (1.0 - pSinNinguna) * tasaBluffSiTiene).clamp(0.0, 1.0);

  // Si el rival debería tener varias del palo, bajar sospecha.
  if (esperadoEnRival >= 3) {
    pMentira *= 0.55;
  } else if (esperadoEnRival >= 2) {
    pMentira *= 0.72;
  } else if (esperadoEnRival >= 1.2) {
    pMentira *= 0.85;
  }

  // Primera carta del pozo: casi nunca desconfiar salvo certeza o rival a punto.
  if (pozo <= 1 && cartasRival > 3) {
    final pPrimera = switch (dificultad) {
      DificultadPc.facil => 0.02,
      DificultadPc.medio => 0.04,
      DificultadPc.dificil => 0.07,
    };
    // Solo si la sospecha es altísima y el azar lo permite.
    return pMentira >= 0.82 && r.nextDouble() < pPrimera;
  }

  // Segundas/terceras cartas: todavía prudente.
  if (pozo <= 3 && cartasRival > 4) {
    pMentira *= 0.75;
  }

  var umbral = switch (dificultad) {
    DificultadPc.facil => 0.78,
    DificultadPc.medio => 0.68,
    DificultadPc.dificil => 0.58,
  };

  // Pozo grande → más prudente (equivocarse duele).
  if (pozo >= 6) {
    umbral += switch (dificultad) {
      DificultadPc.facil => 0.12,
      DificultadPc.medio => 0.10,
      DificultadPc.dificil => 0.06,
    };
  } else if (pozo >= 4) {
    umbral += 0.05;
  }

  // Rival cerca de ganar → más agresivo.
  if (cartasRival <= 1) {
    umbral -= switch (dificultad) {
      DificultadPc.facil => 0.28,
      DificultadPc.medio => 0.22,
      DificultadPc.dificil => 0.18,
    };
  } else if (cartasRival <= 2) {
    umbral -= switch (dificultad) {
      DificultadPc.facil => 0.18,
      DificultadPc.medio => 0.14,
      DificultadPc.dificil => 0.12,
    };
  } else if (cartasRival <= 3) {
    umbral -= 0.08;
  }

  umbral = umbral.clamp(0.35, 0.92);

  if (pMentira >= umbral) {
    // Ruido: a veces duda aunque el score alcance.
    final ruido = switch (dificultad) {
      DificultadPc.facil => 0.35,
      DificultadPc.medio => 0.18,
      DificultadPc.dificil => 0.08,
    };
    if (r.nextDouble() < ruido) return false;
    return true;
  }

  // Sospecha random rara (personalidad), nunca en la 1.ª carta.
  if (pozo >= 3) {
    if (dificultad == DificultadPc.facil && r.nextDouble() < 0.04) {
      return true;
    }
    if (dificultad == DificultadPc.medio &&
        maxPEnTirador <= 2 &&
        r.nextDouble() < 0.08) {
      return true;
    }
  }

  return false;
}

/// P(el rival no tiene ninguna carta del palo) vía hipergeométrica.
double _probCeroDelPalo({
  required int cartasFuera,
  required int cartasPaloFuera,
  required int manoRival,
}) {
  if (manoRival <= 0 || cartasFuera <= 0) return 1;
  if (cartasPaloFuera <= 0) return 1;
  if (cartasFuera - cartasPaloFuera < manoRival) return 0; // debe tener ≥1
  if (manoRival > cartasFuera) return 0;

  // P(X=0) = C(N-K, n) / C(N, n)
  // = Π_{i=0}^{n-1} (N-K-i)/(N-i)
  var p = 1.0;
  final n = manoRival;
  final nSin = cartasFuera - cartasPaloFuera;
  for (var i = 0; i < n; i++) {
    p *= (nSin - i) / (cartasFuera - i);
    if (p <= 0) return 0;
  }
  return p.clamp(0.0, 1.0);
}

/// Elige un PC (no tirador) para desconfiar, o null si ninguno debe.
JugadorDesconfio? pcQueDesconfia({
  required PartidaDesconfio partida,
  required DificultadPc dificultad,
  math.Random? rng,
}) {
  final ultima = partida.ultimaDelPozo;
  if (ultima == null) return null;
  final candidatos = [
    for (final j in partida.jugadores)
      if (!j.rendido && esNombrePc(j.nombre) && j.nombre != ultima.jugador) j,
  ];
  if (candidatos.isEmpty) return null;

  for (final pc in candidatos) {
    if (pcDebeDesconfiar(
      partida: partida,
      pc: pc,
      dificultad: dificultad,
      rng: rng,
    )) {
      return pc;
    }
  }
  return null;
}
