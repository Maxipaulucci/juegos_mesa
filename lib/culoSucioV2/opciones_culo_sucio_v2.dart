/// Opciones de “Modificar partida” para Culo sucio v2.
class OpcionesCuloSucioV2 {
  const OpcionesCuloSucioV2({
    this.eliminarParesAuto = true,
    this.detectarParTrasRobo = true,
    this.moverCuloSucio = true,
  });

  /// Si true, en la fase de pares se muestra el botón
  /// “Eliminar pares automáticamente”.
  final bool eliminarParesAuto;

  /// Si true, al robar y formar un par se marcan las cartas y hay que
  /// tocar una para descartarlo. Si false, la carta solo entra a la mano.
  final bool detectarParTrasRobo;

  /// Si true, en tu turno podés mover el 1 de oro dentro de tu mano.
  final bool moverCuloSucio;

  OpcionesCuloSucioV2 copyWith({
    bool? eliminarParesAuto,
    bool? detectarParTrasRobo,
    bool? moverCuloSucio,
  }) {
    return OpcionesCuloSucioV2(
      eliminarParesAuto: eliminarParesAuto ?? this.eliminarParesAuto,
      detectarParTrasRobo: detectarParTrasRobo ?? this.detectarParTrasRobo,
      moverCuloSucio: moverCuloSucio ?? this.moverCuloSucio,
    );
  }
}
