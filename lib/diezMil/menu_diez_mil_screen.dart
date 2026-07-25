import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ajustes_overlay.dart';
import 'crear_sala_screen.dart';
import 'motor.dart';
import 'partida_diez_mil_screen.dart';
import 'unirse_sala_screen.dart';

class MenuDiezMilScreen extends StatefulWidget {
  const MenuDiezMilScreen({super.key});

  static const juegoId = 'diezMil';

  @override
  State<MenuDiezMilScreen> createState() => _MenuDiezMilScreenState();
}

class _MenuDiezMilScreenState extends State<MenuDiezMilScreen> {
  bool _modoDios = false;
  AjustesEstado _ajustes = const AjustesEstado();

  Future<void> _abrirAjustes() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AjustesOverlay(
          ajustes: _ajustes,
          onChanged: (ajustes) {
            setState(() => _ajustes = ajustes);
            setDialogState(() {});
          },
          onCerrar: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
  }

  void _abrirPartidaRapida(Modo modo) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartidaDiezMilScreen(
          nombres: const ['Jugador 1', 'Jugador 2'],
          modo: modo,
          partidaRapida: true,
          modoDios: _modoDios,
          ajustesIniciales: _ajustes,
        ),
      ),
    );
  }

  void _abrirVsPc(Modo modo) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartidaDiezMilScreen(
          nombres: const ['Jugador 1', 'PC'],
          modo: modo,
          contraPc: true,
          modoDios: _modoDios,
          ajustesIniciales: _ajustes,
        ),
      ),
    );
  }

  void _explicarModoDios() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.carta,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.help, color: AppColors.textoSuave),
            SizedBox(width: 8),
            Text(
              'Modo Dios',
              style: TextStyle(color: AppColors.acento, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Es un modo de prueba. Durante la partida aparece un botón al lado '
          'de los dados que te deja elegir a mano los valores de la próxima '
          'tirada, en vez de dejarlos al azar.\n\n'
          'Sirve para probar combos y situaciones puntuales sin depender de '
          'la suerte. Solo está disponible en partidas rápidas.',
          style: TextStyle(color: AppColors.texto, height: 1.45),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diez Mil'),
        actions: [
          IconButton(
            onPressed: _abrirAjustes,
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
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
                    builder: (_) =>
                        const CrearSalaScreen(juegoId: MenuDiezMilScreen.juegoId),
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
                    builder: (_) => const UnirseSalaScreen(
                      juegoId: MenuDiezMilScreen.juegoId,
                    ),
                  ),
                );
              },
              child: const Text('Unirse'),
            ),
            const SizedBox(height: 28),
            const Divider(color: AppColors.fondoSuave),
            const SizedBox(height: 16),
            Row(
              children: [
                const Flexible(
                  fit: FlexFit.loose,
                  child: Text(
                    'Probar sin sala (mismo celular)',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textoSuave,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E061C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.violeta.withValues(alpha: 0.7),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Modo Dios',
                        style: TextStyle(
                          color: AppColors.texto,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ModoDiosToggle(
                        activo: _modoDios,
                        onChanged: (v) => setState(() => _modoDios = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _explicarModoDios,
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.help,
                        size: 18,
                        color: AppColors.textoSuave,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _abrirPartidaRapida(Modo.cinco),
              child: const Text('Partida rápida · 5 dados'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _abrirPartidaRapida(Modo.seis),
              child: const Text('Partida rápida · 6 dados'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Jugar vs PC',
              style: TextStyle(
                color: AppColors.textoSuave,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _abrirVsPc(Modo.cinco),
              child: const Text('Jugar vs PC · 5 dados'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _abrirVsPc(Modo.seis),
              child: const Text('Jugar vs PC · 6 dados'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mismo estilo de switch que "Animaciones" en ajustes.
class _ModoDiosToggle extends StatelessWidget {
  const _ModoDiosToggle({
    required this.activo,
    required this.onChanged,
  });

  final bool activo;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!activo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: activo
              ? AppColors.azul.withValues(alpha: 0.45)
              : AppColors.textoSuave.withValues(alpha: 0.28),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: activo ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activo ? AppColors.azulSuave : AppColors.textoSuave,
              boxShadow: activo ? neonGlow(AppColors.azul, blur: 8) : null,
            ),
          ),
        ),
      ),
    );
  }
}
