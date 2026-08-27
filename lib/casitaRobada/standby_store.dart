import 'dart:async';

import 'package:app_juegos_mesa/casitaRobada/motor_casita.dart';
import 'package:app_juegos_mesa/casitaRobada/standby_codec.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/persistencia/standby_almacen.dart';

/// Resume en memoria para vs PC (stand by).
class PartidaCasitaResume {
  PartidaCasitaResume({
    required this.partida,
    required this.nombres,
    required this.modoDios,
  });

  final PartidaCasita partida;
  final List<String> nombres;
  final bool modoDios;
}

abstract final class CasitaStandByStore {
  static const _juegoId = MenuJuegoScreen.juegoIdCasitaRobada;

  static PartidaCasitaResume? _resume;

  static bool _omitirPersistencia(PartidaCasitaResume r) =>
      r.partida.terminada || r.partida.ganador != null;

  static void guardar(PartidaCasitaResume resume) {
    _resume = resume;
    if (_omitirPersistencia(resume)) return;
    unawaited(
      StandbyAlmacen.guardar(_juegoId, encodeCasitaStandby(resume)),
    );
  }

  static PartidaCasitaResume? consumir() {
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
    final resume = decodeCasitaStandby(raw);
    if (resume == null || _omitirPersistencia(resume)) {
      await StandbyAlmacen.borrar(_juegoId);
      return;
    }
    _resume = resume;
  }
}
