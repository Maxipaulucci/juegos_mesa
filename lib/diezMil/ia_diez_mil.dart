/// Decisiones del rival controlado por la PC, según dificultad.
library;

import 'dart:math';

import 'motor.dart';

const String nombreJugadorPc = 'PC';

final _rng = Random();

/// Dificultades disponibles para jugar contra la PC.
enum DificultadPc {
  /// 🎲 Temeraria: casi siempre sigue tirando. 20% de errores.
  facil('Fácil'),

  /// ⚖ Equilibrada: razona el turno actual. 8% de errores.
  medio('Medio'),

  /// 🧠 Calculadora: mira toda la partida y estima probabilidades.
  /// 2% de errores.
  dificil('Difícil');

  const DificultadPc(this.etiqueta);

  final String etiqueta;

  /// Porcentaje de decisiones malas (error humano).
  double get error => switch (this) {
        DificultadPc.facil => 0.20,
        DificultadPc.medio => 0.08,
        DificultadPc.dificil => 0.02,
      };
}

/// Probabilidad aproximada de que una tirada de [n] dados sume algo.
double probabilidadDeSumar(int n) => switch (n) {
      <= 1 => 0.33,
      2 => 0.56,
      3 => 0.72,
      4 => 0.80,
      5 => 0.88,
      _ => 0.93,
    };

/// Decide si plantarse (true) o seguir tirando (false) tras sumar puntos.
///
/// [ultimoTurnoRival] son los puntos que bancó el rival en su último turno,
/// para que la IA difícil reaccione a tiradas enormes.
bool iaDebePlantarse(
  Partida partida, {
  DificultadPc dificultad = DificultadPc.medio,
  int ultimoTurnoRival = 0,
  Random? rng,
}) {
  if (!puedePlantarse(partida)) return false;

  final r = rng ?? _rng;
  final j = partida.jugadorActual;
  final t = partida.turno;
  final pts = t.puntosTurno;
  final total = j.puntos + pts;

  // Decisiones obvias: acá ninguna IA se equivoca.
  if (total == meta) return true; // cierra la partida
  if (total > meta) return false; // pasarse anula el turno

  var decision = switch (dificultad) {
    DificultadPc.facil => _decisionFacil(j, pts, r),
    DificultadPc.medio => _decisionMedia(j, t, pts),
    DificultadPc.dificil =>
      _decisionDificil(partida, j, t, pts, ultimoTurnoRival),
  };

  // Error humano: a veces toma la decisión contraria.
  if (r.nextDouble() < dificultad.error) decision = !decision;
  return decision;
}

/// 🎲 Temeraria: se emociona y sigue aunque le quede 1 dado.
bool _decisionFacil(Jugador j, int pts, Random r) {
  // Recién llega a la apertura: igual suele seguir buscando puntos.
  if (!j.abierto) return r.nextDouble() < 0.35;
  // Solo un botín muy grande la convence de frenar.
  if (pts >= 1500) return true;
  return r.nextDouble() < 0.15;
}

/// ⚖ Equilibrada: razona el turno actual como una persona promedio.
bool _decisionMedia(Jugador j, EstadoTurno t, int pts) {
  // Llegó a la apertura: la asegura.
  if (!j.abierto) return true;

  if (t.dadosEnMano == 1) {
    if (pts < 400) return false;
    if (pts > 600) return true;
    return pts >= 500;
  }
  if (t.dadosEnMano == 2) return pts >= 300;
  if (t.dadosEnMano == 3) return pts >= 450;
  return pts >= 800;
}

/// 🧠 Calculadora: mira el marcador completo y estima probabilidades.
bool _decisionDificil(
  Partida partida,
  Jugador j,
  EstadoTurno t,
  int pts,
  int ultimoTurnoRival,
) {
  final rivales =
      partida.jugadores.where((x) => !identical(x, j)).toList();
  final mejorRival =
      rivales.fold(0, (acc, x) => x.puntos > acc ? x.puntos : acc);
  final algunRivalAbierto = rivales.any((x) => x.abierto);
  final ventaja = j.puntos - mejorRival;
  final faltan = meta - j.puntos;

  // Para abrir: asegura la apertura salvo que vaya perdiendo por mucho.
  if (!j.abierto) {
    if (ventaja <= -2000) return pts >= 1000;
    return true;
  }

  // Cerca de ganar: prioriza cerrar la partida sin regalar el turno.
  if (faltan <= 800) return pts >= 300;

  // El rival todavía no abrió: no necesita arriesgar.
  if (!algunRivalAbierto) return pts >= 350;

  // Va perdiendo por mucho: plantarse ahora es perder igual.
  if (ventaja <= -2000) return pts >= 1200;

  // Va ganando por mucho: no hace falta ninguna locura.
  if (ventaja >= 2000) return pts >= 500;

  // El rival viene de un turno enorme: el partido cambió, arriesga más.
  if (ultimoTurnoRival >= 1500) return pts >= 900;

  // Con 1 dado (~33% de sumar) asegura turnos sólidos, sobre todo si va ganando.
  if (t.dadosEnMano == 1) {
    if (pts >= 300) return true;
    if (pts >= 200 && ventaja > 0) return true;
    return false;
  }

  // Caso general: compara lo que arriesga contra la chance de sumar.
  // Ej.: 2 dados (56% de sumar) con 800 pts → riesgo 352 → se planta.
  final riesgo = pts * (1 - probabilidadDeSumar(t.dadosEnMano));
  return riesgo >= 220;
}
