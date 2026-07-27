enum RolJugadorSala { anfitrion, invitado }

class JugadorSala {
  JugadorSala({
    required this.id,
    required this.nombre,
    required this.rol,
  });

  final String id;
  final String nombre;
  final RolJugadorSala rol;
}

/// Sala local (sin backend todavía).
/// Más adelante se sincroniza con Firebase/Supabase.
class Sala {
  Sala({
    required this.codigo,
    required this.juegoId,
    required this.anfitrionId,
    List<JugadorSala>? jugadores,
  }) : jugadores = jugadores ?? [];

  final String codigo;
  final String juegoId;
  final String anfitrionId;
  final List<JugadorSala> jugadores;

  bool get soyAnfitrion =>
      jugadores.any((j) => j.id == anfitrionId && j.rol == RolJugadorSala.anfitrion);
}
