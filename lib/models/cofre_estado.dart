class CofreEstado {
  const CofreEstado({
    required this.listo,
    required this.monedas,
    required this.cooldownMs,
    required this.restanteMs,
  });

  final bool listo;
  final int monedas;
  final int cooldownMs;
  final int restanteMs;

  factory CofreEstado.vacio({int monedas = 0, int cooldownMs = 0}) {
    return CofreEstado(
      listo: false,
      monedas: monedas,
      cooldownMs: cooldownMs,
      restanteMs: cooldownMs,
    );
  }

  factory CofreEstado.fromJson(Map<String, dynamic> json) {
    return CofreEstado(
      listo: json['listo'] == true,
      monedas: (json['monedas'] as num?)?.toInt() ?? 0,
      cooldownMs: (json['cooldownMs'] as num?)?.toInt() ?? 0,
      restanteMs: (json['restanteMs'] as num?)?.toInt() ?? 0,
    );
  }

  CofreEstado conRestante(int ms) {
    return CofreEstado(
      listo: ms <= 0,
      monedas: monedas,
      cooldownMs: cooldownMs,
      restanteMs: ms < 0 ? 0 : ms,
    );
  }

  CofreEstado forzarListo() {
    return CofreEstado(
      listo: true,
      monedas: monedas,
      cooldownMs: cooldownMs,
      restanteMs: 0,
    );
  }
}

class CofresEstado {
  const CofresEstado({
    required this.madera,
    required this.oro,
  });

  final CofreEstado madera;
  final CofreEstado oro;

  static const maderaMonedas = 10;
  static const oroMonedas = 75;
  static const maderaCooldownMs = 4 * 60 * 60 * 1000;
  static const oroCooldownMs = 24 * 60 * 60 * 1000;

  factory CofresEstado.bloqueado() {
    return CofresEstado(
      madera: CofreEstado.vacio(
        monedas: maderaMonedas,
        cooldownMs: maderaCooldownMs,
      ),
      oro: CofreEstado.vacio(
        monedas: oroMonedas,
        cooldownMs: oroCooldownMs,
      ),
    );
  }

  factory CofresEstado.fromJson(Map<String, dynamic> json) {
    final raw = json['cofres'];
    if (raw is! Map) return CofresEstado.bloqueado();
    final m = Map<String, dynamic>.from(raw);
    return CofresEstado(
      madera: m['madera'] is Map
          ? CofreEstado.fromJson(Map<String, dynamic>.from(m['madera'] as Map))
          : CofreEstado.vacio(
              monedas: maderaMonedas,
              cooldownMs: maderaCooldownMs,
            ),
      oro: m['oro'] is Map
          ? CofreEstado.fromJson(Map<String, dynamic>.from(m['oro'] as Map))
          : CofreEstado.vacio(
              monedas: oroMonedas,
              cooldownMs: oroCooldownMs,
            ),
    );
  }

  CofresEstado tick() {
    return CofresEstado(
      madera: madera.conRestante(madera.restanteMs - 1000),
      oro: oro.conRestante(oro.restanteMs - 1000),
    );
  }

  bool get hayCooldown =>
      (!madera.listo && madera.restanteMs > 0) ||
      (!oro.listo && oro.restanteMs > 0);

  CofresEstado forzarListos() {
    return CofresEstado(
      madera: madera.forzarListo(),
      oro: oro.forzarListo(),
    );
  }
}
