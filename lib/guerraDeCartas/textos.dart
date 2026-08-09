/// Textos de Guerra de cartas.
abstract final class TextosGuerra {
  static const titulo = 'Guerra de cartas';
  static const vsPcNombre = 'PC';
  static const tuMazo = 'Tu mazo';
  static const tuPozo = 'Tu pozo';
  static const mazoRival = 'Mazo rival';
  static const jugar = 'Jugar carta';
  static const esperandoPc = 'La PC está jugando…';
  static const reiniciar = 'Otra vez';
  static const volverMenu = 'Volver al menú';
  static const onlineProximamente = 'Online de Guerra de cartas próximamente';
  static const infoModoDios =
      'Solo aplica a “Jugar vs PC”.\n\n'
      'Durante la partida ves la cima del mazo de la PC.';
  static const reglaCorta =
      'Mazo inglés de 52 (sin comodines). AS es la más alta y el 2 la más baja. '
      'Cada uno saca la cima: gana la más alta. Empate = guerra. '
      'Gana quien se queda con todas las cartas.';

  static String reglas() => '''
· Se juega con mazo inglés de 52 cartas (sin comodines).
  Valores de menor a mayor: 2, 3, 4, 5, 6, 7, 8, 9, 10, J, Q, K, AS.

· Se reparte el mazo en partes iguales. Cada jugador tiene una pila
  boca abajo (mazo) y un pozo con las cartas que va ganando.

· En cada ronda todos vuelven la carta de arriba. Quien tenga la más
  alta se lleva todas las cartas jugadas a su pozo.

· Si hay empate en la más alta, hay guerra: esos jugadores vuelven
  otra carta. El que gane se lleva todo el pozo de la mesa.
  Excepción: si empatan y uno ya no tiene cartas para seguir,
  gana quien sí pueda tirar.

· Si se te acaba el mazo, mezclás tu pozo y seguís con esas cartas.

· Gana quien se queda con todas las cartas. Pierde quien se queda
  sin ninguna.
'''.trim();
}
