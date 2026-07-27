import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ajustes_overlay.dart';
import 'crear_sala_screen.dart';
import 'ia_diez_mil.dart';
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
  DificultadPc _dificultad = DificultadPc.medio;

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
          dificultadPc: _dificultad,
          modoDios: _modoDios,
          ajustesIniciales: _ajustes,
        ),
      ),
    );
  }

  Future<void> _elegirDificultad() async {
    final elegida = await showDialog<DificultadPc>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.carta,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Dificultad',
          style: TextStyle(color: AppColors.acento, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final d in DificultadPc.values) ...[
              if (d != DificultadPc.values.first) const SizedBox(height: 10),
              // El borde de la opción elegida va por afuera para no achicar
              // el botón.
              Container(
                decoration: BoxDecoration(
                  // Radio del botón (18) + grosor del borde.
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(
                    color: d == _dificultad ? Colors.black : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(d),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: d.color,
                    foregroundColor: const Color(0xFF1A0A00),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(
                    d.etiqueta,
                    style: const TextStyle(
                      color: Color(0xFF1A0A00),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (elegida != null && mounted) {
      setState(() => _dificultad = elegida);
    }
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
          'la suerte. Funciona en partidas rápidas y jugando contra la PC '
          '(en tu turno).',
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: constraints.maxWidth - 0.1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '¿Cómo querés jugar?',
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppColors.texto,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Creá una sala con código o unite a una existente.',
                      style: TextStyle(color: AppColors.textoSuave),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CrearSalaScreen(
                              juegoId: MenuDiezMilScreen.juegoId,
                            ),
                          ),
                        );
                      },
                      child: const Text('Crear'),
                    ),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 16),
                    const Divider(color: AppColors.fondoSuave),
                    const SizedBox(height: 12),
                    _FilaModoDios(
                      etiqueta: 'Probar sin sala (mismo celular)',
                      activo: _modoDios,
                      onChanged: (v) => setState(() => _modoDios = v),
                      onInfo: _explicarModoDios,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => _abrirPartidaRapida(Modo.cinco),
                      child: const Text('Partida rápida · 5 dados'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _abrirPartidaRapida(Modo.seis),
                      child: const Text('Partida rápida · 6 dados'),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: AppColors.fondoSuave),
                    const SizedBox(height: 12),
                    _FilaModoDios(
                      etiqueta: 'Jugar vs PC',
                      activo: _modoDios,
                      onChanged: (v) => setState(() => _modoDios = v),
                      onInfo: _explicarModoDios,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => _abrirVsPc(Modo.cinco),
                      child: const Text('Jugar vs PC · 5 dados'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _abrirVsPc(Modo.seis),
                      child: const Text('Jugar vs PC · 6 dados'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _elegirDificultad,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _dificultad.color,
                        foregroundColor: const Color(0xFF1A0A00),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Dificultad · ${_dificultad.etiqueta}',
                        style: const TextStyle(
                          color: Color(0xFF1A0A00),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Color de UI para cada dificultad (la lógica vive en ia_diez_mil.dart).
extension DificultadPcUi on DificultadPc {
  Color get color => switch (this) {
        DificultadPc.facil => AppColors.mint,
        DificultadPc.medio => AppColors.acento,
        DificultadPc.dificil => AppColors.peligro,
      };
}

/// Etiqueta de sección + toggle de Modo Dios + ícono de ayuda.
class _FilaModoDios extends StatelessWidget {
  const _FilaModoDios({
    required this.etiqueta,
    required this.activo,
    required this.onChanged,
    required this.onInfo,
  });

  final String etiqueta;
  final bool activo;
  final ValueChanged<bool> onChanged;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            etiqueta,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
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
              _ModoDiosToggle(activo: activo, onChanged: onChanged),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onInfo,
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
