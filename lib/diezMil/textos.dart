import 'motor.dart';

String reglasDe(Modo modo) {
  switch (modo) {
    case Modo.cinco:
      return '''
· El 10.000 se juega con 5 dados. El objetivo es llegar a exactamente $meta puntos.

· Cómo sumar:
   - Cada 1 suma 100.
   - Cada 5 suma 50.
   - Tres iguales: valor × 100 (los 1 valen 1000).
   - Cinco iguales: valor × 1000 (los 1 valen 10.000).
   - Escalera 1-2-3-4-5 o 2-3-4-5-6: 500 puntos.

· Para abrir (empezar a anotar) necesitás al menos $apertura puntos en un solo turno.
· Si una tirada no suma nada, perdés los puntos de ese turno (farkle).
· Los dados que sumaron se retiran; si suman todos, volvés a tirar con los 5 (hot dice).
· Si te pasás de $meta, se anula el turno. Hay que caer exactamente en $meta.
'''.trim();
    case Modo.seis:
      return '''
· El 10.000 se juega con 6 dados. El objetivo es llegar a exactamente $meta puntos.

· Cómo sumar:
   - Cada 1 suma 100.
   - Cada 5 suma 50.
   - Tres iguales: valor × 100 (los 1 valen 1000).
   - Escalera 1-2-3-4-5-6: 1500 puntos.
   - Tres pares: 1500 (podés aceptar o puntuar dados sueltos).
   - Cuatro iguales + un par: 1500 (idem, es opcional).
   - Seis iguales: victoria inmediata.

· Para abrir necesitás al menos $apertura puntos en un solo turno.
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
