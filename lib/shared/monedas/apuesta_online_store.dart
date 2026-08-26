/// Montos de apuesta permitidos en salas online.
const montosApuestaOnline = <int>[0, 5, 10, 25, 50, 100, 250, 500, 1000];

/// Contexto de apuesta de la sala online actual (para resolver al ganar).
class ApuestaOnlineStore {
  ApuestaOnlineStore._();

  static String? codigoSala;
  static String? juegoId;
  static int apuestaMonedas = 0;

  static void configurar({
    required String codigo,
    required String juego,
    required int apuesta,
  }) {
    codigoSala = codigo.trim().toUpperCase();
    juegoId = juego;
    apuestaMonedas = apuesta;
  }

  static void limpiar() {
    codigoSala = null;
    juegoId = null;
    apuestaMonedas = 0;
  }
}
