import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:app_juegos_mesa/laPapa/motor_la_papa.dart';

void main() {
  test('consecutivos separados y fuera de misma fila/columna', () {
    for (var i = 0; i < 30; i++) {
      final p = nuevaPartidaPapa(nombres: const ['A'], semilla: i * 97 + 3);
      expect(p.casillas.whereType<int>().length, maxNumeroPapa);
      for (var n = 1; n < maxNumeroPapa; n++) {
        final a = p.indiceDeNumero(n)!;
        final b = p.indiceDeNumero(n + 1)!;
        expect(
          posicionesConsecutivasValidasPapa(a, b),
          isTrue,
          reason: 'falla $n->$n+1 en semilla $i',
        );
      }
    }
  });

  test('cruzar un trazo previo pierde al toque', () {
    const board = Size(200, 400);
    // Misma columna: línea vertical 1→2 (como en la captura).
    final c1 = centroCasillaPapa(47, board); // fila 9, col 2
    final c2 = centroCasillaPapa(2, board); // fila 0, col 2

    final casillas = List<int?>.filled(totalCasillasPapa, null);
    casillas[47] = 1;
    casillas[2] = 2;
    casillas[40] = 3;

    final p = PartidaPapa(
      nombres: const ['A', 'B'],
      casillas: casillas,
      siguienteConectar: 2,
      indiceTurno: 1,
      trazos: [
        TrazoPapa(
          puntos: [
            c1,
            Offset(c1.dx, c1.dy * 0.65 + c2.dy * 0.35),
            Offset(c1.dx, c1.dy * 0.35 + c2.dy * 0.65),
            c2,
          ],
          de: 1,
          a: 2,
          jugador: 'A',
        ),
      ],
    );

    // Sale del 2 y cruza en X la línea vertical 1→2.
    final trazoCruza = <Offset>[
      c2,
      Offset(c2.dx + 12, c2.dy + 25),
      Offset(c2.dx - 35, c2.dy + 140),
    ];
    expect(
      trazoChocaConPreviosPapa(p, trazoCruza, boardSize: board),
      isTrue,
    );

    // Sale del 2 hacia un costado libre, sin cruzar.
    final trazoLibre = <Offset>[
      c2,
      Offset(c2.dx + 55, c2.dy + 10),
      Offset(c2.dx + 80, c2.dy + 90),
    ];
    expect(
      trazoChocaConPreviosPapa(p, trazoLibre, boardSize: board),
      isFalse,
    );
  });
}
