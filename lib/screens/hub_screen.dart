import 'dart:async';

import 'package:flutter/material.dart';

import '../services/usuario_mongo_service.dart';
import '../shared/ajustes/ajustes_overlay.dart';
import '../shared/carga/pantalla_carga.dart';
import '../shared/cuenta/cuenta_overlay.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';
import 'home_screen.dart';

/// Primera pantalla: header + Juegos / Salas / Ranking.
class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  bool _mostrarAjustes = false;
  bool _mostrarCuenta = false;
  AjustesEstado _ajustes = const AjustesEstado();
  bool _abriendoJuegos = false;

  Future<void> _abrirJuegos() async {
    if (_abriendoJuegos) return;
    setState(() => _abriendoJuegos = true);

    // Cold start de Render (~1 min en free). No bloquea la navegación.
    unawaited(UsuarioMongoService.instance.despertarBackend());

    final barra = Completer<void>();
    final nav = Navigator.of(context);

    unawaited(() async {
      try {
        await Future.wait<void>([
          barra.future,
          Future<void>(() async {
            await WidgetsBinding.instance.endOfFrame;
            if (!mounted) return;
            await HomeScreen.precargar(context);
          }),
        ]);
        await Future<void>.delayed(pausaTrasCienPorCiento);
        if (!mounted) return;
        nav.pushReplacement(
          PageRouteBuilder<void>(
            pageBuilder: (_, __, ___) => const AppShell(),
            transitionDuration: const Duration(milliseconds: 350),
            transitionsBuilder: (_, anim, __, child) {
              return FadeTransition(opacity: anim, child: child);
            },
          ),
        );
      } catch (_) {
        if (mounted) setState(() => _abriendoJuegos = false);
      }
    }());

    await nav.push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) {
          return PantallaCarga(
            mensaje: 'Cargando juegos…',
            duracion: duracionCargaMinima,
            onBarraCompleta: () {
              if (!barra.isCompleted) barra.complete();
            },
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );

    if (mounted) setState(() => _abriendoJuegos = false);
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderHub(
                    onCuenta: () => setState(() => _mostrarCuenta = true),
                    onAjustes: () => setState(() => _mostrarAjustes = true),
                  ),
                  const Spacer(flex: 2),
                  _BotonHub(
                    label: 'Juegos',
                    icono: Icons.sports_esports_rounded,
                    color: AppColors.azul,
                    enabled: !_abriendoJuegos,
                    onTap: _abrirJuegos,
                  ),
                  const SizedBox(height: 16),
                  const _BotonHub(
                    label: 'Salas',
                    icono: Icons.groups_rounded,
                    color: AppColors.violeta,
                    enabled: false,
                  ),
                  const SizedBox(height: 16),
                  const _BotonHub(
                    label: 'Ranking',
                    icono: Icons.emoji_events_rounded,
                    color: AppColors.acento,
                    enabled: false,
                  ),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
          if (_mostrarCuenta)
            Positioned.fill(
              child: CuentaOverlay(
                onCerrar: () => setState(() => _mostrarCuenta = false),
              ),
            ),
          if (_mostrarAjustes)
            Positioned.fill(
              child: AjustesOverlay(
                ajustes: _ajustes,
                onChanged: (v) => setState(() => _ajustes = v),
                onCerrar: () => setState(() => _mostrarAjustes = false),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderHub extends StatelessWidget {
  const _HeaderHub({
    required this.onCuenta,
    required this.onAjustes,
  });

  final VoidCallback onCuenta;
  final VoidCallback onAjustes;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                        height: 1.05,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Juegos ',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextSpan(
                          text: 'de ',
                          style: TextStyle(color: AppColors.acento),
                        ),
                        TextSpan(
                          text: 'mesa ',
                          style: TextStyle(color: AppColors.mint),
                        ),
                        TextSpan(
                          text: 'Argentos',
                          style: TextStyle(color: AppColors.azul),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Argentinos · multijugador',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textoSuave,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            child: _IconoCircular(
              colorBorde: AppColors.azul,
              onTap: onCuenta,
              child: Builder(
                builder: (context) {
                  final nick =
                      UsuarioMongoService.instance.usuario?.nombreUsuario ?? '';
                  if (!UsuarioMongoService.instance.haySesion) {
                    return const Icon(
                      Icons.person_rounded,
                      color: AppColors.texto,
                      size: 22,
                    );
                  }
                  final letra =
                      nick.isEmpty ? '?' : nick.substring(0, 1).toUpperCase();
                  return Text(
                    letra,
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: _IconoCircular(
              colorBorde: AppColors.rosa,
              onTap: onAjustes,
              child: const Icon(
                Icons.settings_rounded,
                color: AppColors.texto,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconoCircular extends StatelessWidget {
  const _IconoCircular({
    required this.colorBorde,
    required this.onTap,
    required this.child,
  });

  final Color colorBorde;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.carta,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colorBorde.withValues(alpha: 0.85),
              width: 1.6,
            ),
            boxShadow: neonGlow(colorBorde, blur: 10),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _BotonHub extends StatelessWidget {
  const _BotonHub({
    required this.label,
    required this.icono,
    required this.color,
    required this.enabled,
    this.onTap,
  });

  final String label;
  final IconData icono;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.38,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.35),
                  AppColors.carta,
                  AppColors.carta.withValues(alpha: 0.92),
                ],
              ),
              border: Border.all(color: color, width: 1.8),
              boxShadow: enabled ? neonGlow(color, blur: 12) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icono, color: AppColors.texto, size: 30),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 0.6,
                  ),
                ),
                if (!enabled) ...[
                  const SizedBox(width: 10),
                  Icon(
                    Icons.lock_rounded,
                    color: AppColors.textoSuave.withValues(alpha: 0.9),
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
