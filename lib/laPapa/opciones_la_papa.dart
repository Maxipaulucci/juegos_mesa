/// Opciones de “Modificar partida” para La papa.
class OpcionesPapa {
  const OpcionesPapa({
    this.conVidas = false,
    this.numerosAleatorios = true,
    this.cantidadNumeros = maxNumeroPapaDefault,
    this.modoFantasma = false,
    this.mostrarCuadricula = true,
    this.permitirTrazoSobreNumeros = true,
    this.mostrarLupa = true,
    this.modificarGrosorTrazo = true,
    this.excepcionGeneracionNumeros = false,
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
  /// Fuerza 50 números, aleatorios, sin vidas, sin cuadrícula,
  /// sin lupa, sin cambiar grosor y sin trazar sobre números.
  final bool modoFantasma;

  /// Si true, se dibujan las líneas de la cuadrícula de la hoja.
  final bool mostrarCuadricula;

  /// Si true (default), el trazo puede pasar por encima de otros números.
  /// Si false, tocar la zona de otro número = pérdida.
  final bool permitirTrazoSobreNumeros;

  /// Si true (default), al dibujar se muestra la lupa de ampliación.
  final bool mostrarLupa;

  /// Si true (default), se puede cambiar el grosor (botón Trazos / tecla T).
  final bool modificarGrosorTrazo;

  /// Si true, consecutivos no comparten fila/columna ni son vecinos.
  /// Si false (default), la generación es aleatoria libre en las 50 casillas.
  final bool excepcionGeneracionNumeros;

  /// Alias de UI: el modo fantasma se muestra como “Modo infernal”.
  bool get modoInfernal => modoFantasma;

  bool get conVidasEfectivas => !modoFantasma && conVidas;

  bool get numerosAleatoriosEfectivos => modoFantasma || numerosAleatorios;

  bool get mostrarCuadriculaEfectiva => !modoFantasma && mostrarCuadricula;

  /// En Modo infernal no se puede trazar sobre números.
  bool get permitirTrazoSobreNumerosEfectivo =>
      !modoFantasma && permitirTrazoSobreNumeros;

  /// En Modo infernal no hay lupa.
  bool get mostrarLupaEfectiva => !modoFantasma && mostrarLupa;

  /// En Modo infernal no se puede cambiar el grosor.
  bool get modificarGrosorTrazoEfectivo =>
      !modoFantasma && modificarGrosorTrazo;

  OpcionesPapa copyWith({
    bool? conVidas,
    bool? numerosAleatorios,
    int? cantidadNumeros,
    bool? modoFantasma,
    bool? mostrarCuadricula,
    bool? permitirTrazoSobreNumeros,
    bool? mostrarLupa,
    bool? modificarGrosorTrazo,
    bool? excepcionGeneracionNumeros,
  }) {
    return OpcionesPapa(
      conVidas: conVidas ?? this.conVidas,
      numerosAleatorios: numerosAleatorios ?? this.numerosAleatorios,
      cantidadNumeros: cantidadNumeros ?? this.cantidadNumeros,
      modoFantasma: modoFantasma ?? this.modoFantasma,
      mostrarCuadricula: mostrarCuadricula ?? this.mostrarCuadricula,
      permitirTrazoSobreNumeros:
          permitirTrazoSobreNumeros ?? this.permitirTrazoSobreNumeros,
      mostrarLupa: mostrarLupa ?? this.mostrarLupa,
      modificarGrosorTrazo:
          modificarGrosorTrazo ?? this.modificarGrosorTrazo,
      excepcionGeneracionNumeros:
          excepcionGeneracionNumeros ?? this.excepcionGeneracionNumeros,
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
      permitirTrazoSobreNumeros: false,
      mostrarLupa: false,
      modificarGrosorTrazo: false,
    );
  }

  int get cantidadNumerosClamped => modoFantasma
      ? maxCantidadNumeros
      : cantidadNumeros.clamp(
          minCantidadNumeros,
          maxCantidadNumeros,
        );
}
