import 'package:app_juegos_mesa/culoSucio/motor_culo_sucio.dart';
import 'package:app_juegos_mesa/culoSucio/opciones_culo_sucio.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';

/// Resume en memoria para partidas vs PC (se pierde al cerrar/reiniciar la app).
class PartidaCuloSucioResume {
  PartidaCuloSucioResume({
    required this.partida,
    required this.nombres,
    required this.opciones,
    this.modoDios = false,
  });

  final PartidaCuloSucio partida;
  final List<String> nombres;
  final OpcionesCuloSucio opciones;
  final bool modoDios;
}

class CuloSucioStandByStore {
  CuloSucioStandByStore._();

  static PartidaCuloSucioResume? _resume;

  static void guardar(PartidaCuloSucioResume resume) {
    _resume = resume;
  }

  static PartidaCuloSucioResume? peek() => _resume;

  /// Devuelve y consume el resume vs PC si opciones y cantidad de PC coinciden.
  static PartidaCuloSucioResume? consumirSiCoincide(
    OpcionesCuloSucio opciones, {
    int? cantidadPc,
  }) {
    final r = _resume;
    if (r == null) return null;
    if (r.opciones.comodines != opciones.comodines) {
      _resume = null;
      return null;
    }
    if (cantidadPc != null && !coincideCantidadPc(r.nombres, cantidadPc)) {
      _resume = null;
      return null;
    }
    _resume = null;
    return r;
  }

  static void limpiar() {
    _resume = null;
  }
}
