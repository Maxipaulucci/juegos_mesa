import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:app_juegos_mesa/escobaDel15/motor_escoba.dart';

void main() {
  test('mazo tiene 40 cartas sin 8 ni 9', () {
    final mazo = crearMazoEscoba();
    expect(mazo.length, 40);
    expect(mazo.any((c) => c.numero == 8 || c.numero == 9), isFalse);
    expect(CartaEscoba(numero: 10, palo: PaloEscoba.copa).valorSuma, 8);
    expect(CartaEscoba(numero: 11, palo: PaloEscoba.copa).valorSuma, 9);
    expect(CartaEscoba(numero: 12, palo: PaloEscoba.copa).valorSuma, 10);
  });

  test('captura que suma 15', () {
    final jugada = CartaEscoba(numero: 12, palo: PaloEscoba.espada); // 10
    final mesa = [
      CartaEscoba(numero: 5, palo: PaloEscoba.oro),
    ];
    final caps = capturasPosiblesEscoba(jugada, mesa);
    expect(caps.length, 1);
    expect(caps.first.single.numero, 5);
  });

  test('puntos: 7 de oro y más sietes con desempate', () {
    final p = PartidaEscoba(
      jugadores: [JugadorEscoba('A'), JugadorEscoba('B')],
    );
    // A: 7 espada, 7 oro + 6 basto, 5 copa (para desempate vs B)
    p.jugadores[0].capturadas.addAll([
      const CartaEscoba(numero: 7, palo: PaloEscoba.espada),
      const CartaEscoba(numero: 7, palo: PaloEscoba.oro),
      const CartaEscoba(numero: 6, palo: PaloEscoba.basto),
      const CartaEscoba(numero: 5, palo: PaloEscoba.copa),
    ]);
    // B: 7 basto, 7 copa + 4 espada, 3 oro
    p.jugadores[1].capturadas.addAll([
      const CartaEscoba(numero: 7, palo: PaloEscoba.basto),
      const CartaEscoba(numero: 7, palo: PaloEscoba.copa),
      const CartaEscoba(numero: 4, palo: PaloEscoba.espada),
      const CartaEscoba(numero: 3, palo: PaloEscoba.oro),
    ]);

    final r = puntuarRondaEscoba(p);

    // 7 de oro → A
    expect(r.idxSieteOro, 0);
    // Empate 2–2 en sietes: A mira basto+copa → 6+5=11; B mira espada+oro → 4+3=7 → A
    expect(r.idxMasSietes, 0);
    // A: 1 (7 oro) + 1 (sietes) = 2 (sin escobas ni cartas/oros únicos claros)
    expect(p.jugadores[0].puntos, greaterThanOrEqualTo(2));
  });

  test('cartas de mesa al final van al último que capturó', () {
    final cinco = CartaEscoba(numero: 5, palo: PaloEscoba.oro);
    final doce = CartaEscoba(numero: 12, palo: PaloEscoba.espada); // 10
    final as = CartaEscoba(numero: 1, palo: PaloEscoba.basto);
    final sobra = CartaEscoba(numero: 3, palo: PaloEscoba.copa);

    final p = PartidaEscoba(
      jugadores: [JugadorEscoba('A'), JugadorEscoba('B')],
      mazo: [],
      mesa: [cinco, sobra],
    );
    p.jugadores[0].mano.add(doce);
    p.jugadores[1].mano.add(as);
    p.indiceTurno = 0;

    // A captura 12+5=15; queda el 3 en mesa.
    final errA = jugarCartaEscoba(p, doce, mesaElegida: [cinco]);
    expect(errA, isNull);
    expect(p.ultimaCapturaIdx, 0);
    expect(p.mesa, [sobra]);

    // B tira su última carta (no captura). Fin de ronda.
    final errB = jugarCartaEscoba(p, as, forzarTirar: true);
    expect(errB, isNull);
    expect(p.mesa, isEmpty);
    // A se lleva 12, 5 y las sobras (3 y el as tirado).
    expect(
      p.jugadores[0].capturadas.map((c) => c.etiqueta).toSet(),
      {'12 de espada', '5 de oro', '3 de copa', '1 de basto'},
    );
    expect(p.jugadores[1].capturadas, isEmpty);
    expect(p.ultimoResultado?.idxLlevoPozo, 0);
    expect(
      p.ultimoResultado!.cartasPozoFinal.map((c) => c.etiqueta).toSet(),
      {'3 de copa', '1 de basto'},
    );
    expect(p.jugadores[0].combos.length, 2); // captura + pozo final
    expect(p.jugadores[0].combos.last.esPozoFinal, isTrue);
  });

  test('combos se conservan hasta la primera jugada de la nueva ronda', () {
    final p = PartidaEscoba(
      jugadores: [JugadorEscoba('A'), JugadorEscoba('B')],
      fase: FaseEscoba.finRonda,
      mazo: [],
    );
    p.jugadores[0].combos.add(
      const ComboCapturaEscoba(
        cartas: [CartaEscoba(numero: 5, palo: PaloEscoba.oro)],
      ),
    );
    siguienteRondaEscoba(p, math.Random(1));
    expect(p.reiniciarCombosEnProximaJugada, isTrue);
    expect(p.jugadores[0].combos, isNotEmpty);

    final carta = p.jugadorActual.mano.first;
    jugarCartaEscoba(p, carta, forzarTirar: true);
    expect(p.reiniciarCombosEnProximaJugada, isFalse);
    // Se reinició; si tiró, no hay combos nuevos.
    expect(
      p.jugadores.every((j) => j.combos.isEmpty),
      isTrue,
    );
  });

  test('escobas automáticas: dos pares de 15', () {
    final p = PartidaEscoba(
      jugadores: [JugadorEscoba('A'), JugadorEscoba('B')],
      indiceTurno: 0,
    );
    // 5+12(10)=15 y 6+11(9)=15
    p.mesa.addAll(const [
      CartaEscoba(numero: 5, palo: PaloEscoba.oro),
      CartaEscoba(numero: 12, palo: PaloEscoba.espada),
      CartaEscoba(numero: 6, palo: PaloEscoba.copa),
      CartaEscoba(numero: 11, palo: PaloEscoba.basto),
    ]);
    final r = aplicarEscobasAutomaticasInicio(p);
    expect(r, isNotNull);
    expect(r!.dosParesEscoba, isTrue);
    expect(r.escobasOtorgadas, 2);
    expect(p.jugadores[0].escobasRonda, 2);
    expect(p.mesa, isEmpty);
    expect(p.jugadores[0].capturadas.length, 4);
  });

  test('escobas automáticas: mesa suma 15', () {
    final p = PartidaEscoba(
      jugadores: [JugadorEscoba('A'), JugadorEscoba('B')],
      indiceTurno: 1,
    );
    // 1+2+3+11(9)=15
    p.mesa.addAll(const [
      CartaEscoba(numero: 1, palo: PaloEscoba.oro),
      CartaEscoba(numero: 2, palo: PaloEscoba.copa),
      CartaEscoba(numero: 3, palo: PaloEscoba.espada),
      CartaEscoba(numero: 11, palo: PaloEscoba.basto),
    ]);
    final r = aplicarEscobasAutomaticasInicio(p);
    expect(r, isNotNull);
    expect(r!.mesaSuma15, isTrue);
    expect(r.escobasOtorgadas, 1);
    expect(r.nombreBeneficiario, 'B');
    expect(p.jugadores[1].escobasRonda, 1);
    expect(p.mesa.length, 4);
  });
}

