class UsuarioMongo {
  const UsuarioMongo({
    required this.id,
    required this.nombre,
    required this.email,
    required this.puntos,
    this.nombreUsuario = '',
    this.monedas = 0,
    this.rachaDias = 0,
    this.rachaMaxima = 0,
    this.creadoEn,
  });

  final String id;
  final String nombre;
  final String nombreUsuario;
  final String email;
  final Map<String, int> puntos;
  final int monedas;
  final int rachaDias;
  final int rachaMaxima;
  final DateTime? creadoEn;

  int puntosDe(String juego) => puntos[juego] ?? 0;

  int get puntosGlobal => puntosDe('global');

  factory UsuarioMongo.fromJson(Map<String, dynamic> json) {
    final raw = json['puntos'];
    final puntos = <String, int>{};
    if (raw is Map) {
      for (final e in raw.entries) {
        puntos[e.key.toString()] = (e.value as num?)?.toInt() ?? 0;
      }
    }
    DateTime? creado;
    final c = json['creadoEn'];
    if (c is String) creado = DateTime.tryParse(c);
    return UsuarioMongo(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ??
          json['nombreUsuario']?.toString() ??
          '',
      nombreUsuario: json['nombreUsuario']?.toString() ??
          json['nombre']?.toString() ??
          '',
      email: json['email']?.toString() ?? '',
      puntos: puntos,
      monedas: (json['monedas'] as num?)?.toInt() ?? 0,
      rachaDias: (json['rachaDias'] as num?)?.toInt() ?? 0,
      rachaMaxima: (json['rachaMaxima'] as num?)?.toInt() ?? 0,
      creadoEn: creado,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'nombreUsuario': nombreUsuario,
        'email': email,
        'puntos': puntos,
        'monedas': monedas,
        'rachaDias': rachaDias,
        'rachaMaxima': rachaMaxima,
        if (creadoEn != null) 'creadoEn': creadoEn!.toIso8601String(),
      };

  UsuarioMongo copyWith({
    int? monedas,
    int? rachaDias,
    int? rachaMaxima,
  }) {
    return UsuarioMongo(
      id: id,
      nombre: nombre,
      nombreUsuario: nombreUsuario,
      email: email,
      puntos: puntos,
      monedas: monedas ?? this.monedas,
      rachaDias: rachaDias ?? this.rachaDias,
      rachaMaxima: rachaMaxima ?? this.rachaMaxima,
      creadoEn: creadoEn,
    );
  }
}

class PuestoRanking {
  const PuestoRanking({
    required this.puesto,
    required this.id,
    required this.nombre,
    required this.puntos,
  });

  final int puesto;
  final String id;
  final String nombre;
  final int puntos;

  factory PuestoRanking.fromJson(Map<String, dynamic> json) {
    return PuestoRanking(
      puesto: (json['puesto'] as num?)?.toInt() ?? 0,
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      puntos: (json['puntos'] as num?)?.toInt() ?? 0,
    );
  }
}
