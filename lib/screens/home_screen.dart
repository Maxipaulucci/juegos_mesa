import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../diezMil/menu_diez_mil_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Juegos de Mesa',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Argentinos · multijugador',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textoSuave,
                    ),
              ),
              const SizedBox(height: 40),
              _JuegoTile(
                titulo: 'Diez Mil',
                subtitulo: 'Dados · 5 o 6 caras',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MenuDiezMilScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              const _JuegoTile(
                titulo: 'Escoba del 15',
                subtitulo: 'Próximamente',
                enabled: false,
              ),
              const SizedBox(height: 12),
              const _JuegoTile(
                titulo: 'Tutti Frutti',
                subtitulo: 'Próximamente',
                enabled: false,
              ),
              const SizedBox(height: 12),
              const _JuegoTile(
                titulo: 'Canasta',
                subtitulo: 'Próximamente',
                enabled: false,
              ),
              const Spacer(),
              Text(
                'Elegí un juego para crear o unirte a una sala',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textoSuave,
                    ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _JuegoTile extends StatelessWidget {
  const _JuegoTile({
    required this.titulo,
    required this.subtitulo,
    this.onTap,
    this.enabled = true,
  });

  final String titulo;
  final String subtitulo;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppColors.carta : AppColors.fondoSuave.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        color: enabled ? AppColors.texto : AppColors.textoSuave,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitulo,
                      style: const TextStyle(
                        color: AppColors.textoSuave,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                enabled ? Icons.chevron_right : Icons.lock_outline,
                color: AppColors.textoSuave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
