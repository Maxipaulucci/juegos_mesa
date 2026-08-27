import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias locales (web, Windows, móvil).
class AlmacenLocal {
  AlmacenLocal._();

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences get _p {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('AlmacenLocal.init() no se llamó.');
    }
    return prefs;
  }

  static Future<void> setString(String key, String value) async {
    await _p.setString(key, value);
  }

  static String? getString(String key) => _p.getString(key);

  static Future<void> remove(String key) async {
    await _p.remove(key);
  }
}
