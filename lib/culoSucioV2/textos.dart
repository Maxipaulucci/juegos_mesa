/// Textos de Culo sucio v2.
abstract final class TextosCuloSucioV2 {
  static const titulo = 'Culo sucio v2';
  static const reglaCorta =
      'Mazo de 45 cartas (solo el 1 de oro entre los ases). '
      'Al empezar, sacá vos los pares del mismo número. '
      'Después robá una carta del rival; quien se quede con el 1 de oro pierde.';
  static const vsPcNombre = 'PC';
  static const tuMano = 'Tu mano';
  static const manoRival = 'Mano del rival';
  static const paresDescartados = 'Pares descartados';
  static const robaUna = 'Tocá una carta tapada del rival';
  static const moverCulo =
      'Tenés el 1 de oro: tocálo y después otra carta para moverlo';
  static const culoSeleccionado =
      '1 de oro seleccionado: tocá otra carta de tu mano para colocarlo';
  static const tocaParParaSacar =
      'Formaste un par: tocá una de las cartas marcadas para sacarlo';
  static const notifPuedeEliminarPar =
      'Podés eliminar un par de tu mano. Tocá una de las cartas marcadas.';
  static const sacandoPares =
      'Tocá dos cartas del mismo número: se sacan solas';
  static const listoPares = 'Listo · sin más pares';
  static const eliminarParesAuto = 'Eliminar pares automáticamente';
  static const infoEliminarParesAuto =
      'Si no querés este botón, desactivalo desde '
      '“Modificar partida” en el menú del juego.';
  static const detectarParTrasRobo = 'Autodetectar par al robar';
  static const infoDetectarParTrasRobo =
      'Activado: si al robar formás un par, se marcan las dos cartas '
      'y tocás una para sacarlo.\n\n'
      'Desactivado: la carta robada solo se agrega a tu mano '
      '(sin aviso ni selección). El rival espera 2 segundos antes '
      'de robarte.\n\n'
      'Viene activado por defecto.';
  static const moverCuloSucio = "Mover 'culo sucio'";
  static const infoMoverCuloSucio =
      'Activado: en tu turno, si tenés el 1 de oro, podés tocarlo y '
      'moverlo a otra posición de tu mano (el rival roba esa posición).\n\n'
      'Desactivado: el 1 de oro no se puede reordenar.\n\n'
      'Viene activado por defecto.';
  static const esperandoPc = 'La PC está eligiendo…';
  static const pcSeLleva = 'LA PC SE LLEVA';
  static const pcEligioCarta = '¡La PC eligió una de tus cartas!';
  static const esperandoRivalPares = 'Esperando que el rival saque sus pares…';
  static const esperandoMazoOnline = 'Esperando el mazo…';
  static const esperandoTuTurno = 'Esperando al rival…';
  static const rivalTeSaco = 'TE SACARON ESTA CARTA';
  static const cambioDeJugador = 'Cambio de jugador';
  static const aceptarCambioJugador = 'Aceptar';
  static const culoSucio = '¡CULO SUCIO!';
  static const reiniciar = 'Otra vez';
  static const volverMenu = 'Volver al menú';
  static const infoModoDios =
      'Solo aplica a “Jugar vs PC”.\n\n'
      'Durante la partida ves las cartas de la PC boca arriba '
      'para probar jugadas.';

  static String reglasCompletas() => '''
· Culo sucio v2 se juega con un mazo de 45 cartas españolas:
  del 1 al 12 de cada palo, pero de los ases solo queda el 1 de oro
  (el “culo sucio”).

· Al empezar se reparte todo el mazo. Cada jugador saca de su mano
  los pares del mismo número (sin importar el palo).

· Cuando todos terminaron de sacar pares, empieza el juego:
  en tu turno tocás una carta tapada de la mano del rival y te la
  llevás a tu mano.

· Si con esa carta formás un par, podés sacarlo (según las opciones
  de la partida: autodetección o a mano).

· Quien se queda solo con el 1 de oro (o se queda sin cartas
  dejando el culo sucio al otro) pierde: ¡CULO SUCIO!
'''.trim();
}
