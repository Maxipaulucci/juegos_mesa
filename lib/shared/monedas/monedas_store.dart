import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:app_juegos_mesa/services/usuario_mongo_service.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';
import 'apuesta_online_store.dart';

/// Estado de monedas para la burbuja del shell (escucha sesión / premios).
class MonedasStore extends ChangeNotifier {
  MonedasStore._();
  static final instance = MonedasStore._();

  int? _monedasAnimadas;
  bool _animandoMonedas = false;
  int? _bonusCofre;
  double _bonusCofreProgreso = 0;
  bool _animacionCofreEnCurso = false;

  bool get visible => UsuarioMongoService.instance.haySesion;

  int get monedas => UsuarioMongoService.instance.usuario?.monedas ?? 0;

  int get monedasMostradas =>
      _animandoMonedas && _monedasAnimadas != null ? _monedasAnimadas! : monedas;

  int? get bonusCofre => _bonusCofre;

  double get bonusCofreProgreso => _bonusCofreProgreso;

  bool get animandoCofre => _animacionCofreEnCurso;

  void notificar() => notifyListeners();

  /// Tras reclamar un cofre: +N arriba de la burbuja y contador subiendo.
  Future<void> animarSumaCofre(int sumadas) async {
    if (sumadas <= 0) return;
    _animacionCofreEnCurso = true;
    final hasta = monedas;
    final desde = (hasta - sumadas).clamp(0, hasta);
    _bonusCofre = sumadas;
    _bonusCofreProgreso = 0;
    _animandoMonedas = true;
    _monedasAnimadas = desde;
    notifyListeners();

    const pasos = 36;
    const duracionMs = 1100;
    final stepMs = duracionMs ~/ pasos;

    for (var i = 1; i <= pasos; i++) {
      await Future<void>.delayed(Duration(milliseconds: stepMs));
      final t = i / pasos;
      _monedasAnimadas = desde + ((hasta - desde) * t).round();
      _bonusCofreProgreso = t;
      notifyListeners();
    }

    _monedasAnimadas = hasta;
    _animandoMonedas = false;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 500));
    _bonusCofre = null;
    _bonusCofreProgreso = 0;
    _animacionCofreEnCurso = false;
    notifyListeners();
  }

  /// +3 monedas y +3 puntos ranking si hay sesión y el humano ganó vs PC.
  Future<void> premiarVictoriaPcSiCorresponde({
    required bool contraPc,
    required bool online,
    required bool ganoHumano,
    String? juegoId,
  }) async {
    if (!contraPc || online || !ganoHumano) return;
    if (!UsuarioMongoService.instance.haySesion) return;
    try {
      await UsuarioMongoService.instance.sumarMonedasVictoriaPc(
        juegoId: juegoId,
      );
      notifyListeners();
    } catch (_) {
      // Red / backend: no bloquea la UI de victoria.
    }
  }

  /// Si gané online y había apuesta, cobro el pozo (monedas + ranking).
  Future<void> resolverApuestaOnlineSiGane({
    required bool online,
    required bool ganeYo,
    String? salaCodigo,
    String? juegoId,
  }) async {
    if (!online || !ganeYo) return;
    if (!UsuarioMongoService.instance.haySesion) return;
    final codigo = (salaCodigo ?? ApuestaOnlineStore.codigoSala)?.trim();
    final juego = juegoId ?? ApuestaOnlineStore.juegoId;
    final apuesta = ApuestaOnlineStore.apuestaMonedas;
    if (codigo == null ||
        codigo.isEmpty ||
        juego == null ||
        juego.isEmpty ||
        apuesta <= 0) {
      return;
    }
    try {
      await UsuarioMongoService.instance.resolverApuesta(
        codigoSala: codigo,
        juegoId: juego,
      );
      ApuestaOnlineStore.limpiar();
      notifyListeners();
    } catch (_) {}
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

/// ¿Gané yo la partida online? (para cobrar el pozo de apuestas).
bool ganePartidaOnline({
  required bool online,
  required String? ganador,
  required String? miNombre,
}) {
  if (!online) return false;
  final g = ganador?.trim();
  final m = miNombre?.trim();
  if (g == null || g.isEmpty || m == null || m.isEmpty) return false;
  return g == m;
}
