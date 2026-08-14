/// Ordenamiento cíclico de una mano de cartas (español / similar).
///
/// Ciclo:
/// 1. menor → mayor (sin importar palo)
/// 2. por palo, y dentro de cada palo menor → mayor
/// 3. mayor → menor (sin importar palo)
/// 4. por palo, y dentro de cada palo mayor → menor
library;

enum ModoOrdenManoCartas {
  /// Números de menor a mayor; ignora palo.
  menorAMayor,

  /// Agrupa por palo; dentro de cada palo, menor a mayor.
  porPaloAscendente,

  /// Números de mayor a menor; ignora palo.
  mayorAMenor,

  /// Agrupa por palo; dentro de cada palo, mayor a menor.
  porPaloDescendente;

  /// Siguiente modo del ciclo (vuelve al primero tras el último).
  ModoOrdenManoCartas get siguiente => ModoOrdenManoCartas
      .values[(index + 1) % ModoOrdenManoCartas.values.length];
}

/// Claves genéricas para ordenar cualquier tipo de carta.
class ClavesOrdenCarta {
  const ClavesOrdenCarta({
    required this.numero,
    required this.palo,
    this.esComodin = false,
  });

  /// Valor numérico (1–12 en mazo español). Ignorado si [esComodin].
  final int numero;

  /// Índice de palo estable (p. ej. 0=oro, 1=copa, 2=espada, 3=basto).
  final int palo;

  /// Los comodines van al final al ordenar por valor ascendente / por palo.
  final bool esComodin;
}

/// Ordena [cartas] **in-place** según [modo].
void ordenarManoCartas<T>(
  List<T> cartas, {
  required ModoOrdenManoCartas modo,
  required ClavesOrdenCarta Function(T carta) claves,
}) {
  int cmpPorNumero(T a, T b, {required bool ascendente}) {
    final ca = claves(a);
    final cb = claves(b);
    if (ca.esComodin != cb.esComodin) {
      // Asc: comodín al final. Desc: comodín al inicio (como “más alto”).
      if (ascendente) return ca.esComodin ? 1 : -1;
      return ca.esComodin ? -1 : 1;
    }
    if (ca.esComodin) return 0;
    final c = ca.numero.compareTo(cb.numero);
    if (c != 0) return ascendente ? c : -c;
    // Empate de número: desempata por palo para orden estable.
    return ca.palo.compareTo(cb.palo);
  }

  int cmpPorPaloLuegoNumero(T a, T b, {required bool numeroAsc}) {
    final ca = claves(a);
    final cb = claves(b);
    if (ca.esComodin != cb.esComodin) {
      return ca.esComodin ? 1 : -1; // comodines al final
    }
    if (ca.esComodin) return 0;
    final cp = ca.palo.compareTo(cb.palo);
    if (cp != 0) return cp;
    final cn = ca.numero.compareTo(cb.numero);
    return numeroAsc ? cn : -cn;
  }

  switch (modo) {
    case ModoOrdenManoCartas.menorAMayor:
      cartas.sort((a, b) => cmpPorNumero(a, b, ascendente: true));
    case ModoOrdenManoCartas.mayorAMenor:
      cartas.sort((a, b) => cmpPorNumero(a, b, ascendente: false));
    case ModoOrdenManoCartas.porPaloAscendente:
      cartas.sort((a, b) => cmpPorPaloLuegoNumero(a, b, numeroAsc: true));
    case ModoOrdenManoCartas.porPaloDescendente:
      cartas.sort((a, b) => cmpPorPaloLuegoNumero(a, b, numeroAsc: false));
  }
}

/// Aplica el siguiente modo del ciclo y lo devuelve.
ModoOrdenManoCartas ciclarOrdenManoCartas<T>(
  List<T> cartas, {
  ModoOrdenManoCartas? modoActual,
  required ClavesOrdenCarta Function(T carta) claves,
}) {
  final modo = modoActual?.siguiente ?? ModoOrdenManoCartas.menorAMayor;
  ordenarManoCartas(cartas, modo: modo, claves: claves);
  return modo;
}
