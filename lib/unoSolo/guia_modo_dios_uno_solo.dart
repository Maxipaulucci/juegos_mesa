import 'package:app_juegos_mesa/unoSolo/motor_uno_solo.dart';

/// Numeración Durango Bill (centro = 16) → índice 7×7 de [PartidaUnoSolo].
const _mapaDurangoATablero = <int>[
  // 0..2 fila superior
  2, 3, 4,
  // 3..5
  9, 10, 11,
  // 6..12
  14, 15, 16, 17, 18, 19, 20,
  // 13..19 (16 = centro → 24)
  21, 22, 23, 24, 25, 26, 27,
  // 20..26
  28, 29, 30, 31, 32, 33, 34,
  // 27..29
  37, 38, 39,
  // 30..32
  44, 45, 46,
];

/// Solución conocida (centro vacío → una ficha en el centro).
/// Fuente: secuencia de Durango Bill convertida a índices del tablero.
const _saltosDurango = <(int, int)>[
  (4, 16),
  (7, 9),
  (0, 8),
  (2, 0),
  (9, 7),
  (6, 8),
  (10, 2),
  (12, 10),
  (15, 3),
  (0, 8),
  (13, 15),
  (15, 3),
  (17, 5),
  (2, 10),
  (19, 17),
  (17, 5),
  (27, 15),
  (20, 22),
  (22, 8),
  (3, 15),
  (15, 17),
  (24, 10),
  (5, 17),
  (26, 24),
  (23, 25),
  (32, 24),
  (17, 29),
  (30, 32),
  (32, 24),
  (25, 23),
  (28, 16),
];

int _medioEntre(int desde, int hasta) {
  final (f0, c0) = PartidaUnoSolo.filaCol(desde);
  final (f1, c1) = PartidaUnoSolo.filaCol(hasta);
  return PartidaUnoSolo.indexOf((f0 + f1) ~/ 2, (c0 + c1) ~/ 2);
}

/// Guía de solución para Modo Dios (tutorial).
class GuiaModoDiosUnoSolo {
  GuiaModoDiosUnoSolo._({
    required this.movimientos,
    required this.ordenEliminacion,
  });

  final List<MovimientoUnoSolo> movimientos;
  /// Índice de casilla → paso (1..) en que esa ficha es eliminada.
  final Map<int, int> ordenEliminacion;

  factory GuiaModoDiosUnoSolo.estandar() {
    final movs = <MovimientoUnoSolo>[];
    final orden = <int, int>{};
    var paso = 0;
    for (final (dDur, hDur) in _saltosDurango) {
      final desde = _mapaDurangoATablero[dDur];
      final hasta = _mapaDurangoATablero[hDur];
      final medio = _medioEntre(desde, hasta);
      paso++;
      orden[medio] = paso;
      movs.add(
        MovimientoUnoSolo(desde: desde, medio: medio, hasta: hasta),
      );
    }
    return GuiaModoDiosUnoSolo._(
      movimientos: movs,
      ordenEliminacion: orden,
    );
  }

  /// Próximo salto de la guía que sigue siendo legal en [p].
  MovimientoUnoSolo? proximoLegal(PartidaUnoSolo p) {
    for (final m in movimientos) {
      final ok = movimientosDesdeUnoSolo(p, m.desde).any(
            (x) =>
                x.desde == m.desde && x.medio == m.medio && x.hasta == m.hasta,
          );
      if (ok) return m;
    }
    return null;
  }
}
