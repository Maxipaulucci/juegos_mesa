/// Guarda en memoria el último nombre y código escritos en los formularios
/// de Crear sala y Unirse a sala, para que persistan al volver al menú.
class SalaFormStore {
  SalaFormStore._();

  static String nombre = '';
  static String codigo = '';
  /// Opciones de La Papa del anfitrión al iniciar la sala (mapa del codec).
  static Map<String, dynamic>? opcionesPapa;
  /// Chancho va: opciones serializadas del anfitrión.
  static Map<String, dynamic>? opcionesChancho;
  /// Total de asientos online (2 humanos + 1–2 PCs → 3 o 4).
  static int totalJugadoresChancho = 3;

  static void limpiarCodigo() => codigo = '';
}
