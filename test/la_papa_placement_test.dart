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
      maxNumero: maxNumeroPapa,
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
      maxNumero: maxNumeroPapa,
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

  test('tinta que atraviesa el círculo verde colisiona al roce', () {
    const board = Size(200, 400);
    final idx5 = 12; // fila 2, col 2
    final c5 = centroCasillaPapa(idx5, board);
    final cell = math.min(board.width / columnasPapa, board.height / filasPapa);
    final radioVerde = cell * factorRadioVerificacionPapa;

    final casillas = List<int?>.filled(totalCasillasPapa, null);
    casillas[47] = 4;
    casillas[idx5] = 5;
    casillas[0] = 6;

    // Línea rival que cruza el círculo verde del 5 (no solo la punta).
    final rival = TrazoPapa(
      puntos: [
        Offset(c5.dx - radioVerde - 20, c5.dy),
        Offset(c5.dx - radioVerde * 0.4, c5.dy),
        Offset(c5.dx + radioVerde * 0.4, c5.dy),
        Offset(c5.dx + radioVerde + 20, c5.dy),
      ],
      de: 1,
      a: 2,
      jugador: 'B',
    );
    // Llegada propia al 5 desde abajo (punta ignorada al despegar).
    final llegada = TrazoPapa(
      puntos: [
        Offset(c5.dx, c5.dy + radioVerde + 40),
        Offset(c5.dx, c5.dy + 4),
        c5,
      ],
      de: 4,
      a: 5,
      jugador: 'A',
    );

    final p = PartidaPapa(
      nombres: const ['A', 'B'],
      casillas: casillas,
      maxNumero: maxNumeroPapa,
      siguienteConectar: 5,
      trazos: [rival, llegada],
    );

    // Sale hacia arriba libre: todavía no toca la tinta horizontal.
    final libre = <Offset>[
      c5,
      Offset(c5.dx, c5.dy - radioVerde * 0.5),
      Offset(c5.dx, c5.dy - radioVerde - 10),
    ];
    expect(
      trazoChocaConPreviosPapa(p, libre, boardSize: board),
      isFalse,
    );

    // Sigue trazando hasta rozar la línea que atraviesa el círculo.
    final choca = <Offset>[
      c5,
      Offset(c5.dx, c5.dy - 6),
      Offset(c5.dx - radioVerde * 0.35, c5.dy - 2),
      Offset(c5.dx - radioVerde * 0.35, c5.dy), // sobre la tinta rival
    ];
    expect(
      trazoChocaConPreviosPapa(p, choca, boardSize: board),
      isTrue,
    );
  });

  test('zona del número cortada por una línea: visión al centro', () {
    const board = Size(200, 400);
    final idx3 = 22; // centro
    final c3 = centroCasillaPapa(idx3, board);
    final cell = math.min(board.width / columnasPapa, board.height / filasPapa);
    final radio = cell * factorRadioVerificacionPapa;

    final casillas = List<int?>.filled(totalCasillasPapa, null);
    casillas[2] = 1;
    casillas[47] = 2;
    casillas[idx3] = 3;

    // Línea vertical que parte el círculo del 3 a la derecha del centro
    // (como el 1→2 pasando por un costado de la zona).
    final corta = TrazoPapa(
      puntos: [
        Offset(c3.dx + radio * 0.25, c3.dy - radio - 40),
        Offset(c3.dx + radio * 0.25, c3.dy - radio * 0.2),
        Offset(c3.dx + radio * 0.25, c3.dy + radio * 0.2),
        Offset(c3.dx + radio * 0.25, c3.dy + radio + 40),
      ],
      de: 1,
      a: 2,
      jugador: 'A',
    );

    final p = PartidaPapa(
      nombres: const ['A'],
      casillas: casillas,
      maxNumero: maxNumeroPapa,
      siguienteConectar: 3,
      trazos: [corta],
    );

    // Lado izquierdo: ve el centro sin cruzar tinta → habilitada.
    final izq = Offset(c3.dx - radio * 0.55, c3.dy);
    expect(puntoEnZonaHabilitadaPapa(p, 3, izq, board), isTrue);

    // Lado derecho (detrás del corte): no ve el centro → no habilitada.
    final der = Offset(c3.dx + radio * 0.7, c3.dy);
    expect(puntoEnZonaHabilitadaPapa(p, 3, der, board), isFalse);

    // Encima de la tinta: no habilitada.
    final sobreTinta = Offset(c3.dx + radio * 0.25, c3.dy);
    expect(puntoEnZonaHabilitadaPapa(p, 3, sobreTinta, board), isFalse);
  });

  test('reescalar trazos mantiene proporción al cambiar el tablero', () {
    const desde = Size(200, 400);
    const hacia = Size(100, 200);
    final p = PartidaPapa(
      nombres: const ['A'],
      casillas: List<int?>.filled(totalCasillasPapa, null),
      maxNumero: maxNumeroPapa,
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
      const Offset(40, 80),
      const Offset(40, 120),
      const Offset(40, 160),
      const Offset(40, 200),
      const Offset(70, 200),
      const Offset(100, 200),
      const Offset(100, 160),
      const Offset(100, 120),
      const Offset(20, 120), // cruza el tramo vertical x=40
    ];
    expect(
      trazoSeTocaASiMismoPapa(bucle, boardSize: board),
      isTrue,
    );

    final recto = <Offset>[
      for (var i = 0; i <= 20; i++) Offset(40, 40.0 + i * 12),
    ];
    expect(
      trazoSeTocaASiMismoPapa(recto, boardSize: board),
      isFalse,
    );
  });

  test('cruzar cerca del destino también pierde', () {
    const board = Size(200, 400);
    final c7 = centroCasillaPapa(47, board); // abajo
    final c8 = centroCasillaPapa(0, board); // arriba-izquierda

    final casillas = List<int?>.filled(totalCasillasPapa, null);
    casillas[47] = 7;
    casillas[0] = 8;

    // Línea horizontal que el trazo 7→8 debe cruzar cerca del 8.
    final barrera = TrazoPapa(
      puntos: [
        Offset(c8.dx - 40, c8.dy + 35),
        Offset(c8.dx + 40, c8.dy + 35),
      ],
      de: 1,
      a: 2,
      jugador: 'A',
    );

    final p = PartidaPapa(
      nombres: const ['A', 'B'],
      casillas: casillas,
      maxNumero: maxNumeroPapa,
      siguienteConectar: 7,
      trazos: [barrera],
    );

    final trazoCruza = <Offset>[
      c7,
      Offset(c7.dx, (c7.dy + c8.dy) / 2),
      Offset(c8.dx, c8.dy + 35), // sobre la barrera
      c8,
    ];
    expect(
      trazoChocaConPreviosPapa(p, trazoCruza, boardSize: board),
      isTrue,
    );
  });

  test('roce visual de trazos gruesos cuenta aunque los ejes no se crucen', () {
    const board = Size(200, 400);
    final c2 = centroCasillaPapa(2, board);

    final casillas = List<int?>.filled(totalCasillasPapa, null);
    casillas[47] = 1;
    casillas[2] = 2;
    casillas[40] = 3;

    // Vertical en x = 100.
    final previo = TrazoPapa(
      puntos: const [
        Offset(100, 50),
        Offset(100, 350),
      ],
      de: 1,
      a: 2,
      jugador: 'A',
      grosor: GrosorTrazoPapa.grueso,
    );

    final p = PartidaPapa(
      nombres: const ['A', 'B'],
      casillas: casillas,
      maxNumero: maxNumeroPapa,
      siguienteConectar: 2,
      indiceTurno: 1,
      trazos: [previo],
    );

    // Horizontal que pasa a ~3px del eje vertical: se tocan a ojo con grueso.
    final roce = <Offset>[
      c2,
      const Offset(103.2, 80),
      const Offset(160, 80),
    ];
    expect(
      trazoChocaConPreviosPapa(
        p,
        roce,
        boardSize: board,
        grosorActual: GrosorTrazoPapa.grueso,
      ),
      isTrue,
    );
  });
}
