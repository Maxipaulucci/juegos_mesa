import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/persistencia/almacen_local.dart';
import 'package:app_juegos_mesa/shared/persistencia/persistencia_comun.dart';

/// Preferencias globales de la app (música, sonidos, animaciones).
class AjustesStore extends ChangeNotifier {
  AjustesStore._();
  static final instance = AjustesStore._();

  static const _clave = 'ajustes_app_v1';

  AjustesEstado _estado = const AjustesEstado();

  AjustesEstado get estado => _estado;

  bool get animaciones => _estado.animaciones;

  void cargar() {
    try {
      final raw = AlmacenLocal.getString(_clave);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      _estado = decodeAjustes(decoded);
    } catch (_) {
      _estado = const AjustesEstado();
    }
  }

  void actualizar(AjustesEstado nuevo) {
    if (_estado.volumenMusica == nuevo.volumenMusica &&
        _estado.volumenSonidos == nuevo.volumenSonidos &&
        _estado.animaciones == nuevo.animaciones) {
      return;
    }
    _estado = nuevo;
    notifyListeners();
    _guardar();
  }

  Future<void> _guardar() async {
    try {
      await AlmacenLocal.setString(
        _clave,
        jsonEncode(encodeAjustes(_estado)),
      );
    } catch (_) {}
  }
}
