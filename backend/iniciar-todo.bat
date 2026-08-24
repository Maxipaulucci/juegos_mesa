@echo off
cd /d "%~dp0"

for %%F in ("spring\target\salas-api-*.jar") do set "SPRING_JAR=%%~fF"
if not defined SPRING_JAR (
  echo Compilando Spring Boot...
  call mvn -q -f spring\pom.xml package -DskipTests
  for %%F in ("spring\target\salas-api-*.jar") do set "SPRING_JAR=%%~fF"
)

if not exist mongo\node_modules (
  echo Instalando dependencias Node...
  call npm install --prefix mongo
)

if not exist mongo\.env (
  if exist mongo\.env.example copy /Y mongo\.env.example mongo\.env >nul
)

echo.
echo Spring Boot en puerto interno 8080 ^(salas^)
echo Node en http://127.0.0.1:27080 ^(cuentas + proxy /api/sala^)
echo.
echo Flutter:
echo   flutter run --dart-define=API_BASE=http://127.0.0.1:27080
echo.

start "JuegosMesa-Spring" /MIN cmd /c java -jar "%SPRING_JAR%" --server.port=8080

echo Esperando Spring Boot...
timeout /t 12 /nobreak >nul

set SALAS_INTERNAL_PORT=8080
set PORT=27080
cd mongo
call npm start
