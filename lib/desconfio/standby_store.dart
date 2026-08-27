import 'dart:async';

import 'package:app_juegos_mesa/desconfio/motor_desconfio.dart';
import 'package:app_juegos_mesa/desconfio/standby_codec.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/persistencia/standby_almacen.dart';

class PartidaDesconfioResume {
  PartidaDesconfioResume({
    required this.partida,
    required this.nombres,
    required this.modoDios,
  });

  final PartidaDesconfio partida;
  final List<String> nombres;
  final bool modoDios;
}

abstract final class DesconfioStandByStore {
  static const _juegoId = MenuJuegoScreen.juegoIdDesconfio;

  static PartidaDesconfioResume? _resume;

  static bool _omitirPersistencia(PartidaDesconfioResume r) =>
      r.partida.terminada || r.partida.ganador != null;

  static void guardar(PartidaDesconfioResume resume) {
    _resume = resume;
    if (_omitirPersistencia(resume)) return;
    unawaited(
      StandbyAlmacen.guardar(_juegoId, encodeDesconfioStandby(resume)),
    );
  }

  static PartidaDesconfioResume? peek() => _resume;

  static PartidaDesconfioResume? consumir() {
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
    final resume = decodeDesconfioStandby(raw);
    if (resume == null || _omitirPersistencia(resume)) {
      await StandbyAlmacen.borrar(_juegoId);
      return;
    }
    _resume = resume;
  }
}
