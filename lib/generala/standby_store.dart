import 'dart:async';

import 'package:app_juegos_mesa/generala/motor_generala.dart';
import 'package:app_juegos_mesa/generala/standby_codec.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/persistencia/standby_almacen.dart';

/// Resume en memoria para partidas vs PC (se pierde al cerrar/reiniciar la app).
class PartidaGeneralaResume {
  PartidaGeneralaResume({
    required this.partida,
    required this.nombres,
    required this.contraPc,
    required this.dificultadPc,
    required this.modoDios,
    required this.ajustesIniciales,
  });

  final PartidaGenerala partida;
  final List<String> nombres;
  final bool contraPc;
  final DificultadPc dificultadPc;
  final bool modoDios;
  final AjustesEstado ajustesIniciales;
}

class GeneralaStandByStore {
  GeneralaStandByStore._();

  static const _juegoId = MenuJuegoScreen.juegoIdGenerala;

  static PartidaGeneralaResume? _resume;

  static bool _omitirPersistencia(PartidaGeneralaResume r) =>
      !r.contraPc || r.partida.ganador != null;

  static void guardar(PartidaGeneralaResume resume) {
    _resume = resume;
    if (_omitirPersistencia(resume)) return;
    unawaited(
      StandbyAlmacen.guardar(_juegoId, encodeGeneralaStandby(resume)),
    );
  }

  static PartidaGeneralaResume? peek() => _resume;

  /// Devuelve el resume y lo consume si dificultad y cantidad de PC coinciden.
  /// Si cambió algo, lo descarta y parte de cero.
  static PartidaGeneralaResume? consumirSiCoincide(
    DificultadPc dificultad, {
    int? cantidadPc,
  }) {
    final r = _resume;
    if (r == null) return null;
    if (!r.contraPc) return null;
    if (r.dificultadPc != dificultad) {
      _resume = null;
      return null;
    }
    if (cantidadPc != null && !coincideCantidadPc(r.nombres, cantidadPc)) {
      _resume = null;
      return null;
    }
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
    final resume = decodeGeneralaStandby(raw);
    if (resume == null || _omitirPersistencia(resume)) {
      await StandbyAlmacen.borrar(_juegoId);
      return;
    }
    _resume = resume;
  }
}
