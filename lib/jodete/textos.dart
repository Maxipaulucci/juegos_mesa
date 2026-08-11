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

  static const reglaCorta =
      'Mazo español. Tirás mismo palo o número. '
      'Se anotan puntos por ronda; gana quien llega al objetivo.';
}

String reglasJodete({
  bool comodines = true,
  int objetivo = 30,
  bool puntajePorCartas = false,
}) =>
    '''
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
