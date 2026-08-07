import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:app_juegos_mesa/chanchoVa/motor_chancho_va.dart';

void main() {
  test('reparte 4 cartas por jugador con N números', () {
    final p = nuevaPartidaChancho(nombres: const ['A', 'B']);
    final err = aplicarNumerosElegidosChancho(p, const [7, 10], math.Random(1));
    expect(err, isNull);
    expect(p.fase, FaseChancho.anunciando);
    expect(p.jugadores.every((j) => j.mano.length == 4), isTrue);
  });

  test('rotación a la derecha', () {
    final p = nuevaPartidaChancho(nombres: const ['A', 'B']);
    aplicarNumerosElegidosChancho(p, const [5, 6], math.Random(2));
    final a = p.jugadores[0];
    final b = p.jugadores[1];
    // Forzar manos conocidas
    a.mano
      ..clear()
      ..addAll(const [
        CartaChancho(numero: 5, palo: PaloChancho.oro),
        CartaChancho(numero: 5, palo: PaloChancho.copa),
        CartaChancho(numero: 5, palo: PaloChancho.espada),
        CartaChancho(numero: 6, palo: PaloChancho.oro),
      ]);
    b.mano
      ..clear()
      ..addAll(const [
        CartaChancho(numero: 6, palo: PaloChancho.copa),
        CartaChancho(numero: 6, palo: PaloChancho.espada),
        CartaChancho(numero: 6, palo: PaloChancho.basto),
        CartaChancho(numero: 5, palo: PaloChancho.basto),
      ]);

    anunciarPaseChancho(p, cantidad: 1, direccion: DireccionChancho.derecha);
    final cartaA = a.mano.last;
    confirmarSeleccionPaseChancho(p, jugador: a, cartas: [cartaA]);
    final cartaB = b.mano.first;
    confirmarSeleccionPaseChancho(
      p,
      jugador: b,
      cartas: [cartaB],
      rng: math.Random(0),
    );

    expect(b.mano.contains(cartaA), isTrue);
    expect(a.mano.contains(cartaB), isTrue);
    expect(a.mano.length, 4);
    expect(b.mano.length, 4);
  });

  test('pase al centro no devuelve propias (si es posible)', () {
    final p = nuevaPartidaChancho(nombres: const ['A', 'B', 'C']);
    aplicarNumerosElegidosChancho(p, const [1, 2, 3], math.Random(3));

    // Manos controladas con cartas únicas
    for (var i = 0; i < 3; i++) {
      p.jugadores[i].mano
        ..clear()
        ..addAll([
          CartaChancho(numero: i + 1, palo: PaloChancho.oro),
          CartaChancho(numero: i + 1, palo: PaloChancho.copa),
          CartaChancho(numero: i + 1, palo: PaloChancho.espada),
          CartaChancho(numero: i + 1, palo: PaloChancho.basto),
        ]);
    }

    anunciarPaseChancho(p, cantidad: 2, direccion: DireccionChancho.centro);
    final aportes = <List<CartaChancho>>[];
    for (final j in p.jugadores) {
      final sel = j.mano.take(2).toList();
      aportes.add(sel);
      confirmarSeleccionPaseChancho(
        p,
        jugador: j,
        cartas: sel,
        rng: math.Random(42),
      );
    }

    for (var i = 0; i < 3; i++) {
      final propias = aportes[i].toSet();
      final recibidas = p.jugadores[i].mano.toSet();
      expect(
        recibidas.intersection(propias).isEmpty,
        isTrue,
        reason: 'Jugador $i no debería recuperar las que aportó',
      );
      expect(p.jugadores[i].mano.length, 4);
    }
  });

  test('PC no rompe el grupo más grande si puede', () {
    final pc = JugadorChancho('PC');
    pc.mano.addAll(const [
      CartaChancho(numero: 7, palo: PaloChancho.oro),
      CartaChancho(numero: 7, palo: PaloChancho.copa),
      CartaChancho(numero: 7, palo: PaloChancho.espada),
      CartaChancho(numero: 12, palo: PaloChancho.oro),
    ]);
    final elegidas = elegirCartasPcChancho(pc, 1, math.Random(1));
    expect(elegidas.length, 1);
    expect(elegidas.single.numero, 12);
  });

  test('último en Chancho recibe letra', () {
    final p = nuevaPartidaChancho(nombres: const ['A', 'B']);
    aplicarNumerosElegidosChancho(p, const [4, 5], math.Random(5));
    final a = p.jugadores[0];
    final b = p.jugadores[1];
    a.mano
      ..clear()
      ..addAll(const [
        CartaChancho(numero: 4, palo: PaloChancho.oro),
        CartaChancho(numero: 4, palo: PaloChancho.copa),
        CartaChancho(numero: 4, palo: PaloChancho.espada),
        CartaChancho(numero: 4, palo: PaloChancho.basto),
      ]);
    expect(a.tieneCuarteto, isTrue);

    expect(decirChanchoVa(p, jugador: a), isNull);
    expect(p.fase, FaseChancho.carreraChancho);
    expect(decirChanchoVa(p, jugador: b), isNull);
    expect(b.letras, isNotEmpty);
    expect(b.letras.first, 'C');
    expect(p.fase, FaseChancho.anunciando);
  });
}
