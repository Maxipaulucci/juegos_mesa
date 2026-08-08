/// Textos de Casita robada.
abstract final class TextosCasita {
  static const titulo = 'Casita robada';
  static const vsPcNombre = 'PC';
  static const tuMano = 'Tu mano';
  static const manoRival = 'Mano del rival';
  static const mesa = 'Mesa';
  static const tuCasita = 'Tu casita';
  static const casitaRival = 'Casita rival';

  static String casitaRivalDe(String nombre) => '$casitaRival $nombre';
  static String tuCasitaDe(String nombre) => '$tuCasita $nombre';
  static const juegaUna =
      'Elegí una carta de tu mano y de la mesa (mismo número), o tirala';
  static const esperandoPc = 'La PC está jugando…';
  static const esperandoRival = 'Turno del rival…';
  static const listoCapturar = ' · ¡listo para capturar!';
  static const faltaMesaOCasita =
      ' · elegí carta(s) de la mesa o la casita rival';
  static const reiniciar = 'Otra vez';
  static const volverMenu = 'Volver al menú';
  static const onlineProximamente = 'Online de Casita robada próximamente';
  static const infoModoDios =
      'Solo aplica a “Jugar vs PC”.\n\n'
      'Durante la partida ves las cartas de la PC boca arriba '
      'para probar jugadas.';
  static const reglaCorta =
      'Mazo español de 48 (con 8 y 9; sin comodines). Se reparte 4 a la mesa '
      'y 3 a cada uno. Jugá una carta: si hay el mismo número en la mesa, '
      'las capturás a tu casita (cima visible). Si coincide con la cima de '
      'la casita rival, ¡le robás toda la casita! Gana quien juntó más cartas.';
}

String reglasCasitaRobada() => '''
· Casita robada se juega con mazo español de 48 cartas (del 1 al 12 en los
  cuatro palos). Incluye 8 y 9; únicamente se juega sin comodines.

· Se reparte 4 cartas a la mesa y 3 a cada jugador.

· En tu turno jugás una carta de la mano:
  - Si el número coincide con la cima de la casita del rival,
    le robás toda su casita y tu carta queda arriba.
  - Si no, y hay cartas del mismo número en la mesa, las capturás
    junto con tu carta a tu casita (tu carta queda visible arriba).
  - Si no hay coincidencia, la carta queda en la mesa.

· Cuando nadie tiene cartas en la mano, se vuelven a repartir 3
  (mientras quede mazo).

· Al final, las cartas que quedan en la mesa se las lleva el último
  que haya capturado o robado. Gana quien tenga más cartas en su casita.
'''.trim();
