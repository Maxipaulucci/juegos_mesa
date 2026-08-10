/// Textos de Desconfío.
abstract final class TextosDesconfio {
  static const titulo = 'Desconfío';
  static const jugar = 'Tirar carta';
  static const desconfio = '¡Desconfío!';
  static const tirar = 'Tirar';
  static const continuar = 'Continuar';
  static const elegirPalo = 'Elegí el palo';
  static const pozo = 'Pozo';
  static const tuMano = 'Tu mano';
  static const reiniciar = 'Otra vez';
  static const volverMenu = 'Volver al menú';
  static const onlineProximamente = 'Online de Desconfío próximamente';
  static const infoModoDios =
      'Solo aplica a “Jugar vs PC”.\n\n'
      'Durante la partida ves boca arriba las cartas que tira la PC '
      'al pozo (las tuyas siguen ocultas para el bluff).';

  static const reglaCorta =
      'Mazo español de 48 (12 por palo). Se reparte todo. Declarás un palo y '
      'cada uno tira una carta boca abajo. Si alguien dice desconfío y mentiste, '
      'te llevás el pozo; si era verdad, se lo lleva quien dudó. '
      'Gana quien se queda sin cartas.';
}

String reglasDesconfio() => '''
· Se juega con mazo español de 48 cartas (del 1 al 12 en los cuatro palos:
  oro, copa, espada y basto).

· Se reparte todo el mazo (una carta a cada jugador hasta agotarlo).

· El primer jugador elige un palo (oro, copa, espada o basto).

· En cada turno tirás UNA carta boca abajo al pozo, diciendo que es
  de ese palo (podés mentir).

· Después de cada tirada, otro jugador puede decir «¡Desconfío!»:
  - Se da vuelta la última carta.
  - Si NO es del palo declarado, quien tiró se lleva todo el pozo
    y quien desconfió (acertó) elige el próximo palo.
  - Si SÍ es del palo, quien dijo desconfío se lleva el pozo y
    quien tiró (dijo la verdad) elige el próximo palo.

· Si nadie desconfía, el siguiente tira con el mismo palo.

· Gana quien se queda sin cartas en la mano.
'''.trim();
