import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Barra inferior: inicio, juegos, cuenta, ranking y tienda.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.indiceActual,
    required this.onTap,
  });

  /// 0 inicio · 1 juegos · 2 cuenta · 3 ranking · 4 tienda
  final int indiceActual;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.nav,
        border: Border(
          top: BorderSide(color: AppColors.cartaBorde.withValues(alpha: 0.85)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.violeta.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottom),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ItemNav(
            icono: Icons.home_rounded,
            color: AppColors.azul,
            activo: indiceActual == 0,
            habilitado: true,
            onTap: () => onTap(0),
          ),
          _ItemNav(
            icono: Icons.sports_esports_rounded,
            color: AppColors.azul,
            activo: indiceActual == 1,
            habilitado: true,
            onTap: () => onTap(1),
          ),
          _ItemNav(
            icono: Icons.person_rounded,
            color: AppColors.mint,
            activo: indiceActual == 2,
            habilitado: true,
            onTap: () => onTap(2),
          ),
          _ItemNav(
            icono: Icons.emoji_events_rounded,
            color: AppColors.acento,
            activo: false,
            habilitado: false,
            onTap: () => onTap(3),
          ),
          _ItemNav(
            icono: Icons.shopping_cart_rounded,
            color: AppColors.rosa,
            activo: false,
            habilitado: false,
            onTap: () => onTap(4),
          ),
        ],
      ),
    );
  }
}

class _ItemNav extends StatelessWidget {
  const _ItemNav({
    required this.icono,
    required this.color,
    required this.activo,
    required this.habilitado,
    required this.onTap,
  });

  final IconData icono;
  final Color color;
  final bool activo;
  final bool habilitado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final opacidad = habilitado ? 1.0 : 0.38;

    return Opacity(
      opacity: opacidad,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: activo ? color.withValues(alpha: 0.16) : Colors.transparent,
              border: activo
                  ? Border.all(color: color.withValues(alpha: 0.85), width: 1.6)
                  : null,
              boxShadow: activo ? neonGlow(color, blur: 10) : null,
            ),
            child: Icon(
              icono,
              color: activo ? color : AppColors.textoSuave,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
