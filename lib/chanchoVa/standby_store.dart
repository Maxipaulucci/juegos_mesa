import 'dart:async';

import 'package:app_juegos_mesa/chanchoVa/motor_chancho_va.dart';
import 'package:app_juegos_mesa/chanchoVa/opciones_chancho_va.dart';
import 'package:app_juegos_mesa/chanchoVa/standby_codec.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/persistencia/standby_almacen.dart';

/// Resume en memoria para partidas vs PC.
class PartidaChanchoResume {
  PartidaChanchoResume({
    required this.partida,
    required this.nombres,
    this.ajustesIniciales = const AjustesEstado(),
    this.modoDios = false,
    this.opciones = const OpcionesChanchoVa(),
  });

  final PartidaChancho partida;
  final List<String> nombres;
  final AjustesEstado ajustesIniciales;
  final bool modoDios;
  final OpcionesChanchoVa opciones;
}

class ChanchoStandByStore {
  ChanchoStandByStore._();

  static const _juegoId = MenuJuegoScreen.juegoIdChanchoVa;

  static PartidaChanchoResume? _resume;

  static bool _omitirPersistencia(PartidaChanchoResume r) =>
      r.partida.terminada ||
      r.partida.ganador != null ||
      r.partida.perdedor != null;

  static void guardar(PartidaChanchoResume resume) {
    _resume = resume;
    if (_omitirPersistencia(resume)) return;
    unawaited(
      StandbyAlmacen.guardar(_juegoId, encodeChanchoStandby(resume)),
    );
  }

  static PartidaChanchoResume? consumir() {
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
    final resume = decodeChanchoStandby(raw);
    if (resume == null || _omitirPersistencia(resume)) {
      await StandbyAlmacen.borrar(_juegoId);
      return;
    }
    _resume = resume;
  }
}
