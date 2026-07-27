import 'dart:math';

import '../models/sala.dart';

/// Servicio local de salas.
/// Hoy vive en memoria; después se reemplaza por Firebase/Supabase
/// sin cambiar las pantallas.
class SalaService {
  SalaService._();
  static final instance = SalaService._();

  final Map<String, Sala> _salas = {};
  final _rng = Random();

  String generarCodigo({int largo = 6}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(largo, (_) => chars[_rng.nextInt(chars.length)]).join();
  }

  Sala crear({
    required String juegoId,
    required String nombreAnfitrion,
    String? codigoPreferido,
  }) {
    var codigo = (codigoPreferido ?? '').trim().toUpperCase();
    if (codigo.isEmpty) {
      do {
        codigo = generarCodigo();
      } while (_salas.containsKey(codigo));
    } else if (_salas.containsKey(codigo)) {
      throw StateError('Ese código ya está en uso. Probá otro.');
    }

    final anfitrionId = 'local-host';
    final sala = Sala(
      codigo: codigo,
      juegoId: juegoId,
      anfitrionId: anfitrionId,
      jugadores: [
        JugadorSala(
          id: anfitrionId,
          nombre: nombreAnfitrion.trim(),
          rol: RolJugadorSala.anfitrion,
        ),
      ],
    );
    _salas[codigo] = sala;
    return sala;
  }

  Sala unirse({
    required String codigo,
    required String nombre,
  }) {
    final key = codigo.trim().toUpperCase();
    final sala = _salas[key];
    if (sala == null) {
      throw StateError('No existe una sala con ese código.');
    }
    if (sala.jugadores.any((j) => j.nombre.toLowerCase() == nombre.trim().toLowerCase())) {
      throw StateError('Ese nombre ya está en la sala.');
    }

    final invitado = JugadorSala(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      nombre: nombre.trim(),
      rol: RolJugadorSala.invitado,
    );
    sala.jugadores.add(invitado);
    return sala;
  }

  void expulsar(Sala sala, String jugadorId) {
    if (jugadorId == sala.anfitrionId) return;
    sala.jugadores.removeWhere((j) => j.id == jugadorId);
  }

  Sala? obtener(String codigo) => _salas[codigo.trim().toUpperCase()];

  void cerrar(String codigo) {
    _salas.remove(codigo.trim().toUpperCase());
  }
}
