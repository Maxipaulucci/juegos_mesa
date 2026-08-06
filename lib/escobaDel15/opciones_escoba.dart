/// Opciones de “Modificar partida” para Escoba del 15.
class OpcionesEscoba {
  const OpcionesEscoba({
    this.escobasAutomaticasInicio = false,
  });

  /// Al repartir: revela izquierda→derecha; si hay 2 pares de 15 se toman
  /// como escobas; si las 4 suman 15, +1 escoba al jugador de turno.
  final bool escobasAutomaticasInicio;

  OpcionesEscoba copyWith({bool? escobasAutomaticasInicio}) {
    return OpcionesEscoba(
      escobasAutomaticasInicio:
          escobasAutomaticasInicio ?? this.escobasAutomaticasInicio,
    );
  }
}
