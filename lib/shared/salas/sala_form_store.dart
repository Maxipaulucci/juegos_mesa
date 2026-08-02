/// Guarda en memoria el último nombre y código escritos en los formularios
/// de Crear sala y Unirse a sala, para que persistan al volver al menú.
class SalaFormStore {
  SalaFormStore._();

  static String nombre = '';
  static String codigo = '';
  /// Opciones de La Papa del anfitrión al iniciar la sala (mapa del codec).
  static Map<String, dynamic>? opcionesPapa;

  static void limpiarCodigo() => codigo = '';
}
