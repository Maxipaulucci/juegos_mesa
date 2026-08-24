/// Catálogo de juegos con IDs iguales al backend (`backend/mongo/src/juegos.mjs`).
class JuegoCatalogoEntry {
  const JuegoCatalogoEntry(this.id, this.nombre);

  final String id;
  final String nombre;
}

const kCatalogoJuegos = <JuegoCatalogoEntry>[
  JuegoCatalogoEntry('diezMil', 'Diez Mil'),
  JuegoCatalogoEntry('generala', 'Generala'),
  JuegoCatalogoEntry('tutiFruti', 'Tutti Frutti'),
  JuegoCatalogoEntry('culoSucioV1', 'Culo sucio v1'),
  JuegoCatalogoEntry('culoSucioV2', 'Culo sucio v2'),
  JuegoCatalogoEntry('laPapa', 'La papa'),
  JuegoCatalogoEntry('unoSolo', 'Uno solo'),
  JuegoCatalogoEntry('escobaDel15', 'Escoba del 15'),
  JuegoCatalogoEntry('canasta', 'Canasta'),
  JuegoCatalogoEntry('casitaRobada', 'Casita robada'),
  JuegoCatalogoEntry('chanchoVa', 'Chancho va'),
  JuegoCatalogoEntry('guerraDeCartas', 'Guerra de cartas'),
  JuegoCatalogoEntry('desconfio', 'Desconfío'),
  JuegoCatalogoEntry('jodete', 'Jodete'),
];
