@echo off
:: Self-elevate to Administrator automatically — no right-click needed
:: Double-click this file to install EcaAfrica as Windows services

net session >nul 2>&1
if %errorlevel% == 0 goto :already_admin

:: Not admin — re-launch with elevation via PowerShell
echo Requesting Administrator privileges...
powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
exit /b

:already_admin
echo.
echo  EcaAfrica Tablet Service Installer
echo  ====================================
echo.
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "install-services.ps1"
