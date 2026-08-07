/// Textos de Chancho va.
abstract final class TextosChancho {
  static const titulo = 'Chancho va';
  static const vsPcNombre = 'PC';
  static const onlineProximamente = 'Online de Chancho va: próximamente.';
  static const tuMano = 'Tu mano';
  static const eligeNumeros = 'Elegí los números de la partida';
  static const confirmarNumeros = 'Listo';
  static const numero = 'Número';
  static const direccion = 'Dirección';
  static const repetir = 'Repetir';
  static const chancho = 'CHANCHO';
  static const izquierda = 'Izquierda';
  static const derecha = 'Derecha';
  static const centro = 'Centro';
  static const confirmarPase = 'Pasar cartas';
  static const anunciando = 'Elegí cuántas cartas y hacia dónde';
  static const eligiendoCartas = 'Elegí las cartas a pasar';
  static const carrera = '¡Chancho! Tocá antes de quedar último';
  static const esperandoPc = 'La PC está jugando…';
  static const reiniciar = 'Otra vez';
  static const volverMenu = 'Volver al menú';
  static const infoModoDios =
      'Solo aplica a “Jugar vs PC”.\n\n'
      'Durante la partida ves las cartas de la PC boca arriba.';

  static String reglas() => '''
· Se juega con sets de 4 cartas del mismo número (distinto palo).
  Con 2 jugadores hay 2 números (8 cartas); con 3, tres números; etc.

· Al inicio, el primer jugador elige qué números entran en juego.

· En cada turno alguien anuncia cuántas cartas se pasan y hacia dónde
  (izquierda, derecha o centro). Cada uno elige cuáles cartas pasar.

· Al centro: las cartas se mezclan y se redistribuyen; preferimos que
  no te toquen de nuevo las que vos aportaste.

· Quien junta 4 del mismo número puede decir CHANCHO. El último en
  decirlo suma una letra del tablero C-H-A-N-C-H-O- -V-A.
  Quien completa CHANCHO VA pierde.
'''.trim();
}
