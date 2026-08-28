class RachaLogin {
  const RachaLogin({
    required this.aplicada,
    required this.monedasSumadas,
    required this.diasRacha,
    required this.bonusSemana,
    required this.bonusMes,
    required this.reinicioCiclo,
    required this.objetivoSemana,
    required this.objetivoMes,
  });

  final bool aplicada;
  final int monedasSumadas;
  final int diasRacha;
  final bool bonusSemana;
  final bool bonusMes;
  final bool reinicioCiclo;
  final int objetivoSemana;
  final int objetivoMes;

  factory RachaLogin.vacia() {
    return const RachaLogin(
      aplicada: false,
      monedasSumadas: 0,
      diasRacha: 0,
      bonusSemana: false,
      bonusMes: false,
      reinicioCiclo: false,
      objetivoSemana: 7,
      objetivoMes: 30,
    );
  }

  factory RachaLogin.fromJson(Map<String, dynamic>? json) {
    if (json == null) return RachaLogin.vacia();
    return RachaLogin(
      aplicada: json['aplicada'] == true,
      monedasSumadas: (json['monedasSumadas'] as num?)?.toInt() ?? 0,
      diasRacha: (json['diasRacha'] as num?)?.toInt() ?? 0,
      bonusSemana: json['bonusSemana'] == true,
      bonusMes: json['bonusMes'] == true,
      reinicioCiclo: json['reinicioCiclo'] == true,
      objetivoSemana: (json['objetivoSemana'] as num?)?.toInt() ?? 7,
      objetivoMes: (json['objetivoMes'] as num?)?.toInt() ?? 30,
    );
  }

  String get mensajeNotificacion {
    if (!aplicada || monedasSumadas <= 0) return '';
    if (bonusMes) {
      return '¡Racha de $objetivoMes días! +$monedasSumadas monedas (mes completo).';
    }
    if (bonusSemana) {
      return '¡Racha de $objetivoSemana días! +$monedasSumadas monedas.';
    }
    return 'Racha día $diasRacha: +$monedasSumadas monedas.';
  }
}
