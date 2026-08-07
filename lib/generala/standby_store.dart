import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'package:app_juegos_mesa/generala/motor_generala.dart';

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

  static PartidaGeneralaResume? _resume;

  static void guardar(PartidaGeneralaResume resume) {
    _resume = resume;
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
  }
}
