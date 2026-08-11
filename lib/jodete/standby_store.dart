import 'package:app_juegos_mesa/jodete/motor_jodete.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';

class PartidaJodeteResume {
  PartidaJodeteResume({
    required this.partida,
    required this.nombres,
    required this.modoDios,
    required this.dificultad,
    this.ajustesIniciales,
  });

  final PartidaJodete partida;
  final List<String> nombres;
  final bool modoDios;
  final DificultadPc dificultad;
  final AjustesEstado? ajustesIniciales;
}

abstract final class JodeteStandByStore {
  static PartidaJodeteResume? _resume;

  static void guardar(PartidaJodeteResume resume) => _resume = resume;

  static PartidaJodeteResume? peek() => _resume;

  static PartidaJodeteResume? consumir() {
    final r = _resume;
    _resume = null;
    return r;
  }

  static void limpiar() => _resume = null;
}
