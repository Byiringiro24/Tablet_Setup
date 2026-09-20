@echo off
setlocal

pushd "%~dp0"
title EcaAfrica Tablet Setup

echo.
echo ============================================================
echo                   EcaAfrica Tablet Setup
echo ============================================================
echo.
echo This setup will request Administrator permission.
echo Please click YES when Windows asks for permission.
echo.
pause

set "SCRIPT=%~dp0Setup-EcaAfrica.ps1"

if not exist "%SCRIPT%" (
    echo.
    echo ERROR: Setup-EcaAfrica.ps1 was not found in this folder.
    echo Expected path: %SCRIPT%
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"

if errorlevel 1 (
    echo.
    echo Setup failed.
    echo.
    pause
    exit /b 1
)

exit /b 0