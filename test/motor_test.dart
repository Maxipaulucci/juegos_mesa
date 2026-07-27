import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_juegos_mesa/diezMil/ia_diez_mil.dart';
import 'package:app_juegos_mesa/diezMil/motor.dart';

/// nextDouble siempre alto: nunca dispara el error humano ni chances random.
class _RngSinError implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0.99;

  @override
  int nextInt(int max) => max - 1;
}

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

  test('pasarse de 10000 anula el turno al aplicar la tirada', () {
    final partida = nuevaPartida(['A', 'B'], Modo.cinco);
    iniciarTurno(partida);
    partida.jugadorActual.abierto = true;
    partida.jugadorActual.puntos = 9950;

    final resultado = ejecutarTirada(partida, dadosForzados: [1, 2, 3, 4, 6]);
    final resumen = aplicarPuntosTirada(partida, resultado);

    expect(resumen.pasado, isTrue);
    expect(resumen.intentoTotal, 10050);
    expect(partida.turno.puntosTurno, 0);
    expect(partida.jugadorActual.puntos, 9950);
    expect(partida.ganador, isNull);
  });

  test('llegar exacto a 10000 gana al aplicar la tirada', () {
    final partida = nuevaPartida(['A', 'B'], Modo.cinco);
    iniciarTurno(partida);
    partida.jugadorActual.abierto = true;
    partida.jugadorActual.puntos = 9900;

    final resultado = ejecutarTirada(partida, dadosForzados: [1, 2, 3, 4, 6]);
    final resumen = aplicarPuntosTirada(partida, resultado);

    expect(resumen.victoria, isTrue);
    expect(partida.jugadorActual.puntos, meta);
    expect(partida.ganador, 'A');
  });

  test('especial que supera 10000 se descarta y usa combos normales', () {
    final partida = nuevaPartida(['A', 'B'], Modo.seis);
    iniciarTurno(partida);
    partida.jugadorActual.abierto = true;
    partida.jugadorActual.puntos = 8550;

    final tirada =
        ejecutarTirada(partida, dadosForzados: [1, 1, 2, 2, 3, 3]);
    expect(tirada.combosOpcionales.single.puntos, 1500);

    final filtrada = filtrarEspecialesQuePasanMeta(partida, tirada);
    expect(filtrada.combosOpcionales, isEmpty);

    final resumen = aplicarPuntosTirada(partida, filtrada);
    expect(resumen.puntosTirada, 200);
    expect(resumen.pasado, isFalse);
  });

  group('IA por dificultad', () {
    Partida armar({
      required int puntosPc,
      required int puntosRival,
      required int puntosTurno,
      int dadosEnMano = 4,
      bool abierto = true,
      bool rivalAbierto = true,
    }) {
      final partida = nuevaPartida(['PC', 'Rival'], Modo.cinco);
      iniciarTurno(partida);
      partida.jugadorActual.puntos = puntosPc;
      partida.jugadorActual.abierto = abierto;
      partida.jugadores[1].puntos = puntosRival;
      partida.jugadores[1].abierto = rivalAbierto;
      partida.turno.puntosTurno = puntosTurno;
      partida.turno.dadosEnMano = dadosEnMano;
      return partida;
    }

    // rng fijo que nunca dispara el error humano ni las chances random.
    final rngSinError = _RngSinError();

    test('todas cierran la partida si llegan justo a 10000', () {
      for (final d in DificultadPc.values) {
        final p = armar(puntosPc: 9500, puntosRival: 0, puntosTurno: 500);
        expect(
          iaDebePlantarse(p, dificultad: d, rng: rngSinError),
          isTrue,
          reason: d.name,
        );
      }
    });

    test('ninguna se planta si el total supera 10000', () {
      for (final d in DificultadPc.values) {
        final p = armar(puntosPc: 9800, puntosTurno: 500, puntosRival: 0);
        expect(
          iaDebePlantarse(p, dificultad: d, rng: rngSinError),
          isFalse,
          reason: d.name,
        );
      }
    });

    test('media se planta con 1 dado y más de 600 en el turno', () {
      final p = armar(puntosPc: 2000, puntosRival: 2000, puntosTurno: 700, dadosEnMano: 1);
      expect(
        iaDebePlantarse(p, dificultad: DificultadPc.medio, rng: rngSinError),
        isTrue,
      );
    });

    test('media sigue con 1 dado y menos de 400 en el turno', () {
      final p = armar(puntosPc: 2000, puntosRival: 2000, puntosTurno: 300, dadosEnMano: 1);
      expect(
        iaDebePlantarse(p, dificultad: DificultadPc.medio, rng: rngSinError),
        isFalse,
      );
    });

    test('difícil arriesga cuando pierde por más de 2000', () {
      final p = armar(puntosPc: 4200, puntosRival: 8500, puntosTurno: 800);
      expect(
        iaDebePlantarse(p, dificultad: DificultadPc.dificil, rng: rngSinError),
        isFalse,
      );
    });

    test('difícil se conforma con 500 cuando gana por más de 2000', () {
      final p = armar(puntosPc: 8800, puntosRival: 6300, puntosTurno: 500);
      expect(
        iaDebePlantarse(p, dificultad: DificultadPc.dificil, rng: rngSinError),
        isTrue,
      );
    });

    test('difícil se planta con 1 dado y 800 pts (riesgo alto)', () {
      final p = armar(puntosPc: 3000, puntosRival: 3000, puntosTurno: 800, dadosEnMano: 1);
      expect(
        iaDebePlantarse(p, dificultad: DificultadPc.dificil, rng: rngSinError),
        isTrue,
      );
    });

    test('difícil se planta con 1 dado, 300 pts y ventaja modesta', () {
      final p = armar(
        puntosPc: 4900,
        puntosRival: 4000,
        puntosTurno: 300,
        dadosEnMano: 1,
      );
      expect(
        iaDebePlantarse(p, dificultad: DificultadPc.dificil, rng: rngSinError),
        isTrue,
      );
    });
  });
}
