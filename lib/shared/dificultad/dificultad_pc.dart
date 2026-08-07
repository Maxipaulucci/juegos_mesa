/// Constantes y dificultad compartidas para partidas vs PC.
library;

const String nombreJugadorPc = 'PC';

/// True para `"PC"`, `"PC 1"`, `"PC 2"`, …
bool esNombrePc(String nombre) =>
    nombre == nombreJugadorPc ||
    (nombre.startsWith('PC ') && nombre.length > 3);

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
