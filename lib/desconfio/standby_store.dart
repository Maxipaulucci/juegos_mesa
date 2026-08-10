import 'package:app_juegos_mesa/desconfio/motor_desconfio.dart';

class PartidaDesconfioResume {
  PartidaDesconfioResume({
    required this.partida,
    required this.nombres,
    required this.modoDios,
  });

  final PartidaDesconfio partida;
  final List<String> nombres;
  final bool modoDios;
}

abstract final class DesconfioStandByStore {
  static PartidaDesconfioResume? _resume;

  static void guardar(PartidaDesconfioResume resume) => _resume = resume;

  static PartidaDesconfioResume? peek() => _resume;

  static PartidaDesconfioResume? consumir() {
    final r = _resume;
    _resume = null;
    return r;
  }

  static void limpiar() => _resume = null;
}
