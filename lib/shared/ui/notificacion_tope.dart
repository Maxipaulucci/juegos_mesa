import 'dart:async';

import 'package:flutter/material.dart';

import 'package:app_juegos_mesa/theme/app_theme.dart';

OverlayEntry? _notificacionTopeActual;

/// Aviso flotante arriba: no mueve el layout y se desvanece solo.
void mostrarNotificacionTope(
  BuildContext context, {
  required String mensaje,
  Duration duracion = const Duration(seconds: 3),
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  _notificacionTopeActual?.remove();
  _notificacionTopeActual = null;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _NotificacionTope(
      mensaje: mensaje,
      duracion: duracion,
      onCerrar: () {
        entry.remove();
        if (_notificacionTopeActual == entry) {
          _notificacionTopeActual = null;
        }
      },
    ),
  );
  _notificacionTopeActual = entry;
  overlay.insert(entry);
}

class _NotificacionTope extends StatefulWidget {
  const _NotificacionTope({
    required this.mensaje,
    required this.duracion,
    required this.onCerrar,
  });

  final String mensaje;
  final Duration duracion;
  final VoidCallback onCerrar;

  @override
  State<_NotificacionTope> createState() => _NotificacionTopeState();
}

class _NotificacionTopeState extends State<_NotificacionTope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacidad;
  late final Animation<Offset> _desplazamiento;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 280),
    );
    _opacidad = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _desplazamiento = Tween<Offset>(
      begin: const Offset(0, -0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    unawaited(_ctrl.forward());
    _timer = Timer(widget.duracion, _cerrar);
  }

  Future<void> _cerrar() async {
    _timer?.cancel();
    if (!mounted) {
      widget.onCerrar();
      return;
    }
    await _ctrl.reverse();
    if (mounted) widget.onCerrar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SlideTransition(
            position: _desplazamiento,
            child: FadeTransition(
              opacity: _opacidad,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Material(
                  color: Colors.transparent,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A1040),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.rosa.withValues(alpha: 0.75),
                        width: 1.3,
                      ),
                      boxShadow: [
                        ...neonGlow(AppColors.rosa, blur: 12),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Text(
                        widget.mensaje,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
