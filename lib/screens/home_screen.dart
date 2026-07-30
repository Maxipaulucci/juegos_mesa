import 'package:flutter/material.dart';

import '../diezMil/menu_diez_mil_screen.dart';
import '../generala/menu_generala_screen.dart';
import '../laPapa/menu_la_papa_screen.dart';
import '../shared/carga/pantalla_carga.dart';
import '../theme/app_theme.dart';
import '../tutiFruti/menu_tuti_fruti_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _navegando = false;

  Future<void> _abrirJuego({
    required Widget menu,
    required Color acento,
    required String mensaje,
  }) async {
    if (_navegando) return;
    setState(() => _navegando = true);
    try {
      await navegarConCarga<void>(
        context,
        builder: (_) => menu,
        mensaje: mensaje,
        acento: acento,
      );
    } finally {
      if (mounted) setState(() => _navegando = false);
    }
  }

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
                  radius: 1.1,
                  colors: [
                    Color(0xFF2A1450),
                    AppColors.fondo,
                    Color(0xFF070312),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Colors.white, AppColors.acento, AppColors.azul],
                    ).createShader(bounds),
                    child: const Text(
                      'JUEGOS DE MESA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Argentinos · multijugador',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textoSuave,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Expanded(
                    child: ListView(
                      children: [
                        _JuegoTile(
                          titulo: 'Diez Mil',
                          subtitulo: 'Dados · 5 o 6',
                          accent: AppColors.acento,
                          onTap: _navegando
                              ? null
                              : () => _abrirJuego(
                                    menu: const MenuDiezMilScreen(),
                                    acento: AppColors.acento,
                                    mensaje: 'Diez Mil',
                                  ),
                        ),
                        const SizedBox(height: 12),
                        _JuegoTile(
                          titulo: 'Generala',
                          subtitulo: 'Dados · tabla de anotación',
                          accent: AppColors.violeta,
                          onTap: _navegando
                              ? null
                              : () => _abrirJuego(
                                    menu: const MenuGeneralaScreen(),
                                    acento: AppColors.violeta,
                                    mensaje: 'Generala',
                                  ),
                        ),
                        const SizedBox(height: 12),
                        _JuegoTile(
                          titulo: 'Tutti Frutti',
                          subtitulo: 'Letras · categorías online',
                          accent: AppColors.rosa,
                          onTap: _navegando
                              ? null
                              : () => _abrirJuego(
                                    menu: const MenuTutiFrutiScreen(),
                                    acento: AppColors.rosa,
                                    mensaje: 'Tutti Frutti',
                                  ),
                        ),
                        const SizedBox(height: 12),
                        const _JuegoTile(
                          titulo: 'Culo sucio',
                          subtitulo: 'Próximamente',
                          accent: AppColors.peligro,
                          enabled: false,
                        ),
                        const SizedBox(height: 12),
                        _JuegoTile(
                          titulo: 'La papa',
                          subtitulo: 'Hoja · uní los números',
                          accent: AppColors.mint,
                          onTap: _navegando
                              ? null
                              : () => _abrirJuego(
                                    menu: const MenuLaPapaScreen(),
                                    acento: AppColors.mint,
                                    mensaje: 'La papa',
                                  ),
                        ),
                        const SizedBox(height: 12),
                        const _JuegoTile(
                          titulo: 'Escoba del 15',
                          subtitulo: 'Próximamente',
                          accent: AppColors.azul,
                          enabled: false,
                        ),
                        const SizedBox(height: 12),
                        const _JuegoTile(
                          titulo: 'Canasta',
                          subtitulo: 'Próximamente',
                          accent: AppColors.violeta,
                          enabled: false,
                        ),
                        const SizedBox(height: 12),
                        const _JuegoTile(
                          titulo: 'Casita robada',
                          subtitulo: 'Próximamente',
                          accent: AppColors.mint,
                          enabled: false,
                        ),
                        const SizedBox(height: 12),
                        const _JuegoTile(
                          titulo: 'Chancho va',
                          subtitulo: 'Próximamente',
                          accent: AppColors.acentoSuave,
                          enabled: false,
                        ),
                        const SizedBox(height: 12),
                        const _JuegoTile(
                          titulo: 'Desconfío',
                          subtitulo: 'Próximamente',
                          accent: AppColors.azulSuave,
                          enabled: false,
                        ),
                        const SizedBox(height: 12),
                        const _JuegoTile(
                          titulo: 'Jodete',
                          subtitulo: 'Próximamente',
                          accent: AppColors.peligro,
                          enabled: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Elegí un juego para crear o unirte a una sala',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textoSuave, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JuegoTile extends StatelessWidget {
  const _JuegoTile({
    required this.titulo,
    required this.subtitulo,
    required this.accent,
    this.onTap,
    this.enabled = true,
  });

  final String titulo;
  final String subtitulo;
  final Color accent;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final activo = enabled && onTap != null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: activo ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        splashColor: accent.withValues(alpha: 0.25),
        highlightColor: accent.withValues(alpha: 0.12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.carta.withValues(alpha: enabled ? 0.95 : 0.45),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: enabled ? accent : accent.withValues(alpha: 0.25),
              width: enabled ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        color:
                            enabled ? AppColors.texto : AppColors.textoSuave,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        color: enabled ? accent : AppColors.textoSuave,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                enabled ? Icons.chevron_right : Icons.lock_outline,
                color: enabled ? accent : AppColors.textoSuave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
