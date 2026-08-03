import 'dart:ui';

import 'package:app_juegos_mesa/laPapa/motor_la_papa.dart';
import 'package:app_juegos_mesa/laPapa/opciones_la_papa.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';

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

  static PartidaPapaResume? _resume;

  static void guardar(PartidaPapaResume resume) {
    _resume = resume;
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
  }

  static bool _mismasOpciones(OpcionesPapa a, OpcionesPapa b) {
    return a.conVidas == b.conVidas &&
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
