import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/services/usuario_mongo_service.dart';
import 'package:app_juegos_mesa/shared/ui/animacion_overlay_entrada.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

const _fuego = Color(0xFFFF7043);

const _meses = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

/// Cartel con el calendario del mes actual y los días con login de racha.
Future<void> mostrarCartelCalendarioRacha(BuildContext context) {
  final ahora = DateTime.now();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Calendario de racha',
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (ctx, _, __) {
      return AnimacionOverlayEntrada(
        child: _CartelCalendarioRacha(
          anio: ahora.year,
          mes: ahora.month,
        ),
      );
    },
  );
}

class _CartelCalendarioRacha extends StatefulWidget {
  const _CartelCalendarioRacha({
    required this.anio,
    required this.mes,
  });

  final int anio;
  final int mes;

  @override
  State<_CartelCalendarioRacha> createState() => _CartelCalendarioRachaState();
}

class _CartelCalendarioRachaState extends State<_CartelCalendarioRacha> {
  late Future<Set<int>> _diasFuture;

  @override
  void initState() {
    super.initState();
    _diasFuture = _cargarDias();
  }

  Future<Set<int>> _cargarDias() async {
    final dias = await UsuarioMongoService.instance.diasRachaMes(
      anio: widget.anio,
      mes: widget.mes,
    );
    return dias.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final esMesActual =
        hoy.year == widget.anio && hoy.month == widget.mes;
    final tituloMes = '${_meses[widget.mes - 1]} ${widget.anio}';

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          OverlayFondoEntrada(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.72),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: OverlayCartelEntrada(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF3B1D6E),
                              Color(0xFF1A0A33),
                              Color(0xFF2A1050),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _fuego, width: 2),
                          boxShadow: neonGlow(_fuego, blur: 18),
                        ),
                        child: FutureBuilder<Set<int>>(
                          future: _diasFuture,
                          builder: (context, snap) {
                            final diasLogin = snap.data ?? const <int>{};
                            final cargando =
                                snap.connectionState == ConnectionState.waiting;

                            return OverlayColumnaEntrada(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_month_rounded,
                                      color: _fuego,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        tituloMes,
                                        style: const TextStyle(
                                          color: AppColors.acento,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      icon: const Icon(
                                        Icons.close,
                                        color: AppColors.texto,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Días con inicio de sesión',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textoSuave
                                        .withValues(alpha: 0.95),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (cargando)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 28),
                                    child: Center(
                                      child: SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: _fuego,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  _GrillaMes(
                                    anio: widget.anio,
                                    mes: widget.mes,
                                    diasLogin: diasLogin,
                                    diaHoy: esMesActual ? hoy.day : null,
                                  ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: _fuego,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Iniciaste sesión',
                                      style: TextStyle(
                                        color: AppColors.textoSuave
                                            .withValues(alpha: 0.95),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrillaMes extends StatelessWidget {
  const _GrillaMes({
    required this.anio,
    required this.mes,
    required this.diasLogin,
    this.diaHoy,
  });

  final int anio;
  final int mes;
  final Set<int> diasLogin;
  final int? diaHoy;

  static const _cabeceras = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final primerDia = DateTime(anio, mes, 1);
    final diasEnMes = DateTime(anio, mes + 1, 0).day;
    final offset = primerDia.weekday - DateTime.monday;
    final celdas = <int?>[
      for (var i = 0; i < offset; i++) null,
      for (var d = 1; d <= diasEnMes; d++) d,
    ];
    while (celdas.length % 7 != 0) {
      celdas.add(null);
    }

    return Column(
      children: [
        Row(
          children: [
            for (final letra in _cabeceras)
              Expanded(
                child: Center(
                  child: Text(
                    letra,
                    style: TextStyle(
                      color: AppColors.textoSuave.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (var fila = 0; fila < celdas.length; fila += 7)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _CeldaDia(
                      dia: celdas[fila + col],
                      activo: celdas[fila + col] != null &&
                          diasLogin.contains(celdas[fila + col]),
                      esHoy: celdas[fila + col] == diaHoy,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CeldaDia extends StatelessWidget {
  const _CeldaDia({
    required this.dia,
    required this.activo,
    required this.esHoy,
  });

  final int? dia;
  final bool activo;
  final bool esHoy;

  @override
  Widget build(BuildContext context) {
    if (dia == null) return const SizedBox(height: 34);

    final fondo = activo
        ? _fuego
        : AppColors.carta.withValues(alpha: 0.35);
    final borde = esHoy
        ? Border.all(color: AppColors.acento, width: 1.6)
        : Border.all(color: Colors.transparent, width: 1.6);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(8),
            border: borde,
          ),
          child: Center(
            child: Text(
              '$dia',
              style: TextStyle(
                color: activo ? Colors.white : AppColors.textoSuave,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
