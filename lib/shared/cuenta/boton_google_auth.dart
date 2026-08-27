import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:app_juegos_mesa/services/google_auth_service.dart';
import 'package:app_juegos_mesa/shared/cuenta/google_web_button_stub.dart'
    if (dart.library.html) 'package:app_juegos_mesa/shared/cuenta/google_web_button_web.dart'
    as google_web;

/// Botón Google: en web usa el oficial; en móvil el estilo de la app.
class BotonGoogleAuth extends StatefulWidget {
  const BotonGoogleAuth({
    super.key,
    required this.registro,
    required this.onExito,
    required this.onError,
    this.enabled = true,
  });

  /// true = texto de registro; false = iniciar sesión.
  final bool registro;
  final Future<void> Function() onExito;
  final ValueChanged<String> onError;
  final bool enabled;

  @override
  State<BotonGoogleAuth> createState() => _BotonGoogleAuthState();
}

class _BotonGoogleAuthState extends State<BotonGoogleAuth> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _sub;
  bool _listo = false;
  bool _ocupado = false;

  String get _etiqueta => widget.registro
      ? 'Regístrate con Google'
      : 'Inicia sesión con Google';

  @override
  void initState() {
    super.initState();
    unawaited(_preparar());
  }

  Future<void> _preparar() async {
    final google = GoogleAuthService.instance;
    if (!google.disponible) {
      if (mounted) setState(() => _listo = true);
      return;
    }
    try {
      await google.ensureInitialized();
      if (google.usarBotonOficialWeb) {
        _sub = GoogleSignIn.instance.authenticationEvents.listen(
          _onEvento,
          onError: (Object e) {
            if (!mounted) return;
            widget.onError(e.toString().replaceFirst('Bad state: ', ''));
          },
        );
      }
    } catch (e) {
      if (mounted) {
        widget.onError(e.toString().replaceFirst('Bad state: ', ''));
      }
    }
    if (mounted) setState(() => _listo = true);
  }

  Future<void> _onEvento(GoogleSignInAuthenticationEvent event) async {
    if (event is! GoogleSignInAuthenticationEventSignIn) return;
    if (_ocupado || !widget.enabled) return;
    setState(() => _ocupado = true);
    try {
      await GoogleAuthService.instance.completarConCuenta(event.user);
      await widget.onExito();
    } catch (e) {
      widget.onError(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _onTapMobile() async {
    if (!widget.enabled || _ocupado) return;
    final google = GoogleAuthService.instance;
    if (!google.disponible) {
      widget.onError(google.mensajeNoDisponible);
      return;
    }
    setState(() => _ocupado = true);
    try {
      await google.entrarConAuthenticate();
      await widget.onExito();
    } catch (e) {
      widget.onError(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final google = GoogleAuthService.instance;

    if (!_listo) {
      return const SizedBox(
        height: 46,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (google.usarBotonOficialWeb) {
      return AbsorbPointer(
        absorbing: !widget.enabled || _ocupado,
        child: Opacity(
          opacity: (!widget.enabled || _ocupado) ? 0.55 : 1,
          child: Center(
            child: google_web.buildGoogleSignInWebButton(
              registro: widget.registro,
            ),
          ),
        ),
      );
    }

    return _BotonEstiloApp(
      etiqueta: _etiqueta,
      onPressed: (!widget.enabled || _ocupado) ? null : _onTapMobile,
    );
  }
}

class _BotonEstiloApp extends StatelessWidget {
  const _BotonEstiloApp({
    required this.etiqueta,
    required this.onPressed,
  });

  final String etiqueta;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: enabled ? const Color(0xFFF1F3F4) : const Color(0xFFE8EAED),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDADCE0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _LogoGoogle(size: 20),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  etiqueta,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled
                        ? const Color(0xFF3C4043)
                        : const Color(0xFF9AA0A6),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoGoogle extends StatelessWidget {
  const _LogoGoogle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.42;
    final stroke = size.width * 0.18;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.35, 1.55, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 1.2, 1.0, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.2, 0.9, false, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.1, 1.0, false, paint);

    final bar = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final top = cy - stroke * 0.55;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - stroke * 0.15, top, size.width * 0.42, stroke * 1.1),
        const Radius.circular(1),
      ),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
