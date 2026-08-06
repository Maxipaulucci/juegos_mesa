/// Opciones de “Modificar partida” para Culo sucio v2.
class OpcionesCuloSucioV2 {
  const OpcionesCuloSucioV2({
    this.eliminarParesAuto = true,
  });

  /// Si true, en la fase de pares se muestra el botón
  /// “Eliminar pares automáticamente”.
  final bool eliminarParesAuto;

  OpcionesCuloSucioV2 copyWith({bool? eliminarParesAuto}) {
    return OpcionesCuloSucioV2(
      eliminarParesAuto: eliminarParesAuto ?? this.eliminarParesAuto,
    );
  }
}
