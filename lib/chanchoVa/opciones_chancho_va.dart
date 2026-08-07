/// Opciones de “Modificar partida” para Chancho va.
class OpcionesChanchoVa {
  const OpcionesChanchoVa({
    this.chancha = true,
    this.sinEspacio = false,
    this.finAlPrimerPerdedor = false,
  });

  /// Si true (default), hay botón CHANCHA y las PCs también pueden lanzarla.
  final bool chancha;

  /// Si true, el tablero es CHANCHOVA (sin espacio). Desactivado por defecto.
  final bool sinEspacio;

  /// Si true, la partida termina cuando el primer jugador completa la palabra.
  /// Si false (default), ese jugador queda fuera y se sigue hasta que quede uno.
  final bool finAlPrimerPerdedor;

  OpcionesChanchoVa copyWith({
    bool? chancha,
    bool? sinEspacio,
    bool? finAlPrimerPerdedor,
  }) {
    return OpcionesChanchoVa(
      chancha: chancha ?? this.chancha,
      sinEspacio: sinEspacio ?? this.sinEspacio,
      finAlPrimerPerdedor: finAlPrimerPerdedor ?? this.finAlPrimerPerdedor,
    );
  }
}
