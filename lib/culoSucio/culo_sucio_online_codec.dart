/// Serialización de Culo sucio v1 para multijugador online.
library;

import 'package:app_juegos_mesa/culoSucio/motor_culo_sucio.dart';

Map<String, dynamic> _encodeCarta(CartaCuloSucio c) => {
      'numero': c.numero,
      'palo': c.palo?.name,
      'esComodin': c.esComodin,
    };

CartaCuloSucio? _decodeCarta(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final esComodin = m['esComodin'] == true;
  if (esComodin) {
    return CartaCuloSucio(numero: null, palo: null, esComodin: true);
  }
  final numero = (m['numero'] as num?)?.toInt();
  final paloId = m['palo']?.toString();
  if (numero == null || paloId == null) return null;
  PaloCuloSucio? palo;
  for (final p in PaloCuloSucio.values) {
    if (p.name == paloId) {
      palo = p;
      break;
    }
  }
  if (palo == null) return null;
  return CartaCuloSucio(numero: numero, palo: palo);
}

List<Map<String, dynamic>> _encodeCartas(List<CartaCuloSucio> cartas) => [
      for (final c in cartas) _encodeCarta(c),
    ];

List<CartaCuloSucio> _decodeCartas(dynamic raw) {
  if (raw is! List) return [];
  final out = <CartaCuloSucio>[];
  for (final item in raw) {
    final c = _decodeCarta(item);
    if (c != null) out.add(c);
  }
  return out;
}

FaseCuloSucio _faseFromId(String? id) {
  for (final f in FaseCuloSucio.values) {
    if (f.name == id) return f;
  }
  return FaseCuloSucio.jugando;
}

bool culoSucioPartidaGenerada(Map<String, dynamic>? raw) {
  if (raw == null) return false;
  if (raw['pendienteMazo'] == true) return false;
  if (raw['juego']?.toString() != 'culoSucioV1') return false;
  final mazo = raw['mazo'];
  // Mazo puede estar vacío al final; basta con que exista la lista.
  return mazo is List;
}

bool culoSucioEsperaMazo(Map<String, dynamic>? raw) =>
    raw != null &&
    raw['juego']?.toString() == 'culoSucioV1' &&
    !culoSucioPartidaGenerada(raw);

Map<String, dynamic> encodeCuloSucioGameState({
  required PartidaCuloSucio partida,
  required int version,
  required bool comodines,
}) {
  return {
    'version': version,
    'juego': 'culoSucioV1',
    'pendienteMazo': false,
    'comodines': comodines,
    'nombres': List<String>.from(partida.nombres),
    'indiceTurno': partida.indiceTurno,
    'fase': partida.fase.name,
    'mazo': _encodeCartas(partida.mazo),
    'ultimaCarta':
        partida.ultimaCarta == null ? null : _encodeCarta(partida.ultimaCarta!),
    'cartasSacadas': partida.cartasSacadas,
    'perdedor': partida.perdedor,
    'ganador': partida.ganador,
    'mensajeFin': partida.mensajeFin,
    'historial': [
      for (final j in partida.historial)
        {
          'turno': j.turno,
          'jugador': j.jugador,
          'carta': _encodeCarta(j.carta),
        },
    ],
    'mostrarVictoria': partida.terminada,
  };
}

void applyCuloSucioGameState(
  PartidaCuloSucio destino,
  Map<String, dynamic> raw,
) {
  destino.indiceTurno = (raw['indiceTurno'] as num?)?.toInt() ?? 0;
  destino.fase = _faseFromId(raw['fase']?.toString());
  destino.cartasSacadas = (raw['cartasSacadas'] as num?)?.toInt() ?? 0;
  destino.perdedor = raw['perdedor']?.toString();
  destino.ganador = raw['ganador']?.toString();
  destino.mensajeFin = raw['mensajeFin']?.toString();
  destino.ultimaCarta = _decodeCarta(raw['ultimaCarta']);

  final nombres = (raw['nombres'] as List?)
      ?.map((e) => e.toString())
      .toList();
  if (nombres != null && nombres.isNotEmpty) {
    destino.nombres
      ..clear()
      ..addAll(nombres);
  }

  destino.mazo
    ..clear()
    ..addAll(_decodeCartas(raw['mazo']));

  destino.historial.clear();
  final histRaw = raw['historial'];
  if (histRaw is List) {
    for (final item in histRaw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final turno = (m['turno'] as num?)?.toInt();
      final jugador = m['jugador']?.toString();
      final carta = _decodeCarta(m['carta']);
      if (turno == null || jugador == null || carta == null) continue;
      destino.historial.add(
        JugadaHistorialCuloSucio(
          turno: turno,
          jugador: jugador,
          carta: carta,
        ),
      );
    }
  }
}
