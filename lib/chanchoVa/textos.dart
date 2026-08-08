/// Textos de Chancho va.
abstract final class TextosChancho {
  static const titulo = 'Chancho va';
  static const vsPcNombre = 'PC';

  /// Nombres de PC: "PC", "PC 1", "PC 2", …
  static bool esPc(String nombre) =>
      nombre == vsPcNombre ||
      (nombre.startsWith('PC ') && nombre.length > 3);

  /// 1 humano + (total-1) PCs. [total] entre 3 y 4 (mín. 2 PCs).
  static List<String> nombresVsPc({
    required String humano,
    required int total,
  }) {
    final n = total.clamp(3, 4);
    return [
      humano,
      for (var i = 1; i < n; i++) 'PC $i',
    ];
  }
  static const onlineProximamente = '';
  static const tuMano = 'Tu mano';
  static const eligeNumeros = 'Elegí los números de la partida';
  static const confirmarNumeros = 'Listo';
  static const cantidad = 'Cantidad';
  static const direccion = 'Dirección';
  static const repetir = 'Repetir';
  static const chancho = 'CHANCHO';
  static const chancha = 'CHANCHA';
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
      'Durante la partida ves las cartas de cada PC boca arriba.';

  static const infoOpcionChancha =
      'Activado (por defecto): aparece el botón CHANCHA y las PCs también '
      'pueden lanzarla. Cada jugador (humano o PC) solo puede decir CHANCHA '
      'una vez por ronda, hasta que alguien saque Chancho y empiece otra.\n\n'
      'Desactivado: no hay botón CHANCHA y las PCs no pueden usarla.';

  static const infoOpcionSinEspacio =
      'Desactivado (por defecto): el tablero es CHANCHO VA '
      '(el espacio cuenta como una letra).\n\n'
      'Activado: el tablero es CHANCHOVA, sin espacio.';

  static const infoOpcionFinAlPrimerPerdedor =
      'Desactivado (por defecto): quien completa la palabra queda fuera y '
      'la partida sigue hasta que quede un solo jugador (ese gana).\n\n'
      'Activado: la partida termina en cuanto el primer jugador completa '
      'la palabra.';

  static String reglas() => '''
· Se juega con sets de 4 cartas del mismo número (distinto palo).
  Mínimo 3 jugadores: tres números (12 cartas); con 4, cuatro números.

· Al inicio, el primer jugador elige qué números entran en juego.

· En cada ronda un jugador anuncia cuántas cartas se pasan y hacia dónde
  (izquierda, derecha o centro). Cada uno elige cuáles cartas pasar.
  Ese mismo anunciante sigue anunciando hasta que alguien diga CHANCHO;
  después le toca anunciar al siguiente.

· Al centro: las cartas se mezclan y se redistribuyen; preferimos que
  no te toquen de nuevo las que vos aportaste.

· Quien junta 4 del mismo número puede decir CHANCHO. El último en
  decirlo suma una letra del tablero. Quien completa la palabra queda
  fuera; la partida sigue hasta que quede un solo jugador (salvo que
  actives “Fin al primer perdedor” en Modificar partida).

· CHANCHA (si está activa): cada jugador o PC solo puede lanzarla una
  vez por ronda, hasta que alguien saque Chancho y empiece otra.
'''.trim();
}
