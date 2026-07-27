import 'ajustes_overlay.dart';
import 'estadisticas.dart';
import 'ia_diez_mil.dart';
import 'motor.dart';

/// Resume en memoria para "stand by" sin persistencia (se pierde si se cierra
/// o se reinicia la app).
class PartidaDiezMilResume {
  PartidaDiezMilResume({
    required this.partida,
    required this.estadisticas,
    required this.nombres,
    required this.modo,
    required this.contraPc,
    required this.dificultadPc,
    required this.modoDios,
    required this.ajustesIniciales,
    required this.ultimaTirada,
    required this.ultimoResumen,
    required this.mensaje,
    required this.mejorTiradaPartida,
    required this.mejorTiradaJugador,
    required this.ultimoTurnoHumano,
  });

  final Partida partida;
  final EstadisticasPartida estadisticas;
  final List<String> nombres;
  final Modo modo;
  final bool contraPc;
  final DificultadPc dificultadPc;
  final bool modoDios;
  final AjustesEstado ajustesIniciales;
  final ResultadoTirada? ultimaTirada;
  final ResumenTirada? ultimoResumen;
  final String? mensaje;
  final int mejorTiradaPartida;
  final String? mejorTiradaJugador;
  final int ultimoTurnoHumano;
}

class DiezMilStandByStore {
  DiezMilStandByStore._();

  static PartidaDiezMilResume? _resume;

  static void guardar(PartidaDiezMilResume resume) {
    _resume = resume;
  }

  static PartidaDiezMilResume? peek() => _resume;

  /// Devuelve el resume y lo consume solo si el modo Y la dificultad coinciden.
  /// Si cambiaron, descarta el resume y retorna null (parte de cero).
  static PartidaDiezMilResume? consumirSiCoincide(
    Modo modo,
    DificultadPc dificultad,
  ) {
    final r = _resume;
    if (r == null) return null;
    if (!r.contraPc) return null;
    if (r.modo != modo || r.dificultadPc != dificultad) {
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

