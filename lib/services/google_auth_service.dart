import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/api_config.dart';
import '../models/usuario_mongo.dart';
import 'usuario_mongo_service.dart';

/// Login / registro con Google → mismo JWT del backend.
class GoogleAuthService {
  GoogleAuthService._();
  static final instance = GoogleAuthService._();

  bool _inicializado = false;
  Future<void>? _initFuture;

  bool get disponible {
    if (!kGoogleSignInConfigurado) return false;
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// En web hay que usar el botón oficial de Google (`renderButton`).
  bool get usarBotonOficialWeb => kIsWeb && disponible;

  bool get puedeAuthenticate =>
      disponible && GoogleSignIn.instance.supportsAuthenticate();

  String get mensajeNoDisponible {
    if (!kGoogleSignInConfigurado) {
      return 'Google Sign-In no está configurado (falta GOOGLE_CLIENT_ID).';
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return 'En Windows, iniciá sesión con Google desde la versión web.';
    }
    return 'Google Sign-In no está disponible en esta plataforma.';
  }

  Future<void> ensureInitialized() {
    final existing = _initFuture;
    if (existing != null) return existing;
    _initFuture = _doInit();
    return _initFuture!;
  }

  Future<void> _doInit() async {
    if (_inicializado) return;
    if (!kGoogleSignInConfigurado) {
      throw StateError(mensajeNoDisponible);
    }
    final id = kGoogleClientId;
    await GoogleSignIn.instance.initialize(
      clientId: id,
      // En móvil, el Client ID web actúa como serverClientId para idToken.
      serverClientId: kIsWeb ? null : id,
    );
    _inicializado = true;
  }

  /// Flujo interactivo (Android / iOS / macOS).
  Future<UsuarioMongo> entrarConAuthenticate() async {
    await ensureInitialized();
    if (!puedeAuthenticate) {
      throw StateError(mensajeNoDisponible);
    }
    try {
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      return await _enviarIdToken(account);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw StateError('Inicio con Google cancelado.');
      }
      throw StateError(e.description ?? 'Error al iniciar con Google.');
    }
  }

  /// Completa el login cuando el botón web oficial ya autenticó al usuario.
  Future<UsuarioMongo> completarConCuenta(GoogleSignInAccount account) {
    return _enviarIdToken(account);
  }

  Future<UsuarioMongo> _enviarIdToken(GoogleSignInAccount account) async {
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google no devolvió un token. Revisá el Client ID de tipo Web.',
      );
    }
    return UsuarioMongoService.instance.loginConGoogle(idToken: idToken);
  }

  Future<void> cerrarSesionGoogle() async {
    try {
      if (!_inicializado) return;
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
