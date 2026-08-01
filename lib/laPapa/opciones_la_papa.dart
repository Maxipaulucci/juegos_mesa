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

  /// Modo infernal: solo se ven líneas + número actual + siguiente.
  /// Fuerza 50 números, aleatorios, sin vidas y sin cuadrícula.
  final bool modoFantasma;

  /// Si true, se dibujan las líneas de la cuadrícula de la hoja.
  final bool mostrarCuadricula;

  /// Alias de UI: el modo fantasma se muestra como “Modo infernal”.
  bool get modoInfernal => modoFantasma;

  bool get conVidasEfectivas => !modoFantasma && conVidas;

  bool get numerosAleatoriosEfectivos => modoFantasma || numerosAleatorios;

  bool get mostrarCuadriculaEfectiva => !modoFantasma && mostrarCuadricula;

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

  /// Activa el modo infernal y fija el resto de opciones.
  OpcionesPapa conModoInfernal(bool activo) {
    if (!activo) return copyWith(modoFantasma: false);
    return copyWith(
      modoFantasma: true,
      conVidas: false,
      numerosAleatorios: true,
      cantidadNumeros: maxCantidadNumeros,
      mostrarCuadricula: false,
    );
  }

  int get cantidadNumerosClamped => modoFantasma
      ? maxCantidadNumeros
      : cantidadNumeros.clamp(
          minCantidadNumeros,
          maxCantidadNumeros,
        );
}
