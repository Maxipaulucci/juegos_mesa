import 'package:app_juegos_mesa/laPapa/opciones_la_papa.dart';

String reglasLaPapa({OpcionesPapa opciones = const OpcionesPapa()}) {
  final n = opciones.cantidadNumerosClamped;
  final colocacion = !opciones.numerosAleatorios
      ? 'Antes de jugar, los jugadores colocan los números por turnos '
          '(el primero pone el 1, el siguiente el 2, y así).'
      : (opciones.excepcionGeneracionNumeros
          ? 'Los números se colocan al azar, con la excepción de que '
              'consecutivos no comparten fila ni columna ni son vecinos.'
          : 'Los números se colocan al azar en cualquier casilla del '
              'tablero de 50.');

  final extras = <String>[
    if (opciones.conVidas)
      '· Vidas: cada jugador empieza con ${OpcionesPapa.vidasIniciales} '
          'vidas. Si fallás, perdés una vida y seguís tu turno. '
          'Sin vidas, terminás la partida.',
    if (opciones.modoFantasma)
      '· Modo infernal: solo ves las líneas dibujadas, el número actual '
          'y el siguiente. Siempre hay 50 números al azar, sin cuadrícula, '
          'sin vidas, sin lupa, sin cambiar grosor y sin trazar sobre números.',
    if (!opciones.permitirTrazoSobreNumerosEfectivo && !opciones.modoFantasma)
      '· Trazo sobre números desactivado: si tu línea toca la zona de otro '
          'número (que no sea el de salida o el de llegada), perdés.',
  ];

  return '''
· La papa se juega en una hoja de 5×10 casillas con los números del 1 al $n.

· $colocacion

· En tu turno tenés que unir el número actual con el siguiente (1→2, 2→3, …) dibujando un trazo continuo con el dedo o el mouse.

· El trazo tiene que empezar cerca del número de origen y terminar sobre el destino, sin soltar antes.

· Perdés el intento (o la partida) si:
   - soltás sin llegar al número siguiente;
   - salís de la hoja;
   - cruzás o tocás una línea ya dibujada (incluida la tuya, cerca de la punta).

· Si completás la conexión, el turno pasa al siguiente jugador. Quien conecte hasta el $n gana la hoja.

· Podés elegir el grosor del lápiz (fino / normal / grueso) antes de dibujar.
  Mientras trazás, tocá “Trazos” para ciclar Grueso → Fino → Normal.
  En computadora también podés usar la tecla T.
${extras.isEmpty ? '' : '\n${extras.join('\n\n')}\n'}
· Tocá tu nombre arriba para cambiarlo durante la partida.
'''.trim();
}
