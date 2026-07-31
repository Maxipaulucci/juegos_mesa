import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app_juegos_mesa/shared/menu/opcion_toggle.dart';
import 'package:app_juegos_mesa/theme/app_theme.dart';

/// Botón azul compartido: abre el cartel de modificar partida de cada juego.
class BotonModificarPartida extends StatelessWidget {
  const BotonModificarPartida({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.azul,
        side: const BorderSide(color: AppColors.azul, width: 1.6),
        backgroundColor: AppColors.azul.withValues(alpha: 0.12),
      ),
      child: const Text(
        'Modificar partida',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Cartel compartido. [buildOpciones] arma el contenido propio de cada juego.
/// Devuelve `true` si el usuario tocó Listo.
Future<bool> mostrarCartelModificarPartida({
  required BuildContext context,
  required Widget Function(
    BuildContext dialogContext,
    StateSetter setDialogState,
  ) buildOpciones,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.carta,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Modificar partida',
              style: TextStyle(
                color: AppColors.mint,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildOpciones(dialogContext, setDialogState),
                  const SizedBox(height: 20),
                  BotonListoModificarPartida(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                  const SizedBox(height: 12),
                  BotonCancelarModificarPartida(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  return result == true;
}

class BotonListoModificarPartida extends StatelessWidget {
  const BotonListoModificarPartida({
    super.key,
    required this.onPressed,
    this.etiqueta = 'Listo',
  });

  final VoidCallback onPressed;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.mint,
          foregroundColor: const Color(0xFF062018),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(
          etiqueta,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class BotonCancelarModificarPartida extends StatelessWidget {
  const BotonCancelarModificarPartida({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.peligro,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 4,
          shadowColor: Colors.black54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: const Text(
          'Cancelar',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

/// Fila con switch + ayuda, para opciones de modificar partida.
class FilaToggleModificarPartida extends StatelessWidget {
  const FilaToggleModificarPartida({
    super.key,
    required this.titulo,
    required this.activo,
    required this.onChanged,
    required this.info,
  });

  final String titulo;
  final bool activo;
  final ValueChanged<bool> onChanged;
  final String info;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(
              color: AppColors.texto,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        SwitchNeon(activo: activo, onChanged: onChanged),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Info',
          onPressed: () => mostrarInfoModificarPartida(
            context,
            titulo: titulo,
            cuerpo: info,
          ),
          icon: const Icon(Icons.help, size: 18, color: AppColors.textoSuave),
        ),
      ],
    );
  }
}

/// Cantidad con − / valor tocable / +.
class FilaCantidadModificarPartida extends StatelessWidget {
  const FilaCantidadModificarPartida({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String etiqueta;
  final int valor;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            etiqueta,
            style: const TextStyle(
              color: AppColors.texto,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        IconButton(
          onPressed: valor <= min ? null : () => onChanged(valor - 1),
          icon: const Icon(Icons.remove_circle_outline, color: AppColors.mint),
        ),
        InkWell(
          onTap: () async {
            final nuevo = await _editarCantidadDialog(
              context: context,
              actual: valor,
              min: min,
              max: max,
            );
            if (nuevo != null) onChanged(nuevo);
          },
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFF3A2A58),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.violeta.withValues(alpha: 0.45),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                '$valor',
                style: const TextStyle(
                  color: AppColors.mint,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: valor >= max ? null : () => onChanged(valor + 1),
          icon: const Icon(Icons.add_circle_outline, color: AppColors.mint),
        ),
      ],
    );
  }
}

void mostrarInfoModificarPartida(
  BuildContext context, {
  required String titulo,
  required String cuerpo,
}) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.carta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        titulo,
        style: const TextStyle(color: AppColors.mint, fontSize: 18),
      ),
      content: Text(
        cuerpo,
        style: const TextStyle(color: AppColors.texto, height: 1.45),
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

Future<int?> _editarCantidadDialog({
  required BuildContext context,
  required int actual,
  required int min,
  required int max,
}) async {
  final controller = TextEditingController(text: '$actual');
  final valor = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.carta,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Cantidad',
        style: TextStyle(color: AppColors.mint, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: AppColors.texto, fontSize: 18),
            decoration: InputDecoration(
              hintText: '$min–$max',
              hintStyle: const TextStyle(color: AppColors.textoSuave),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.mint),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.mint, width: 2),
              ),
            ),
            onSubmitted: (raw) {
              final parsed = int.tryParse(raw.trim());
              if (parsed == null) {
                Navigator.of(ctx).pop();
                return;
              }
              Navigator.of(ctx).pop(parsed.clamp(min, max));
            },
          ),
          const SizedBox(height: 20),
          BotonListoModificarPartida(
            etiqueta: 'OK',
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed == null) {
                Navigator.of(ctx).pop();
                return;
              }
              Navigator.of(ctx).pop(parsed.clamp(min, max));
            },
          ),
          const SizedBox(height: 12),
          BotonCancelarModificarPartida(
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return valor;
}
