import 'dart:async';

import 'package:app_juegos_mesa/escobaDel15/motor_escoba.dart';
import 'package:app_juegos_mesa/escobaDel15/opciones_escoba.dart';
import 'package:app_juegos_mesa/escobaDel15/standby_codec.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/persistencia/standby_almacen.dart';

/// Resume en memoria para partidas vs PC (se pierde al cerrar/reiniciar la app).
class PartidaEscobaResume {
  PartidaEscobaResume({
    required this.partida,
    required this.nombres,
    required this.ajustesIniciales,
    this.modoDios = false,
    this.opciones = const OpcionesEscoba(),
  });

  final PartidaEscoba partida;
  final List<String> nombres;
  final AjustesEstado ajustesIniciales;
  final bool modoDios;
  final OpcionesEscoba opciones;
}

class EscobaStandByStore {
  EscobaStandByStore._();

  static const _juegoId = MenuJuegoScreen.juegoIdEscobaDel15;

  static PartidaEscobaResume? _resume;

  static bool _omitirPersistencia(PartidaEscobaResume r) =>
      r.partida.terminada || r.partida.ganador != null;

  static void guardar(PartidaEscobaResume resume) {
    _resume = resume;
    if (_omitirPersistencia(resume)) return;
    unawaited(
      StandbyAlmacen.guardar(_juegoId, encodeEscobaStandby(resume)),
    );
  }

  static PartidaEscobaResume? peek() => _resume;

  /// Devuelve y consume el resume vs PC, si hay uno.
  static PartidaEscobaResume? consumir() {
    final r = _resume;
    if (r == null) return null;
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
    final resume = decodeEscobaStandby(raw);
    if (resume == null || _omitirPersistencia(resume)) {
      await StandbyAlmacen.borrar(_juegoId);
      return;
    }
    _resume = resume;
  }
}
