/// Opciones de “Modificar partida” para Culo sucio v2.
class OpcionesCuloSucioV2 {
  const OpcionesCuloSucioV2({
    this.eliminarParesAuto = true,
    this.detectarParTrasRobo = true,
  });

  /// Si true, en la fase de pares se muestra el botón
  /// “Eliminar pares automáticamente”.
  final bool eliminarParesAuto;

  /// Si true, al robar y formar un par se marcan las cartas y hay que
  /// tocar una para descartarlo. Si false, la carta solo entra a la mano.
  final bool detectarParTrasRobo;

  OpcionesCuloSucioV2 copyWith({
    bool? eliminarParesAuto,
    bool? detectarParTrasRobo,
  }) {
    return OpcionesCuloSucioV2(
      eliminarParesAuto: eliminarParesAuto ?? this.eliminarParesAuto,
      detectarParTrasRobo: detectarParTrasRobo ?? this.detectarParTrasRobo,
    );
  }
}
