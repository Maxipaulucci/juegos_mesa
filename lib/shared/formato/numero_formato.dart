import 'package:intl/intl.dart';

final _fmtEntero = NumberFormat.decimalPattern('es_AR');

/// Formato argentino: miles con punto (ej. 2425 → 2.425).
String formatoNumero(int valor) {
  return _fmtEntero.format(valor);
}

/// Prefijo + para ganancias de monedas (ej. +2.425).
String formatoMonedasGanadas(int valor) {
  if (valor <= 0) return formatoNumero(valor);
  return '+${formatoNumero(valor)}';
}
