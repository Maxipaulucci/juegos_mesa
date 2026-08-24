# Juegos de Mesa Argentinos

App Flutter con salas por código. Primer juego: **Diez Mil** (motor portado desde `DIEZ MIL/motor.py`).

## Estructura

```
lib/                    ← app Flutter
backend/
  mongo/                ← API Node (cuentas, ranking, mail)
  spring/               ← API Spring Boot (salas online)
```

## Cómo correrlo

1. Instalá Flutter: https://docs.flutter.dev/get-started/install/windows
2. En esta carpeta:

```bash
flutter pub get
flutter run
```

## Flujo actual

1. Hub → **Juegos** (Salas y Ranking en preparación)
2. **Crear** / **Unirse** con código (lobby online vía Spring Boot + MongoDB)
3. O **Partida rápida** en el mismo dispositivo

Backends locales: `backend\iniciar-todo.bat` (una URL) o por separado en `mongo/` y `spring/`.

Producción (Render): `--dart-define=API_BASE=https://tu-app.onrender.com`
