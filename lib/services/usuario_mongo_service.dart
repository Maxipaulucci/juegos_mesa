import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/usuario_mongo.dart';

/// API local de Mongo (carpeta `mongo/` del repo).
///
/// Arranque: `mongo/iniciar-api.bat` o `npm start` dentro de `mongo`.
const String kMongoApiBase = String.fromEnvironment(
  'MONGO_API_BASE',
  defaultValue: 'http://127.0.0.1:27080',
);

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

  Future<void> pedirRegistro({
    required String nombreUsuario,
    required String email,
    required String password,
  }) async {
    await _post('/api/usuarios/registro', {
      'nombreUsuario': nombreUsuario.trim(),
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
