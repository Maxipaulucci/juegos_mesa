/// Guarda en memoria el último nombre y código escritos en los formularios
/// de Crear sala y Unirse a sala, para que persistan al volver al menú.
class SalaFormStore {
  SalaFormStore._();

  static String nombre = '';
  static String codigo = '';

  static void limpiarCodigo() => codigo = '';
}
