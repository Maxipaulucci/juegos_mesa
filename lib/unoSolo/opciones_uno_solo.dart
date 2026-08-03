/// Opciones de “Modificar partida” para Uno solo.
class OpcionesUnoSolo {
  const OpcionesUnoSolo({
    this.modoPractica = false,
  });

  /// Permite deshacer de a un salto hacia atrás (hasta el inicio).
  final bool modoPractica;

  OpcionesUnoSolo copyWith({bool? modoPractica}) {
    return OpcionesUnoSolo(
      modoPractica: modoPractica ?? this.modoPractica,
    );
  }
}
