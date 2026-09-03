#Requires -RunAsAdministrator
<#
.SYNOPSIS
    EcaAfrica Tablet — Uninstall Windows Services
    Stops and removes the EcaAfrica-Bridge and EcaAfrica-Frontend services.
    Use this before reinstalling or moving the folder.
#>

$ErrorActionPreference = "SilentlyContinue"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$NSSM_EXE   = Join-Path $SCRIPT_DIR "tools\nssm.exe"

function Remove-Svc($name) {
    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Host "  $name — not installed, skipping" -ForegroundColor Gray; return }
    if ($svc.Status -eq "Running") {
        Write-Host "  Stopping $name..." -ForegroundColor Yellow
        Stop-Service -Name $name -Force
        Start-Sleep 2
    }
    if (Test-Path $NSSM_EXE) {
        & $NSSM_EXE remove $name confirm 2>&1 | Out-Null
    } else {
        sc.exe delete $name | Out-Null
    }
    Write-Host "  $name removed" -ForegroundColor Green
}

Write-Host "`nRemoving EcaAfrica services..." -ForegroundColor Cyan
Remove-Svc "EcaAfrica-Frontend"
Remove-Svc "EcaAfrica-Bridge"

Write-Host "`nDone. Services removed." -ForegroundColor Green
Read-Host "Press Enter to close"
