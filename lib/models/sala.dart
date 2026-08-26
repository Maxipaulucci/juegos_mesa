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

/// Sala online (Spring Boot + MongoDB).
class Sala {
  Sala({
    required this.codigo,
    required this.juegoId,
    required this.anfitrionId,
    List<JugadorSala>? jugadores,
    this.estado = 'lobby',
    this.dados = 5,
    this.gameState,
    this.lobbyCategorias = const [],
    this.lobbyMaxRondas,
    this.lobbyOpcionesResumen = const [],
    this.apuestaMonedas = 0,
  }) : jugadores = jugadores ?? [];

  final String codigo;
  final String juegoId;
  final String anfitrionId;
  final List<JugadorSala> jugadores;
  /// `lobby` | `jugando`
  final String estado;
  final int dados;
  /// Estado sincronizado de la partida (JSON).
  final Map<String, dynamic>? gameState;
  /// Tutti Frutti: categorías que el anfitrión está armando (lobby).
  final List<String> lobbyCategorias;
  /// Tutti Frutti: rondas elegidas en lobby.
  final int? lobbyMaxRondas;
  /// Resumen legible de “Modificar partida” del anfitrión.
  final List<String> lobbyOpcionesResumen;
  /// Monedas que cada jugador apuesta (0 = sin apuesta).
  final int apuestaMonedas;

  bool get soyAnfitrion =>
      jugadores.any((j) => j.id == anfitrionId && j.rol == RolJugadorSala.anfitrion);

  bool get iniciada => estado == 'jugando';

  int get gameVersion => (gameState?['version'] as num?)?.toInt() ?? 0;
}

/// Datos para arrancar una partida desde una sala online.
class InicioPartidaOnline {
  const InicioPartidaOnline({
    required this.nombres,
    required this.dados,
    required this.salaCodigo,
    required this.miNombre,
  });

  final List<String> nombres;
  final int dados;
  final String salaCodigo;
  final String miNombre;
}
