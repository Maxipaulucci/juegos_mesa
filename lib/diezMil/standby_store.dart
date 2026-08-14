import 'ajustes_overlay.dart';
import 'estadisticas.dart';
import 'ia_diez_mil.dart';
import 'motor.dart';
import 'opciones_diez_mil.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';

/// Resume en memoria para "stand by" sin persistencia (se pierde si se cierra
/// o se reinicia la app).
class PartidaDiezMilResume {
  PartidaDiezMilResume({
    required this.partida,
    required this.estadisticas,
    required this.nombres,
    required this.modo,
    this.opciones = const OpcionesDiezMil(),
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
  final OpcionesDiezMil opciones;
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

  /// Reanuda la partida vs PC guardada.
  ///
  /// No exige que coincidan dificultad ni opciones del menú: esos cambios
  /// solo aplican al reiniciar. Si cambia la cantidad de PCs, no reanuda
  /// (pero conserva el resume por si vuelve a la cantidad anterior).
  static PartidaDiezMilResume? consumirVsPc({int? cantidadPc}) {
    final r = _resume;
    if (r == null || !r.contraPc) return null;
    if (cantidadPc != null && !coincideCantidadPc(r.nombres, cantidadPc)) {
      return null;
    }
    _resume = null;
    return r;
  }

  static void limpiar() {
    _resume = null;
  }
}
