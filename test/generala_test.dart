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
    final j = JugadorGenerala('A');
    expect(
      puedeElegirCategoria(j, CategoriaGenerala.generalaDoble),
      isTrue,
    );
  });

  test('generala no se tacha hasta anotar generala doble', () {
    final j = JugadorGenerala('A');
    final basura = [1, 2, 3, 4, 6];
    expect(
      puedeElegirCategoria(j, CategoriaGenerala.generala,
          dados: basura, servida: false),
      isFalse,
    );
    expect(
      puedeElegirCategoria(j, CategoriaGenerala.generalaDoble,
          dados: basura, servida: false),
      isTrue,
    );
    // Sí se puede anotar generala si salió de verdad.
    expect(
      puedeElegirCategoria(j, CategoriaGenerala.generala,
          dados: [5, 5, 5, 5, 5], servida: false),
      isTrue,
    );
    j.casillas[CategoriaGenerala.generalaDoble] = 0;
    expect(
      puedeElegirCategoria(j, CategoriaGenerala.generala,
          dados: basura, servida: false),
      isTrue,
    );
  });

  test('PC tacha doble, luego generala, luego números bajos', () {
    final j = JugadorGenerala('A');
    // Sin puntos útiles en casillas libres (números de estos dados ya llenos).
    final dados = [2, 2, 3, 3, 4];
    j.casillas[CategoriaGenerala.dos] = 4;
    j.casillas[CategoriaGenerala.tres] = 6;
    j.casillas[CategoriaGenerala.cuatro] = 4;
    j.casillas[CategoriaGenerala.full] = 30;
    j.casillas[CategoriaGenerala.poker] = 40;

    expect(
      elegirCategoriaPc(j, dados, servida: false),
      CategoriaGenerala.generalaDoble,
    );
    j.casillas[CategoriaGenerala.generalaDoble] = 0;
    expect(
      elegirCategoriaPc(j, dados, servida: false),
      CategoriaGenerala.generala,
    );
    j.casillas[CategoriaGenerala.generala] = 0;
    // Números bajos libres primero (1 antes que 5/6/escalera).
    expect(
      elegirCategoriaPc(j, dados, servida: false),
      CategoriaGenerala.uno,
    );
    j.casillas[CategoriaGenerala.uno] = 0;
    expect(
      elegirCategoriaPc(j, dados, servida: false),
      CategoriaGenerala.cinco,
    );
  });

  test('PC prefiere puntos positivos antes de tachar', () {
    final j = JugadorGenerala('A');
    j.casillas[CategoriaGenerala.generalaDoble] = 0;
    expect(
      elegirCategoriaPc(j, [2, 2, 2, 5, 5], servida: false),
      CategoriaGenerala.full,
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
    expect(p.jugadores[0].historial, hasLength(1));
    expect(p.jugadores[0].historial.first.tiradasUsadas, 3);
    expect(p.jugadores[0].historial.first.categoria, CategoriaGenerala.uno);
    expect(p.jugadores[0].historial.first.puntos, 2);
    expect(p.indiceTurno, 1);
  });

  test('escalera 12345 y 23456', () {
    expect(esEscalera([1, 2, 3, 4, 5]), isTrue);
    expect(esEscalera([5, 4, 1, 2, 3]), isTrue);
    expect(esEscalera([2, 3, 4, 5, 6]), isTrue);
    expect(esEscalera([1, 2, 3, 4, 6]), isFalse);
    expect(
      puntosCategoria(CategoriaGenerala.escalera, [1, 2, 3, 4, 5],
          yaTieneGenerala: false),
      ptsEscalera,
    );
    expect(
      puntosCategoria(CategoriaGenerala.escalera, [2, 3, 4, 5, 6],
          yaTieneGenerala: false, servida: true),
      ptsEscaleraServida,
    );
  });

  test('full y poker servidos suman bonus', () {
    expect(
      puntosCategoria(CategoriaGenerala.full, [2, 2, 2, 5, 5],
          yaTieneGenerala: false, servida: true),
      ptsFullServida,
    );
    expect(
      puntosCategoria(CategoriaGenerala.poker, [4, 4, 4, 4, 1],
          yaTieneGenerala: false, servida: true),
      ptsPokerServida,
    );
  });

  test('casilla ocupada no se puede volver a anotar', () {
    final p = nuevaPartidaGenerala(['A', 'B']);
    iniciarTurnoGenerala(p);
    tirarDadosGenerala(p.turno, dadosForzados: [4, 4, 4, 4, 1]);
    anotarCategoria(p, CategoriaGenerala.poker);
    expect(p.jugadores[0].casillas[CategoriaGenerala.poker], ptsPokerServida);
    expect(puedeElegirCategoria(p.jugadores[0], CategoriaGenerala.poker), isFalse);

    // Turno de B y vuelve A.
    tirarDadosGenerala(p.turno, dadosForzados: [2, 2, 3, 3, 4]);
    anotarCategoria(p, CategoriaGenerala.dos);

    tirarDadosGenerala(p.turno, dadosForzados: [5, 5, 5, 5, 5]);
    expect(puedeElegirCategoria(p.jugadores[0], CategoriaGenerala.poker), isFalse);
    expect(puedeElegirCategoria(p.jugadores[0], CategoriaGenerala.generala), isTrue);
    // Generala no vale como poker.
    expect(
      puntosCategoria(CategoriaGenerala.poker, [5, 5, 5, 5, 5],
          yaTieneGenerala: false),
      0,
    );
    expect(
      () => anotarCategoria(p, CategoriaGenerala.poker),
      throwsStateError,
    );
    anotarCategoria(p, CategoriaGenerala.generala);
    expect(p.jugadores[0].casillas[CategoriaGenerala.poker], ptsPokerServida);
    expect(p.jugadores[0].casillas[CategoriaGenerala.generala], ptsGenerala);
  });

  test('anotar temprano solo si la casilla del especial sigue libre', () {
    final j = JugadorGenerala('A');
    final full = [2, 2, 2, 5, 5];
    expect(puedeAnotarTemprano(j, full), isTrue);

    j.casillas[CategoriaGenerala.full] = ptsFull;
    expect(puedeAnotarTemprano(j, full), isFalse);

    final escalera = [1, 2, 3, 4, 5];
    expect(puedeAnotarTemprano(j, escalera), isTrue);
    j.casillas[CategoriaGenerala.escalera] = ptsEscalera;
    expect(puedeAnotarTemprano(j, escalera), isFalse);

    final poker = [4, 4, 4, 4, 1];
    // Póker no abre anotar temprano: aún se puede buscar generala.
    expect(puedeAnotarTemprano(j, poker), isFalse);

    final generala = [6, 6, 6, 6, 6];
    expect(puedeAnotarTemprano(j, generala), isTrue);
    j.casillas[CategoriaGenerala.generala] = ptsGenerala;
    // Ya tiene generala: ahora sirve para doble.
    expect(puedeAnotarTemprano(j, generala), isTrue);
    j.casillas[CategoriaGenerala.generalaDoble] = ptsGeneralaDoble;
    // Ambas generalas llenas: aún se puede sumar en el número (6).
    expect(puedeAnotarTemprano(j, generala), isTrue);
    j.casillas[CategoriaGenerala.seis] = 30;
    expect(puedeAnotarTemprano(j, generala), isFalse);
  });

  test('auto-selecciona iguales y suma los que matchean lo guardado', () {
    final j = JugadorGenerala('A');
    final t = EstadoTurnoGenerala();
    tirarDadosGenerala(t, dadosForzados: [1, 1, 1, 4, 5]);
    autoSeleccionarDadosUtiles(j, t);
    expect(t.guardados.where((g) => g).length, 3);
    expect(t.dados.take(3).toList(), [1, 1, 1]);

    // Segunda tirada: salen dos 1 → también dorados.
    tirarDadosGenerala(t, dadosForzados: [1, 1]);
    autoSeleccionarDadosUtiles(j, t);
    expect(t.guardados.every((g) => g), isTrue);
    expect(t.dados, [1, 1, 1, 1, 1]);
  });

  test('auto-selecciona full y escalera completos', () {
    final j = JugadorGenerala('A');
    final t = EstadoTurnoGenerala();
    tirarDadosGenerala(t, dadosForzados: [2, 2, 2, 5, 5]);
    autoSeleccionarDadosUtiles(j, t);
    expect(t.guardados.every((g) => g), isTrue);

    final t2 = EstadoTurnoGenerala();
    tirarDadosGenerala(t2, dadosForzados: [1, 2, 3, 4, 5]);
    autoSeleccionarDadosUtiles(j, t2);
    expect(t2.guardados.every((g) => g), isTrue);
  });

  test('auto-selecciona los dos pares', () {
    final j = JugadorGenerala('A');
    final t = EstadoTurnoGenerala();
    tirarDadosGenerala(t, dadosForzados: [5, 5, 4, 2, 4]);
    autoSeleccionarDadosUtiles(j, t);
    expect(t.guardados.where((g) => g).length, 4);
    expect(t.dados.take(4).toSet(), {5, 4});
    expect(t.dados.last, 2);
    expect(t.guardados.last, isFalse);
  });

  test('no auto-selecciona pares de números ya anotados si full está lleno', () {
    final j = JugadorGenerala('A');
    j.casillas[CategoriaGenerala.tres] = 9;
    j.casillas[CategoriaGenerala.seis] = 12;
    j.casillas[CategoriaGenerala.full] = ptsFull;
    j.casillas[CategoriaGenerala.generala] = ptsGenerala;
    // Quedan libres: 1, escalera, poker, doble…
    final t = EstadoTurnoGenerala();
    tirarDadosGenerala(t, dadosForzados: [6, 3, 6, 3, 4]);
    autoSeleccionarDadosUtiles(j, t);
    // No marca los dos pares; arma hacia escalera (3, 4, 6).
    expect(t.guardados.where((g) => g).length, 3);
    expect(t.dados.take(3).toSet(), {3, 4, 6});
  });

  test('PC suelta un par si full/poker llenos y busca generala', () {
    final j = JugadorGenerala('PC');
    for (final c in CategoriaGenerala.values) {
      if (c.esNumero) j.casillas[c] = c.cara! * 2;
    }
    j.casillas[CategoriaGenerala.full] = ptsFull;
    j.casillas[CategoriaGenerala.poker] = ptsPoker;
    j.casillas[CategoriaGenerala.escalera] = 0;
    // Solo generala libre → un solo par.
    final t = EstadoTurnoGenerala();
    tirarDadosGenerala(t, dadosForzados: [3, 3, 4, 4, 2]);
    elegirGuardadosPc(j, t);
    expect(t.guardados.where((g) => g).length, 2);
    expect(t.dados.take(2).toSet(), {4}); // cara más alta del empate de pares
  });

  test('PC arma escalera si es lo único libre', () {
    final j = JugadorGenerala('PC');
    for (final c in CategoriaGenerala.values) {
      if (c != CategoriaGenerala.escalera) {
        j.casillas[c] = 0;
      }
    }
    final t = EstadoTurnoGenerala();
    tirarDadosGenerala(t, dadosForzados: [3, 3, 4, 4, 5]);
    elegirGuardadosPc(j, t);
    // Un 3, un 4 y el 5 hacia escalera (no los dos pares).
    expect(t.guardados.where((g) => g).length, 3);
    expect(t.dados.take(3).toSet(), {3, 4, 5});
  });
}
