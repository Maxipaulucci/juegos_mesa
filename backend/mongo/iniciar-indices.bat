@echo off
cd /d "%~dp0"
if not exist .env (
  copy /Y .env.example .env >nul
)
if not exist node_modules call npm install
echo Creando indices en juegosMesa.usuarios ...
call npm run init
pause
