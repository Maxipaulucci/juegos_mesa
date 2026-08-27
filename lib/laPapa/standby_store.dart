import 'dart:async';
import 'dart:ui';

import 'package:app_juegos_mesa/laPapa/motor_la_papa.dart';
import 'package:app_juegos_mesa/laPapa/opciones_la_papa.dart';
import 'package:app_juegos_mesa/laPapa/standby_codec.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/menu/menu_juego_screen.dart';
import 'package:app_juegos_mesa/shared/persistencia/standby_almacen.dart';

/// Resume en memoria para “Jugar solo” (se pierde al cerrar/reiniciar la app).
class PartidaPapaResume {
  PartidaPapaResume({
    required this.partida,
    required this.nombres,
    required this.opciones,
    required this.ajustesIniciales,
    required this.grosor,
    this.boardSize,
    List<Offset>? trazoFallido,
  }) : trazoFallido = trazoFallido ?? [];

  final PartidaPapa partida;
  final List<String> nombres;
  final OpcionesPapa opciones;
  final AjustesEstado ajustesIniciales;
  final GrosorTrazoPapa grosor;
  final Size? boardSize;
  final List<Offset> trazoFallido;
}

class PapaStandByStore {
  PapaStandByStore._();

  static const _juegoId = MenuJuegoScreen.juegoIdLaPapa;

  static PartidaPapaResume? _resume;

  static bool _omitirPersistencia(PartidaPapaResume r) => r.partida.terminada;

  static void guardar(PartidaPapaResume resume) {
    _resume = resume;
    if (_omitirPersistencia(resume)) return;
    unawaited(
      StandbyAlmacen.guardar(_juegoId, encodePapaStandby(resume)),
    );
  }

  static PartidaPapaResume? peek() => _resume;

  /// Devuelve el resume y lo consume si las opciones coinciden.
  /// Si cambió “Modificar partida”, descarta y parte de cero.
  static PartidaPapaResume? consumirSiCoincide(OpcionesPapa opciones) {
    final r = _resume;
    if (r == null) return null;
    if (!_mismasOpciones(r.opciones, opciones)) {
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
    final resume = decodePapaStandby(raw);
    if (resume == null || _omitirPersistencia(resume)) {
      await StandbyAlmacen.borrar(_juegoId);
      return;
    }
    _resume = resume;
  }

  static bool _mismasOpciones(OpcionesPapa a, OpcionesPapa b) {
    return a.conVidas == b.conVidas &&
        a.puentes == b.puentes &&
        a.numerosAleatorios == b.numerosAleatorios &&
        a.cantidadNumeros == b.cantidadNumeros &&
        a.modoFantasma == b.modoFantasma &&
        a.mostrarCuadricula == b.mostrarCuadricula &&
        a.permitirTrazoSobreNumeros == b.permitirTrazoSobreNumeros &&
        a.mostrarLupa == b.mostrarLupa &&
        a.modificarGrosorTrazo == b.modificarGrosorTrazo &&
        a.excepcionGeneracionNumeros == b.excepcionGeneracionNumeros;
  }
}
