import 'motor_generala.dart';

String reglasGenerala() {
  return '''
· La Generala se juega con $dadosGenerala dados. Cada jugador anota en su tablero hasta completar todas las categorías. Gana quien tenga más puntos al final.

· En tu turno tenés hasta $maxTiradasGenerala tiradas. Después de la primera podés tocar dados para guardarlos (quedan en amarillo a la izquierda); solo se vuelven a tirar los no guardados.

· Al terminar las $maxTiradasGenerala tiradas (o antes, si ya armaste Escalera, FULL o Generala) elegís una casilla libre del tablero para anotar.

· Números (1 al 6):
   - Se suman cara × cantidad de esa cara en los dados finales.
   - Ejemplo: dos 1 → 2 puntos en el “1”; tres 6 → 18 en el “6”.

· Especiales:
   - ESCALERA: 1-2-3-4-5 o 2-3-4-5-6 → $ptsEscalera pts ($ptsEscaleraServida si sale en la 1.ª tirada).
   - FULL: tres iguales + un par → $ptsFull pts ($ptsFullServida servida).
   - PÓKER: exactamente cuatro iguales → $ptsPoker pts ($ptsPokerServida servida).
   - GENERALA: cinco iguales → $ptsGenerala pts.
   - GENERALA DOBLE: otra generala después de haber anotado Generala con puntos → $ptsGeneralaDoble pts.

· Si no te sirve la tirada, podés tachar una casilla libre con 0. No se puede tachar Generala con 0 hasta haber anotado (o tachado) Generala Doble.

· Cada casilla se anota una sola vez. Servida = combinación armada en la primera tirada del turno (bonus en Escalera, FULL y Póker).

· Podés anotar antes de la 3.ª tirada solo si ya tenés Escalera, FULL o Generala y esa casilla sigue libre (el póker no: conviene seguir buscando la generala).
'''.trim();
}
