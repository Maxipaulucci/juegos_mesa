import 'package:app_juegos_mesa/chanchoVa/motor_chancho_va.dart';
import 'package:app_juegos_mesa/chanchoVa/opciones_chancho_va.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';

/// Resume en memoria para partidas vs PC.
class PartidaChanchoResume {
  PartidaChanchoResume({
    required this.partida,
    required this.nombres,
    this.ajustesIniciales = const AjustesEstado(),
    this.modoDios = false,
    this.opciones = const OpcionesChanchoVa(),
  });

  final PartidaChancho partida;
  final List<String> nombres;
  final AjustesEstado ajustesIniciales;
  final bool modoDios;
  final OpcionesChanchoVa opciones;
}

class ChanchoStandByStore {
  ChanchoStandByStore._();

  static PartidaChanchoResume? _resume;

  static void guardar(PartidaChanchoResume resume) {
    _resume = resume;
  }

  static PartidaChanchoResume? consumir() {
    final r = _resume;
    _resume = null;
    return r;
  }

  static void limpiar() {
    _resume = null;
  }
}
