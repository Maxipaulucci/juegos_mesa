import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tienda visual (sin compras reales): paquetes de monedas.
class TiendaScreen extends StatelessWidget {
  const TiendaScreen({super.key});

  static const _basicos = <_PaqueteMonedas>[
    _PaqueteMonedas(monedas: 100, precioUsd: 1),
    _PaqueteMonedas(monedas: 1000, precioUsd: 5),
    _PaqueteMonedas(monedas: 10000, precioUsd: 25),
  ];

  static const _mega = _PaqueteMonedas(
    monedas: 100000,
    precioUsd: 100,
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
  final int precioUsd;
  final bool premium;
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

    return SizedBox.expand(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _avisar(context),
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
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
              boxShadow: neonGlow(glow, blur: premium ? 14 : 8),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (premium) ...[
                  Positioned(
                    top: -4,
                    right: 16,
                    child: Icon(
                      Icons.auto_awesome,
                      color: const Color(0xFFFFECB3).withValues(alpha: 0.9),
                      size: 20,
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 12,
                    child: Icon(
                      Icons.diamond_rounded,
                      color: const Color(0xFFFFECB3).withValues(alpha: 0.45),
                      size: 14,
                    ),
                  ),
                ],
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compacta ? 10 : 18,
                    vertical: compacta ? 14 : 16,
                  ),
                  child: SizedBox.expand(
                    child: Center(
                      child: compacta
                          ? _contenidoCompacto()
                          : _contenidoAncho(),
                    ),
                  ),
                ),
              ],
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
          'US\$ ${paquete.precioUsd}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: amarillo,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Icon(
          Icons.lock_outline_rounded,
          color: amarillo.withValues(alpha: 0.75),
          size: 16,
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
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.acento.withValues(alpha: 0.22),
            border: Border.all(color: borde, width: 1.4),
          ),
          child: const Icon(
            Icons.monetization_on_rounded,
            color: AppColors.acento,
            size: 26,
          ),
        ),
        const SizedBox(height: 8),
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
            fontSize: 17,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'US\$ ${paquete.precioUsd}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.acento,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 6),
        Icon(
          Icons.lock_outline_rounded,
          color: AppColors.acento.withValues(alpha: 0.75),
          size: 18,
        ),
      ],
    );
  }
}
