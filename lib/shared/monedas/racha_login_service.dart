import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/models/racha_login.dart';
import 'package:app_juegos_mesa/shared/ui/notificacion_tope.dart';

/// Muestra la recompensa de racha diaria tras login o al abrir la app.
class RachaLoginService {
  RachaLoginService._();
  static final instance = RachaLoginService._();

  RachaLogin? _pendiente;

  void registrarDesdeRespuesta(Map<String, dynamic> data) {
    final raw = data['racha'];
    if (raw is! Map) return;
    final racha = RachaLogin.fromJson(Map<String, dynamic>.from(raw));
    if (!racha.aplicada || racha.monedasSumadas <= 0) return;
    _pendiente = racha;
  }

  void mostrarPendienteSiHay(BuildContext context) {
    final racha = _pendiente;
    if (racha == null) return;
    _pendiente = null;
    final mensaje = racha.mensajeNotificacion;
    if (mensaje.isEmpty) return;
    mostrarNotificacionTope(
      context,
      mensaje: mensaje,
      duracion: const Duration(seconds: 4),
    );
  }
}
