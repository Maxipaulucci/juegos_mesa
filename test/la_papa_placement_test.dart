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
}
