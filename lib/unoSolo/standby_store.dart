import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/unoSolo/motor_uno_solo.dart';
import 'package:app_juegos_mesa/unoSolo/opciones_uno_solo.dart';

class PartidaUnoSoloResume {
  PartidaUnoSoloResume({
    required this.partida,
    required this.nombres,
    required this.ajustesIniciales,
    this.modoDios = false,
    this.opciones = const OpcionesUnoSolo(),
    List<MovimientoUnoSolo>? historial,
  }) : historial = historial ?? <MovimientoUnoSolo>[];

  final PartidaUnoSolo partida;
  final List<String> nombres;
  final AjustesEstado ajustesIniciales;
  final bool modoDios;
  final OpcionesUnoSolo opciones;
  final List<MovimientoUnoSolo> historial;
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
