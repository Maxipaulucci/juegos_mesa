import 'package:app_juegos_mesa/shared/ajustes/ajustes_overlay.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';

Map<String, dynamic> encodeAjustes(AjustesEstado a) => {
      'volumenMusica': a.volumenMusica,
      'volumenSonidos': a.volumenSonidos,
      'animaciones': a.animaciones,
    };

AjustesEstado decodeAjustes(Object? raw) {
  if (raw is! Map) return const AjustesEstado();
  final m = Map<String, dynamic>.from(raw);
  return AjustesEstado(
    volumenMusica: (m['volumenMusica'] as num?)?.toDouble() ?? 0.8,
    volumenSonidos: (m['volumenSonidos'] as num?)?.toDouble() ?? 0.8,
    animaciones: m['animaciones'] != false,
  );
}

String encodeDificultad(DificultadPc d) => d.name;

DificultadPc decodeDificultad(Object? raw) {
  final id = raw?.toString();
  for (final d in DificultadPc.values) {
    if (d.name == id) return d;
  }
  return DificultadPc.medio;
}
