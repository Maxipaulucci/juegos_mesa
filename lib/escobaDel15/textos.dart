String reglasEscobaDel15() => '''
· Escoba del 15 se juega con mazo español de 40 cartas (sin 8, 9 ni comodines):
  del 1 al 7 y el 10, 11 y 12 de cada palo (oro, copa, espada, basto).

· Valores para sumar 15: el 10 vale 8, el 11 vale 9 y el 12 vale 10.
  El resto vale su número.

· Se reparte 3 cartas a cada jugador y se ponen 4 sobre la mesa.

· En tu turno jugás una carta de la mano:
  - Si con cartas de la mesa sumás exactamente 15, las capturás.
  - Si no podés, la carta queda en la mesa.

· Escoba: si te llevás todas las cartas de la mesa, sumás 1 punto
  (por cada escoba) al final de la ronda.

· Al terminar la ronda, las cartas que quedan en la mesa (el pozo)
  se las lleva el último jugador que haya capturado una combinación.

· Al terminar la ronda también suman:
  - 1 punto por cada escoba hecha en la ronda;
  - 1 punto quien juntó más cartas (si empatan, nadie);
  - 1 punto quien juntó más oros (si empatan, nadie);
  - 1 punto quien tiene el 7 de oro;
  - 1 punto quien juntó más sietes. Si empatan en cantidad de 7s,
    cada uno mira los palos de los 7 del rival y suma su mejor carta
    de ese palo por debajo del 7 (6, 5, 4…). Gana el de mayor suma;
    si siguen empatados, nadie suma ese punto.

· Gana el primero que llegue a 15 puntos (anotación con palitos,
  como en el truco: cuadrado y diagonal al 5).
'''.trim();
