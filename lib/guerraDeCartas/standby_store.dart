import 'dart:async';

import 'package:app_juegos_mesa/guerraDeCartas/motor_guerra.dart';
import 'package:app_juegos_mesa/guerraDeCartas/opciones_guerra.dart';
import 'package:app_juegos_mesa/guerraDeCartas/standby_codec.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/persistencia/standby_almacen.dart';

class PartidaGuerraResume {
  PartidaGuerraResume({
    required this.partida,
    required this.nombres,
    required this.modoDios,
    OpcionesGuerra? opciones,
  }) : opciones = opciones ?? partida.opciones;

  final PartidaGuerra partida;
  final List<String> nombres;
  final bool modoDios;
  final OpcionesGuerra opciones;
}

abstract final class GuerraStandByStore {
  static const _juegoId = MenuJuegoScreen.juegoIdGuerraDeCartas;

  static PartidaGuerraResume? _resume;

  static bool _omitirPersistencia(PartidaGuerraResume r) =>
      r.partida.terminada || r.partida.ganador != null;

  static void guardar(PartidaGuerraResume resume) {
    _resume = resume;
    if (_omitirPersistencia(resume)) return;
    unawaited(
      StandbyAlmacen.guardar(_juegoId, encodeGuerraStandby(resume)),
    );
  }

  static PartidaGuerraResume? peek() => _resume;

  /// Si cambió “Modificar partida”, descarta y parte de cero.
  static PartidaGuerraResume? consumirSiCoincide(OpcionesGuerra opciones) {
    final r = _resume;
    if (r == null) return null;
    if (r.opciones != opciones) {
      _resume = null;
      return null;
    }
    _resume = null;
    return r;
  }

  static PartidaGuerraResume? consumir() {
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
    final resume = decodeGuerraStandby(raw);
    if (resume == null || _omitirPersistencia(resume)) {
      await StandbyAlmacen.borrar(_juegoId);
      return;
    }
    _resume = resume;
  }
}
