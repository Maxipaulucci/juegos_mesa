/// Opciones de “Modificar partida” para Uno solo.
class OpcionesUnoSolo {
  const OpcionesUnoSolo({
    this.modoPractica = true,
  });

  /// Permite deshacer de a un salto hacia atrás (hasta el inicio).
  /// Activado por defecto; se puede apagar en Modificar partida.
  final bool modoPractica;

  OpcionesUnoSolo copyWith({bool? modoPractica}) {
    return OpcionesUnoSolo(
      modoPractica: modoPractica ?? this.modoPractica,
    );
  }
}

/// Últimas opciones del menú (para reiniciar con la config actual).
abstract final class UnoSoloMenuConfig {
  static OpcionesUnoSolo opciones = const OpcionesUnoSolo();

  static void actualizar(OpcionesUnoSolo value) => opciones = value;
}
