/// Opciones de “Modificar partida” para Jodete.
class OpcionesJodete {
  const OpcionesJodete({
    this.comodines = true,
    this.levantarHastaTirar = false,
  });

  /// Si true, el mazo incluye 2 comodines (50 cartas); si no, 48.
  final bool comodines;

  /// Si true: al no poder tirar, levantás del mazo hasta sacar una jugable
  /// y podés tirarla en el mismo turno. Si false: levantás 1 y pasás.
  final bool levantarHastaTirar;

  OpcionesJodete copyWith({
    bool? comodines,
    bool? levantarHastaTirar,
  }) {
    return OpcionesJodete(
      comodines: comodines ?? this.comodines,
      levantarHastaTirar: levantarHastaTirar ?? this.levantarHastaTirar,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OpcionesJodete &&
      other.comodines == comodines &&
      other.levantarHastaTirar == levantarHastaTirar;

  @override
  int get hashCode => Object.hash(comodines, levantarHastaTirar);
}

/// Config del menú (para reinicio / coerencia con standby).
abstract final class JodeteMenuConfig {
  static OpcionesJodete _opciones = const OpcionesJodete();

  static OpcionesJodete get opciones => _opciones;

  static void actualizar(OpcionesJodete o) => _opciones = o;
}
