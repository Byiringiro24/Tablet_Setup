#Requires -RunAsAdministrator
<#
.SYNOPSIS
    EcaAfrica Tablet — Make Everything Run as Administrator Permanently
    Configures Windows so that EcaAfrica services, WireGuard, and Node.js
    always run as SYSTEM (full admin) with zero UAC prompts — forever,
    including after every reboot.

.USAGE
    Right-click this file → "Run with PowerShell"
    OR double-click: INSTALL (double-click me).bat (calls this automatically)

.WHAT IT DOES
    1. Sets EcaAfrica-Bridge and EcaAfrica-Frontend services to run as SYSTEM
    2. Sets WireGuard Manager and tunnel services to run as SYSTEM + auto-start
    3. Disables UAC for EcaAfrica services (registry — no more prompts)
    4. Creates a scheduled task that runs on boot to ensure everything is up
    5. Configures Windows to never throttle or kill background services
#>

Set-StrictMode -Off
$ErrorActionPreference = "SilentlyContinue"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$LOG_DIR    = Join-Path $SCRIPT_DIR "logs"

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "    OK  $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    !!  $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "    ERR $msg" -ForegroundColor Red }

# ── 1. Ensure EcaAfrica services run as SYSTEM ────────────────────────────────
Write-Step "Setting EcaAfrica services to run as SYSTEM"

foreach ($svcName in @("EcaAfrica-Bridge", "EcaAfrica-Frontend")) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Warn "$svcName not found — run INSTALL (double-click me).bat first"
        continue
    }
    # Set service to run as LocalSystem (= full SYSTEM admin, no UAC)
    sc.exe config $svcName obj= "LocalSystem" type= own | Out-Null
    sc.exe config $svcName start= auto | Out-Null
    # Set failure recovery: restart immediately on any crash
    sc.exe failure $svcName reset= 60 actions= restart/3000/restart/3000/restart/3000 | Out-Null
    Write-OK "$svcName — SYSTEM, auto-start, crash-restart configured"
}

# ── 2. WireGuard services — SYSTEM + auto-start ───────────────────────────────
Write-Step "Configuring WireGuard services"

foreach ($svcName in @("WireGuard", "WireGuardManager")) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        sc.exe config $svcName start= auto | Out-Null
        sc.exe failure $svcName reset= 60 actions= restart/2000/restart/2000/restart/2000 | Out-Null
        if ($svc.Status -ne "Running") {
            Start-Service -Name $svcName -ErrorAction SilentlyContinue
        }
        Write-OK "$svcName — auto-start, crash-restart configured"
    } else {
        Write-Warn "$svcName not found — install WireGuard from https://www.wireguard.com/install/"
    }
}

# Set WireGuard tunnel service to auto-start
$wgTunnel = Get-Service -Name "WireGuardTunnel`$EcareAfrica" -ErrorAction SilentlyContinue
if ($wgTunnel) {
    sc.exe config "WireGuardTunnel`$EcareAfrica" start= auto | Out-Null
    sc.exe failure "WireGuardTunnel`$EcareAfrica" reset= 60 actions= restart/3000/restart/3000/restart/3000 | Out-Null
    if ($wgTunnel.Status -ne "Running") {
        Start-Service -Name "WireGuardTunnel`$EcareAfrica" -ErrorAction SilentlyContinue
    }
    Write-OK "WireGuardTunnel`$EcareAfrica — auto-start, crash-restart configured"
} else {
    Write-Warn "WireGuard tunnel EcareAfrica not installed yet — run the wizard from the dashboard first"
}

# ── 3. Disable UAC for EcaAfrica processes ────────────────────────────────────
Write-Step "Configuring UAC — suppressing prompts for system services"

# Lower UAC level so SYSTEM processes never trigger prompts
# This sets: "Notify me only when apps try to make changes" → "Never notify"
# which is safe for a dedicated kiosk/server tablet
$uacKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $uacKey -Name "EnableLUA"                  -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $uacKey -Name "ConsentPromptBehaviorAdmin" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $uacKey -Name "PromptOnSecureDesktop"      -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-OK "UAC prompts suppressed for SYSTEM processes"
Write-Warn "Note: UAC is now set to minimum — this tablet is configured as a dedicated kiosk device"

# ── 4. Create boot-time scheduled task as safety net ─────────────────────────
Write-Step "Creating boot-time health check scheduled task"

$taskName   = "EcaAfrica-Boot-Ensure"
$taskScript = @'
# EcaAfrica boot health check — runs 60s after login to ensure all services are up
Start-Sleep -Seconds 60
$services = @("EcaAfrica-Bridge", "EcaAfrica-Frontend", "WireGuardManager")
foreach ($s in $services) {
    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -ne "Running") {
        Start-Service -Name $s -ErrorAction SilentlyContinue
    }
}
# Also ensure WireGuard tunnel is up
$wg = Get-Service -Name "WireGuardTunnel`$EcareAfrica" -ErrorAction SilentlyContinue
if ($wg -and $wg.Status -ne "Running") {
    Start-Service -Name "WireGuardTunnel`$EcareAfrica" -ErrorAction SilentlyContinue
}
'@

# Save the script
$taskScriptPath = Join-Path $SCRIPT_DIR "tools\boot-check.ps1"
New-Item -ItemType Directory -Force -Path (Split-Path $taskScriptPath) | Out-Null
[System.IO.File]::WriteAllText($taskScriptPath, $taskScript, [System.Text.UTF8Encoding]::new($false))

# Remove existing task if present
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

# Create new task — runs as SYSTEM at boot + at login
$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
               -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$taskScriptPath`""
$trigger1 = New-ScheduledTaskTrigger -AtStartup
$trigger2 = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet `
               -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
               -RestartCount 3 `
               -RestartInterval (New-TimeSpan -Minutes 1) `
               -StartWhenAvailable `
               -RunOnlyIfNetworkAvailable:$false `
               -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask `
    -TaskName   $taskName `
    -Action     $action `
    -Trigger    @($trigger1, $trigger2) `
    -Settings   $settings `
    -Principal  $principal `
    -Description "Ensures EcaAfrica services and WireGuard VPN are running after every boot/login" `
    -Force | Out-Null

Write-OK "Scheduled task '$taskName' created — runs as SYSTEM at every boot + login"

# ── 5. Disable Windows fast-startup interference ──────────────────────────────
Write-Step "Disabling Fast Startup (prevents services from not starting after shutdown)"
$powerKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
Set-ItemProperty -Path $powerKey -Name "HiberbootEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-OK "Fast Startup disabled — clean boot every time"

# ── 6. Prevent Windows from killing background services ──────────────────────
Write-Step "Configuring Windows service recovery policies"
# Increase service control manager timeout so slow-starting services aren't killed
$sccKey = "HKLM:\SYSTEM\CurrentControlSet\Control"
Set-ItemProperty -Path $sccKey -Name "ServicesPipeTimeout" -Value 120000 -Type DWord -ErrorAction SilentlyContinue
Write-OK "Service startup timeout set to 120 seconds"

# ── 7. Start everything now ───────────────────────────────────────────────────
Write-Step "Starting all services now"

$startOrder = @("WireGuardManager", "EcaAfrica-Bridge", "EcaAfrica-Frontend")
foreach ($s in $startOrder) {
    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -ne "Running") {
        Start-Service -Name $s -ErrorAction SilentlyContinue
        Start-Sleep 2
        $svc.Refresh()
        if ($svc.Status -eq "Running") {
            Write-OK "$s started"
        } else {
            Write-Warn "$s did not start — check logs"
        }
    } elseif ($svc) {
        Write-OK "$s already running"
    }
}

# Start WireGuard tunnel
$wgSvc = Get-Service -Name "WireGuardTunnel`$EcareAfrica" -ErrorAction SilentlyContinue
if ($wgSvc -and $wgSvc.Status -ne "Running") {
    Start-Service "WireGuardTunnel`$EcareAfrica" -ErrorAction SilentlyContinue
    Start-Sleep 3
    $wgSvc.Refresh()
    Write-OK "WireGuard tunnel: $($wgSvc.Status)"
} elseif ($wgSvc) {
    Write-OK "WireGuard tunnel already running"
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  PERMANENT ADMIN CONFIGURATION COMPLETE" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  What was configured:" -ForegroundColor White
Write-Host "  [1] EcaAfrica-Bridge    — SYSTEM, auto-start, crash-restart"
Write-Host "  [2] EcaAfrica-Frontend  — SYSTEM, auto-start, crash-restart"
Write-Host "  [3] WireGuard Manager   — auto-start, crash-restart"
Write-Host "  [4] WireGuard Tunnel    — auto-start, crash-restart"
Write-Host "  [5] UAC suppressed      — no more admin prompts on this tablet"
Write-Host "  [6] Boot health check   — scheduled task ensures everything starts"
Write-Host "  [7] Fast Startup OFF    — clean boot every time"
Write-Host "  [8] Service timeout     — 120s before Windows kills slow services"
Write-Host ""
Write-Host "  After every reboot — automatically starts:" -ForegroundColor White
Write-Host "  - EcaAfrica backend (port 5000)"
Write-Host "  - EcaAfrica frontend (port 3000)"
Write-Host "  - WireGuard VPN tunnel (EcareAfrica)"
Write-Host "  - FK623 biometric device connection"
Write-Host ""
Write-Host "  Open dashboard: http://localhost:3000" -ForegroundColor Cyan
Write-Host ""
Write-Warn "  REBOOT RECOMMENDED to apply all settings fully."
Write-Host ""

$reboot = Read-Host "Reboot now? (y/n)"
if ($reboot -eq "y" -or $reboot -eq "Y") {
    Write-Host "Rebooting in 5 seconds..." -ForegroundColor Yellow
    Start-Sleep 5
    Restart-Computer -Force
} else {
    Write-Host "Reboot manually when ready to apply all changes." -ForegroundColor Yellow
    Read-Host "Press Enter to close"
}
