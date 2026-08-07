import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:app_juegos_mesa/chanchoVa/motor_chancho_va.dart';

void main() {
  test('reparte 4 cartas por jugador con N números', () {
    final p = nuevaPartidaChancho(nombres: const ['A', 'B', 'C']);
    final err =
        aplicarNumerosElegidosChancho(p, const [7, 10, 11], math.Random(1));
    expect(err, isNull);
    expect(p.fase, FaseChancho.anunciando);
    expect(p.jugadores.every((j) => j.mano.length == 4), isTrue);
  });

  test('rotación a la derecha', () {
    final p = nuevaPartidaChancho(nombres: const ['A', 'B', 'C']);
    aplicarNumerosElegidosChancho(p, const [5, 6, 7], math.Random(2));
    final a = p.jugadores[0];
    final b = p.jugadores[1];
    // Forzar manos conocidas (solo A y B participan del pase de prueba)
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
    // C también debe confirmar para cerrar el pase.
    final c = p.jugadores[2];
    confirmarSeleccionPaseChancho(
      p,
      jugador: c,
      cartas: [c.mano.first],
      rng: math.Random(0),
    );

    expect(b.mano.contains(cartaA), isTrue);
    expect(a.mano.length, 4);
    expect(b.mano.length, 4);
    // El anunciante no cambia tras un pase sin Chancho.
    expect(p.indiceTurno, 0);
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
    final p = nuevaPartidaChancho(nombres: const ['A', 'B', 'C']);
    aplicarNumerosElegidosChancho(p, const [4, 5, 6], math.Random(5));
    final a = p.jugadores[0];
    final b = p.jugadores[1];
    final c = p.jugadores[2];
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
    expect(decirChanchoVa(p, jugador: c), isNull);
    expect(c.letras, isNotEmpty);
    expect(c.letras.first, 'C');
    expect(p.historialLetras, hasLength(1));
    expect(p.historialLetras.first.jugador, 'C');
    expect(p.historialLetras.first.letrasTras, 'C');
    expect(
      p.historialLetras.first.motivo,
      MotivoPenalizacionChancho.ultimoEnChancho,
    );
    expect(p.fase, FaseChancho.finRonda);
    expect(p.ultimoResumenRonda?.chanchoDe, 'A');
    expect(p.ultimoResumenRonda?.chancho, 'C');
    expect(p.indiceTurno, 0);
    continuarTrasFinRondaChancho(p);
    expect(p.fase, FaseChancho.anunciando);
    // Tras Chancho, anuncia el siguiente jugador.
    expect(p.indiceTurno, 1);
  });

  test('se puede abrir Chancho durante la elección de cartas', () {
    final p = nuevaPartidaChancho(nombres: const ['A', 'B', 'C']);
    aplicarNumerosElegidosChancho(p, const [4, 5, 6], math.Random(9));
    final a = p.jugadores[0];
    a.mano
      ..clear()
      ..addAll(const [
        CartaChancho(numero: 4, palo: PaloChancho.oro),
        CartaChancho(numero: 4, palo: PaloChancho.copa),
        CartaChancho(numero: 4, palo: PaloChancho.espada),
        CartaChancho(numero: 4, palo: PaloChancho.basto),
      ]);
    anunciarPaseChancho(p, cantidad: 1, direccion: DireccionChancho.centro);
    expect(p.fase, FaseChancho.eligiendoCartas);
    expect(decirChanchoVa(p, jugador: a), isNull);
    expect(p.fase, FaseChancho.carreraChancho);
    expect(p.quienAbrioChancho, 'A');
    expect(p.anuncioActual, isNull);
  });

  test('historial acumula letras por chancha en tarjetas sucesivas', () {
    final p = nuevaPartidaChancho(nombres: const ['Yo', 'PC 1', 'PC 2']);
    aplicarNumerosElegidosChancho(p, const [4, 5, 6], math.Random(2));
    final pc1 = p.jugadores[1];
    final anunciante = p.indiceTurno;
    final faseAntes = p.fase;

    penalizarJugadorChancho(
      p,
      pc1,
      motivo: MotivoPenalizacionChancho.chancha,
      lanzadorChancha: 'Yo',
    );
    expect(pc1.letrasTexto, 'C');
    // Chancha no cierra la ronda ni cambia anunciante.
    expect(p.fase, faseAntes);
    expect(p.indiceTurno, anunciante);
    expect(p.historialLetras, hasLength(1));
    expect(p.historialLetras[0].letrasTras, 'C');
    expect(p.historialLetras[0].motivo, MotivoPenalizacionChancho.chancha);

    penalizarJugadorChancho(
      p,
      pc1,
      motivo: MotivoPenalizacionChancho.ultimoEnChancho,
    );
    expect(pc1.letrasTexto, 'CH');
    expect(p.fase, FaseChancho.finRonda);
    expect(p.historialLetras, hasLength(2));
    expect(p.historialLetras[1].jugador, 'PC 1');
    expect(p.historialLetras[1].letrasTras, 'CH');
    expect(
      p.historialLetras[1].motivo,
      MotivoPenalizacionChancho.ultimoEnChancho,
    );
  });

  test('tablero sin espacio usa CHANCHOVA', () {
    final p = nuevaPartidaChancho(
      nombres: const ['A', 'B', 'C'],
      sinEspacio: true,
      finAlPrimerPerdedor: true,
    );
    expect(p.palabraObjetivo, 'CHANCHOVA');
    expect(p.objetivoLetras, 9);
    expect(p.secuenciaLetras.contains(' '), isFalse);

    final a = p.jugadores[0];
    for (var i = 0; i < 9; i++) {
      penalizarJugadorChancho(
        p,
        a,
        motivo: MotivoPenalizacionChancho.chancha,
        lanzadorChancha: 'B',
      );
    }
    expect(a.letrasTexto, 'CHANCHOVA');
    expect(p.terminada, isTrue);
  });

  test('sin fin al primer perdedor sigue hasta que quede uno', () {
    final p = nuevaPartidaChancho(
      nombres: const ['A', 'B', 'C'],
      sinEspacio: true,
      finAlPrimerPerdedor: false,
    );
    aplicarNumerosElegidosChancho(p, const [4, 5, 6], math.Random(3));
    final a = p.jugadores[0];
    final b = p.jugadores[1];

    for (var i = 0; i < 9; i++) {
      penalizarJugadorChancho(
        p,
        a,
        motivo: MotivoPenalizacionChancho.chancha,
        lanzadorChancha: 'B',
      );
    }
    expect(a.eliminado, isTrue);
    expect(p.terminada, isFalse);
    expect(p.jugadoresActivos, hasLength(2));

    for (var i = 0; i < 9; i++) {
      penalizarJugadorChancho(
        p,
        b,
        motivo: MotivoPenalizacionChancho.chancha,
        lanzadorChancha: 'C',
      );
    }
    expect(b.eliminado, isTrue);
    expect(p.terminada, isTrue);
    expect(p.ganador, 'C');
    expect(p.jugadoresActivos, hasLength(1));
  });

  test('fin al primer perdedor termina con el primero', () {
    final p = nuevaPartidaChancho(
      nombres: const ['A', 'B', 'C'],
      sinEspacio: true,
      finAlPrimerPerdedor: true,
    );
    final a = p.jugadores[0];
    for (var i = 0; i < 9; i++) {
      penalizarJugadorChancho(
        p,
        a,
        motivo: MotivoPenalizacionChancho.chancha,
        lanzadorChancha: 'B',
      );
    }
    expect(p.terminada, isTrue);
    expect(p.perdedor, 'A');
    expect(p.jugadoresActivos, hasLength(2));
  });
}
