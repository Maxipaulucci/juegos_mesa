import 'package:app_juegos_mesa/casitaRobada/motor_casita.dart';

/// Resume en memoria para vs PC (stand by).
class PartidaCasitaResume {
  PartidaCasitaResume({
    required this.partida,
    required this.nombres,
    required this.modoDios,
  });

  final PartidaCasita partida;
  final List<String> nombres;
  final bool modoDios;
}

abstract final class CasitaStandByStore {
  static PartidaCasitaResume? _resume;

  static void guardar(PartidaCasitaResume resume) => _resume = resume;

  static PartidaCasitaResume? consumir() {
    final r = _resume;
    _resume = null;
    return r;
  }

  static void limpiar() => _resume = null;
}
