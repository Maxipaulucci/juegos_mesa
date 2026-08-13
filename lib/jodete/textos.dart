/// Textos de Jodete.
abstract final class TextosJodete {
  static const titulo = 'Jodete';
  static const tuMano = 'Tu mano';
  static const descarte = 'Pozo';
  static const paloVigente = 'Palo vigente';
  static const levantar = 'Levantar';
  static const tirar = 'Tirar';
  static const elegirPalo = 'Elegí el palo';
  static const reiniciar = 'Otra vez';
  static const volverMenu = 'Volver al menú';
  static const onlineProximamente = 'Online de Jodete próximamente';
  static const infoModoDios =
      'Solo aplica a “Jugar vs PC”.\n\n'
      'Durante la partida ves boca arriba las manos de las PCs.\n\n'
      'También aparece el botón de forzar cartas (araña): '
      'elegís la cima del pozo y las cartas de tu mano.';

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
      'y te deja elegir el palo. Si “Tirar 2 sobre 2” está activado, '
      'también se puede tapar un comodín con otro (apila +5).\n\n'
      'Desactivado: mazo de 48 cartas, sin comodines.';

  static const infoObjetivo =
      'Puntos necesarios para ganar la partida (modo por puestos).\n\n'
      'Por defecto se juega a 30. También podés elegir 15 '
      '(partida más corta).\n\n'
      'Si activás “Puntaje por cartas (a 100)”, este valor no aplica.';

  static const infoPuntajePorCartas =
      'Activado: al terminar la ronda, el 1º (quien se quedó sin cartas '
      'primero) suma el valor de las cartas que quedan en las manos de '
      'los demás. Gana quien llega a 100 puntos.\n\n'
      'Valor de las cartas:\n'
      '· Número (1, 3–9): su valor\n'
      '· 2, 10, 11 y 12: 20 puntos\n'
      '· Comodín: 50 puntos\n\n'
      'Desactivado: se usan los puntos por puesto (15 o 30).';

  static const infoLevantarHastaTirar =
      'Activado: si no tenés ninguna carta para tirar, levantás del mazo '
      'hasta que te toque una jugable y podés tirarla en el mismo turno.\n\n'
      'Desactivado (clásico): levantás solo 1 carta y pasás el turno.';

  static const infoApilarDoses =
      'Activado: si te tiran un 2, podés responder con otro 2 y se apila '
      '(+2, +4, +6…). Si no, levantás lo acumulado.\n\n'
      'Si también hay comodines, se apilan igual: comodín sobre comodín '
      '(+5, +10…). Si no tapás, levantás lo acumulado.\n\n'
      'Desactivado: el 2 no se puede tapar con otro 2 ni el comodín con '
      'otro comodín; el siguiente levanta y pierde el turno.';

  static const infoGanarConEspecial =
      'Activado: nadie puede terminar la mano con una carta especial '
      '(2, 4, 7, 10, 11, 12 o comodín). La última carta tiene que ser '
      'un número “normal” (1, 3, 5, 6, 8 o 9).\n\n'
      'Desactivado: se puede ganar tirando cualquier carta válida, '
      'incluida una especial.';

  static const reglaCorta =
      'Mazo español. Tirás mismo palo o número. '
      'Se anotan puntos por ronda; gana quien llega al objetivo.';
}

String reglasJodete({
  bool comodines = true,
  int objetivo = 30,
  bool puntajePorCartas = false,
  bool apilarDoses = true,
  bool ganarConEspecial = false,
}) =>
    '''
· Se juega con mazo español de ${comodines ? '50' : '48'} cartas (1 al 12
  en oro, copa, espada y basto${comodines ? ', más 2 comodines' : ''}).

· Se reparte 7 cartas a cada jugador. La primera del pozo no es especial.

· En tu turno tirás una carta (mismo palo o mismo número${comodines ? ', o comodín' : ''})
  O levantás del mazo. El 4 y el 7 te dejan tirar de nuevo.

· Efectos:
  - 2 → ${apilarDoses ? 'el siguiente puede tirar otro 2 (apila +2) o levantar las cartas acumuladas (2, 4, 6…). Si no tiene un 2, las levanta solo a los 2 segundos' : 'el siguiente levanta 2 (no se puede tapar con otro 2). Si no responde, las levanta solo a los 2 segundos'}
  - 4 y 7 → tirás otra carta (o levantás) en el mismo turno
  - 10 → elegís el palo vigente
  - 11 → saltea al siguiente jugador
  - 12 → invierte el sentido (con 2 jugadores funciona como salteo)
${comodines ? (apilarDoses
      ? '  - Comodín → el siguiente puede tirar otro comodín (apila +5) o levantar lo acumulado (5, 10…). Si no tiene comodín, las levanta solo a los 2 segundos. Elegís el palo.\n'
      : '  - Comodín → el siguiente levanta 5, pierde el turno, y elegís el palo\n') : ''}
${ganarConEspecial ? '· Finalizar mano con especial (activado): no se puede terminar la mano con '
      '2, 4, 7, 10, 11, 12 o comodín.\n' : ''}
· Si no podés tirar, levantás 1 del mazo y pasás (o, si activaste
  “Levantar hasta tirar” en Modificar partida, levantás hasta sacar una
  jugable y la tirás en el mismo turno).

${puntajePorCartas ? '''· Puntaje por cartas (activado): el 1º de la ronda suma el valor de las
  cartas que quedan en las demás manos.
  Valores: número = su cifra; 2/10/11/12 = 20; comodín = 50.
  Gana quien primero llega a $objetivo puntos.''' : '''· Puntos por ronda (quien se queda sin cartas antes):
  - 2 jugadores: 1º +1 · 2º +0
  - 3 jugadores: 1º +2 · 2º +1 · 3º +0
  - 4 jugadores: 1º +3 · 2º +2 · 3º +1 · 4º +0
  Con 3 o 4, la ronda sigue hasta que quede uno con cartas.

· Gana la partida quien primero llega a $objetivo puntos (15 o 30 en
  Modificar partida).'''}

· Los puntos se marcan con palitos en la tarjeta de cada jugador.
'''.trim();
