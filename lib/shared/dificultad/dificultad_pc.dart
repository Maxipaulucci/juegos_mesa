/// Constantes y dificultad compartidas para partidas vs PC.
library;

const String nombreJugadorPc = 'PC';

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
