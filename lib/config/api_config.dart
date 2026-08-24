/// Resuelve la URL base del backend.
///
/// En Render (un solo servicio) usá:
/// `--dart-define=API_BASE=https://tu-app.onrender.com`
///
/// Local con [backend/iniciar-todo.bat]: `http://127.0.0.1:27080`
/// Local por separado: cuentas 27080, salas 8080 (defaults abajo).
String resolveApiBase({
  required String specificKey,
  required String localDefault,
}) {
  const specific = String.fromEnvironment(specificKey);
  if (specific.isNotEmpty) return specific;
  const unified = String.fromEnvironment('API_BASE');
  if (unified.isNotEmpty) return unified;
  return localDefault;
}

String get kMongoApiBase => resolveApiBase(
      specificKey: 'MONGO_API_BASE',
      localDefault: 'http://127.0.0.1:27080',
    );

String get kSalaApiBase => resolveApiBase(
      specificKey: 'SALA_API_BASE',
      localDefault: 'http://127.0.0.1:8080',
    );
