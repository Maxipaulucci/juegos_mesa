/// Opciones de “Modificar partida” para Generala.
class OpcionesGenerala {
  const OpcionesGenerala({
    this.escaleraCircular = false,
  });

  /// Permite escaleras que “dan la vuelta”: después del 6 sigue el 1
  /// (p. ej. 4-5-6-1-2).
  final bool escaleraCircular;

  OpcionesGenerala copyWith({bool? escaleraCircular}) {
    return OpcionesGenerala(
      escaleraCircular: escaleraCircular ?? this.escaleraCircular,
    );
  }
}
