import 'dart:convert';

import 'almacen_local.dart';

/// Partidas vs PC guardadas en disco (stand by).
class StandbyAlmacen {
  StandbyAlmacen._();

  static const _version = 1;

  static String _key(String juegoId) => 'standby_v${_version}_$juegoId';

  static Future<void> guardar(
    String juegoId,
    Map<String, dynamic> data,
  ) async {
    await AlmacenLocal.setString(_key(juegoId), jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> leer(String juegoId) async {
    final raw = AlmacenLocal.getString(_key(juegoId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  static Future<void> borrar(String juegoId) async {
    await AlmacenLocal.remove(_key(juegoId));
  }
}
