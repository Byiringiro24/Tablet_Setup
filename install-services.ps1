#Requires -RunAsAdministrator
<#
.SYNOPSIS
    EcaAfrica Tablet — Install Windows Services
    Installs the bridge (backend) and frontend as Windows services that start
    automatically on boot, run as SYSTEM (full admin), and restart on crash.
    Also installs the WireGuard VPN tunnel as a service if a config exists.
    No manual "Run as Administrator" ever needed after this runs once.

.USAGE
    Double-click: INSTALL (double-click me).bat
    OR in an admin PowerShell terminal:
        .\install-services.ps1

.WHAT IT DOES
    1. Downloads NSSM (Non-Sucking Service Manager) if not present
    2. Installs EcaAfrica-Bridge  → node backend/server.js   (port 5000, runs as SYSTEM)
    3. Installs EcaAfrica-Frontend → next start               (port 3000, runs as SYSTEM)
    4. Installs WireGuard EcareAfrica tunnel as a service     (if conf exists)
    5. Starts all services immediately
    6. Verifies everything is running
#>

Set-StrictMode -Off
$ErrorActionPreference = "Stop"

# ── Configuration ──────────────────────────────────────────────────────────────
$SCRIPT_DIR    = Split-Path -Parent $MyInvocation.MyCommand.Path
$BACKEND_DIR   = Join-Path $SCRIPT_DIR "backend"
$FRONTEND_DIR  = Join-Path $SCRIPT_DIR "frontend"
$NSSM_DIR      = Join-Path $SCRIPT_DIR "tools"
$NSSM_EXE      = Join-Path $NSSM_DIR   "nssm.exe"
$LOG_DIR       = Join-Path $SCRIPT_DIR "logs"
$NODE_EXE      = (Get-Command node -ErrorAction SilentlyContinue)?.Source
$NPM_EXE       = (Get-Command npm  -ErrorAction SilentlyContinue)?.Source

$BRIDGE_SVC    = "EcaAfrica-Bridge"
$FRONTEND_SVC  = "EcaAfrica-Frontend"
$WG_TUNNEL     = "EcareAfrica"
$WG_EXE        = "C:\Program Files\WireGuard\wireguard.exe"
$WG_CONF       = "C:\ProgramData\WireGuard\$WG_TUNNEL.conf"

# ── Helpers ────────────────────────────────────────────────────────────────────
function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "    OK  $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    !!  $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "    ERR $msg" -ForegroundColor Red }

function Stop-AndRemove($name) {
    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Warn "Removing existing service: $name"
        if ($svc.Status -eq "Running") {
            Stop-Service -Name $name -Force -ErrorAction SilentlyContinue
            Start-Sleep 2
        }
        & $NSSM_EXE remove $name confirm 2>&1 | Out-Null
    }
}

# ── Pre-flight checks ──────────────────────────────────────────────────────────
Write-Step "Pre-flight checks"

if (-not $NODE_EXE) {
    Write-Fail "Node.js not found. Download from https://nodejs.org and install, then run this script again."
    Read-Host "Press Enter to exit"
    exit 1
}
Write-OK "Node.js: $NODE_EXE  ($(node --version))"

if (-not (Test-Path "$BACKEND_DIR\server.js")) {
    Write-Fail "backend\server.js not found. Run this from the EcaAfrica folder."
    Read-Host "Press Enter to exit"
    exit 1
}
Write-OK "Backend: $BACKEND_DIR\server.js"

if (-not (Test-Path "$FRONTEND_DIR\package.json")) {
    Write-Fail "frontend\package.json not found."
    Read-Host "Press Enter to exit"
    exit 1
}
Write-OK "Frontend: $FRONTEND_DIR"

# ── Create folders ─────────────────────────────────────────────────────────────
Write-Step "Creating log and tools directories"
New-Item -ItemType Directory -Force -Path $NSSM_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $LOG_DIR  | Out-Null
Write-OK "Logs: $LOG_DIR"

# ── Download NSSM ──────────────────────────────────────────────────────────────
Write-Step "Checking NSSM"
if (-not (Test-Path $NSSM_EXE)) {
    Write-Warn "NSSM not found — downloading..."
    $nssmZip = Join-Path $env:TEMP "nssm.zip"
    try {
        Invoke-WebRequest -Uri "https://nssm.cc/release/nssm-2.24.zip" `
            -OutFile $nssmZip -UseBasicParsing
        Expand-Archive -Path $nssmZip -DestinationPath $env:TEMP -Force
        $arch = if ([Environment]::Is64BitOperatingSystem) { "win64" } else { "win32" }
        Copy-Item "$env:TEMP\nssm-2.24\$arch\nssm.exe" $NSSM_EXE -Force
        Write-OK "NSSM downloaded"
    } catch {
        Write-Fail "Failed to download NSSM: $_"
        Write-Warn "Download nssm.exe from https://nssm.cc/download and place it in: $NSSM_DIR"
        Read-Host "Press Enter to exit"
        exit 1
    }
} else {
    Write-OK "NSSM: $NSSM_EXE"
}

# ── Install backend deps ───────────────────────────────────────────────────────
Write-Step "Installing backend dependencies"
Push-Location $BACKEND_DIR
try {
    & $NPM_EXE install --production --prefer-offline 2>&1 | Out-Null
    Write-OK "Backend npm install done"
} catch {
    Write-Warn "npm install warning: $_ (continuing)"
} finally { Pop-Location }

# ── Build frontend if .next folder missing ─────────────────────────────────────
Write-Step "Checking frontend build"
$nextBuildDir = Join-Path $FRONTEND_DIR ".next"
if (-not (Test-Path $nextBuildDir)) {
    Write-Warn ".next not found — running npm run build (~2 minutes)..."
    Push-Location $FRONTEND_DIR
    try {
        & $NPM_EXE install 2>&1 | Out-Null
        & $NPM_EXE run build
        Write-OK "Frontend build complete"
    } catch {
        Write-Warn "Frontend build failed: $_ — service installed but may not start until you run: npm run build"
    } finally { Pop-Location }
} else {
    Write-OK ".next build exists"
}

# ── Install Backend (Bridge) Service ──────────────────────────────────────────
Write-Step "Installing EcaAfrica-Bridge service (runs as SYSTEM)"
Stop-AndRemove $BRIDGE_SVC

& $NSSM_EXE install     $BRIDGE_SVC $NODE_EXE "server.js"
& $NSSM_EXE set         $BRIDGE_SVC AppDirectory     $BACKEND_DIR
& $NSSM_EXE set         $BRIDGE_SVC DisplayName      "EcaAfrica Bridge (FK623 + WireGuard)"
& $NSSM_EXE set         $BRIDGE_SVC Description      "Manages FK623 biometric device, WireGuard VPN, and syncs attendance to school server"
& $NSSM_EXE set         $BRIDGE_SVC Start            SERVICE_AUTO_START
& $NSSM_EXE set         $BRIDGE_SVC ObjectName       LocalSystem        # SYSTEM = full Administrator, no UAC
& $NSSM_EXE set         $BRIDGE_SVC AppStdout        "$LOG_DIR\bridge-out.log"
& $NSSM_EXE set         $BRIDGE_SVC AppStderr        "$LOG_DIR\bridge-err.log"
& $NSSM_EXE set         $BRIDGE_SVC AppRotateFiles   1
& $NSSM_EXE set         $BRIDGE_SVC AppRotateBytes   10485760
& $NSSM_EXE set         $BRIDGE_SVC AppRestartDelay  3000
& $NSSM_EXE set         $BRIDGE_SVC AppThrottle      5000
& $NSSM_EXE set         $BRIDGE_SVC DependOnService  Tcpip

Write-OK "EcaAfrica-Bridge installed (SYSTEM)"

# ── Install Frontend Service ───────────────────────────────────────────────────
Write-Step "Installing EcaAfrica-Frontend service (runs as SYSTEM)"
Stop-AndRemove $FRONTEND_SVC

$nextScript = Join-Path $FRONTEND_DIR "node_modules\.bin\next"
if (Test-Path "$nextScript.cmd") {
    & $NSSM_EXE install $FRONTEND_SVC $NODE_EXE "`"$nextScript`" start --port 3000"
} else {
    & $NSSM_EXE install $FRONTEND_SVC $NPM_EXE "run start"
}

& $NSSM_EXE set $FRONTEND_SVC AppDirectory     $FRONTEND_DIR
& $NSSM_EXE set $FRONTEND_SVC DisplayName      "EcaAfrica Frontend (tablet web UI)"
& $NSSM_EXE set $FRONTEND_SVC Description      "Serves the attendance dashboard on http://localhost:3000"
& $NSSM_EXE set $FRONTEND_SVC Start            SERVICE_AUTO_START
& $NSSM_EXE set $FRONTEND_SVC ObjectName       LocalSystem
& $NSSM_EXE set $FRONTEND_SVC AppStdout        "$LOG_DIR\frontend-out.log"
& $NSSM_EXE set $FRONTEND_SVC AppStderr        "$LOG_DIR\frontend-err.log"
& $NSSM_EXE set $FRONTEND_SVC AppRotateFiles   1
& $NSSM_EXE set $FRONTEND_SVC AppRotateBytes   10485760
& $NSSM_EXE set $FRONTEND_SVC AppRestartDelay  3000
& $NSSM_EXE set $FRONTEND_SVC AppThrottle      5000
& $NSSM_EXE set $FRONTEND_SVC DependOnService  $BRIDGE_SVC

Write-OK "EcaAfrica-Frontend installed (SYSTEM)"

# ── Install WireGuard Tunnel Service ──────────────────────────────────────────
Write-Step "WireGuard VPN tunnel"
if (-not (Test-Path $WG_EXE)) {
    Write-Warn "WireGuard not installed — skipping tunnel service. Install from https://www.wireguard.com/install/ then run wizard from the dashboard."
} elseif (-not (Test-Path $WG_CONF)) {
    Write-Warn "No WireGuard config found at $WG_CONF"
    Write-Warn "Use the WireGuard VPN wizard in the dashboard (http://localhost:3000) to generate keys and configure the tunnel."
    Write-Warn "After Step 4 (Activate), the tunnel will be installed as a service automatically."
} else {
    Write-OK "WireGuard config found: $WG_CONF"
    # Remove existing tunnel service if present
    $wgSvcName = "WireGuardTunnel`$$WG_TUNNEL"
    $wgSvc = Get-Service -Name $wgSvcName -ErrorAction SilentlyContinue
    if ($wgSvc -and $wgSvc.Status -eq "Running") {
        Write-Warn "Stopping existing WireGuard tunnel..."
        Stop-Service -Name $wgSvcName -Force -ErrorAction SilentlyContinue
        Start-Sleep 2
    }
    & $WG_EXE /uninstalltunnelservice $WG_TUNNEL 2>&1 | Out-Null
    Start-Sleep 2

    # Install tunnel — runs as SYSTEM (wireguard.exe /installtunnelservice always runs elevated)
    & $WG_EXE /installtunnelservice $WG_CONF
    Start-Sleep 3

    $wgRunning = Get-Service -Name $wgSvcName -ErrorAction SilentlyContinue
    if ($wgRunning -and $wgRunning.Status -eq "Running") {
        Write-OK "WireGuard tunnel EcareAfrica installed and RUNNING"
    } else {
        Write-Warn "WireGuard tunnel installed but not yet running — it will start automatically on next boot or when the WireGuard app activates it."
    }
}

# ── Set WireGuard Manager to auto-start ───────────────────────────────────────
Write-Step "Configuring WireGuard Manager auto-start"
$wgMgr = Get-Service -Name "WireGuardManager" -ErrorAction SilentlyContinue
if ($wgMgr) {
    Set-Service -Name "WireGuardManager" -StartupType Automatic
    if ($wgMgr.Status -ne "Running") { Start-Service "WireGuardManager" -ErrorAction SilentlyContinue }
    Write-OK "WireGuard Manager set to auto-start"
} else {
    Write-Warn "WireGuard Manager service not found — install WireGuard first"
}

# ── Start EcaAfrica services ──────────────────────────────────────────────────
Write-Step "Starting EcaAfrica services"
Start-Service -Name $BRIDGE_SVC -ErrorAction SilentlyContinue
Start-Sleep 4
Start-Service -Name $FRONTEND_SVC -ErrorAction SilentlyContinue
Start-Sleep 3

# ── Verify ────────────────────────────────────────────────────────────────────
Write-Step "Verifying services"
$bSvc = Get-Service -Name $BRIDGE_SVC  -ErrorAction SilentlyContinue
$fSvc = Get-Service -Name $FRONTEND_SVC -ErrorAction SilentlyContinue

if ($bSvc -and $bSvc.Status -eq "Running") {
    Write-OK "$BRIDGE_SVC    RUNNING  (as SYSTEM — full Administrator)"
} else {
    Write-Fail "$BRIDGE_SVC    $($bSvc?.Status ?? 'NOT FOUND') — check $LOG_DIR\bridge-err.log"
}

if ($fSvc -and $fSvc.Status -eq "Running") {
    Write-OK "$FRONTEND_SVC  RUNNING  (as SYSTEM — full Administrator)"
} else {
    Write-Fail "$FRONTEND_SVC  $($fSvc?.Status ?? 'NOT FOUND') — check $LOG_DIR\frontend-err.log"
}

# ── HTTP health check ─────────────────────────────────────────────────────────
Write-Step "HTTP health check"
Start-Sleep 5
try {
    $health = Invoke-RestMethod -Uri "http://localhost:5000/api/health" -TimeoutSec 10
    Write-OK "Backend API    http://localhost:5000   status=$($health.status)  bridge=$($health.bridgeReady)"
} catch {
    Write-Warn "Backend not yet responding — check $LOG_DIR\bridge-err.log"
}
try {
    $null = Invoke-WebRequest -Uri "http://localhost:3000" -TimeoutSec 10 -UseBasicParsing
    Write-OK "Frontend UI    http://localhost:3000   reachable"
} catch {
    Write-Warn "Frontend not yet responding — check $LOG_DIR\frontend-err.log"
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  SETUP COMPLETE — All services run as SYSTEM (Administrator)" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  EcaAfrica-Bridge    → http://localhost:5000  (auto-start, SYSTEM)"
Write-Host "  EcaAfrica-Frontend  → http://localhost:3000  (auto-start, SYSTEM)"
Write-Host "  WireGuard EcareAfrica → auto-start on boot   (SYSTEM)"
Write-Host ""
Write-Host "  Because services run as SYSTEM:"
Write-Host "  - WireGuard install/uninstall works without UAC prompts"
Write-Host "  - FKBridge.exe has full access to COM ports and DLLs"
Write-Host "  - No 'Run as Administrator' ever needed manually"
Write-Host ""
Write-Host "  Log files:  $LOG_DIR"
Write-Host ""
Write-Host "  Manage services:"
Write-Host "    Restart-Service EcaAfrica-Bridge"
Write-Host "    Restart-Service EcaAfrica-Frontend"
Write-Host "    Get-Service EcaAfrica-Bridge, EcaAfrica-Frontend"
Write-Host ""
Write-Host "  To uninstall:  .\uninstall-services.ps1"
Write-Host ""

Read-Host "Press Enter to close"
