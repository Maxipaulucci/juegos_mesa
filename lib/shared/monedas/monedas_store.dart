import 'package:flutter/foundation.dart';

import '../services/usuario_mongo_service.dart';
import '../shared/dificultad/dificultad_pc.dart';

/// Estado de monedas para la burbuja del shell (escucha sesión / premios).
class MonedasStore extends ChangeNotifier {
  MonedasStore._();
  static final instance = MonedasStore._();

  bool get visible => UsuarioMongoService.instance.haySesion;

  int get monedas => UsuarioMongoService.instance.usuario?.monedas ?? 0;

  void notificar() => notifyListeners();

  /// +3 si hay sesión y el humano ganó vs PC (local). Sin sesión: no hace nada.
  Future<void> premiarVictoriaPcSiCorresponde({
    required bool contraPc,
    required bool online,
    required bool ganoHumano,
  }) async {
    if (!contraPc || online || !ganoHumano) return;
    if (!UsuarioMongoService.instance.haySesion) return;
    try {
      await UsuarioMongoService.instance.sumarMonedasVictoriaPc();
      notifyListeners();
    } catch (_) {
      // Red / backend: no bloquea la UI de victoria.
    }
  }
}

/// ¿Ganó un humano (no PC) en vs PC?
bool ganoHumanoEnVsPc({
  required bool contraPc,
  required bool online,
  required String? ganador,
}) {
  if (!contraPc || online) return false;
  if (ganador == null || ganador.trim().isEmpty) return false;
  return !esNombrePc(ganador);
}
