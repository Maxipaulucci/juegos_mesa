/// Formato común para el resumen de opciones online.
String lineaOpcionOnline(String titulo, bool activo) =>
    '$titulo: ${activo ? 'activado' : 'desactivado'}';
