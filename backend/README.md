# Backend

Un solo despliegue en Render ejecuta **Node (cuentas/ranking/mail)** y **Spring Boot (salas online)**. Ambos usan **MongoDB Atlas** (`MONGO_URI`); no hace falta instalar Mongo en Render.

## Estructura

```
backend/
  mongo/          ← API Node (puerto público + proxy /api/sala)
  spring/         ← API Spring Boot (puerto interno 8080)
  Dockerfile      ← imagen unificada para Render
  start.sh        ← arranca Spring + Node
  iniciar-todo.bat← lo mismo en Windows (local)
```

La app Flutter habla con **una sola URL** en producción.

## Local

**Todo junto** (recomendado, una URL):

```bat
backend\iniciar-todo.bat
```

→ `http://127.0.0.1:27080` (cuentas y salas vía proxy)

```bat
flutter run --dart-define=API_BASE=http://127.0.0.1:27080
```

**Por separado** (dos terminales):

```bat
backend\mongo\iniciar-api.bat      rem :27080
backend\spring\iniciar-salas.bat   rem :8080
```

```bat
flutter run ^
  --dart-define=MONGO_API_BASE=http://127.0.0.1:27080 ^
  --dart-define=SALA_API_BASE=http://127.0.0.1:8080
```

Documentación:

- [mongo/README.md](mongo/README.md)
- [spring/README.md](spring/README.md)

## Render (una instancia)

1. Creá un **Web Service** con **Docker**.
2. **Root Directory:** `backend` (o usá el Blueprint `render.yaml` en la raíz del repo).
3. **Health check:** `/api/salud`
4. Variables de entorno:

| Variable        | Ejemplo / notas                          |
|-----------------|------------------------------------------|
| `MONGO_URI`     | URI de Atlas (`mongodb+srv://...`)     |
| `MONGO_DB`      | `juegosMesa`                             |
| `JWT_SECRET`    | clave larga aleatoria                    |
| `RESEND_API_KEY`| clave Resend                             |
| `MAIL_FROM`       | remitente verificado                     |
| `SPRING_PORT`   | `8080` (interno, opcional)               |

Render asigna `PORT` automáticamente; Node escucha ahí y reenvía `/api/sala` a Spring.

**Flutter en producción:**

```bat
flutter build web --dart-define=API_BASE=https://tu-app.onrender.com
```

## Cómo funciona

```
Flutter  →  https://tu-app.onrender.com  (Node, puerto PORT)
              ├─ /api/usuarios/*, /api/puntos, /api/ranking  → Node
              └─ /api/sala/*  → proxy → Spring (127.0.0.1:8080) → Atlas
```

## Legacy

Salas antes en `netlify/functions/sala.mjs` (Netlify Blobs). Reemplazado por Spring + MongoDB.
