import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tienda visual (sin compras reales): paquetes de monedas.
class TiendaScreen extends StatelessWidget {
  const TiendaScreen({super.key});

  static const _paquetes = <_PaqueteMonedas>[
    _PaqueteMonedas(monedas: 100, precioUsd: 1),
    _PaqueteMonedas(monedas: 1000, precioUsd: 5),
    _PaqueteMonedas(monedas: 10000, precioUsd: 25),
    _PaqueteMonedas(monedas: 100000, precioUsd: 100, premium: true),
  ];

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Text(
                    'Tienda',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Text(
                    'Paquetes de monedas (próximamente)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textoSuave,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final ancho = constraints.maxWidth;
                      final cols = ancho >= 720 ? 2 : 1;
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: cols == 1 ? 2.35 : 1.55,
                        ),
                        itemCount: _paquetes.length,
                        itemBuilder: (context, i) =>
                            _TarjetaPaquete(paquete: _paquetes[i]),
                      );
                    },
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
  const _TarjetaPaquete({required this.paquete});

  final _PaqueteMonedas paquete;

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

  @override
  Widget build(BuildContext context) {
    final premium = paquete.premium;
    final borde = premium
        ? const Color(0xFFFFD54F)
        : AppColors.rosa.withValues(alpha: 0.85);
    final glow = premium ? const Color(0xFFFFC107) : AppColors.rosa;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La tienda aún no está disponible.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
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
            border: Border.all(color: borde, width: premium ? 2.2 : 1.6),
            boxShadow: neonGlow(glow, blur: premium ? 16 : 10),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (premium) ...[
                Positioned(
                  top: -6,
                  right: 18,
                  child: Icon(
                    Icons.auto_awesome,
                    color: const Color(0xFFFFECB3).withValues(alpha: 0.9),
                    size: 22,
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 14,
                  child: Icon(
                    Icons.star_rounded,
                    color: const Color(0xFFFFD54F).withValues(alpha: 0.55),
                    size: 18,
                  ),
                ),
                Positioned(
                  top: 18,
                  left: 12,
                  child: Icon(
                    Icons.diamond_rounded,
                    color: const Color(0xFFFFECB3).withValues(alpha: 0.45),
                    size: 16,
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (premium ? AppColors.acento : AppColors.rosa)
                            .withValues(alpha: 0.22),
                        border: Border.all(
                          color: borde,
                          width: 1.4,
                        ),
                      ),
                      child: Icon(
                        Icons.monetization_on_rounded,
                        color: premium ? AppColors.acento : AppColors.rosa,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (premium)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
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
                          Text(
                            '$_monedasFmt monedas',
                            style: TextStyle(
                              color: premium
                                  ? const Color(0xFFFFECB3)
                                  : AppColors.texto,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'US\$ ${paquete.precioUsd}',
                            style: TextStyle(
                              color: premium
                                  ? AppColors.acento
                                  : AppColors.textoSuave,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.lock_outline_rounded,
                      color: (premium ? AppColors.acento : AppColors.textoSuave)
                          .withValues(alpha: 0.75),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
