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

  static const infoComodines =
      'Activado: el mazo lleva 50 cartas (48 + 2 comodines). '
      'El comodín se puede tirar siempre, hace levantar 5 al siguiente '
      'y te deja elegir el palo.\n\n'
      'Desactivado: mazo de 48 cartas, sin comodines.';

  static const infoLevantarHastaTirar =
      'Activado: si no tenés ninguna carta para tirar, levantás del mazo '
      'hasta que te toque una jugable y podés tirarla en el mismo turno.\n\n'
      'Desactivado (clásico): levantás solo 1 carta y pasás el turno.';

  static const reglaCorta =
      'Mazo español (con o sin comodines). Tirás mismo palo o número. '
      'Gana quien se queda sin cartas.';
}

String reglasJodete({bool comodines = true}) => '''
· Se juega con mazo español de ${comodines ? '50' : '48'} cartas (1 al 12
  en oro, copa, espada y basto${comodines ? ', más 2 comodines' : ''}).

· Se reparte 7 cartas a cada jugador. La primera del descarte no es especial.

· En tu turno hacés UNA sola acción: tirás una carta (mismo palo o mismo
  número${comodines ? ', o comodín' : ''}) O levantás del mazo. Después
  juega el siguiente. No se tira de nuevo con el 4 ni con el 7.

· Efectos:
  - 2 → el siguiente debe tirar otro 2 (apila +2) o, si no tiene 2,
    levanta automáticamente las cartas acumuladas (2, 4, 6…) y pierde
    el turno.
  - 10 → elegís el palo vigente
  - 11 → saltea al siguiente jugador
  - 12 → invierte el sentido (con 2 jugadores funciona como salteo)
${comodines ? '  - Comodín → el siguiente levanta 5, pierde el turno, y elegís el palo\n' : ''}  - 4 y 7 no tienen efecto especial (solo cuentan como número/palo)

· Si no podés tirar, levantás 1 del mazo y pasás (o, si activaste
  “Levantar hasta tirar” en Modificar partida, levantás hasta sacar una
  jugable y la tirás en el mismo turno).

· Gana quien se queda sin cartas.
'''.trim();
