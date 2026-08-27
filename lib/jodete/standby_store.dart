import 'dart:async';

import 'package:app_juegos_mesa/jodete/motor_jodete.dart';
import 'package:app_juegos_mesa/jodete/opciones_jodete.dart';
import 'package:app_juegos_mesa/jodete/standby_codec.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/persistencia/standby_almacen.dart';

class PartidaJodeteResume {
  PartidaJodeteResume({
    required this.partida,
    required this.nombres,
    required this.modoDios,
    required this.dificultad,
    required this.opciones,
    this.ajustesIniciales,
  });

  final PartidaJodete partida;
  final List<String> nombres;
  final bool modoDios;
  final DificultadPc dificultad;
  final OpcionesJodete opciones;
  final AjustesEstado? ajustesIniciales;
}

abstract final class JodeteStandByStore {
  static const _juegoId = MenuJuegoScreen.juegoIdJodete;

  static PartidaJodeteResume? _resume;

  static bool _omitirPersistencia(PartidaJodeteResume r) =>
      r.partida.terminada || r.partida.ganador != null;

  static void guardar(PartidaJodeteResume resume) {
    _resume = resume;
    if (_omitirPersistencia(resume)) return;
    unawaited(
      StandbyAlmacen.guardar(_juegoId, encodeJodeteStandby(resume)),
    );
  }

  static PartidaJodeteResume? peek() => _resume;

  static PartidaJodeteResume? consumir() {
    final r = _resume;
    _resume = null;
    return r;
  }

  static void limpiar() {
    _resume = null;
    unawaited(StandbyAlmacen.borrar(_juegoId));
  }

  static Future<void> restaurarDesdeDisco() async {
    final raw = await StandbyAlmacen.leer(_juegoId);
    if (raw == null) return;
    final resume = decodeJodeteStandby(raw);
    if (resume == null || _omitirPersistencia(resume)) {
      await StandbyAlmacen.borrar(_juegoId);
      return;
    }
    _resume = resume;
  }
}
