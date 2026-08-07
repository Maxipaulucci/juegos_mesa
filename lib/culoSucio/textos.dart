/// Textos de Culo sucio v1.
abstract final class TextosCuloSucio {
  static const titulo = 'Culo sucio v1';
  static const reglaCorta =
      'Mazo español. Por turnos sacás una carta. '
      'Quien saque el 1 de oro es el culo sucio y pierde.';
  static String reglaConOpciones({required bool comodines}) => comodines
      ? 'Mazo español de 50 cartas (con comodines). '
          'Por turnos sacás una carta. Quien saque el 1 de oro '
          'es el culo sucio y pierde.'
      : 'Mazo español de 48 cartas. '
          'Por turnos sacás una carta. Quien saque el 1 de oro '
          'es el culo sucio y pierde.';
  static const sacarCarta = 'Sacar carta';
  static const cartasRestantes = 'Cartas en el mazo';
  static const turnoDe = 'Turno de';
  static const ultimaCarta = 'Última carta';
  static const culoSucio = '¡CULO SUCIO!';
  static const reiniciar = 'Otra vez';
  static const volverMenu = 'Volver al menú';
  static const vsPcNombre = 'PC';
  static const infoModoDios =
      'Solo aplica a “Jugar vs PC”.\n\n'
      'Durante la partida ves qué carta va a salir del mazo, '
      'y aparece un botón (el del bichito) para abrir el mazo restante '
      'en orden, reordenarlo y elegir cuál es la próxima.\n\n'
      'Sirve para probar partidas sin depender del azar.';
}

String reglasCuloSucio({required bool comodines}) => comodines
    ? '''
· Se juega con mazo español de 50 cartas (incluye comodines).

· Por turnos, cada jugador saca una carta del mazo.

· Quien saque el 1 de oro es el culo sucio y pierde.
'''.trim()
    : '''
· Se juega con mazo español de 48 cartas (sin comodines).

· Por turnos, cada jugador saca una carta del mazo.

· Quien saque el 1 de oro es el culo sucio y pierde.
'''.trim();
