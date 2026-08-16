/** IDs iguales a los de la app Flutter (`MenuJuegoScreen.juegoId…`). */
export const JUEGOS = [
  'diezMil',
  'generala',
  'tutiFruti',
  'culoSucioV1',
  'culoSucioV2',
  'laPapa',
  'unoSolo',
  'escobaDel15',
  'canasta',
  'casitaRobada',
  'chanchoVa',
  'guerraDeCartas',
  'desconfio',
  'jodete',
];

export const JUEGO_GLOBAL = 'global';

export function puntosVacios() {
  const puntos = { [JUEGO_GLOBAL]: 0 };
  for (const id of JUEGOS) puntos[id] = 0;
  return puntos;
}

export function juegoValido(id) {
  return id === JUEGO_GLOBAL || JUEGOS.includes(id);
}
