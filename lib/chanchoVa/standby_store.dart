import 'package:app_juegos_mesa/chanchoVa/motor_chancho_va.dart';

/// Resume en memoria para partidas vs PC.
class PartidaChanchoResume {
  PartidaChanchoResume({
    required this.partida,
    required this.nombres,
    this.modoDios = false,
  });

  final PartidaChancho partida;
  final List<String> nombres;
  final bool modoDios;
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
