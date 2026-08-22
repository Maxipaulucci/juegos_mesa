# Mongo local (Compass)

La app Flutter **no se conecta directo** a Mongo. Esta carpeta es una API en tu PC que habla con el Mongo que ya tenés en Compass.

- Base: `juegosMesa`
- Colección: `usuarios` (la que creaste)
- API: `http://127.0.0.1:27080`

## Qué tenés que hacer

### 1. Servicio Mongo (una sola vez / cada vez que apagues la PC)

En Windows, Mongo local suele ser el servicio **MongoDB**. Si Compass ya se conecta a `localhost:27017`, esto ya está.

Compass: **New Connection** → `mongodb://127.0.0.1:27017` → Connect.  
Tenés que ver `juegosMesa` → `usuarios`.

### 2. Índices (una sola vez)

Doble clic en `iniciar-indices.bat` **o** en esta carpeta:

```bat
npm install
npm run init
```

Eso usa tu colección `usuarios` (no la borra) y crea índices de email y ranking. También deja lista la colección `partidas` para el historial de puntos.

### 3. Mail con Resend (para el código de 6 dígitos)

En Render free el SMTP de Gmail suele fallar. Usamos [Resend](https://resend.com):

1. Creá cuenta → **API Keys** → copiá la clave `re_...`
2. En `mongo/.env` (y en las env vars de Render) poné:

```
RESEND_API_KEY=re_xxxxxxxx
MAIL_FROM=Juegos de mesa Argentos <onboarding@resend.dev>
```

Sin dominio verificado, el remitente gratis es `onboarding@resend.dev` (Resend solo deja enviar a tu propio mail de cuenta). Cuando verifiques un dominio, cambiá `MAIL_FROM` a algo como `Juegos de mesa Argentos <noreply@tudominio.com>`.

El texto del mail es:

```
Tu código de verificación es: 123456
Este código expira en 15 minutos.
```

Si `RESEND_API_KEY` está vacío, el código se imprime en la consola de la API para probar.

### 4. Arrancar la API (cada vez que uses la app con ranking/cuentas)

Doble clic en `iniciar-api.bat` **o**:

```bat
npm start
```

Dejá esa ventana abierta. Debería decir `API Mongo en http://127.0.0.1:27080`.

### 4. Flutter en Windows (esta PC)

```bat
flutter run -d windows
```

El cliente ya apunta a `http://127.0.0.1:27080`.

### 5. Flutter en un celular (misma Wi‑Fi)

En la PC, `ipconfig` y usá tu IPv4 (ej. `192.168.0.12`):

```bat
flutter run --dart-define=MONGO_API_BASE=http://192.168.0.12:27080
```

Emulador Android:

```bat
flutter run -d emulator-5554 --dart-define=MONGO_API_BASE=http://10.0.2.2:27080
```

Windows Firewall: permití Node en el puerto **27080** si el teléfono no conecta.

### 6. Ver usuarios en Compass

Después de un registro, refrescá `juegosMesa` → `usuarios`. Vas a ver documentos con `nombre`, `email`, `passwordHash` y `puntos` (por juego + `global`).

## Endpoints

| Método | Ruta | Qué hace |
|---|---|---|
| GET | `/api/salud` | Comprueba Mongo |
| POST | `/api/usuarios/registro` | `{ nombre, email, password }` |
| POST | `/api/usuarios/login` | `{ email, password }` |
| GET | `/api/usuarios/yo` | Perfil (Bearer token) |
| POST | `/api/puntos` | `{ juegoId, puntos }` y suma también `global` |
| GET | `/api/ranking?juego=global` | Ranking global o de un juego (`diezMil`, `escobaDel15`, …) |

## Documento de usuario

```json
{
  "nombre": "Maxi",
  "email": "maxi@correo.com",
  "passwordHash": "...",
  "puntos": {
    "global": 0,
    "diezMil": 0,
    "generala": 0
  },
  "creadoEn": "..."
}
```

`global` se actualiza solo: cada vez que sumás puntos de un juego, se incrementa ese juego y el total.
