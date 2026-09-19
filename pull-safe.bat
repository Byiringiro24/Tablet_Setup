@echo off
:: ================================================================
:: EcaAfrica — Safe Auto-Pull
:: Double-click to pull latest code WITHOUT losing any local data.
::
:: Protected files (never touched by this script):
::   backend/data/device-config.json     — your device IP
::   backend/data/students.json          — registered students
::   backend/data/attendance-settings.json — time rules
::   backend/.env                        — TABLET_UUID and config
::   backend/data/wireguard-private.key  — VPN private key
:: ================================================================

echo.
echo  EcaAfrica — Pulling latest code safely...
echo  ==========================================
echo.

cd /d "%~dp0"

:: Pull latest code — data files are in .gitignore so they are never touched
git pull origin Testing-Branch

if %errorlevel% neq 0 (
    echo.
    echo  [ERR] Pull failed. Check your internet connection.
    pause
    exit /b 1
)

echo.
echo  [OK] Code updated. Restarting services...
echo.

:: Restart backend service if installed
sc query EcaAfrica-Bridge >nul 2>&1
if %errorlevel% == 0 (
    net stop EcaAfrica-Bridge >nul 2>&1
    net stop EcaAfrica-Frontend >nul 2>&1
    timeout /t 3 /nobreak >nul
    net start EcaAfrica-Bridge >nul 2>&1
    timeout /t 3 /nobreak >nul
    net start EcaAfrica-Frontend >nul 2>&1
    echo  [OK] Services restarted.
) else (
    echo  [!!] Services not installed — start manually if needed.
)

echo.
echo  Done. Your data files were NOT touched.
echo.
pause
