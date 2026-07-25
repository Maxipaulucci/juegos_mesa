import 'package:flutter_test/flutter_test.dart';

import 'package:app_juegos_mesa/diezMil/motor.dart';

void main() {
  test('tres unos suman 1000', () {
    final r = analizarTirada([1, 1, 1, 2, 3], Modo.cinco);
    expect(puntosDeCombos(r.combosAuto), 1000);
  });

  test('farkle deja 0 puntos', () {
    final partida = nuevaPartida(['A', 'B'], Modo.cinco);
    iniciarTurno(partida);
    final resultado = ejecutarTirada(partida, dadosForzados: [2, 3, 4, 6, 6]);
    final resumen = aplicarPuntosTirada(partida, resultado);
    expect(resumen.bust, isTrue);
    expect(resumen.puntosTirada, 0);
  });

  test('escalera de 5 dados', () {
    final r = analizarTirada([1, 2, 3, 4, 5], Modo.cinco);
    expect(r.combosAuto.single.nombre, 'escalera');
    expect(r.combosAuto.single.puntos, 500);
  });

  test('cinco unos gana automáticamente', () {
    final r = analizarTirada([1, 1, 1, 1, 1], Modo.cinco);
    expect(r.victoriaInmediata, isTrue);

    final partida = nuevaPartida(['A', 'B'], Modo.cinco);
    iniciarTurno(partida);
    final resultado = ejecutarTirada(partida, dadosForzados: [1, 1, 1, 1, 1]);
    final resumen = aplicarPuntosTirada(partida, resultado);
    expect(resumen.victoria, isTrue);
    expect(partida.ganador, 'A');
    expect(partida.jugadorActual.puntos, meta);
  });

  test('apertura requiere 750', () {
    final partida = nuevaPartida(['A', 'B'], Modo.cinco);
    iniciarTurno(partida);
    partida.turno.puntosTurno = 700;
    final banco = plantarse(partida);
    expect(banco.ok, isFalse);
    expect(banco.motivo, 'apertura');
  });

  test('sin abrir no se puede plantar antes de 750', () {
    final partida = nuevaPartida(['A', 'B'], Modo.cinco);
    iniciarTurno(partida);

    partida.turno.puntosTurno = 50;
    expect(puedePlantarse(partida), isFalse);

    partida.turno.puntosTurno = 749;
    expect(puedePlantarse(partida), isFalse);

    partida.turno.puntosTurno = 750;
    expect(puedePlantarse(partida), isTrue);
  });

  test('ya abierto puede plantarse con pocos puntos', () {
    final partida = nuevaPartida(['A', 'B'], Modo.cinco);
    iniciarTurno(partida);
    partida.jugadorActual.abierto = true;
    partida.turno.puntosTurno = 50;
    expect(puedePlantarse(partida), isTrue);
  });
}
