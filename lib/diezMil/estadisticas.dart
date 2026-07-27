/// Estadísticas de una partida de Diez Mil (por jugador).
class RegistroTirada {
  const RegistroTirada({
    required this.numero,
    required this.puntos,
  });

  final int numero;
  final int puntos;

  bool get sumo => puntos > 0;
}

class EstadisticasJugador {
  EstadisticasJugador(this.nombre);

  String nombre;
  final List<RegistroTirada> tiradas = [];

  int get tirosTotales => tiradas.length;
  int get tirosConPuntos => tiradas.where((t) => t.sumo).length;
  int get tirosSinPuntos => tiradas.where((t) => !t.sumo).length;
  int get puntosTirados =>
      tiradas.fold(0, (sum, t) => sum + t.puntos);

  void registrarTirada(int puntos) {
    tiradas.add(
      RegistroTirada(numero: tiradas.length + 1, puntos: puntos),
    );
  }
}

class EstadisticasPartida {
  EstadisticasPartida(List<String> nombres)
      : porJugador = {
          for (final n in nombres) n: EstadisticasJugador(n),
        };

  final Map<String, EstadisticasJugador> porJugador;

  void registrar(String nombre, int puntos) {
    porJugador[nombre]?.registrarTirada(puntos);
  }

  EstadisticasJugador? de(String nombre) => porJugador[nombre];

  void renombrar(String anterior, String nuevo) {
    if (anterior == nuevo) return;
    final e = porJugador.remove(anterior);
    if (e == null) return;
    e.nombre = nuevo;
    porJugador[nuevo] = e;
  }
}
