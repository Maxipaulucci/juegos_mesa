import 'package:flutter/foundation.dart';

/// Indica si el cartel de cuenta (login / perfil) está abierto.
class CuentaOverlayStore extends ChangeNotifier {
  CuentaOverlayStore._();
  static final instance = CuentaOverlayStore._();

  int _abiertos = 0;

  bool get abierta => _abiertos > 0;

  void abrir() {
    _abiertos++;
    if (_abiertos == 1) notifyListeners();
  }

  void cerrar() {
    if (_abiertos <= 0) return;
    _abiertos--;
    if (_abiertos == 0) notifyListeners();
  }
}
