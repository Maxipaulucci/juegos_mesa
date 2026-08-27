import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tienda visual (sin compras reales): paquetes de monedas.
class TiendaScreen extends StatelessWidget {
  const TiendaScreen({super.key});

  static const _basicos = <_PaqueteMonedas>[
    _PaqueteMonedas(monedas: 100, precioUsd: 0.99),
    _PaqueteMonedas(monedas: 1000, precioUsd: 4.99),
    _PaqueteMonedas(monedas: 10000, precioUsd: 24.99),
  ];

  static const _mega = _PaqueteMonedas(
    monedas: 100000,
    precioUsd: 99.99,
    premium: true,
  );

  /// Misma altura para las 3 de arriba y el MEGA PACK.
  static const double _alturaTarjeta = 168;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.35),
                  radius: 1.15,
                  colors: [
                    Color(0xFF3A1450),
                    AppColors.fondo,
                    Color(0xFF070312),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                const Text(
                  'Tienda',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Paquetes de monedas (próximamente)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textoSuave,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: _alturaTarjeta,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < _basicos.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: _TarjetaPaquete(
                            paquete: _basicos[i],
                            compacta: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: _alturaTarjeta,
                  child: const _TarjetaPaquete(
                    paquete: _mega,
                    compacta: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaqueteMonedas {
  const _PaqueteMonedas({
    required this.monedas,
    required this.precioUsd,
    this.premium = false,
  });

  final int monedas;
  final double precioUsd;
  final bool premium;

  String get precioFmt => precioUsd.toStringAsFixed(2);
}

class _TarjetaPaquete extends StatelessWidget {
  const _TarjetaPaquete({
    required this.paquete,
    required this.compacta,
  });

  final _PaqueteMonedas paquete;
  final bool compacta;

  String get _monedasFmt {
    final s = paquete.monedas.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final desdeFin = s.length - i;
      if (i > 0 && desdeFin % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  void _avisar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('La tienda aún no está disponible.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final premium = paquete.premium;
    final borde = premium
        ? const Color(0xFFFFD54F)
        : AppColors.rosa.withValues(alpha: 0.85);
    final glow = premium ? const Color(0xFFFFC107) : AppColors.rosa;
    const radio = 18.0;

    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radio),
          boxShadow: [
            BoxShadow(
              color: glow.withValues(alpha: 0.45),
              blurRadius: premium ? 16 : 12,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: glow.withValues(alpha: 0.18),
              blurRadius: premium ? 28 : 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(radio),
          child: InkWell(
            onTap: () => _avisar(context),
            borderRadius: BorderRadius.circular(radio),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radio),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: premium
                      ? const [
                          Color(0xFF5C4310),
                          Color(0xFF3A2A08),
                          Color(0xFF1F1604),
                        ]
                      : [
                          AppColors.rosa.withValues(alpha: 0.28),
                          AppColors.carta,
                          AppColors.carta.withValues(alpha: 0.95),
                        ],
                ),
                border: Border.all(color: borde, width: premium ? 2 : 1.4),
              ),
              child: Stack(
                children: [
                  if (premium) ...[
                    Positioned(
                      top: 10,
                      right: 14,
                      child: Icon(
                        Icons.auto_awesome,
                        color: const Color(0xFFFFECB3).withValues(alpha: 0.9),
                        size: 18,
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Icon(
                        Icons.diamond_rounded,
                        color: const Color(0xFFFFECB3).withValues(alpha: 0.45),
                        size: 14,
                      ),
                    ),
                  ],
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      compacta ? 10 : 18,
                      compacta ? 12 : 12,
                      compacta ? 10 : 18,
                      compacta ? 28 : 30,
                    ),
                    child: SizedBox.expand(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: compacta
                              ? _contenidoCompacto()
                              : _contenidoAncho(),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 10,
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: (premium ? AppColors.acento : const Color(0xFFFFD54F))
                          .withValues(alpha: 0.75),
                      size: compacta ? 16 : 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenidoCompacto() {
    const amarillo = Color(0xFFFFD54F);
    const amarilloSuave = Color(0xFFFFECB3);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: amarillo.withValues(alpha: 0.18),
            border: Border.all(color: amarillo, width: 1.3),
          ),
          child: const Icon(
            Icons.monetization_on_rounded,
            color: amarillo,
            size: 24,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$_monedasFmt',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: amarilloSuave,
            fontWeight: FontWeight.w900,
            fontSize: 15,
            height: 1.1,
          ),
        ),
        const Text(
          'monedas',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: amarillo,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'US\$ ${paquete.precioFmt}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: amarillo,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _contenidoAncho() {
    const borde = Color(0xFFFFD54F);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.acento.withValues(alpha: 0.22),
            border: Border.all(color: borde, width: 1.4),
          ),
          child: const Icon(
            Icons.monetization_on_rounded,
            color: AppColors.acento,
            size: 24,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.acento.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.acento.withValues(alpha: 0.7),
            ),
          ),
          child: const Text(
            'MEGA PACK',
            style: TextStyle(
              color: AppColors.acento,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$_monedasFmt monedas',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFFFECB3),
            fontWeight: FontWeight.w900,
            fontSize: 16,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'US\$ ${paquete.precioFmt}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.acento,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
