@echo off
:: ================================================================
:: EcaAfrica — New Tablet Setup (double-click to run)
:: ================================================================
:: This single script does EVERYTHING needed on a brand new Windows
:: tablet — install software, clone code, configure, install services,
:: make everything auto-start as Administrator.
::
:: REQUIREMENTS BEFORE RUNNING:
::   - Windows 10/11 (64-bit)
::   - Internet connection
::   - That's it — everything else is downloaded automatically
:: ================================================================

net session >nul 2>&1
if %errorlevel% == 0 goto :already_admin

echo.
echo  Requesting Administrator privileges...
echo  (Click YES on the UAC prompt that appears)
echo.
powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
exit /b

:already_admin
cls
echo.
echo  ================================================================
echo   EcaAfrica Biometric Attendance — New Tablet Setup
echo  ================================================================
echo.
echo  This will:
echo    1. Install Node.js, .NET 8, Git, WireGuard, Chrome
echo    2. Clone the EcaAfrica code from GitHub
echo    3. Build the frontend and backend
echo    4. Install everything as auto-start Windows services
echo    5. Configure all services to run as SYSTEM (no UAC ever)
echo    6. Open the dashboard at http://localhost:3000
echo.
echo  Estimated time: 5-10 minutes
echo.
pause

cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0setup-new-tablet.ps1"
