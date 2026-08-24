@echo off
cd /d "%~dp0"
if not exist .env (
  copy /Y .env.example .env >nul
  echo Se creo backend\mongo\.env a partir de .env.example. Editalo si queres.
)
if not exist node_modules (
  echo Instalando dependencias...
  call npm install
)
echo.
echo 1^) Mongo tiene que estar corriendo ^(servicio MongoDB^).
echo 2^) Compass conectado a mongodb://127.0.0.1:27017
echo 3^) Esta ventana deja la API en http://127.0.0.1:27080
echo.
call npm start
pause
