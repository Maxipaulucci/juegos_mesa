/// Decisiones simples para el rival controlado por la PC.
library;

import 'motor.dart';

const String nombreJugadorPc = 'PC';

/// Acepta el especial si da igual o más puntos que los combos normales.
bool iaAceptaEspecial(ResultadoTirada resultado) {
  if (resultado.combosOpcionales.isEmpty) return false;
  final auto = puntosDeCombos(resultado.combosAuto);
  final especial = resultado.combosOpcionales.first.puntos;
  return especial >= auto;
}

/// Decide si plantarse o seguir tirando después de una tirada con puntos.
bool iaDebePlantarse(Partida partida) {
  if (!puedePlantarse(partida)) return false;

  final j = partida.jugadorActual;
  final t = partida.turno;
  final pts = t.puntosTurno;
  final totalSiBanca = j.puntos + pts;

  // Exacto a 10.000 → plantarse.
  if (totalSiBanca == meta) return true;
  // Pasarse anula el turno: no plantarse.
  if (totalSiBanca > meta) return false;

  // Todavía no abrió: bancar apenas llega a la apertura.
  if (!j.abierto) return pts >= apertura;

  final faltan = meta - j.puntos;
  if (pts >= faltan) return true;

  // Riesgo según dados en mano.
  if (t.dadosEnMano <= 2) return pts >= 250;
  if (t.dadosEnMano <= 3) return pts >= 450;
  if (pts >= 800) return true;
  if (pts >= 550 && t.dadosEnMano <= 4) return true;

  return false;
}
