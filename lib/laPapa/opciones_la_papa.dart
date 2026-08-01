/// Opciones de “Modificar partida” para La papa.
class OpcionesPapa {
  const OpcionesPapa({
    this.conVidas = false,
    this.numerosAleatorios = true,
    this.cantidadNumeros = maxNumeroPapaDefault,
    this.modoFantasma = false,
    this.mostrarCuadricula = true,
  });

  static const int maxNumeroPapaDefault = 30;
  static const int maxCantidadNumeros = 50;
  static const int minCantidadNumeros = 2;
  static const int vidasIniciales = 3;

  /// Cada jugador empieza con [vidasIniciales] vidas.
  final bool conVidas;

  /// Si false, los jugadores colocan los números a mano antes de jugar.
  final bool numerosAleatorios;

  /// Cantidad de números en la hoja (2..50).
  final int cantidadNumeros;

  /// Solo se ven líneas + número actual + siguiente.
  final bool modoFantasma;

  /// Si true, se dibujan las líneas de la cuadrícula de la hoja.
  final bool mostrarCuadricula;

  OpcionesPapa copyWith({
    bool? conVidas,
    bool? numerosAleatorios,
    int? cantidadNumeros,
    bool? modoFantasma,
    bool? mostrarCuadricula,
  }) {
    return OpcionesPapa(
      conVidas: conVidas ?? this.conVidas,
      numerosAleatorios: numerosAleatorios ?? this.numerosAleatorios,
      cantidadNumeros: cantidadNumeros ?? this.cantidadNumeros,
      modoFantasma: modoFantasma ?? this.modoFantasma,
      mostrarCuadricula: mostrarCuadricula ?? this.mostrarCuadricula,
    );
  }

  int get cantidadNumerosClamped => cantidadNumeros.clamp(
        minCantidadNumeros,
        maxCantidadNumeros,
      );
}
