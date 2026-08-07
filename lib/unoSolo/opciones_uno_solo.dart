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
