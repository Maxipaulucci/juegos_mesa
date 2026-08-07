/// Constantes y dificultad compartidas para partidas vs PC.
library;

const String nombreJugadorPc = 'PC';

/// True para `"PC"`, `"PC 1"`, `"PC 2"`, …
bool esNombrePc(String nombre) =>
    nombre == nombreJugadorPc ||
    (nombre.startsWith('PC ') && nombre.length > 3);

/// Cuántos rivales PC hay en [nombres].
int cantidadPcEnNombres(List<String> nombres) =>
    nombres.where(esNombrePc).length;

/// True si la lista tiene exactamente [cantidadPc] rivales PC.
bool coincideCantidadPc(List<String> nombres, int cantidadPc) =>
    cantidadPcEnNombres(nombres) == cantidadPc;

/// Primer nombre humano de la mesa vs PC.
String humanoPrincipalVsPc(
  List<String> nombres, {
  String fallback = 'Jugador 1',
}) {
  for (final n in nombres) {
    if (!esNombrePc(n)) return n;
  }
  return fallback;
}

/// 1 humano + (total−1) PCs. Con 2 jugadores el rival se llama [nombreJugadorPc].
List<String> nombresPartidaVsPc({
  required String humano,
  required int total,
  int min = 2,
  int max = 4,
}) {
  final n = total.clamp(min, max);
  if (n <= 2) return [humano, nombreJugadorPc];
  return [
    humano,
    for (var i = 1; i < n; i++) 'PC $i',
  ];
}

/// Reescribe la mesa vs PC conservando el humano y [cantidadPc] rivales.
List<String> reconstruirNombresVsPc({
  required List<String> actuales,
  required int cantidadPc,
  int minTotal = 2,
  int maxTotal = 4,
  List<String> Function(String humano, int total)? armarNombres,
}) {
  final humano = humanoPrincipalVsPc(actuales);
  final total = (cantidadPc + 1).clamp(minTotal, maxTotal);
  if (armarNombres != null) return armarNombres(humano, total);
  return nombresPartidaVsPc(
    humano: humano,
    total: total,
    min: minTotal,
    max: maxTotal,
  );
}

final Map<String, int> _cantidadPcElegidaPorJuego = {};

/// Guarda la cantidad de PC elegida en el menú de un juego.
void registrarCantidadPcMenu(String juegoId, int cantidad) {
  _cantidadPcElegidaPorJuego[juegoId] = cantidad;
}

/// Última cantidad de PC elegida en el menú, si hay.
int? cantidadPcElegidaEnMenu(String juegoId) =>
    _cantidadPcElegidaPorJuego[juegoId];

/// Dificultades disponibles para jugar contra la PC.
enum DificultadPc {
  /// Temeraria: casi siempre sigue tirando. 20% de errores.
  facil('Fácil'),

  /// Equilibrada: razona el turno actual. 8% de errores.
  medio('Medio'),

  /// Calculadora: mira toda la partida. 2% de errores.
  dificil('Difícil');

  const DificultadPc(this.etiqueta);

  final String etiqueta;

  /// Porcentaje de decisiones malas (error humano).
  double get error => switch (this) {
        DificultadPc.facil => 0.20,
        DificultadPc.medio => 0.08,
        DificultadPc.dificil => 0.02,
      };
}
