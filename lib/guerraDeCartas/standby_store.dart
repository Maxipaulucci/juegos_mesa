import 'package:app_juegos_mesa/guerraDeCartas/motor_guerra.dart';

class PartidaGuerraResume {
  PartidaGuerraResume({
    required this.partida,
    required this.nombres,
    required this.modoDios,
  });

  final PartidaGuerra partida;
  final List<String> nombres;
  final bool modoDios;
}

abstract final class GuerraStandByStore {
  static PartidaGuerraResume? _resume;

  static void guardar(PartidaGuerraResume resume) => _resume = resume;

  static PartidaGuerraResume? consumir() {
    final r = _resume;
    _resume = null;
    return r;
  }

  static void limpiar() => _resume = null;
}
