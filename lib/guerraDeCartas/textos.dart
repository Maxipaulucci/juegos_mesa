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
      'Durante la partida ves la próxima carta del mazo de la PC '
      '(transparente sobre su mazo) y podés reordenar tu mazo con el botón '
      'del bichito para elegir qué carta tirás a continuación.';
  static const reglaCorta =
      'Mazo inglés de 52 (sin comodines). AS es la más alta y el 2 la más baja. '
      'Cada uno saca la cima: gana la más alta. Empate = guerra. '
      'Opcional: 15 vidas (al vaciar el mazo perdés 1 ♥).';

  static const infoOpcionVidas =
      'Activado por defecto.\n\n'
      'Cada jugador empieza con 15 vidas ♥. Cada vez que se le acaba el mazo '
      'y tiene que mezclar el pozo para seguir, pierde 1 vida.\n\n'
      'Si se queda sin vidas o sin cartas, queda fuera de la partida.\n\n'
      'Desactivá esta opción para jugar solo a quedarse con todas las cartas, '
      'sin el sistema de vidas.';

  static const infoVidasEnPartida =
      'Cada jugador empieza con 15 vidas ♥.\n\n'
      'Perdés 1 vida cuando se te acaba el mazo (al jugar tu última carta '
      'de la pila). Después podés mezclar el pozo y seguir tirando.\n\n'
      'Si te quedás sin vidas o sin ninguna carta, quedás fuera.\n\n'
      'Podés desactivar las vidas desde Modificar partida en el menú del juego '
      'y jugar hasta que algún jugador se quede sin cartas.';

  static String reglas() => '''
· Se juega con mazo inglés de 52 cartas (sin comodines).
  Valores de menor a mayor: 2, 3, 4, 5, 6, 7, 8, 9, 10, J, Q, K, AS.

· Se reparte el mazo en partes iguales. Cada jugador tiene una pila
  boca abajo (mazo) y un pozo con las cartas que va ganando.

· En cada ronda todos vuelven la carta de arriba. Quien tenga la más
  alta se lleva todas las cartas jugadas a su pozo.

· Si hay empate en la más alta, esas cartas quedan en la mesa y
  hay que tocar “Jugar carta” otra vez: solo los empatados vuelven
  otra carta. El que gane se lleva todo el pozo de la mesa.
  Excepción: si empatan y uno ya no tiene cartas para seguir,
  gana quien sí pueda tirar.

· Si se te acaba el mazo, primero se mezcla tu pozo y recién
  después esas cartas pasan a ser tu mazo para seguir tirando.
  Con vidas activas (Modificar partida): perdés 1 ♥ al vaciar el mazo
  (empezás con 15). Sin vidas, quedás fuera.

· Gana quien se queda con todas las cartas (o el último con vidas,
  si están activas). Pierde quien se queda sin cartas o sin vidas.
'''.trim();
}
