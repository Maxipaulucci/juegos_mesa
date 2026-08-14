import 'motor.dart';

String reglasDe(
  Modo modo, {
  bool combosEspeciales = true,
  bool escalera = true,
  bool escaleraCircular = false,
}) {
  final String lineaEscalera5;
  if (!escalera) {
    lineaEscalera5 = 'Escalera: desactivada (no suma).';
  } else if (escaleraCircular) {
    lineaEscalera5 =
        'Escalera de 5 dados (1-2-3-4-5, 2-3-4-5-6 o dando la vuelta 6→1, '
        'p. ej. 5-6-1-2-3): 500 puntos.';
  } else {
    lineaEscalera5 = 'Escalera 1-2-3-4-5 o 2-3-4-5-6: 500 puntos.';
  }

  switch (modo) {
    case Modo.cinco:
      final extras = combosEspeciales
          ? '   - Cinco iguales: valor × 1000 (los 1 valen 10.000).\n'
          : '   - (Combos especiales desactivados: cinco iguales no suman '
              'valor × 1000; cuentan como triples / sueltos.)\n';
      return '''
· El 10.000 se juega con 5 dados. El objetivo es llegar a exactamente $meta puntos.

· Cómo sumar:
   - Cada 1 suma 100.
   - Cada 5 suma 50.
   - Tres iguales: valor × 100 (los 1 valen 1000).
$extras   - $lineaEscalera5

· Para abrir (empezar a anotar) necesitás al menos ${modo.apertura} puntos en un solo turno.
· Si una tirada no suma nada, perdés los puntos de ese turno (farkle).
· Los dados que sumaron se retiran; si suman todos, volvés a tirar con los 5 (hot dice).
· Si te pasás de $meta, se anula el turno. Hay que caer exactamente en $meta.
'''.trim();
    case Modo.seis:
      final extras = combosEspeciales
          ? '''   - Tres pares: 1500 puntos (se aplica solo).
   - Cuatro iguales + un par: 1500 puntos (se aplica solo).
   - Cinco iguales: valor × 1000 (los 1 valen 10.000).
   - Seis iguales: victoria inmediata.
'''
          : '''   - (Combos especiales desactivados: no valen tres pares, cuatro+par,
     cinco iguales ×1000 ni seis iguales = victoria; se cuentan triples / sueltos.)
''';
      final lineaEscalera6 = escalera
          ? '   - Escalera 1-2-3-4-5-6: 1500 puntos.\n   - $lineaEscalera5'
          : '   - Escalera: desactivada (no suma).';
      return '''
· El 10.000 se juega con 6 dados. El objetivo es llegar a exactamente $meta puntos.

· Cómo sumar:
   - Cada 1 suma 100.
   - Cada 5 suma 50.
   - Tres iguales: valor × 100 (los 1 valen 1000).
$lineaEscalera6
$extras
· Para abrir necesitás al menos ${modo.apertura} puntos en un solo turno.
· Tirada en cero = perdés el turno. Pasarte de $meta anula el turno.
· Hay que caer exactamente en $meta para ganar.
'''.trim();
  }
}

const especialNombres = {
  'tres_pares': 'tres pares',
  'cuatro_y_par': 'cuatro iguales y un par',
};

String nombreEspecial(Especial e) {
  switch (e) {
    case Especial.tresPares:
      return especialNombres['tres_pares']!;
    case Especial.cuatroYPar:
      return especialNombres['cuatro_y_par']!;
    case Especial.seisIguales:
      return 'seis iguales';
  }
}

String formatearCombos(List<Combo> combos) {
  if (combos.isEmpty) return '—';
  return combos.map((c) => '${c.nombre} (+${c.puntos})').join(', ');
}

/// Textos de ayuda de dificultad (vs PC).
abstract final class TextosDiezMil {
  static const infoDificultadFacil =
      'La PC es temeraria: sigue tirando casi siempre, aunque arriesgue '
      'perder el turno.\n\n'
      'Solo se planta con un botín muy grande. Comete más errores: ideal '
      'para aprender o ganar más fácil.';

  static const infoDificultadMedio =
      'La PC juega equilibrada: mira los puntos del turno y cuántos dados '
      'le quedan.\n\n'
      'Se planta cuando el turno ya es sólido (por ejemplo con pocos dados '
      'y bastantes puntos). Se equivoca poco.';

  static const infoDificultadDificil =
      'La PC calcula mejor: mira el marcador de todos, si alguien ya abrió '
      'y qué tan cerca está de los 10.000.\n\n'
      'Arriesga cuando va perdiendo y se cuida cuando va ganando o cerca '
      'de cerrar. Casi no se equivoca.';
}
