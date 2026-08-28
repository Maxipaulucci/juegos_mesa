import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:app_juegos_mesa/models/cofre_estado.dart';
import 'package:app_juegos_mesa/services/usuario_mongo_service.dart';
import 'package:app_juegos_mesa/shared/monedas/monedas_store.dart';

/// Estado de los cofres diarios / cada 4 h (esquina inferior izquierda).
class CofresStore extends ChangeNotifier {
  CofresStore._();
  static final instance = CofresStore._();

  CofresEstado _estado = CofresEstado.bloqueado();
  bool _cargando = false;
  Timer? _tick;

  CofresEstado get estado => _estado;
  bool get cargando => _cargando;
  bool get haySesion => UsuarioMongoService.instance.haySesion;

  bool _iniciado = false;

  void iniciar() {
    if (_iniciado) return;
    _iniciado = true;
    MonedasStore.instance.addListener(_onSesion);
    unawaited(refrescar());
  }

  void disposeStore() {
    MonedasStore.instance.removeListener(_onSesion);
    _detenerTick();
  }

  void _onSesion() {
    unawaited(refrescar());
  }

  Future<void> refrescar() async {
    if (!haySesion) {
      _estado = CofresEstado.bloqueado();
      _detenerTick();
      notifyListeners();
      return;
    }
    _cargando = true;
    notifyListeners();
    try {
      final data = await UsuarioMongoService.instance.estadoCofres();
      _estado = CofresEstado.fromJson(data);
      _ajustarTick();
    } catch (_) {
      _estado = CofresEstado.bloqueado();
      _detenerTick();
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<int?> reclamar(String tipo) async {
    if (!haySesion) return null;
    try {
      final data = await UsuarioMongoService.instance.reclamarCofre(tipo: tipo);
      _estado = CofresEstado.fromJson(data);
      _ajustarTick();
      notifyListeners();
      return (data['monedasSumadas'] as num?)?.toInt();
    } catch (_) {
      await refrescar();
      rethrow;
    }
  }

  void _ajustarTick() {
    if (_estado.hayCooldown) {
      _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        _estado = _estado.tick();
        notifyListeners();
        if (!_estado.hayCooldown) _detenerTick();
      });
    } else {
      _detenerTick();
    }
  }

  void _detenerTick() {
    _tick?.cancel();
    _tick = null;
  }
}
