import 'dart:async';

import 'package:app_juegos_mesa/culoSucioV2/motor_culo_sucio_v2.dart';
import 'package:app_juegos_mesa/culoSucioV2/opciones_culo_sucio_v2.dart';
import 'package:app_juegos_mesa/culoSucioV2/standby_codec.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/persistencia/standby_almacen.dart';

/// Resume en memoria para partidas vs PC (se pierde al reiniciar la app).
class PartidaCuloSucioV2Resume {
  PartidaCuloSucioV2Resume({
    required this.partida,
    required this.nombres,
    this.modoDios = false,
    this.opciones = const OpcionesCuloSucioV2(),
    this.ajustesIniciales = const AjustesEstado(),
  });

  final PartidaCuloSucioV2 partida;
  final List<String> nombres;
  final bool modoDios;
  final OpcionesCuloSucioV2 opciones;
  final AjustesEstado ajustesIniciales;
}

class CuloSucioV2StandByStore {
  CuloSucioV2StandByStore._();

  static const _juegoId = MenuJuegoScreen.juegoIdCuloSucioV2;

  static PartidaCuloSucioV2Resume? _resume;

  static bool _omitirPersistencia(PartidaCuloSucioV2Resume r) =>
      r.partida.terminada ||
      r.partida.ganador != null ||
      r.partida.perdedor != null;

  static void guardar(PartidaCuloSucioV2Resume resume) {
    _resume = resume;
    if (_omitirPersistencia(resume)) return;
    unawaited(
      StandbyAlmacen.guardar(_juegoId, encodeCuloSucioV2Standby(resume)),
    );
  }

  static PartidaCuloSucioV2Resume? consumir() {
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
    final resume = decodeCuloSucioV2Standby(raw);
    if (resume == null || _omitirPersistencia(resume)) {
      await StandbyAlmacen.borrar(_juegoId);
      return;
    }
    _resume = resume;
  }
}
