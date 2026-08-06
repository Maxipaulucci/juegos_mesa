/// Serialización de Culo sucio v2 para multijugador online.
library;

import 'package:app_juegos_mesa/culoSucioV2/motor_culo_sucio_v2.dart';
import 'package:app_juegos_mesa/culoSucioV2/opciones_culo_sucio_v2.dart';

Map<String, dynamic> _encodeCarta(CartaCuloSucioV2 c) => {
      'numero': c.numero,
      'palo': c.palo.name,
    };

CartaCuloSucioV2? _decodeCarta(dynamic raw) {
  if (raw is! Map) return null;
  final m = Map<String, dynamic>.from(raw);
  final numero = (m['numero'] as num?)?.toInt();
  final paloId = m['palo']?.toString();
  if (numero == null || paloId == null) return null;
  PaloCuloSucioV2? palo;
  for (final p in PaloCuloSucioV2.values) {
    if (p.name == paloId) {
      palo = p;
      break;
    }
  }
  if (palo == null) return null;
  return CartaCuloSucioV2(numero: numero, palo: palo);
}

List<Map<String, dynamic>> _encodeCartas(List<CartaCuloSucioV2> cartas) => [
      for (final c in cartas) _encodeCarta(c),
    ];

List<CartaCuloSucioV2> _decodeCartas(dynamic raw) {
  if (raw is! List) return [];
  final out = <CartaCuloSucioV2>[];
  for (final item in raw) {
    final c = _decodeCarta(item);
    if (c != null) out.add(c);
  }
  return out;
}

FaseCuloSucioV2 _faseFromId(String? id) {
  for (final f in FaseCuloSucioV2.values) {
    if (f.name == id) return f;
  }
  return FaseCuloSucioV2.jugando;
}

/// True cuando el anfitrión ya publicó el mazo repartido.
bool culoSucioV2PartidaGenerada(Map<String, dynamic>? raw) {
  if (raw == null) return false;
  if (raw['pendienteMazo'] == true) return false;
  if (raw['juego']?.toString() != 'culoSucioV2') return false;
  final jugadores = raw['jugadores'];
  if (jugadores is! List || jugadores.isEmpty) return false;
  final fase = raw['fase']?.toString();
  if (fase == 'jugando' || fase == 'terminada') return true;
  for (final item in jugadores) {
    if (item is! Map) continue;
    final mano = item['mano'];
    final descartes = item['descartes'];
    if (mano is List && mano.isNotEmpty) return true;
    if (descartes is List && descartes.isNotEmpty) return true;
  }
  return false;
}

bool culoSucioV2EsperaMazo(Map<String, dynamic>? raw) =>
    raw != null &&
    raw['juego']?.toString() == 'culoSucioV2' &&
    !culoSucioV2PartidaGenerada(raw);

Map<String, dynamic> encodeCuloSucioV2GameState({
  required PartidaCuloSucioV2 partida,
  required int version,
  required OpcionesCuloSucioV2 opciones,
}) {
  return {
    'version': version,
    'juego': 'culoSucioV2',
    'pendienteMazo': false,
    'indiceTurno': partida.indiceTurno,
    'fase': partida.fase.name,
    'perdedor': partida.perdedor,
    'ganador': partida.ganador,
    'mensajeFin': partida.mensajeFin,
    'ultimaRobada': partida.ultimaRobada == null
        ? null
        : _encodeCarta(partida.ultimaRobada!),
    'ultimaRobadaDe': partida.ultimaRobadaDe,
    'ultimaRobadaPor': partida.ultimaRobadaPor,
    'ultimoPar': partida.ultimoPar == null
        ? null
        : _encodeCartas(partida.ultimoPar!),
    'eliminarParesAuto': opciones.eliminarParesAuto,
    'detectarParTrasRobo': opciones.detectarParTrasRobo,
    'jugadores': [
      for (final j in partida.jugadores)
        {
          'nombre': j.nombre,
          'mano': _encodeCartas(j.mano),
          'descartes': _encodeCartas(j.descartes),
          'paresInicialesListos': j.paresInicialesListos,
        },
    ],
    'mostrarVictoria': partida.terminada,
  };
}

/// Aplica [raw] sobre [destino] (mutándola).
void applyCuloSucioV2GameState(
  PartidaCuloSucioV2 destino,
  Map<String, dynamic> raw,
) {
  destino.indiceTurno = (raw['indiceTurno'] as num?)?.toInt() ?? 0;
  destino.fase = _faseFromId(raw['fase']?.toString());
  destino.perdedor = raw['perdedor']?.toString();
  destino.ganador = raw['ganador']?.toString();
  destino.mensajeFin = raw['mensajeFin']?.toString();
  destino.ultimaRobada = _decodeCarta(raw['ultimaRobada']);
  destino.ultimaRobadaDe = raw['ultimaRobadaDe']?.toString();
  destino.ultimaRobadaPor = raw['ultimaRobadaPor']?.toString();

  final parRaw = raw['ultimoPar'];
  if (parRaw is List && parRaw.isNotEmpty) {
    destino.ultimoPar = _decodeCartas(parRaw);
  } else {
    destino.ultimoPar = null;
  }

  final jugadoresRaw = raw['jugadores'];
  if (jugadoresRaw is! List) return;

  // Reordenar / recrear si cambian nombres o cantidad.
  final porNombre = {
    for (final j in destino.jugadores) j.nombre: j,
  };
  final nuevos = <JugadorCuloSucioV2>[];
  for (final item in jugadoresRaw) {
    if (item is! Map) continue;
    final m = Map<String, dynamic>.from(item);
    final nombre = m['nombre']?.toString() ?? '';
    if (nombre.isEmpty) continue;
    final j = porNombre[nombre] ?? JugadorCuloSucioV2(nombre);
    j.mano
      ..clear()
      ..addAll(_decodeCartas(m['mano']));
    j.descartes
      ..clear()
      ..addAll(_decodeCartas(m['descartes']));
    j.paresInicialesListos = m['paresInicialesListos'] == true;
    nuevos.add(j);
  }
  if (nuevos.isNotEmpty) {
    destino.jugadores
      ..clear()
      ..addAll(nuevos);
  }
}

OpcionesCuloSucioV2 opcionesDesdeCuloSucioV2GameState(
  Map<String, dynamic> raw,
  OpcionesCuloSucioV2 fallback,
) {
  if (!raw.containsKey('eliminarParesAuto') &&
      !raw.containsKey('detectarParTrasRobo')) {
    return fallback;
  }
  return fallback.copyWith(
    eliminarParesAuto: raw.containsKey('eliminarParesAuto')
        ? raw['eliminarParesAuto'] == true
        : null,
    detectarParTrasRobo: raw.containsKey('detectarParTrasRobo')
        ? raw['detectarParTrasRobo'] == true
        : null,
  );
}
