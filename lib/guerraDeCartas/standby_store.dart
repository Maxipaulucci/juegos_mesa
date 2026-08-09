import 'package:app_juegos_mesa/guerraDeCartas/motor_guerra.dart';
import 'package:app_juegos_mesa/guerraDeCartas/opciones_guerra.dart';

class PartidaGuerraResume {
  PartidaGuerraResume({
    required this.partida,
    required this.nombres,
    required this.modoDios,
    OpcionesGuerra? opciones,
  }) : opciones = opciones ?? partida.opciones;

  final PartidaGuerra partida;
  final List<String> nombres;
  final bool modoDios;
  final OpcionesGuerra opciones;
}

abstract final class GuerraStandByStore {
  static PartidaGuerraResume? _resume;

  static void guardar(PartidaGuerraResume resume) => _resume = resume;

  static PartidaGuerraResume? peek() => _resume;

  /// Si cambió “Modificar partida”, descarta y parte de cero.
  static PartidaGuerraResume? consumirSiCoincide(OpcionesGuerra opciones) {
    final r = _resume;
    if (r == null) return null;
    if (r.opciones != opciones) {
      _resume = null;
      return null;
    }
    _resume = null;
    return r;
  }

  static PartidaGuerraResume? consumir() {
    final r = _resume;
    _resume = null;
    return r;
  }

  static void limpiar() => _resume = null;
}
