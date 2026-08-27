import 'dart:convert';

import 'package:app_juegos_mesa/models/usuario_mongo.dart';

import 'almacen_local.dart';

const _kToken = 'sesion_token_v1';
const _kUsuario = 'sesion_usuario_v1';

/// Token + perfil en disco.
class SesionLocal {
  SesionLocal._();

  static Future<void> guardar({
    required String token,
    required UsuarioMongo usuario,
  }) async {
    await AlmacenLocal.setString(_kToken, token);
    await AlmacenLocal.setString(_kUsuario, jsonEncode(usuario.toJson()));
  }

  static Future<({String token, UsuarioMongo usuario})?> cargar() async {
    final token = AlmacenLocal.getString(_kToken);
    final raw = AlmacenLocal.getString(_kUsuario);
    if (token == null || token.isEmpty || raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return (
        token: token,
        usuario: UsuarioMongo.fromJson(Map<String, dynamic>.from(decoded)),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> limpiar() async {
    await AlmacenLocal.remove(_kToken);
    await AlmacenLocal.remove(_kUsuario);
  }
}
