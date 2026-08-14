import 'package:app_juegos_mesa/diezMil/motor.dart';
import 'package:app_juegos_mesa/shared/dificultad/dificultad_pc.dart';

/// Opciones de “Modificar partida” para Diez Mil.
class OpcionesDiezMil {
  const OpcionesDiezMil({
    this.seisDados = true,
    this.escalera = true,
    this.combosEspeciales = true,
    this.escaleraCircular = false,
  });

  /// Activado: partida con 6 dados. Desactivado: 5 dados.
  final bool seisDados;

  /// Activado: las escaleras suman puntos. Desactivado: no cuentan.
  final bool escalera;

  /// Activado: tres pares, cuatro+par, seis iguales (victoria), cinco
  /// iguales (valor×1000 / victoria con 1s). Desactivado: solo triples
  /// y sueltos (1 y 5).
  final bool combosEspeciales;

  /// Como en Generala: la escalera puede “dar la vuelta” (6→1), p. ej. 5-6-1-2-3.
  final bool escaleraCircular;

  Modo get modo => seisDados ? Modo.seis : Modo.cinco;

  int get dados => modo.dados;

  OpcionesDiezMil copyWith({
    bool? seisDados,
    bool? escalera,
    bool? combosEspeciales,
    bool? escaleraCircular,
  }) {
    return OpcionesDiezMil(
      seisDados: seisDados ?? this.seisDados,
      escalera: escalera ?? this.escalera,
      combosEspeciales: combosEspeciales ?? this.combosEspeciales,
      escaleraCircular: escaleraCircular ?? this.escaleraCircular,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OpcionesDiezMil &&
      other.seisDados == seisDados &&
      other.escalera == escalera &&
      other.combosEspeciales == combosEspeciales &&
      other.escaleraCircular == escaleraCircular;

  @override
  int get hashCode =>
      Object.hash(seisDados, escalera, combosEspeciales, escaleraCircular);
}

/// Config del menú (para aplicar al reiniciar, no al reanudar standby).
abstract final class DiezMilMenuConfig {
  static OpcionesDiezMil _opciones = const OpcionesDiezMil();
  static DificultadPc _dificultad = DificultadPc.medio;
  static bool _modoDios = false;

  static OpcionesDiezMil get opciones => _opciones;
  static DificultadPc get dificultad => _dificultad;
  static bool get modoDios => _modoDios;

  static void actualizar({
    OpcionesDiezMil? opciones,
    DificultadPc? dificultad,
    bool? modoDios,
  }) {
    if (opciones != null) _opciones = opciones;
    if (dificultad != null) _dificultad = dificultad;
    if (modoDios != null) _modoDios = modoDios;
  }
}

/// Textos de ayuda del cartel Modificar partida.
abstract final class TextosOpcionesDiezMil {
  static const infoSeisDados =
      'Activado: se juega con 6 dados (apertura 750).\n\n'
      'Desactivado: se juega con 5 dados (apertura 500).';

  static const infoEscalera =
      'Activado: las escaleras suman puntos '
      '(500 con 5 dados; 1500 con la escalera completa de 6).\n\n'
      'Desactivado: sacar una escalera no suma; esos dados se tratan '
      'como el resto de la tirada (triples / 1 y 5 sueltos).';

  static const infoCombosEspeciales =
      'Activado (6 dados): valen tres pares, cuatro iguales + par, '
      'seis iguales (victoria) y cinco iguales (valor × 1000; cinco 1 = 10.000).\n\n'
      'Activado (5 dados): cinco iguales suman valor × 1000 (cinco 1 = 10.000).\n\n'
      'Desactivado: esos combos no cuentan; solo triples y dados sueltos (1 y 5). '
      'Por ejemplo, cinco 2 suman como un triple (200), no 2000.';

  static const infoEscaleraCircular =
      'Activado: la escalera puede “dar la vuelta”: después del 6 '
      'sigue el 1 (por ejemplo 5-6-1-2-3 también vale).\n\n'
      'Desactivado: solo valen 1-2-3-4-5 y 2-3-4-5-6 '
      '(con 6 dados, la escalera completa 1-2-3-4-5-6 sigue valiendo).\n\n'
      'Solo aplica si “Escalera” está activada.';
}
