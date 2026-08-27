import 'dart:async';

import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/persistencia/standby_almacen.dart';
import 'package:app_juegos_mesa/unoSolo/motor_uno_solo.dart';
import 'package:app_juegos_mesa/unoSolo/opciones_uno_solo.dart';
import 'package:app_juegos_mesa/unoSolo/standby_codec.dart';

class PartidaUnoSoloResume {
  PartidaUnoSoloResume({
    required this.partida,
    required this.nombres,
    required this.ajustesIniciales,
    this.modoDios = false,
    this.opciones = const OpcionesUnoSolo(),
    List<MovimientoUnoSolo>? historial,
  }) : historial = historial ?? <MovimientoUnoSolo>[];

  final PartidaUnoSolo partida;
  final List<String> nombres;
  final AjustesEstado ajustesIniciales;
  final bool modoDios;
  final OpcionesUnoSolo opciones;
  final List<MovimientoUnoSolo> historial;
}

class UnoSoloStandByStore {
  UnoSoloStandByStore._();

  static const _juegoId = MenuJuegoScreen.juegoIdUnoSolo;

  static PartidaUnoSoloResume? _resume;

  static bool _omitirPersistencia(PartidaUnoSoloResume r) =>
      r.partida.terminada || r.partida.ganador != null;

  static void guardar(PartidaUnoSoloResume resume) {
    _resume = resume;
    if (_omitirPersistencia(resume)) return;
    unawaited(
      StandbyAlmacen.guardar(_juegoId, encodeUnoSoloStandby(resume)),
    );
  }

  static PartidaUnoSoloResume? peek() => _resume;

  static PartidaUnoSoloResume? consumir() {
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
    final resume = decodeUnoSoloStandby(raw);
    if (resume == null || _omitirPersistencia(resume)) {
      await StandbyAlmacen.borrar(_juegoId);
      return;
    }
    _resume = resume;
  }
}
