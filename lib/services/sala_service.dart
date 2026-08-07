import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/sala.dart';

/// URL base del API de salas.
///
/// En Netlify (mismo origen) queda vacío.
/// En `flutter run` local apunta al sitio publicado para compartir salas.
const String kSalaApiBase = String.fromEnvironment(
  'SALA_API_BASE',
  defaultValue: 'https://juegosdemesaargentos.netlify.app',
);

/// Salas online vía Netlify Functions + Blobs.
class SalaService {
  SalaService._();
  static final instance = SalaService._();

  final _rng = Random();

  Uri _uri([Map<String, String>? query]) {
    final base = kIsWeb && !kDebugMode ? '' : kSalaApiBase;
    return Uri.parse('$base/api/sala').replace(queryParameters: query);
  }

  String generarCodigo({int largo = 6}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(largo, (_) => chars[_rng.nextInt(chars.length)]).join();
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final res = await http
        .post(
          _uri(),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    final decoded = _decode(res.body);
    if (res.statusCode >= 400) {
      throw StateError(decoded['error']?.toString() ?? 'Error de red (${res.statusCode}).');
    }
    return decoded;
  }

  Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) return {};
    final v = jsonDecode(body);
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return {};
  }

  Sala _parseSala(Map<String, dynamic> raw) {
    final jugadoresRaw = raw['jugadores'];
    final jugadores = <JugadorSala>[];
    if (jugadoresRaw is List) {
      for (final j in jugadoresRaw) {
        if (j is! Map) continue;
        final m = Map<String, dynamic>.from(j);
        jugadores.add(
          JugadorSala(
            id: m['id']?.toString() ?? '',
            nombre: m['nombre']?.toString() ?? '',
            rol: m['rol']?.toString() == 'anfitrion'
                ? RolJugadorSala.anfitrion
                : RolJugadorSala.invitado,
          ),
        );
      }
    }
    return Sala(
      codigo: raw['codigo']?.toString() ?? '',
      juegoId: raw['juegoId']?.toString() ?? '',
      anfitrionId: raw['anfitrionId']?.toString() ?? '',
      jugadores: jugadores,
      estado: raw['estado']?.toString() ?? 'lobby',
      dados: (raw['dados'] is int) ? raw['dados'] as int : 5,
      gameState: raw['gameState'] is Map
          ? Map<String, dynamic>.from(raw['gameState'] as Map)
          : null,
      lobbyCategorias: (raw['lobbyCategorias'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      lobbyMaxRondas: (raw['lobbyMaxRondas'] as num?)?.toInt(),
    );
  }

  Future<({Sala sala, String miId})> crear({
    required String juegoId,
    required String nombreAnfitrion,
  }) async {
    final data = await _post({
      'action': 'crear',
      'juegoId': juegoId,
      'nombre': nombreAnfitrion.trim(),
    });
    final salaMap = Map<String, dynamic>.from(data['sala'] as Map);
    return (sala: _parseSala(salaMap), miId: data['miId'] as String);
  }

  Future<({Sala sala, String miId})> unirse({
    required String codigo,
    required String nombre,
    required String juegoId,
  }) async {
    final data = await _post({
      'action': 'unirse',
      'codigo': codigo.trim().toUpperCase(),
      'nombre': nombre.trim(),
      'juegoId': juegoId,
    });
    final salaMap = Map<String, dynamic>.from(data['sala'] as Map);
    return (sala: _parseSala(salaMap), miId: data['miId'] as String);
  }

  Future<Sala> obtener(String codigo) async {
    final res = await http
        .get(_uri({'codigo': codigo.trim().toUpperCase()}))
        .timeout(const Duration(seconds: 15));
    final decoded = _decode(res.body);
    if (res.statusCode >= 400) {
      throw StateError(decoded['error']?.toString() ?? 'No se pudo cargar la sala.');
    }
    return _parseSala(Map<String, dynamic>.from(decoded['sala'] as Map));
  }

  Future<Sala> expulsar({
    required String codigo,
    required String anfitrionId,
    required String jugadorId,
  }) async {
    final data = await _post({
      'action': 'expulsar',
      'codigo': codigo,
      'anfitrionId': anfitrionId,
      'jugadorId': jugadorId,
    });
    return _parseSala(Map<String, dynamic>.from(data['sala'] as Map));
  }

  Future<Sala> actualizarLobby({
    required String codigo,
    required String anfitrionId,
    required List<String> categorias,
    required int maxRondas,
  }) async {
    final data = await _post({
      'action': 'actualizarLobby',
      'codigo': codigo,
      'anfitrionId': anfitrionId,
      'categorias': categorias,
      'maxRondas': maxRondas,
    });
    return _parseSala(Map<String, dynamic>.from(data['sala'] as Map));
  }

  Future<Sala> iniciar({
    required String codigo,
    required String anfitrionId,
    required int dados,
    List<String>? categorias,
    int? maxRondas,
    Map<String, dynamic>? opcionesPapa,
    Map<String, dynamic>? opcionesChancho,
  }) async {
    final data = await _post({
      'action': 'iniciar',
      'codigo': codigo,
      'anfitrionId': anfitrionId,
      'dados': dados,
      if (categorias != null) 'categorias': categorias,
      if (maxRondas != null) 'maxRondas': maxRondas,
      if (opcionesPapa != null) 'opcionesPapa': opcionesPapa,
      if (opcionesChancho != null) 'opcionesChancho': opcionesChancho,
    });
    return _parseSala(Map<String, dynamic>.from(data['sala'] as Map));
  }

  /// Publica estado. Devuelve si el servidor lo aceptó (`ignored: false`).
  Future<({Sala sala, bool ignored})> actualizarJuego({
    required String codigo,
    required Map<String, dynamic> gameState,
  }) async {
    final data = await _post({
      'action': 'actualizarJuego',
      'codigo': codigo,
      'gameState': gameState,
    });
    final ignored = data['ignored'] == true;
    return (
      sala: _parseSala(Map<String, dynamic>.from(data['sala'] as Map)),
      ignored: ignored,
    );
  }

  Future<void> cerrar({
    required String codigo,
    required String anfitrionId,
  }) async {
    await _post({
      'action': 'cerrar',
      'codigo': codigo,
      'anfitrionId': anfitrionId,
    });
  }

  /// Polling cada [intervalo] mientras la sala exista.
  Stream<Sala> watch(
    String codigo, {
    Duration intervalo = const Duration(milliseconds: 1200),
  }) async* {
    while (true) {
      try {
        yield await obtener(codigo);
      } catch (_) {
        // Red momentánea: reintenta.
      }
      await Future<void>.delayed(intervalo);
    }
  }
}
