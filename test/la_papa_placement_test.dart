import 'dart:math' as math;
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

  test('entrar al número por lado libre con línea que lo atraviesa', () {
    const board = Size(200, 400);
    final idx7 = 22; // fila 4, col 2
    final c7 = centroCasillaPapa(idx7, board);
    final cell = math.min(board.width / columnasPapa, board.height / filasPapa);
    final radio = cell * 0.32;

    final casillas = List<int?>.filled(totalCasillasPapa, null);
    casillas[0] = 5;
    casillas[47] = 6;
    casillas[idx7] = 7;

    // Línea vertical por el centro del 7 (tapa arriba/abajo, no izquierda).
    final atravesando = TrazoPapa(
      puntos: [
        Offset(c7.dx, c7.dy - radio - 30),
        Offset(c7.dx, c7.dy - radio - 2),
        Offset(c7.dx, c7.dy + radio + 2),
        Offset(c7.dx, c7.dy + radio + 30),
      ],
      de: 5,
      a: 6,
      jugador: 'A',
    );

    final p = PartidaPapa(
      nombres: const ['A', 'B'],
      casillas: casillas,
      siguienteConectar: 6,
      indiceTurno: 1,
      trazos: [atravesando],
    );

    // Entrada por la izquierda: lado libre.
    final entradaLibre = <Offset>[
      Offset(c7.dx - radio - 40, c7.dy),
      Offset(c7.dx - radio - 2, c7.dy),
      c7,
    ];
    expect(
      llegadaPorLadoBloqueadoPapa(p, 7, entradaLibre, board),
      isFalse,
    );

    // Entrada por abajo, encima de la tinta.
    final entradaBloqueada = <Offset>[
      Offset(c7.dx, c7.dy + radio + 40),
      Offset(c7.dx, c7.dy + radio + 1),
      c7,
    ];
    expect(
      llegadaPorLadoBloqueadoPapa(p, 7, entradaBloqueada, board),
      isTrue,
    );
  });

  test('reescalar trazos mantiene proporción al cambiar el tablero', () {
    const desde = Size(200, 400);
    const hacia = Size(100, 200);
    final p = PartidaPapa(
      nombres: const ['A'],
      casillas: List<int?>.filled(totalCasillasPapa, null),
      trazos: [
        TrazoPapa(
          puntos: const [Offset(40, 80), Offset(160, 320)],
          de: 1,
          a: 2,
          jugador: 'A',
        ),
      ],
    );
    reescalarTrazosPapa(p, desde, hacia);
    expect(p.trazos.first.puntos, const [Offset(20, 40), Offset(80, 160)]);
  });

  test('tocar la propia línea cuenta como choque', () {
    const board = Size(200, 400);
    // Trazo en forma de bucle: la punta cruza el tramo inicial.
    final bucle = <Offset>[
      const Offset(40, 40),
      const Offset(40, 120),
      const Offset(40, 200),
      const Offset(100, 200),
      const Offset(100, 120),
      const Offset(20, 120), // cruza el tramo vertical x=40
    ];
    expect(
      trazoSeTocaASiMismoPapa(bucle, boardSize: board),
      isTrue,
    );

    final recto = <Offset>[
      const Offset(40, 40),
      const Offset(40, 100),
      const Offset(40, 160),
      const Offset(40, 220),
    ];
    expect(
      trazoSeTocaASiMismoPapa(recto, boardSize: board),
      isFalse,
    );
  });
}
