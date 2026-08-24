import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/usuario_mongo.dart';

/// API del backend (cuentas y ranking).
///
/// Arranque: `backend/iniciar-todo.bat` o `backend/mongo/iniciar-api.bat`

final _reUsuario = RegExp(r'^[A-Za-z0-9_]{3,20}$');

/// Primera letra mayúscula, el resto minúscula. Solo letras, números y `_`.
String formatoNombreUsuario(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return t;
  return t[0].toUpperCase() + t.substring(1).toLowerCase();
}

bool usuarioNombreValido(String nombre) => _reUsuario.hasMatch(nombre);

class UsuarioMongoService {
  UsuarioMongoService._();
  static final instance = UsuarioMongoService._();

  String? _token;
  UsuarioMongo? usuario;

  bool get haySesion => _token != null && usuario != null;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$kMongoApiBase$path').replace(queryParameters: query);
  }

  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) return {};
    final v = jsonDecode(body);
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return {};
  }

  Never _error(Map<String, dynamic> decoded, int status) {
    throw StateError(
      decoded['error']?.toString() ?? 'Error de Mongo ($status).',
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final res = await http
        .post(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(timeout);
    final decoded = _decode(res.body);
    if (res.statusCode >= 400) _error(decoded, res.statusCode);
    return decoded;
  }

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? query,
  ]) async {
    final res = await http
        .get(_uri(path, query), headers: _headers)
        .timeout(const Duration(seconds: 15));
    final decoded = _decode(res.body);
    if (res.statusCode >= 400) _error(decoded, res.statusCode);
    return decoded;
  }

  Future<bool> salud() async {
    try {
      final data = await _get('/api/salud');
      return data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Ping largo para despertar Render free (cold start ~1 min).
  Future<void> despertarBackend() async {
    try {
      await http
          .get(_uri('/api/salud'), headers: _headers)
          .timeout(const Duration(seconds: 90));
    } catch (_) {
      // Si sigue dormido o hay timeout, igual ya se disparó el arranque.
    }
  }

  Future<void> pedirRegistro({
    required String nombreUsuario,
    required String email,
    required String password,
  }) async {
    await _post('/api/usuarios/registro', {
      'nombreUsuario': formatoNombreUsuario(nombreUsuario),
      'email': email.trim(),
      'password': password,
    });
  }

  Future<void> reenviarCodigo({required String email}) async {
    await _post('/api/usuarios/reenviar', {'email': email.trim()});
  }

  Future<UsuarioMongo> verificarRegistro({
    required String email,
    required String codigo,
  }) async {
    final data = await _post('/api/usuarios/verificar', {
      'email': email.trim(),
      'codigo': codigo.trim(),
    });
    return _guardarSesion(data);
  }

  Future<UsuarioMongo> login({
    required String usuario,
    required String password,
  }) async {
    final data = await _post('/api/usuarios/login', {
      'usuario': usuario.trim(),
      'password': password,
    });
    return _guardarSesion(data);
  }

  Future<void> pedirRecuperacion({required String email}) async {
    await _post('/api/usuarios/recuperar', {'email': email.trim()});
  }

  Future<void> reenviarRecuperacion({required String email}) async {
    await _post('/api/usuarios/recuperar/reenviar', {'email': email.trim()});
  }

  Future<void> verificarRecuperacion({
    required String email,
    required String codigo,
  }) async {
    await _post('/api/usuarios/recuperar/verificar', {
      'email': email.trim(),
      'codigo': codigo.trim(),
    });
  }

  Future<void> restablecerClave({
    required String email,
    required String password,
  }) async {
    await _post('/api/usuarios/recuperar/restablecer', {
      'email': email.trim(),
      'password': password,
    });
  }

  Future<UsuarioMongo> recargarYo() async {
    final data = await _get('/api/usuarios/yo');
    final raw = Map<String, dynamic>.from(data['usuario'] as Map);
    usuario = UsuarioMongo.fromJson(raw);
    return usuario!;
  }

  Future<UsuarioMongo> sumarPuntos({
    required String juegoId,
    required int puntos,
  }) async {
    final data = await _post('/api/puntos', {
      'juegoId': juegoId,
      'puntos': puntos,
    });
    final raw = Map<String, dynamic>.from(data['usuario'] as Map);
    usuario = UsuarioMongo.fromJson(raw);
    return usuario!;
  }

  /// [juego] = `global` o un id de juego (`diezMil`, `escobaDel15`, …).
  Future<List<PuestoRanking>> ranking({
    String juego = 'global',
    int limite = 50,
  }) async {
    final data = await _get('/api/ranking', {
      'juego': juego,
      'limite': '$limite',
    });
    final raw = data['ranking'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          PuestoRanking.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  void cerrarSesion() {
    _token = null;
    usuario = null;
  }

  UsuarioMongo _guardarSesion(Map<String, dynamic> data) {
    _token = data['token']?.toString();
    final raw = Map<String, dynamic>.from(data['usuario'] as Map);
    usuario = UsuarioMongo.fromJson(raw);
    return usuario!;
  }
}
