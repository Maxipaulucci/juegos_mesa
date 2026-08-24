# API de salas online (Spring Boot)

Reemplaza `netlify/functions/sala.mjs` (Netlify Blobs). Persiste salas en MongoDB, colección `salas`.

## Requisitos

- Java 17+
- Maven 3.9+
- MongoDB (local o Atlas)

## Arranque rápido

```bat
backend\spring\iniciar-salas.bat
```

La primera vez copia `application-local.yml.example` → `application-local.yml`. Editá la URI si usás Atlas.

Manual:

```bat
cd backend/spring
mvn spring-boot:run -Dspring-boot.run.profiles=local
```

## Variables de entorno

| Variable   | Default                    | Uso                          |
|------------|----------------------------|------------------------------|
| `MONGO_URI`| `mongodb://127.0.0.1:27017`| URI de MongoDB               |
| `MONGO_DB` | `juegosMesa`               | Base de datos                |
| `PORT`     | `8080`                     | Puerto HTTP (Render usa `PORT`) |

En producción no hace falta `application-local.yml`; basta con las variables.

## Endpoints

- `GET /api/sala?codigo=ABC123` — obtener sala
- `POST /api/sala` — acciones: `crear`, `unirse`, `expulsar`, `iniciar`, `actualizarLobby`, `actualizarJuego`, `cerrar`

Las salas con partida iniciada expiran tras **1 hora** (índice TTL en `iniciadaEn`).

## Flutter

Local:

```bat
flutter run --dart-define=SALA_API_BASE=http://127.0.0.1:8080
```

Producción: `--dart-define=SALA_API_BASE=https://tu-servicio.onrender.com`

## Deploy en Render

No uses un servicio aparte: el backend unificado está en `backend/Dockerfile`.

- Blueprint: `render.yaml` en la raíz del repo
- Health: `/api/salud` (Node)
- Flutter: `--dart-define=API_BASE=https://tu-app.onrender.com`

Ver [../README.md](../README.md) (backend) para variables de entorno.
