#Requires -RunAsAdministrator
<#
.SYNOPSIS
    EcaAfrica — Complete New Tablet Setup Script
    Run this ONCE on a brand new Windows tablet.
    Does everything: installs software, clones code, builds, installs services,
    configures WireGuard, makes everything auto-start as SYSTEM.

.USAGE
    Double-click: SETUP-NEW-TABLET.bat
    (It self-elevates to Administrator automatically)
#>

Set-StrictMode -Off
$ErrorActionPreference = "Continue"
$ProgressPreference    = "SilentlyContinue"   # speeds up Invoke-WebRequest

# ── Configuration — edit these before running ─────────────────────────────────
$INSTALL_DIR    = "C:\EcaAfrica"               # Where the code will live
$GITHUB_REPO    = "https://github.com/Byiringiro24/Tablet_Setup.git"
$GITHUB_BRANCH  = "Testing-Branch"
$DEVICE_IP      = "192.168.1.76"               # FK623 biometric device IP on LAN
$DEVICE_ID      = "DV-KGL-01"                  # Device label (change per school)
$TABLET_UUID    = ""                            # Fill after Super Admin registers tablet
$WG_SERVER      = "169.58.124.150:51820"        # WireGuard server endpoint
$BACKEND_PORT   = 5000
$FRONTEND_PORT  = 3000
# ─────────────────────────────────────────────────────────────────────────────

$LOG_FILE = "$env:TEMP\ecaafrica-setup.log"
Start-Transcript -Path $LOG_FILE -Append -ErrorAction SilentlyContinue

function Write-Step($msg) {
    Write-Host "`n========================================" -ForegroundColor DarkCyan
    Write-Host "  $msg" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor DarkCyan
}
function Write-OK($msg)   { Write-Host "  [OK]  $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  [!!]  $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "  [ERR] $msg" -ForegroundColor Red }
function Write-Info($msg) { Write-Host "        $msg" -ForegroundColor Gray }

function Test-Command($cmd) {
    return $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Install-WithWinget($id, $name) {
    Write-Info "Installing $name..."
    $result = winget install --id $id --silent --accept-package-agreements --accept-source-agreements 2>&1
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
        Write-OK "$name installed"
        return $true
    }
    Write-Warn "$name install returned code $LASTEXITCODE — may already be installed"
    return $false
}

function Refresh-Path {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH","User")
}

# ═══════════════════════════════════════════════════════════════════
# STEP 1 — Install required software
# ═══════════════════════════════════════════════════════════════════
Write-Step "STEP 1 — Installing required software"

# Check winget is available
if (-not (Test-Command "winget")) {
    Write-Warn "winget not found — installing App Installer..."
    Start-Process "ms-appinstaller:" -ErrorAction SilentlyContinue
    Start-Sleep 5
    if (-not (Test-Command "winget")) {
        Write-Fail "winget unavailable. Please install from Microsoft Store: App Installer"
        Write-Warn "Or manually install: Node.js, .NET 8, Git, WireGuard, Chrome"
        Read-Host "Press Enter after manually installing, then re-run this script"
    }
}

# Node.js
if (Test-Command "node") {
    $nv = node --version
    Write-OK "Node.js already installed: $nv"
} else {
    Install-WithWinget "OpenJS.NodeJS.LTS" "Node.js LTS"
    Refresh-Path
}

# .NET 8 Runtime (x86 — required for FK623 DLL)
$dotnetRuntimes = dotnet --list-runtimes 2>&1
if ($dotnetRuntimes -match "8\.0") {
    Write-OK ".NET 8 Runtime already installed"
} else {
    Write-Info "Installing .NET 8 Desktop Runtime x86..."
    $dotnetUrl = "https://aka.ms/dotnet/8.0/windowsdesktop-runtime-win-x86.exe"
    $dotnetInstaller = "$env:TEMP\dotnet8-x86.exe"
    try {
        Invoke-WebRequest -Uri $dotnetUrl -OutFile $dotnetInstaller -UseBasicParsing
        Start-Process -FilePath $dotnetInstaller -ArgumentList "/install /quiet /norestart" -Wait
        Write-OK ".NET 8 Runtime (x86) installed"
    } catch {
        Write-Warn ".NET 8 download failed: $_ — install manually from https://dotnet.microsoft.com/download/dotnet/8.0"
    }
    Refresh-Path
}

# Git
if (Test-Command "git") {
    Write-OK "Git already installed: $(git --version)"
} else {
    Install-WithWinget "Git.Git" "Git"
    Refresh-Path
}

# WireGuard
if (Test-Path "C:\Program Files\WireGuard\wireguard.exe") {
    Write-OK "WireGuard already installed"
} else {
    Write-Info "Installing WireGuard..."
    $wgUrl = "https://download.wireguard.com/windows-client/wireguard-installer.exe"
    $wgInstaller = "$env:TEMP\wireguard-installer.exe"
    try {
        Invoke-WebRequest -Uri $wgUrl -OutFile $wgInstaller -UseBasicParsing
        Start-Process -FilePath $wgInstaller -ArgumentList "/S" -Wait
        Write-OK "WireGuard installed"
    } catch {
        Write-Warn "WireGuard download failed: $_ — install manually from https://www.wireguard.com/install/"
    }
}

# Google Chrome (for kiosk display)
if (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
    Write-OK "Google Chrome already installed"
} else {
    Install-WithWinget "Google.Chrome" "Google Chrome"
}

Refresh-Path

# ═══════════════════════════════════════════════════════════════════
# STEP 2 — Clone or update the repository
# ═══════════════════════════════════════════════════════════════════
Write-Step "STEP 2 — Getting EcaAfrica code from GitHub"

if (Test-Path "$INSTALL_DIR\.git") {
    Write-Info "Repository already exists — pulling latest changes..."
    Push-Location $INSTALL_DIR
    git fetch origin $GITHUB_BRANCH 2>&1 | Out-Null
    git checkout $GITHUB_BRANCH 2>&1 | Out-Null
    git pull origin $GITHUB_BRANCH 2>&1
    Pop-Location
    Write-OK "Code updated to latest $GITHUB_BRANCH"
} else {
    Write-Info "Cloning from $GITHUB_REPO..."
    git clone --branch $GITHUB_BRANCH $GITHUB_REPO $INSTALL_DIR
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "git clone failed. Check internet connection and try again."
        Read-Host "Press Enter to exit"
        exit 1
    }
    Write-OK "Code cloned to $INSTALL_DIR"
}

$BACKEND_DIR  = "$INSTALL_DIR\backend"
$FRONTEND_DIR = "$INSTALL_DIR\frontend"
$FKBRIDGE_DIR = "$INSTALL_DIR\FKBridge"
$LOG_DIR      = "$INSTALL_DIR\logs"
$TOOLS_DIR    = "$INSTALL_DIR\tools"
$NSSM_EXE     = "$TOOLS_DIR\nssm.exe"

New-Item -ItemType Directory -Force -Path $LOG_DIR   | Out-Null
New-Item -ItemType Directory -Force -Path $TOOLS_DIR | Out-Null

# ═══════════════════════════════════════════════════════════════════
# STEP 3 — Write configuration files
# ═══════════════════════════════════════════════════════════════════
Write-Step "STEP 3 — Writing configuration"

# device-config.json
$deviceConfig = @{
    ipAddress   = $DEVICE_IP
    port        = 5005
    license     = 1261
    deviceId    = $DEVICE_ID
    netPassword = 0
    protocolType = -1
    timeoutMs   = 10000
} | ConvertTo-Json -Depth 3

$dataDir = "$BACKEND_DIR\data"
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
[System.IO.File]::WriteAllText("$dataDir\device-config.json", $deviceConfig, [System.Text.UTF8Encoding]::new($false))
Write-OK "device-config.json — device IP: $DEVICE_IP"

# .env
$envContent = @"
PORT=$BACKEND_PORT
SERVER_API_URL=https://backend.ecareafrica.net/api/v1
TABLET_UUID=$TABLET_UUID
WG_SERVER_ENDPOINT=$WG_SERVER
VPN_ALLOWED_IPS=10.0.0.0/16
WG_DNS=1.1.1.1
"@
[System.IO.File]::WriteAllText("$BACKEND_DIR\.env", $envContent.Trim(), [System.Text.UTF8Encoding]::new($false))
Write-OK "backend/.env written"

# .env.local (frontend)
$envLocal = "NEXT_PUBLIC_API_URL=http://localhost:$BACKEND_PORT"
[System.IO.File]::WriteAllText("$FRONTEND_DIR\.env.local", $envLocal, [System.Text.UTF8Encoding]::new($false))
Write-OK "frontend/.env.local written"

# ═══════════════════════════════════════════════════════════════════
# STEP 4 — Install dependencies and build
# ═══════════════════════════════════════════════════════════════════
Write-Step "STEP 4 — Installing dependencies and building"

# Backend npm install
Write-Info "Installing backend dependencies..."
Push-Location $BACKEND_DIR
npm install --prefer-offline 2>&1 | Out-Null
Write-OK "Backend dependencies installed"
Pop-Location

# FKBridge .NET build
Write-Info "Building FKBridge (.NET 8)..."
Push-Location $FKBRIDGE_DIR
$buildResult = dotnet build -c Release 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-OK "FKBridge built successfully"
} else {
    Write-Warn "FKBridge build had issues — check .NET 8 x86 runtime is installed"
    Write-Info $buildResult
}
Pop-Location

# Frontend npm install + build
Write-Info "Installing frontend dependencies..."
Push-Location $FRONTEND_DIR
npm install 2>&1 | Out-Null
Write-OK "Frontend dependencies installed"

Write-Info "Building frontend (this takes 2-3 minutes)..."
$buildOutput = npm run build 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-OK "Frontend built successfully"
} else {
    Write-Warn "Frontend build had warnings — check output above"
}
Pop-Location

# ═══════════════════════════════════════════════════════════════════
# STEP 5 — Download NSSM
# ═══════════════════════════════════════════════════════════════════
Write-Step "STEP 5 — Setting up NSSM service manager"

if (-not (Test-Path $NSSM_EXE)) {
    Write-Info "Downloading NSSM..."
    $nssmZip = "$env:TEMP\nssm.zip"
    try {
        Invoke-WebRequest -Uri "https://nssm.cc/release/nssm-2.24.zip" -OutFile $nssmZip -UseBasicParsing
        Expand-Archive -Path $nssmZip -DestinationPath $env:TEMP -Force
        $arch = if ([Environment]::Is64BitOperatingSystem) { "win64" } else { "win32" }
        Copy-Item "$env:TEMP\nssm-2.24\$arch\nssm.exe" $NSSM_EXE -Force
        Write-OK "NSSM downloaded"
    } catch {
        Write-Fail "Failed to download NSSM: $_"
        Read-Host "Press Enter to exit"
        exit 1
    }
} else {
    Write-OK "NSSM already present"
}

# ═══════════════════════════════════════════════════════════════════
# STEP 6 — Install Windows services
# ═══════════════════════════════════════════════════════════════════
Write-Step "STEP 6 — Installing Windows services (auto-start as SYSTEM)"

$NODE_EXE = (Get-Command node -ErrorAction SilentlyContinue)?.Source
if (-not $NODE_EXE) {
    Write-Fail "Node.js not found in PATH after install. Reboot and run this script again."
    Read-Host "Press Enter to exit"
    exit 1
}

function Install-NssmService($name, $exe, $args, $workDir, $display, $desc, $depend) {
    # Remove if already exists
    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.Status -eq "Running") { Stop-Service $name -Force -ErrorAction SilentlyContinue; Start-Sleep 2 }
        & $NSSM_EXE remove $name confirm 2>&1 | Out-Null
        Start-Sleep 1
    }
    & $NSSM_EXE install     $name $exe $args
    & $NSSM_EXE set         $name AppDirectory    $workDir
    & $NSSM_EXE set         $name DisplayName     $display
    & $NSSM_EXE set         $name Description     $desc
    & $NSSM_EXE set         $name Start           SERVICE_AUTO_START
    & $NSSM_EXE set         $name ObjectName      LocalSystem      # full SYSTEM = admin
    & $NSSM_EXE set         $name AppStdout       "$LOG_DIR\$name-out.log"
    & $NSSM_EXE set         $name AppStderr       "$LOG_DIR\$name-err.log"
    & $NSSM_EXE set         $name AppRotateFiles  1
    & $NSSM_EXE set         $name AppRotateBytes  10485760
    & $NSSM_EXE set         $name AppRestartDelay 3000
    & $NSSM_EXE set         $name AppThrottle     5000
    if ($depend) { & $NSSM_EXE set $name DependOnService $depend }
    sc.exe failure $name reset= 60 actions= restart/3000/restart/3000/restart/3000 | Out-Null
}

# Bridge service
Install-NssmService `
    "EcaAfrica-Bridge" `
    $NODE_EXE `
    "server.js" `
    $BACKEND_DIR `
    "EcaAfrica Bridge (FK623 + WireGuard)" `
    "Manages FK623 biometric device and WireGuard VPN" `
    "Tcpip"
Write-OK "EcaAfrica-Bridge service installed (SYSTEM)"

# Frontend service
$nextBin = "$FRONTEND_DIR\node_modules\.bin\next.cmd"
if (Test-Path $nextBin) {
    Install-NssmService `
        "EcaAfrica-Frontend" `
        $NODE_EXE `
        "`"$nextBin`" start --port $FRONTEND_PORT" `
        $FRONTEND_DIR `
        "EcaAfrica Frontend (tablet dashboard)" `
        "Serves the attendance dashboard on http://localhost:$FRONTEND_PORT" `
        "EcaAfrica-Bridge"
} else {
    $npmExe = (Get-Command npm -ErrorAction SilentlyContinue)?.Source
    Install-NssmService `
        "EcaAfrica-Frontend" `
        $npmExe `
        "run start" `
        $FRONTEND_DIR `
        "EcaAfrica Frontend (tablet dashboard)" `
        "Serves the attendance dashboard on http://localhost:$FRONTEND_PORT" `
        "EcaAfrica-Bridge"
}
Write-OK "EcaAfrica-Frontend service installed (SYSTEM)"

# ═══════════════════════════════════════════════════════════════════
# STEP 7 — WireGuard auto-start
# ═══════════════════════════════════════════════════════════════════
Write-Step "STEP 7 — Configuring WireGuard auto-start"

$wgMgr = Get-Service "WireGuardManager" -ErrorAction SilentlyContinue
if ($wgMgr) {
    Set-Service "WireGuardManager" -StartupType Automatic
    sc.exe failure "WireGuardManager" reset= 60 actions= restart/2000/restart/2000/restart/2000 | Out-Null
    if ($wgMgr.Status -ne "Running") { Start-Service "WireGuardManager" -ErrorAction SilentlyContinue }
    Write-OK "WireGuard Manager set to auto-start"
} else {
    Write-Warn "WireGuard Manager not found — WireGuard may not be installed properly"
}

$wgTunnel = Get-Service "WireGuardTunnel`$EcareAfrica" -ErrorAction SilentlyContinue
if ($wgTunnel) {
    Set-Service "WireGuardTunnel`$EcareAfrica" -StartupType Automatic -ErrorAction SilentlyContinue
    sc.exe failure "WireGuardTunnel`$EcareAfrica" reset= 60 actions= restart/3000/restart/3000/restart/3000 | Out-Null
    Write-OK "WireGuard tunnel EcareAfrica set to auto-start"
} else {
    Write-Warn "WireGuard tunnel not configured yet — complete wizard at http://localhost:3000 after setup"
}

# ═══════════════════════════════════════════════════════════════════
# STEP 8 — System hardening (no UAC, boot task, fast-startup off)
# ═══════════════════════════════════════════════════════════════════
Write-Step "STEP 8 — Hardening system (permanent admin, no UAC, auto-recover)"

# Suppress UAC prompts — tablet is a dedicated kiosk device
$uacKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $uacKey -Name "EnableLUA"                  -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $uacKey -Name "ConsentPromptBehaviorAdmin" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $uacKey -Name "PromptOnSecureDesktop"      -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-OK "UAC suppressed — no more prompts on this tablet"

# Disable Fast Startup — prevents services from missing boot
$powerKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
Set-ItemProperty -Path $powerKey -Name "HiberbootEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-OK "Fast Startup disabled"

# Increase service startup timeout
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "ServicesPipeTimeout" -Value 120000 -Type DWord -ErrorAction SilentlyContinue
Write-OK "Service startup timeout set to 120s"

# Boot health check scheduled task
$bootScript = @"
Start-Sleep -Seconds 90
foreach (`$s in @('EcaAfrica-Bridge','EcaAfrica-Frontend','WireGuardManager')) {
    `$svc = Get-Service `$s -ErrorAction SilentlyContinue
    if (`$svc -and `$svc.Status -ne 'Running') { Start-Service `$s -ErrorAction SilentlyContinue }
}
`$wg = Get-Service 'WireGuardTunnel`$EcareAfrica' -ErrorAction SilentlyContinue
if (`$wg -and `$wg.Status -ne 'Running') { Start-Service 'WireGuardTunnel`$EcareAfrica' -ErrorAction SilentlyContinue }
"@
$bootScriptPath = "$TOOLS_DIR\boot-check.ps1"
[System.IO.File]::WriteAllText($bootScriptPath, $bootScript, [System.Text.UTF8Encoding]::new($false))

Unregister-ScheduledTask "EcaAfrica-Boot-Ensure" -Confirm:$false -ErrorAction SilentlyContinue
$action    = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$bootScriptPath`""
$triggers  = @(New-ScheduledTaskTrigger -AtStartup; New-ScheduledTaskTrigger -AtLogOn)
$settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -StartWhenAvailable -RunOnlyIfNetworkAvailable:$false -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask "EcaAfrica-Boot-Ensure" -Action $action -Trigger $triggers -Settings $settings -Principal $principal -Description "Ensures EcaAfrica + WireGuard start on every boot" -Force | Out-Null
Write-OK "Boot health-check scheduled task registered (runs as SYSTEM)"

# ═══════════════════════════════════════════════════════════════════
# STEP 9 — Auto-login + Chrome kiosk (optional)
# ═══════════════════════════════════════════════════════════════════
Write-Step "STEP 9 — Kiosk auto-open (Chrome launches dashboard on boot)"

$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (Test-Path $chromePath) {
    # Add Chrome to startup folder — opens dashboard after login
    $startupFolder = [System.Environment]::GetFolderPath("CommonStartup")
    $shortcutPath  = "$startupFolder\EcaAfrica Dashboard.lnk"
    $wsh    = New-Object -ComObject WScript.Shell
    $link   = $wsh.CreateShortcut($shortcutPath)
    $link.TargetPath  = $chromePath
    $link.Arguments   = "--kiosk http://localhost:$FRONTEND_PORT --disable-infobars --no-first-run"
    $link.Description = "EcaAfrica Attendance Dashboard"
    $link.Save()
    Write-OK "Chrome kiosk shortcut added to all-users startup"
} else {
    Write-Warn "Chrome not found — install Google Chrome for automatic dashboard launch"
}

# ═══════════════════════════════════════════════════════════════════
# STEP 10 — Start services and verify
# ═══════════════════════════════════════════════════════════════════
Write-Step "STEP 10 — Starting services and verifying"

Start-Service "WireGuardManager"    -ErrorAction SilentlyContinue; Start-Sleep 2
Start-Service "EcaAfrica-Bridge"    -ErrorAction SilentlyContinue; Start-Sleep 5
Start-Service "EcaAfrica-Frontend"  -ErrorAction SilentlyContinue; Start-Sleep 5

# Verify
$results = @()
foreach ($s in @("EcaAfrica-Bridge", "EcaAfrica-Frontend", "WireGuardManager")) {
    $svc = Get-Service $s -ErrorAction SilentlyContinue
    $results += [PSCustomObject]@{ Service=$s; Status=($svc?.Status ?? "NOT FOUND") }
}

Write-Host ""
Write-Host "  Service Status:" -ForegroundColor White
foreach ($r in $results) {
    if ($r.Status -eq "Running") {
        Write-OK "$($r.Service.PadRight(25)) RUNNING"
    } else {
        Write-Fail "$($r.Service.PadRight(25)) $($r.Status)"
    }
}

# HTTP check
Start-Sleep 5
Write-Host ""
Write-Host "  HTTP Health Check:" -ForegroundColor White
try {
    $h = Invoke-RestMethod "http://localhost:$BACKEND_PORT/api/health" -TimeoutSec 10
    Write-OK "Backend  http://localhost:$BACKEND_PORT   status=$($h.status) bridge=$($h.bridgeReady)"
} catch { Write-Warn "Backend not yet responding — check $LOG_DIR\EcaAfrica-Bridge-err.log" }
try {
    $null = Invoke-WebRequest "http://localhost:$FRONTEND_PORT" -TimeoutSec 10 -UseBasicParsing
    Write-OK "Frontend http://localhost:$FRONTEND_PORT   reachable"
} catch { Write-Warn "Frontend not yet responding — it may still be compiling" }

# ═══════════════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  NEW TABLET SETUP COMPLETE" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  What was set up:" -ForegroundColor White
Write-Host "  [1]  Node.js, .NET 8, Git, WireGuard, Chrome — installed"
Write-Host "  [2]  Code cloned from GitHub ($GITHUB_BRANCH)"
Write-Host "  [3]  Device config: $DEVICE_IP  ID: $DEVICE_ID"
Write-Host "  [4]  Backend + Frontend built and running"
Write-Host "  [5]  EcaAfrica-Bridge    — Windows service, auto-start, SYSTEM"
Write-Host "  [6]  EcaAfrica-Frontend  — Windows service, auto-start, SYSTEM"
Write-Host "  [7]  WireGuard Manager   — auto-start, crash-restart"
Write-Host "  [8]  UAC suppressed, Fast Startup OFF, boot health-check task"
Write-Host "  [9]  Chrome opens dashboard automatically on login"
Write-Host ""
Write-Host "  NEXT STEPS:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  A. Open dashboard:     http://localhost:$FRONTEND_PORT" -ForegroundColor Cyan
Write-Host ""
Write-Host "  B. Register tablet in Super Admin portal:" -ForegroundColor White
Write-Host "     https://backend.ecareafrica.net → Hardware → Tablets → Add Tablet"
Write-Host "     Copy the TABLET_UUID, then edit: $BACKEND_DIR\.env"
Write-Host "     Set: TABLET_UUID=<paste here>"
Write-Host "     Then run: Restart-Service EcaAfrica-Bridge"
Write-Host ""
Write-Host "  C. Set up WireGuard VPN:" -ForegroundColor White
Write-Host "     Open dashboard → sidebar → WireGuard VPN → enter password: admin1234"
Write-Host "     Follow Steps 1-5 in the wizard (no terminal needed)"
Write-Host ""
Write-Host "  D. Set correct device IP:" -ForegroundColor White
Write-Host "     Open dashboard → sidebar → Developer → enter password: admin1234"
Write-Host "     Update IP Address to the FK623 device IP on your network"
Write-Host ""
Write-Host "  Log files: $LOG_DIR" -ForegroundColor Gray
Write-Host "  Setup log: $LOG_FILE" -ForegroundColor Gray
Write-Host ""

Stop-Transcript -ErrorAction SilentlyContinue

$reboot = Read-Host "Reboot now to apply all settings? (y/n)"
if ($reboot -eq "y" -or $reboot -eq "Y") {
    Write-Host "Rebooting in 10 seconds — services will start automatically..." -ForegroundColor Yellow
    Start-Sleep 10
    Restart-Computer -Force
} else {
    Write-Host ""
    Write-Host "  Remember to reboot when ready — some settings require a restart." -ForegroundColor Yellow
    Read-Host "  Press Enter to close"
}
