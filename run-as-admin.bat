@echo off
:: ============================================================
:: EcaAfrica — Run Backend as Administrator (immediate)
:: Double-click this to start the backend with full admin rights
:: right now, without installing as a service.
:: ============================================================

net session >nul 2>&1
if %errorlevel% == 0 goto :already_admin

echo Requesting Administrator privileges...
powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
exit /b

:already_admin
echo.
echo  EcaAfrica Backend — Running as Administrator
echo  =============================================
echo.
cd /d "%~dp0backend"
node server.js
pause
