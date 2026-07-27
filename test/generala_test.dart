import 'package:flutter_test/flutter_test.dart';

import 'package:app_juegos_mesa/generala/motor_generala.dart';

void main() {
  test('números suman cara × cantidad', () {
    expect(
      puntosCategoria(CategoriaGenerala.uno, [1, 1, 3, 6, 2],
          yaTieneGenerala: false),
      2,
    );
    expect(
      puntosCategoria(CategoriaGenerala.seis, [6, 6, 6, 4, 3],
          yaTieneGenerala: false),
      18,
    );
  });

  test('full, poker y generala', () {
    expect(esFull([2, 2, 2, 5, 5]), isTrue);
    expect(
      puntosCategoria(CategoriaGenerala.full, [2, 2, 2, 5, 5],
          yaTieneGenerala: false),
      ptsFull,
    );
    expect(
      puntosCategoria(CategoriaGenerala.poker, [4, 4, 4, 4, 1],
          yaTieneGenerala: false),
      ptsPoker,
    );
    expect(
      puntosCategoria(CategoriaGenerala.generala, [3, 3, 3, 3, 3],
          yaTieneGenerala: false),
      ptsGenerala,
    );
  });

  test('generala doble requiere generala previa', () {
    expect(
      puntosCategoria(CategoriaGenerala.generalaDoble, [6, 6, 6, 6, 6],
          yaTieneGenerala: false),
      0,
    );
    expect(
      puntosCategoria(CategoriaGenerala.generalaDoble, [6, 6, 6, 6, 6],
          yaTieneGenerala: true),
      ptsGeneralaDoble,
    );
  });

  test('turno: 3 tiradas y anotar pasa al siguiente', () {
    final p = nuevaPartidaGenerala(['A', 'B']);
    iniciarTurnoGenerala(p);
    tirarDadosGenerala(p.turno, dadosForzados: [1, 1, 2, 3, 4]);
    expect(p.turno.tiradasHechas, 1);
    expect(p.turno.puedeAnotar, isTrue);
    // Guarda los dos 1 a la izquierda.
    p.turno.guardados[0] = true;
    p.turno.guardados[1] = true;
    tirarDadosGenerala(p.turno, dadosForzados: [5, 6, 2]);
    expect(p.turno.dados[0], 1);
    expect(p.turno.dados[1], 1);
    expect(p.turno.guardados[0], isTrue);
    expect(p.turno.guardados[1], isTrue);
    expect(p.turno.guardados[2], isFalse);
    tirarDadosGenerala(p.turno, dadosForzados: [3, 4, 5]);
    expect(p.turno.debeAnotar, isTrue);
    anotarCategoria(p, CategoriaGenerala.uno);
    expect(p.jugadores[0].casillas[CategoriaGenerala.uno], 2);
    expect(p.indiceTurno, 1);
  });
}
