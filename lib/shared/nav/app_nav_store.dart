import 'package:flutter/foundation.dart';

/// Navegación de la barra inferior ([AppShell]).
class AppNavStore extends ChangeNotifier {
  AppNavStore._();
  static final instance = AppNavStore._();

  int? _tabPendiente;

  /// 0 juegos · 1 salas · 2 cuenta · 3 ranking · 4 tienda
  int? consumirTabPendiente() {
    final tab = _tabPendiente;
    _tabPendiente = null;
    return tab;
  }

  void irATab(int index) {
    _tabPendiente = index;
    notifyListeners();
  }

  void irAPerfil() => irATab(2);
}
