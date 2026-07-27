# Juegos de Mesa Argentinos

App Flutter con salas por código. Primer juego: **Diez Mil** (motor portado desde `DIEZ MIL/motor.py`).

## Estructura

```
lib/
  main.dart
  theme/app_theme.dart
  models/sala.dart
  services/sala_service.dart          ← salas locales (luego Firebase/Supabase)
  screens/home_screen.dart
  diezMil/                            ← todo el juego Diez Mil acá
    motor.dart                        ← lógica pura (sin UI)
    textos.dart
    menu_diez_mil_screen.dart         ← Crear / Unirse / partida rápida
    crear_sala_screen.dart
    unirse_sala_screen.dart
    lobby_sala_screen.dart            ← código + ojo + copiar + expulsar
    partida_diez_mil_screen.dart      ← juego jugable
```

## Cómo correrlo

1. Instalá Flutter: https://docs.flutter.dev/get-started/install/windows
2. En esta carpeta:

```bash
flutter pub get
flutter run
```

## Flujo actual

1. Inicio → **Diez Mil**
2. **Crear** / **Unirse** (código tipo contraseña, lobby con lista y tacho)
3. O **Partida rápida** en el mismo celular (usa el motor de verdad)

Las salas hoy son **locales en memoria** (mismo dispositivo). El online se enchufa después reemplazando `SalaService`.
