/// URL base del API de cuentas/ranking.
///
/// Render (un solo servicio): `--dart-define=API_BASE=https://tu-app.onrender.com`
/// Local unificado: `http://127.0.0.1:27080` con `backend/iniciar-todo.bat`
String get kMongoApiBase {
  const specific = String.fromEnvironment('MONGO_API_BASE');
  if (specific.isNotEmpty) return specific;
  const unified = String.fromEnvironment('API_BASE');
  if (unified.isNotEmpty) return unified;
  return 'http://127.0.0.1:27080';
}

/// URL base del API de salas online.
///
/// Si usás `API_BASE`, salas y cuentas comparten la misma URL (proxy en Node).
String get kSalaApiBase {
  const specific = String.fromEnvironment('SALA_API_BASE');
  if (specific.isNotEmpty) return specific;
  const unified = String.fromEnvironment('API_BASE');
  if (unified.isNotEmpty) return unified;
  return 'http://127.0.0.1:8080';
}

/// Client ID de Google OAuth (tipo “Aplicación web”).
///
/// `--dart-define=GOOGLE_CLIENT_ID=123-abc.apps.googleusercontent.com`
String get kGoogleClientId {
  const id = String.fromEnvironment('GOOGLE_CLIENT_ID');
  return id.trim();
}

bool get kGoogleSignInConfigurado => kGoogleClientId.isNotEmpty;
