import 'package:app_juegos_mesa/diezMil/ajustes_overlay.dart';
import 'package:app_juegos_mesa/diezMil/ia_diez_mil.dart';
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

  /// Devuelve el resume y lo consume si la dificultad coincide.
  /// Si cambió, lo descarta y parte de cero.
  static PartidaGeneralaResume? consumirSiCoincide(DificultadPc dificultad) {
    final r = _resume;
    if (r == null) return null;
    if (!r.contraPc) return null;
    if (r.dificultadPc != dificultad) {
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
