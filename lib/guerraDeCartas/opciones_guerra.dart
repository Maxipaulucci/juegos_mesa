/// Opciones de “Modificar partida” para Guerra de cartas.
class OpcionesGuerra {
  const OpcionesGuerra({
    this.vidasActivas = true,
  });

  /// Si true (default), cada jugador tiene 15 vidas y pierde 1 al vaciar el mazo.
  final bool vidasActivas;

  OpcionesGuerra copyWith({bool? vidasActivas}) {
    return OpcionesGuerra(
      vidasActivas: vidasActivas ?? this.vidasActivas,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OpcionesGuerra && other.vidasActivas == vidasActivas;

  @override
  int get hashCode => vidasActivas.hashCode;
}

/// Últimas opciones del menú (para reiniciar con la config actual).
abstract final class GuerraMenuConfig {
  static OpcionesGuerra opciones = const OpcionesGuerra();

  static void actualizar(OpcionesGuerra value) => opciones = value;
}
