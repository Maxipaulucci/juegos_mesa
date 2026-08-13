/// Opciones de “Modificar partida” para Jodete.
class OpcionesJodete {
  const OpcionesJodete({
    this.comodines = true,
    this.levantarHastaTirar = false,
    this.objetivo = 30,
    this.puntajePorCartas = false,
    this.apilarDoses = true,
    this.ganarConEspecial = false,
  });

  static const objetivosPermitidos = [15, 30];
  static const objetivoPorCartas = 100;

  /// Si true, el mazo incluye 2 comodines (50 cartas); si no, 48.
  final bool comodines;

  /// Si true: al no poder tirar, levantás del mazo hasta sacar una jugable
  /// y podés tirarla en el mismo turno. Si false: levantás 1 y pasás.
  final bool levantarHastaTirar;

  /// Puntos para ganar (15 o 30) cuando no está [puntajePorCartas].
  final int objetivo;

  /// Si true: el 1º de la ronda suma el valor de las cartas que quedan
  /// en las demás manos; gana quien llega a 100.
  final bool puntajePorCartas;

  /// Si true, se puede responder un 2 con otro 2 (apila +2)
  /// y un comodín con otro comodín (apila +5).
  final bool apilarDoses;

  /// Si true, nadie puede terminar la mano con carta especial
  /// (2, 4, 7, 10, 11, 12 o comodín).
  final bool ganarConEspecial;

  int get objetivoClamped =>
      objetivosPermitidos.contains(objetivo) ? objetivo : 30;

  /// Objetivo efectivo según el modo de puntuación.
  int get objetivoEfectivo =>
      puntajePorCartas ? objetivoPorCartas : objetivoClamped;

  OpcionesJodete copyWith({
    bool? comodines,
    bool? levantarHastaTirar,
    int? objetivo,
    bool? puntajePorCartas,
    bool? apilarDoses,
    bool? ganarConEspecial,
  }) {
    return OpcionesJodete(
      comodines: comodines ?? this.comodines,
      levantarHastaTirar: levantarHastaTirar ?? this.levantarHastaTirar,
      objetivo: objetivo ?? this.objetivo,
      puntajePorCartas: puntajePorCartas ?? this.puntajePorCartas,
      apilarDoses: apilarDoses ?? this.apilarDoses,
      ganarConEspecial: ganarConEspecial ?? this.ganarConEspecial,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OpcionesJodete &&
      other.comodines == comodines &&
      other.levantarHastaTirar == levantarHastaTirar &&
      other.objetivo == objetivo &&
      other.puntajePorCartas == puntajePorCartas &&
      other.apilarDoses == apilarDoses &&
      other.ganarConEspecial == ganarConEspecial;

  @override
  int get hashCode => Object.hash(
        comodines,
        levantarHastaTirar,
        objetivo,
        puntajePorCartas,
        apilarDoses,
        ganarConEspecial,
      );
}

/// Config del menú (para reinicio / coerencia con standby).
abstract final class JodeteMenuConfig {
  static OpcionesJodete _opciones = const OpcionesJodete();

  static OpcionesJodete get opciones => _opciones;

  static void actualizar(OpcionesJodete o) => _opciones = o;
}
