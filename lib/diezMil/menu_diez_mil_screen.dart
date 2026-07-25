import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'crear_sala_screen.dart';
import 'motor.dart';
import 'partida_diez_mil_screen.dart';
import 'unirse_sala_screen.dart';

class MenuDiezMilScreen extends StatelessWidget {
  const MenuDiezMilScreen({super.key});

  static const juegoId = 'diezMil';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diez Mil')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¿Cómo querés jugar?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Creá una sala con código o unite a una existente.',
              style: TextStyle(color: AppColors.textoSuave),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CrearSalaScreen(juegoId: juegoId),
                  ),
                );
              },
              child: const Text('Crear'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const UnirseSalaScreen(juegoId: juegoId),
                  ),
                );
              },
              child: const Text('Unirse'),
            ),
            const SizedBox(height: 28),
            const Divider(color: AppColors.fondoSuave),
            const SizedBox(height: 16),
            const Text(
              'Probar sin sala (mismo celular)',
              style: TextStyle(color: AppColors.textoSuave, fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PartidaDiezMilScreen(
                      nombres: ['Jugador 1', 'Jugador 2'],
                      modo: Modo.cinco,
                    ),
                  ),
                );
              },
              child: const Text('Partida rápida · 5 dados'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PartidaDiezMilScreen(
                      nombres: ['Jugador 1', 'Jugador 2'],
                      modo: Modo.seis,
                    ),
                  ),
                );
              },
              child: const Text('Partida rápida · 6 dados'),
            ),
          ],
        ),
      ),
    );
  }
}
