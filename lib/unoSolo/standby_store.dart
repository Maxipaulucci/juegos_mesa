import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/unoSolo/motor_uno_solo.dart';

class PartidaUnoSoloResume {
  PartidaUnoSoloResume({
    required this.partida,
    required this.nombres,
    required this.ajustesIniciales,
  });

  final PartidaUnoSolo partida;
  final List<String> nombres;
  final AjustesEstado ajustesIniciales;
}

class UnoSoloStandByStore {
  UnoSoloStandByStore._();

  static PartidaUnoSoloResume? _resume;

  static void guardar(PartidaUnoSoloResume resume) {
    _resume = resume;
  }

  static PartidaUnoSoloResume? peek() => _resume;

  static PartidaUnoSoloResume? consumir() {
    final r = _resume;
    _resume = null;
    return r;
  }

  static void limpiar() {
    _resume = null;
  }
}
