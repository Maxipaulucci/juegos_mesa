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

  test('etiqueta cruda de carta', () {
    expect(
      const CartaEscoba(numero: 1, palo: PaloEscoba.espada).etiqueta,
      '1 de espada',
    );
    expect(
      const CartaEscoba(numero: 12, palo: PaloEscoba.copa).etiqueta,
      '12 de copa',
    );
  });
}
