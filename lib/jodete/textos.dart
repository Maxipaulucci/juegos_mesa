/// Textos de Jodete.
abstract final class TextosJodete {
  static const titulo = 'Jodete';
  static const tuMano = 'Tu mano';
  static const descarte = 'Descarte';
  static const paloVigente = 'Palo vigente';
  static const levantar = 'Levantar';
  static const tirar = 'Tirar';
  static const elegirPalo = 'Elegí el palo';
  static const reiniciar = 'Otra vez';
  static const volverMenu = 'Volver al menú';
  static const onlineProximamente = 'Online de Jodete próximamente';
  static const infoModoDios =
      'Solo aplica a “Jugar vs PC”.\n\n'
      'Durante la partida ves boca arriba las manos de las PCs.';

  static const infoDificultadFacil =
      'La PC tira casi al azar entre las cartas válidas '
      'y elige palo sin estrategia.';

  static const infoDificultadMedio =
      'La PC guarda comodines y doses cuando puede, '
      'y elige el palo del que tiene más cartas.';

  static const infoDificultadDificil =
      'La PC usa skips, reverses y cartas de levantar con más criterio '
      'y elige el palo más fuerte de su mano.';

  static const reglaCorta =
      'Mazo español de 50 (48 + 2 comodines). Tirás mismo palo o número. '
      'Gana quien se queda sin cartas.';
}

String reglasJodete() => '''
· Se juega con mazo español de 50 cartas (1 al 12 en oro, copa, espada y
  basto, más 2 comodines).

· Se reparte 7 cartas a cada jugador. La primera del descarte no es especial.

· En tu turno tirás UNA carta del mismo palo o del mismo número que la cima
  del descarte (o un comodín). Luego juega el siguiente.

· Efectos:
  - 2 → el siguiente debe tirar otro 2 (apila +2) o levantar las cartas
    acumuladas (2, 4, 6…). Quien levanta pierde el turno.
  - 10 → elegís el palo vigente
  - 11 → saltea al siguiente jugador
  - 12 → invierte el sentido (con 2 jugadores funciona como salteo)
  - Comodín → el siguiente levanta 5, pierde el turno, y elegís el palo
  - 4 y 7 no tienen efecto especial (solo cuentan como número/palo)

· Si no podés tirar, levantás 1 del mazo y pasás.

· Gana quien se queda sin cartas.
'''.trim();
