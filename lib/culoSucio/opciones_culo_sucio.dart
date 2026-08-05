/// Opciones de “Modificar partida” para Culo sucio v1.
class OpcionesCuloSucio {
  const OpcionesCuloSucio({
    this.comodines = false,
  });

  /// Si true, el mazo incluye 2 comodines (50 cartas); si no, 48.
  final bool comodines;

  OpcionesCuloSucio copyWith({bool? comodines}) {
    return OpcionesCuloSucio(
      comodines: comodines ?? this.comodines,
    );
  }
}
