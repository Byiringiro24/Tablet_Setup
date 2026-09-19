@echo off
:: ================================================================
:: EcaAfrica — New Tablet Setup
:: Double-click this file — it self-elevates to Administrator
:: and runs the full automated setup.
:: ================================================================

net session >nul 2>&1
if %errorlevel% == 0 goto :already_admin

echo.
echo  Requesting Administrator privileges...
echo  (Click YES on the UAC prompt)
echo.
powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
exit /b

:already_admin
cls
echo.
echo  ================================================================
echo   EcaAfrica Biometric Attendance - New Tablet Setup
echo  ================================================================
echo.
echo  This will automatically:
echo    1. Install Node.js, .NET 8, Git, WireGuard, Chrome
echo    2. Download EcaAfrica code from GitHub
echo    3. Build frontend and FKBridge
echo    4. Install auto-start Windows services (run as SYSTEM)
echo    5. Configure permanent admin rights, no UAC prompts
echo    6. Open dashboard automatically on every login
echo.
echo  Estimated time: 5-10 minutes
echo  Internet connection required.
echo.
pause

:: Run the PowerShell setup script from the same directory as this bat
powershell -ExecutionPolicy Bypass -File "%~dp0setup-new-tablet.ps1"
