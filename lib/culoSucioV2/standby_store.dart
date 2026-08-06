import 'package:app_juegos_mesa/culoSucioV2/motor_culo_sucio_v2.dart';
import 'package:app_juegos_mesa/culoSucioV2/opciones_culo_sucio_v2.dart';
import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';

/// Resume en memoria para partidas vs PC (se pierde al reiniciar la app).
class PartidaCuloSucioV2Resume {
  PartidaCuloSucioV2Resume({
    required this.partida,
    required this.nombres,
    this.modoDios = false,
    this.opciones = const OpcionesCuloSucioV2(),
    this.ajustesIniciales = const AjustesEstado(),
  });

  final PartidaCuloSucioV2 partida;
  final List<String> nombres;
  final bool modoDios;
  final OpcionesCuloSucioV2 opciones;
  final AjustesEstado ajustesIniciales;
}

class CuloSucioV2StandByStore {
  CuloSucioV2StandByStore._();

  static PartidaCuloSucioV2Resume? _resume;

  static void guardar(PartidaCuloSucioV2Resume resume) {
    _resume = resume;
  }

  static PartidaCuloSucioV2Resume? consumir() {
    final r = _resume;
    _resume = null;
    return r;
  }

  static void limpiar() {
    _resume = null;
  }
}
