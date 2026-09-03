#Requires -RunAsAdministrator
<#
.SYNOPSIS
    EcaAfrica Tablet — Install Windows Services
    Installs the bridge (backend) and frontend as Windows services that start
    automatically on boot, run as SYSTEM (elevated), and restart on crash.
    No manual "Run as Administrator" ever needed after this runs once.

.USAGE
    Right-click this file → "Run with PowerShell"
    OR in an admin PowerShell terminal:
        .\install-services.ps1

.WHAT IT DOES
    1. Downloads NSSM (Non-Sucking Service Manager) if not present
    2. Installs EcaAfrica-Bridge  → node backend/server.js   (port 5000)
    3. Installs EcaAfrica-Frontend → npm run start            (port 3000)
    4. Starts both services immediately
    5. Verifies they are running
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

if (-not (Test-Path $BACKEND_DIR\server.js)) {
    Write-Fail "backend\server.js not found. Make sure you are running this from the Tablet Setup folder."
    Read-Host "Press Enter to exit"
    exit 1
}
Write-OK "Backend: $BACKEND_DIR\server.js"

if (-not (Test-Path $FRONTEND_DIR\package.json)) {
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
        # NSSM 2.24 — stable release, widely used
        Invoke-WebRequest -Uri "https://nssm.cc/release/nssm-2.24.zip" `
            -OutFile $nssmZip -UseBasicParsing
        Expand-Archive -Path $nssmZip -DestinationPath $env:TEMP -Force
        # NSSM zip contains win64\nssm.exe and win32\nssm.exe
        $arch = if ([Environment]::Is64BitOperatingSystem) { "win64" } else { "win32" }
        Copy-Item "$env:TEMP\nssm-2.24\$arch\nssm.exe" $NSSM_EXE -Force
        Write-OK "NSSM downloaded and extracted"
    } catch {
        Write-Fail "Failed to download NSSM: $_"
        Write-Warn "Manual fix: Download nssm.exe from https://nssm.cc/download and put it in: $NSSM_DIR"
        Read-Host "Press Enter to exit"
        exit 1
    }
} else {
    Write-OK "NSSM already present: $NSSM_EXE"
}

# ── Build frontend if .next folder missing ─────────────────────────────────────
Write-Step "Checking frontend build"
$nextBuildDir = Join-Path $FRONTEND_DIR ".next"
if (-not (Test-Path $nextBuildDir)) {
    Write-Warn ".next build folder not found — running npm run build (this takes ~2 minutes)..."
    Push-Location $FRONTEND_DIR
    try {
        & $NPM_EXE run build
        Write-OK "Frontend build complete"
    } catch {
        Write-Warn "Frontend build failed: $_"
        Write-Warn "The frontend service will still be installed but may not start until you run: npm run build"
    } finally {
        Pop-Location
    }
} else {
    Write-OK ".next build exists — skipping rebuild"
}

# ── Install Backend (Bridge) Service ──────────────────────────────────────────
Write-Step "Installing EcaAfrica-Bridge service"
Stop-AndRemove $BRIDGE_SVC

& $NSSM_EXE install $BRIDGE_SVC $NODE_EXE "server.js"
& $NSSM_EXE set $BRIDGE_SVC AppDirectory     $BACKEND_DIR
& $NSSM_EXE set $BRIDGE_SVC DisplayName      "EcaAfrica Bridge (FK623 attendance)"
& $NSSM_EXE set $BRIDGE_SVC Description      "Connects to the FK623 biometric device and syncs attendance to the school server via WireGuard VPN"
& $NSSM_EXE set $BRIDGE_SVC Start            SERVICE_AUTO_START
& $NSSM_EXE set $BRIDGE_SVC ObjectName       LocalSystem   # runs as SYSTEM = full admin
& $NSSM_EXE set $BRIDGE_SVC AppStdout        "$LOG_DIR\bridge-out.log"
& $NSSM_EXE set $BRIDGE_SVC AppStderr        "$LOG_DIR\bridge-err.log"
& $NSSM_EXE set $BRIDGE_SVC AppRotateFiles   1
& $NSSM_EXE set $BRIDGE_SVC AppRotateBytes   10485760      # rotate at 10 MB
& $NSSM_EXE set $BRIDGE_SVC AppRestartDelay  3000          # wait 3s before restart on crash
& $NSSM_EXE set $BRIDGE_SVC AppThrottle      5000          # max 1 restart per 5s
& $NSSM_EXE set $BRIDGE_SVC DependOnService  Tcpip         # wait for network

Write-OK "EcaAfrica-Bridge installed"

# ── Install Frontend Service ───────────────────────────────────────────────────
Write-Step "Installing EcaAfrica-Frontend service"
Stop-AndRemove $FRONTEND_SVC

# Find npm's actual .cmd path so NSSM can run it
$npmCmd = (Get-Command npm).Source -replace "npm$","npm.cmd"
if (-not (Test-Path $npmCmd)) { $npmCmd = $NPM_EXE }

# Use node to run next start directly (more reliable than npm in a service)
$nextScript = Join-Path $FRONTEND_DIR "node_modules\.bin\next"
if (Test-Path "$nextScript.cmd") {
    & $NSSM_EXE install $FRONTEND_SVC $NODE_EXE "$nextScript start --port 3000"
} else {
    & $NSSM_EXE install $FRONTEND_SVC $NPM_EXE "run start"
}

& $NSSM_EXE set $FRONTEND_SVC AppDirectory     $FRONTEND_DIR
& $NSSM_EXE set $FRONTEND_SVC DisplayName      "EcaAfrica Frontend (tablet web UI)"
& $NSSM_EXE set $FRONTEND_SVC Description      "Serves the tablet attendance web interface on http://localhost:3000"
& $NSSM_EXE set $FRONTEND_SVC Start            SERVICE_AUTO_START
& $NSSM_EXE set $FRONTEND_SVC ObjectName       LocalSystem
& $NSSM_EXE set $FRONTEND_SVC AppStdout        "$LOG_DIR\frontend-out.log"
& $NSSM_EXE set $FRONTEND_SVC AppStderr        "$LOG_DIR\frontend-err.log"
& $NSSM_EXE set $FRONTEND_SVC AppRotateFiles   1
& $NSSM_EXE set $FRONTEND_SVC AppRotateBytes   10485760
& $NSSM_EXE set $FRONTEND_SVC AppRestartDelay  3000
& $NSSM_EXE set $FRONTEND_SVC AppThrottle      5000
& $NSSM_EXE set $FRONTEND_SVC DependOnService  "$BRIDGE_SVC"  # frontend starts after bridge

Write-OK "EcaAfrica-Frontend installed"

# ── Start both services ────────────────────────────────────────────────────────
Write-Step "Starting services"
Start-Service -Name $BRIDGE_SVC
Start-Sleep 3
Start-Service -Name $FRONTEND_SVC
Start-Sleep 3

# ── Verify ────────────────────────────────────────────────────────────────────
Write-Step "Verifying services"
$bSvc = Get-Service -Name $BRIDGE_SVC
$fSvc = Get-Service -Name $FRONTEND_SVC

if ($bSvc.Status -eq "Running") {
    Write-OK "$BRIDGE_SVC   is RUNNING"
} else {
    Write-Fail "$BRIDGE_SVC   is $($bSvc.Status) — check $LOG_DIR\bridge-err.log"
}

if ($fSvc.Status -eq "Running") {
    Write-OK "$FRONTEND_SVC is RUNNING"
} else {
    Write-Fail "$FRONTEND_SVC is $($fSvc.Status) — check $LOG_DIR\frontend-err.log"
}

# ── Quick HTTP check ───────────────────────────────────────────────────────────
Write-Step "HTTP health check"
Start-Sleep 4
try {
    $health = Invoke-RestMethod -Uri "http://localhost:5000/api/health" -TimeoutSec 10
    Write-OK "Bridge API:    http://localhost:5000/api/health — status: $($health.status)"
} catch {
    Write-Warn "Bridge API not yet responding — may still be starting. Check $LOG_DIR\bridge-err.log"
}
try {
    $null = Invoke-WebRequest -Uri "http://localhost:3000" -TimeoutSec 10 -UseBasicParsing
    Write-OK "Frontend UI:   http://localhost:3000 — reachable"
} catch {
    Write-Warn "Frontend not yet responding — may still be starting. Check $LOG_DIR\frontend-err.log"
}

# ── Summary ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  SETUP COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Both services are now installed and will start automatically"
Write-Host "  on every Windows boot — no manual action needed."
Write-Host ""
Write-Host "  Bridge (backend):   http://localhost:5000"
Write-Host "  Frontend (web UI):  http://localhost:3000"
Write-Host "  Log files:          $LOG_DIR"
Write-Host ""
Write-Host "  To manage services later:"
Write-Host "    View status:     Get-Service EcaAfrica-Bridge, EcaAfrica-Frontend"
Write-Host "    Stop:            Stop-Service  EcaAfrica-Bridge"
Write-Host "    Start:           Start-Service EcaAfrica-Bridge"
Write-Host "    Uninstall:       .\uninstall-services.ps1"
Write-Host ""

Read-Host "Press Enter to close"
