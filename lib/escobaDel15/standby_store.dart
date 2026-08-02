import 'package:app_juegos_mesa/escobaDel15/motor_escoba.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';

/// Resume en memoria para partidas vs PC (se pierde al cerrar/reiniciar la app).
class PartidaEscobaResume {
  PartidaEscobaResume({
    required this.partida,
    required this.nombres,
    required this.ajustesIniciales,
    this.modoDios = false,
  });

  final PartidaEscoba partida;
  final List<String> nombres;
  final AjustesEstado ajustesIniciales;
  final bool modoDios;
}

class EscobaStandByStore {
  EscobaStandByStore._();

  static PartidaEscobaResume? _resume;

  static void guardar(PartidaEscobaResume resume) {
    _resume = resume;
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
  }
}
