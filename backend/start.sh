#!/usr/bin/env bash
set -euo pipefail

SPRING_PORT="${SPRING_PORT:-8080}"
export SALAS_INTERNAL_PORT="${SPRING_PORT}"

JAR="$(ls spring/target/salas-api-*.jar 2>/dev/null | head -1 || true)"
if [[ -z "${JAR}" ]]; then
  echo "No se encontró spring/target/salas-api-*.jar. Ejecutá el build antes."
  exit 1
fi

echo "Iniciando Spring Boot (salas) en puerto interno ${SPRING_PORT}..."
java -jar "${JAR}" --server.port="${SPRING_PORT}" &
SPRING_PID=$!

cleanup() {
  kill "${SPRING_PID}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "Esperando API de salas..."
for _ in $(seq 1 90); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${SPRING_PORT}/api/sala" || true)"
  if [[ "${code}" == "400" || "${code}" == "404" ]]; then
    echo "Spring listo."
    break
  fi
  sleep 1
done

cd mongo
echo "Iniciando API Node (cuentas + proxy salas) en puerto ${PORT:-27080}..."
exec node src/server.mjs
