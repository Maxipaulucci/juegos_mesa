/// Guarda datos para crear/unirse a salas online.
class SalaFormStore {
  SalaFormStore._();

  static String codigo = '';
  /// Resumen legible de “Modificar partida” (se envía al crear la sala).
  static List<String> lobbyOpcionesResumen = const [];
  /// Opciones de La Papa del anfitrión al iniciar la sala (mapa del codec).
  static Map<String, dynamic>? opcionesPapa;
  /// Chancho va: opciones serializadas del anfitrión.
  static Map<String, dynamic>? opcionesChancho;
  /// Total de asientos online (2 humanos + 1–2 PCs → 3 o 4).
  static int totalJugadoresChancho = 3;

  static void limpiarCodigo() => codigo = '';

  static void setResumenOpciones(List<String> resumen) {
    lobbyOpcionesResumen = List.unmodifiable(resumen);
  }

  static void limpiarResumenOpciones() {
    lobbyOpcionesResumen = const [];
  }
}
