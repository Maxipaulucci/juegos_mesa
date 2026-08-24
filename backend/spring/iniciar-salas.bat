@echo off
cd /d "%~dp0"
if not exist src\main\resources\application-local.yml (
  copy /Y src\main\resources\application-local.yml.example src\main\resources\application-local.yml >nul
  echo Se creo application-local.yml. Editalo con tu URI de MongoDB Atlas si hace falta.
)
echo.
echo API de salas online en http://127.0.0.1:8080
echo Perfil: local ^(application-local.yml^)
echo.
call mvn -q spring-boot:run -Dspring-boot.run.profiles=local
pause
