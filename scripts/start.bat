@echo off
echo 🥝 Starting Kiwi Engine...

:: 1. Check Docker
docker info >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo ❌ Error: Docker is not running.
    echo 👉 Please launch Docker Desktop and try again.
    pause
    exit /b
)

:: 2. Run
echo 🚀 Ignition...
docker-compose up -d

echo.
echo ✅ SUCCESS! The engine is running.
echo    - Dashboard: http://localhost:8000/docs
echo.
pause