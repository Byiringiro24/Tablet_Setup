#Requires -RunAsAdministrator
<#
.SYNOPSIS
    EcaAfrica — Complete New Tablet Setup
    Run ONCE on a brand new Windows tablet. Does everything automatically.

.USAGE
    Double-click: SETUP-NEW-TABLET.bat  (self-elevates to Administrator)
#>

Set-StrictMode -Off
$ErrorActionPreference = "Continue"
$ProgressPreference    = "SilentlyContinue"

# ── Configuration — edit DEVICE_IP and DEVICE_ID before deploying ─────────────
$INSTALL_DIR   = "C:\EcaAfrica"
$GITHUB_REPO   = "https://github.com/Byiringiro24/Tablet_Setup.git"
$GITHUB_BRANCH = "Testing-Branch"
$DEVICE_IP     = "192.168.1.76"          # Change to your FK623 device IP
$DEVICE_ID     = "DV-KGL-01"             # Change per school/gate
$TABLET_UUID   = ""                      # Fill after Super Admin registers tablet
$WG_SERVER     = "169.58.124.150:51820"
$BACKEND_PORT  = 5000
$FRONTEND_PORT = 3000
# ─────────────────────────────────────────────────────────────────────────────

$LOG_FILE = "$env:TEMP\ecaafrica-setup-$(Get-Date -f 'yyyyMMdd-HHmmss').log"
Start-Transcript -Path $LOG_FILE -Append -ErrorAction SilentlyContinue

function Write-Step($n, $msg) {
    Write-Host ""
    Write-Host "  [$n] $msg" -ForegroundColor Cyan
    Write-Host "  $('─' * 60)" -ForegroundColor DarkGray
}
function Write-OK($msg)   { Write-Host "      OK  $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "      !!  $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "      ERR $msg" -ForegroundColor Red }
function Write-Info($msg) { Write-Host "      ... $msg" -ForegroundColor Gray }

function Refresh-Path {
    # Reload PATH from registry so newly installed tools are found in this session
    $machine = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") ?? ""
    $user    = [System.Environment]::GetEnvironmentVariable("PATH", "User") ?? ""
    $env:PATH = "$machine;$user;C:\Program Files\nodejs;C:\Program Files\Git\cmd;$env:APPDATA\npm"
}

function Find-Exe($name) {
    # Try PATH first, then common install locations
    $found = (Get-Command $name -ErrorAction SilentlyContinue)?.Source
    if ($found) { return $found }
    $locations = @(
        "C:\Program Files\nodejs\$name.exe",
        "C:\Program Files (x86)\nodejs\$name.exe",
        "$env:LOCALAPPDATA\Programs\nodejs\$name.exe"
    )
    foreach ($loc in $locations) { if (Test-Path $loc) { return $loc } }
    return $null
}

function Wait-ForService($name, $seconds = 30) {
    $end = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $end) {
        $svc = Get-Service $name -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq "Running") { return $true }
        Start-Sleep 2
    }
    return $false
}

# ═══════════════════════════════════════════════════════════════════
Write-Step "1/10" "Installing required software"
# ═══════════════════════════════════════════════════════════════════

# ── Node.js ──
Refresh-Path
$nodeExe = Find-Exe "node"
if ($nodeExe) {
    Write-OK "Node.js: $nodeExe  ($(& $nodeExe --version 2>&1))"
} else {
    Write-Info "Downloading Node.js LTS..."
    $nodeUrl = "https://nodejs.org/dist/v20.19.0/node-v20.19.0-x64.msi"
    $nodeInstaller = "$env:TEMP\nodejs-lts.msi"
    try {
        Invoke-WebRequest -Uri $nodeUrl -OutFile $nodeInstaller -UseBasicParsing
        Start-Process msiexec.exe -ArgumentList "/i `"$nodeInstaller`" /quiet /norestart ADDLOCAL=ALL" -Wait
        Refresh-Path
        $nodeExe = Find-Exe "node"
        Write-OK "Node.js installed: $nodeExe"
    } catch {
        Write-Fail "Node.js download failed: $_"
        Write-Warn "Download manually: https://nodejs.org/en/download"
    }
}

# ── .NET 8 SDK x86 (needed for FKBridge build) ──
$dotnetRt = & dotnet --list-runtimes 2>&1 | Where-Object { $_ -match "8\." }
if ($dotnetRt) {
    Write-OK ".NET 8 already installed"
} else {
    Write-Info "Downloading .NET 8 Desktop Runtime x86..."
    $dotnetUrl = "https://aka.ms/dotnet/8.0/windowsdesktop-runtime-win-x86.exe"
    $dotnetInstaller = "$env:TEMP\dotnet8-x86.exe"
    try {
        Invoke-WebRequest -Uri $dotnetUrl -OutFile $dotnetInstaller -UseBasicParsing
        Start-Process $dotnetInstaller -ArgumentList "/install /quiet /norestart" -Wait
        Write-OK ".NET 8 Desktop Runtime x86 installed"
    } catch {
        Write-Warn ".NET 8 download failed — install from https://dotnet.microsoft.com/download/dotnet/8.0"
    }
}

# Also install .NET 8 SDK for building FKBridge
$dotnetSdk = & dotnet --list-sdks 2>&1 | Where-Object { $_ -match "8\." }
if ($dotnetSdk) {
    Write-OK ".NET 8 SDK already installed"
} else {
    Write-Info "Downloading .NET 8 SDK x86 (for building FKBridge)..."
    $sdkUrl = "https://aka.ms/dotnet/8.0/dotnet-sdk-win-x86.exe"
    $sdkInstaller = "$env:TEMP\dotnet8-sdk-x86.exe"
    try {
        Invoke-WebRequest -Uri $sdkUrl -OutFile $sdkInstaller -UseBasicParsing
        Start-Process $sdkInstaller -ArgumentList "/install /quiet /norestart" -Wait
        Write-OK ".NET 8 SDK x86 installed"
    } catch {
        Write-Warn ".NET 8 SDK download failed — FKBridge build may fail"
    }
}

# ── Git ──
Refresh-Path
$gitExe = Find-Exe "git"
if ($gitExe) {
    Write-OK "Git: $(& $gitExe --version 2>&1)"
} else {
    Write-Info "Downloading Git..."
    $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.47.0.windows.1/Git-2.47.0-64-bit.exe"
    $gitInstaller = "$env:TEMP\git-installer.exe"
    try {
        Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing
        Start-Process $gitInstaller -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS" -Wait
        Refresh-Path
        $gitExe = Find-Exe "git"
        Write-OK "Git installed: $gitExe"
    } catch {
        Write-Warn "Git download failed — install from https://git-scm.com/download/win"
    }
}

# ── WireGuard ──
if (Test-Path "C:\Program Files\WireGuard\wireguard.exe") {
    Write-OK "WireGuard already installed"
} else {
    Write-Info "Downloading WireGuard..."
    $wgInstaller = "$env:TEMP\wireguard-installer.exe"
    try {
        Invoke-WebRequest -Uri "https://download.wireguard.com/windows-client/wireguard-installer.exe" -OutFile $wgInstaller -UseBasicParsing
        Start-Process $wgInstaller -ArgumentList "/S" -Wait
        Write-OK "WireGuard installed"
    } catch {
        Write-Warn "WireGuard download failed — install from https://www.wireguard.com/install/"
    }
}

# ── Google Chrome ──
if (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
    Write-OK "Chrome already installed"
} else {
    Write-Info "Downloading Chrome..."
    $chromeUrl = "https://dl.google.com/chrome/install/ChromeSetup.exe"
    $chromeInstaller = "$env:TEMP\ChromeSetup.exe"
    try {
        Invoke-WebRequest -Uri $chromeUrl -OutFile $chromeInstaller -UseBasicParsing
        Start-Process $chromeInstaller -ArgumentList "/silent /install" -Wait
        Write-OK "Chrome installed"
    } catch {
        Write-Warn "Chrome download failed — install from https://www.google.com/chrome/"
    }
}

Refresh-Path

# Resolve full paths after all installs
$nodeExe = Find-Exe "node"
$npmExe  = Find-Exe "npm"
$gitExe  = Find-Exe "git"

if (-not $nodeExe) {
    Write-Fail "Node.js still not found. Reboot and run this script again."
    Read-Host "Press Enter to exit"; exit 1
}
if (-not $gitExe) {
    Write-Fail "Git still not found. Reboot and run this script again."
    Read-Host "Press Enter to exit"; exit 1
}

Write-OK "Using Node.js: $nodeExe"
Write-OK "Using npm:     $npmExe"
Write-OK "Using git:     $gitExe"

# ═══════════════════════════════════════════════════════════════════
Write-Step "2/10" "Cloning / updating code from GitHub"
# ═══════════════════════════════════════════════════════════════════

if (Test-Path "$INSTALL_DIR\.git") {
    Write-Info "Repo already exists — pulling latest..."
    Push-Location $INSTALL_DIR
    & $gitExe fetch origin $GITHUB_BRANCH 2>&1 | Out-Null
    & $gitExe checkout $GITHUB_BRANCH 2>&1 | Out-Null
    & $gitExe pull origin $GITHUB_BRANCH 2>&1
    Pop-Location
    Write-OK "Updated to latest $GITHUB_BRANCH"
} else {
    if (Test-Path $INSTALL_DIR) {
        Write-Warn "$INSTALL_DIR exists but is not a git repo — removing and re-cloning..."
        Remove-Item $INSTALL_DIR -Recurse -Force
    }
    Write-Info "Cloning from GitHub..."
    & $gitExe clone --branch $GITHUB_BRANCH $GITHUB_REPO $INSTALL_DIR
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "git clone failed. Check internet connection."
        Read-Host "Press Enter to exit"; exit 1
    }
    Write-OK "Cloned to $INSTALL_DIR"
}

$BACKEND_DIR  = "$INSTALL_DIR\backend"
$FRONTEND_DIR = "$INSTALL_DIR\frontend"
$FKBRIDGE_DIR = "$INSTALL_DIR\FKBridge"
$LOG_DIR      = "$INSTALL_DIR\logs"
$TOOLS_DIR    = "$INSTALL_DIR\tools"
$NSSM_EXE     = "$TOOLS_DIR\nssm.exe"

New-Item -ItemType Directory -Force -Path $LOG_DIR, $TOOLS_DIR | Out-Null

# ═══════════════════════════════════════════════════════════════════
Write-Step "3/10" "Writing configuration files"
# ═══════════════════════════════════════════════════════════════════

New-Item -ItemType Directory -Force -Path "$BACKEND_DIR\data" | Out-Null

# device-config.json
$cfg = [ordered]@{
    ipAddress    = $DEVICE_IP
    port         = 5005
    license      = 1261
    deviceId     = $DEVICE_ID
    netPassword  = 0
    protocolType = -1
    timeoutMs    = 10000
}
[System.IO.File]::WriteAllText(
    "$BACKEND_DIR\data\device-config.json",
    ($cfg | ConvertTo-Json -Depth 3),
    [System.Text.UTF8Encoding]::new($false)
)
Write-OK "device-config.json  (device IP: $DEVICE_IP, ID: $DEVICE_ID)"

# backend/.env
$backendEnv = @"
PORT=$BACKEND_PORT
SERVER_API_URL=https://backend.ecareafrica.net/api/v1
TABLET_UUID=$TABLET_UUID
WG_SERVER_ENDPOINT=$WG_SERVER
VPN_ALLOWED_IPS=10.0.0.0/16
WG_DNS=1.1.1.1
"@
[System.IO.File]::WriteAllText("$BACKEND_DIR\.env", $backendEnv.Trim(), [System.Text.UTF8Encoding]::new($false))
Write-OK "backend/.env"

# frontend/.env.local
[System.IO.File]::WriteAllText("$FRONTEND_DIR\.env.local", "NEXT_PUBLIC_API_URL=http://localhost:$BACKEND_PORT", [System.Text.UTF8Encoding]::new($false))
Write-OK "frontend/.env.local"

# Create empty students.json if it doesn't exist
if (-not (Test-Path "$BACKEND_DIR\data\students.json")) {
    [System.IO.File]::WriteAllText("$BACKEND_DIR\data\students.json", "[]", [System.Text.UTF8Encoding]::new($false))
}

# ═══════════════════════════════════════════════════════════════════
Write-Step "4/10" "Installing dependencies and building"
# ═══════════════════════════════════════════════════════════════════

# Backend
Write-Info "npm install (backend)..."
Push-Location $BACKEND_DIR
& $nodeExe (Find-Exe "npm") install --prefer-offline 2>&1 | Out-Null
Write-OK "Backend dependencies installed"
Pop-Location

# FKBridge — .NET build
Write-Info "dotnet build FKBridge (Release)..."
$dotnetExe = (Get-Command dotnet -ErrorAction SilentlyContinue)?.Source ?? "dotnet"
Push-Location $FKBRIDGE_DIR
$buildOut = & $dotnetExe build -c Release 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-OK "FKBridge.exe built successfully"
} else {
    Write-Warn "FKBridge build issues — check .NET 8 x86 SDK is installed"
    $buildOut | Where-Object { $_ -match "error" } | ForEach-Object { Write-Warn $_ }
}
Pop-Location

$fkBridgeExe = "$FKBRIDGE_DIR\bin\Release\net8.0\FKBridge.exe"
if (Test-Path $fkBridgeExe) {
    Write-OK "FKBridge.exe confirmed at: $fkBridgeExe"
} else {
    Write-Warn "FKBridge.exe not found — device commands will not work until it is built"
}

# Frontend
Write-Info "npm install (frontend)..."
Push-Location $FRONTEND_DIR
& $nodeExe (Find-Exe "npm") install 2>&1 | Out-Null
Write-OK "Frontend dependencies installed"

Write-Info "npm run build (frontend — takes 2-3 minutes)..."
$env:NODE_ENV = "production"
& $nodeExe (Find-Exe "npm") run build 2>&1 | ForEach-Object {
    if ($_ -match "error|Error" -and $_ -notmatch "eslint") { Write-Warn $_ }
}
if ($LASTEXITCODE -eq 0) {
    Write-OK "Frontend build complete"
} else {
    Write-Warn "Frontend build had issues — service may not start until fixed"
}
Pop-Location

# ═══════════════════════════════════════════════════════════════════
Write-Step "5/10" "Setting up NSSM service manager"
# ═══════════════════════════════════════════════════════════════════

if (-not (Test-Path $NSSM_EXE)) {
    Write-Info "Downloading NSSM..."
    $nssmZip = "$env:TEMP\nssm-2.24.zip"
    try {
        Invoke-WebRequest -Uri "https://nssm.cc/release/nssm-2.24.zip" -OutFile $nssmZip -UseBasicParsing
        Expand-Archive -Path $nssmZip -DestinationPath $env:TEMP -Force -ErrorAction SilentlyContinue
        $arch = if ([Environment]::Is64BitOperatingSystem) { "win64" } else { "win32" }
        Copy-Item "$env:TEMP\nssm-2.24\$arch\nssm.exe" $NSSM_EXE -Force
        Write-OK "NSSM downloaded: $NSSM_EXE"
    } catch {
        Write-Fail "NSSM download failed: $_"
        Read-Host "Press Enter to exit"; exit 1
    }
} else {
    Write-OK "NSSM: $NSSM_EXE"
}

# ═══════════════════════════════════════════════════════════════════
Write-Step "6/10" "Installing Windows services (auto-start as SYSTEM)"
# ═══════════════════════════════════════════════════════════════════

function Remove-ServiceIfExists($name) {
    $svc = Get-Service $name -ErrorAction SilentlyContinue
    if (-not $svc) { return }
    if ($svc.Status -eq "Running") { Stop-Service $name -Force -ErrorAction SilentlyContinue; Start-Sleep 2 }
    & $NSSM_EXE remove $name confirm 2>&1 | Out-Null
    Start-Sleep 1
}

function New-EcaService($name, $exe, $args, $workDir, $display, $desc, $depend) {
    Remove-ServiceIfExists $name
    # NSSM needs exe and args as separate calls — combine exe+args as full command
    & $NSSM_EXE install $name $exe $args | Out-Null
    & $NSSM_EXE set $name AppDirectory    $workDir      | Out-Null
    & $NSSM_EXE set $name DisplayName     $display      | Out-Null
    & $NSSM_EXE set $name Description     $desc         | Out-Null
    & $NSSM_EXE set $name Start           SERVICE_AUTO_START | Out-Null
    & $NSSM_EXE set $name ObjectName      LocalSystem   | Out-Null  # SYSTEM = full admin
    & $NSSM_EXE set $name AppStdout       "$LOG_DIR\$name.out.log" | Out-Null
    & $NSSM_EXE set $name AppStderr       "$LOG_DIR\$name.err.log" | Out-Null
    & $NSSM_EXE set $name AppRotateFiles  1             | Out-Null
    & $NSSM_EXE set $name AppRotateBytes  10485760      | Out-Null
    & $NSSM_EXE set $name AppRestartDelay 3000          | Out-Null
    & $NSSM_EXE set $name AppThrottle     5000          | Out-Null
    if ($depend) { & $NSSM_EXE set $name DependOnService $depend | Out-Null }
    sc.exe failure $name reset= 86400 actions= restart/5000/restart/10000/restart/30000 | Out-Null
}

# EcaAfrica-Bridge — runs node server.js as SYSTEM
New-EcaService `
    "EcaAfrica-Bridge" `
    $nodeExe `
    "server.js" `
    $BACKEND_DIR `
    "EcaAfrica Bridge (FK623 + WireGuard)" `
    "Manages FK623 biometric device, WireGuard VPN, attendance sync" `
    "Tcpip"
Write-OK "EcaAfrica-Bridge installed (SYSTEM, auto-start)"

# EcaAfrica-Frontend — runs next start via node directly (not npm/cmd)
# Using node + full path to next script avoids cmd.exe/npm PATH issues under SYSTEM
$nextMainJs = "$FRONTEND_DIR\node_modules\next\dist\bin\next"
if (Test-Path "$nextMainJs") {
    New-EcaService `
        "EcaAfrica-Frontend" `
        $nodeExe `
        "`"$nextMainJs`" start --port $FRONTEND_PORT" `
        $FRONTEND_DIR `
        "EcaAfrica Frontend (tablet dashboard)" `
        "Attendance dashboard on http://localhost:$FRONTEND_PORT" `
        "EcaAfrica-Bridge"
} else {
    # Fallback: use cmd.exe to run npm run start (handles missing next bin)
    $cmdExe = "$env:SystemRoot\System32\cmd.exe"
    New-EcaService `
        "EcaAfrica-Frontend" `
        $cmdExe `
        "/c `"$nodeExe`" `"$FRONTEND_DIR\node_modules\next\dist\bin\next`" start --port $FRONTEND_PORT" `
        $FRONTEND_DIR `
        "EcaAfrica Frontend (tablet dashboard)" `
        "Attendance dashboard on http://localhost:$FRONTEND_PORT" `
        "EcaAfrica-Bridge"
}
Write-OK "EcaAfrica-Frontend installed (SYSTEM, auto-start)"

# ═══════════════════════════════════════════════════════════════════
Write-Step "7/10" "Configuring WireGuard auto-start"
# ═══════════════════════════════════════════════════════════════════

foreach ($svcName in @("WireGuard", "WireGuardManager")) {
    $s = Get-Service $svcName -ErrorAction SilentlyContinue
    if ($s) {
        sc.exe config $svcName start= auto | Out-Null
        sc.exe failure $svcName reset= 86400 actions= restart/3000/restart/5000/restart/10000 | Out-Null
        if ($s.Status -ne "Running") { Start-Service $svcName -ErrorAction SilentlyContinue }
        Write-OK "$svcName — auto-start, crash-restart"
    } else {
        Write-Warn "$svcName not found — WireGuard may not be installed"
    }
}

$wgTunnel = Get-Service "WireGuardTunnel`$EcareAfrica" -ErrorAction SilentlyContinue
if ($wgTunnel) {
    sc.exe config "WireGuardTunnel`$EcareAfrica" start= auto | Out-Null
    sc.exe failure "WireGuardTunnel`$EcareAfrica" reset= 86400 actions= restart/5000/restart/10000/restart/30000 | Out-Null
    Write-OK "WireGuard tunnel EcareAfrica — auto-start"
} else {
    Write-Warn "WireGuard tunnel not configured yet — use the WireGuard VPN wizard after setup"
}

# ═══════════════════════════════════════════════════════════════════
Write-Step "8/10" "System hardening — permanent admin, no UAC, auto-recover"
# ═══════════════════════════════════════════════════════════════════

# Suppress UAC — dedicated kiosk tablet
$uacKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty $uacKey "EnableLUA"                  0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty $uacKey "ConsentPromptBehaviorAdmin" 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty $uacKey "PromptOnSecureDesktop"      0 -Type DWord -ErrorAction SilentlyContinue
Write-OK "UAC suppressed — no prompts ever"

# Disable Fast Startup
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0 -Type DWord -ErrorAction SilentlyContinue
Write-OK "Fast Startup disabled"

# Extend service startup timeout to 2 minutes
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control" "ServicesPipeTimeout" 120000 -Type DWord -ErrorAction SilentlyContinue
Write-OK "Service startup timeout: 120s"

# PowerShell execution policy — allow scripts without prompts
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force -ErrorAction SilentlyContinue
Write-OK "ExecutionPolicy set to Bypass (scripts run without prompts)"

# Boot health-check scheduled task — restarts any stopped service 90s after boot
$bootScript = @'
Start-Sleep -Seconds 90
$svcs = @('EcaAfrica-Bridge','EcaAfrica-Frontend','WireGuardManager')
foreach ($s in $svcs) {
    $svc = Get-Service $s -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -ne 'Running') {
        Start-Service $s -ErrorAction SilentlyContinue
        Start-Sleep 3
    }
}
$wg = Get-Service 'WireGuardTunnel$EcareAfrica' -ErrorAction SilentlyContinue
if ($wg -and $wg.Status -ne 'Running') {
    Start-Service 'WireGuardTunnel$EcareAfrica' -ErrorAction SilentlyContinue
}
'@
$bootScriptPath = "$TOOLS_DIR\boot-check.ps1"
[System.IO.File]::WriteAllText($bootScriptPath, $bootScript, [System.Text.UTF8Encoding]::new($false))

Unregister-ScheduledTask "EcaAfrica-Boot-Ensure" -Confirm:$false -ErrorAction SilentlyContinue
$action    = New-ScheduledTaskAction -Execute "powershell.exe" `
                 -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$bootScriptPath`""
# Note: array triggers must use comma, not semicolon
$trigger1  = New-ScheduledTaskTrigger -AtStartup
$trigger2  = New-ScheduledTaskTrigger -AtLogOn
$settings  = New-ScheduledTaskSettingsSet `
                 -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
                 -StartWhenAvailable `
                 -RunOnlyIfNetworkAvailable:$false `
                 -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask "EcaAfrica-Boot-Ensure" `
    -Action $action -Trigger @($trigger1, $trigger2) `
    -Settings $settings -Principal $principal `
    -Description "Ensures EcaAfrica + WireGuard run on every boot" -Force | Out-Null
Write-OK "Boot health-check task registered (runs as SYSTEM at every boot + login)"

# ═══════════════════════════════════════════════════════════════════
Write-Step "9/10" "Kiosk auto-open — Chrome launches dashboard on every login"
# ═══════════════════════════════════════════════════════════════════

$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (Test-Path $chromePath) {
    # Use scheduled task instead of startup folder — gives services time to start first
    Unregister-ScheduledTask "EcaAfrica-OpenDashboard" -Confirm:$false -ErrorAction SilentlyContinue

    $chromeArg  = "--kiosk http://localhost:$FRONTEND_PORT --disable-infobars --no-first-run --disable-session-crashed-bubble"
    $chromeAction = New-ScheduledTaskAction -Execute $chromePath -Argument $chromeArg
    # Delay 30s after login so services have time to start
    $chromeTrigger = New-ScheduledTaskTrigger -AtLogOn
    $chromeTrigger.Delay = "PT30S"
    $chromeSettings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 12) -MultipleInstances IgnoreNew
    $chromePrincipal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest

    Register-ScheduledTask "EcaAfrica-OpenDashboard" `
        -Action $chromeAction -Trigger $chromeTrigger `
        -Settings $chromeSettings -Principal $chromePrincipal `
        -Description "Opens EcaAfrica dashboard in Chrome 30s after login" -Force | Out-Null
    Write-OK "Chrome kiosk scheduled task — opens http://localhost:$FRONTEND_PORT at login (+30s delay)"
} else {
    Write-Warn "Chrome not found — install Chrome for automatic dashboard launch"
}

# ═══════════════════════════════════════════════════════════════════
Write-Step "10/10" "Starting services and verifying"
# ═══════════════════════════════════════════════════════════════════

Write-Info "Starting WireGuard Manager..."
Start-Service "WireGuardManager" -ErrorAction SilentlyContinue
Start-Sleep 3

Write-Info "Starting EcaAfrica-Bridge..."
Start-Service "EcaAfrica-Bridge" -ErrorAction SilentlyContinue
$bridgeUp = Wait-ForService "EcaAfrica-Bridge" 30
if ($bridgeUp) { Write-OK "EcaAfrica-Bridge RUNNING" }
else { Write-Warn "EcaAfrica-Bridge slow to start — check $LOG_DIR\EcaAfrica-Bridge.err.log" }

Write-Info "Starting EcaAfrica-Frontend..."
Start-Service "EcaAfrica-Frontend" -ErrorAction SilentlyContinue
$frontendUp = Wait-ForService "EcaAfrica-Frontend" 30
if ($frontendUp) { Write-OK "EcaAfrica-Frontend RUNNING" }
else { Write-Warn "EcaAfrica-Frontend slow to start — check $LOG_DIR\EcaAfrica-Frontend.err.log" }

# HTTP health check
Write-Info "Waiting 10s then checking HTTP..."
Start-Sleep 10
$backendOk  = $false
$frontendOk = $false
try {
    $h = Invoke-RestMethod "http://localhost:$BACKEND_PORT/api/health" -TimeoutSec 10
    $backendOk = $true
    Write-OK "Backend  http://localhost:$BACKEND_PORT  status=$($h.status)  bridge=$($h.bridgeReady)"
} catch { Write-Warn "Backend HTTP not yet ready — may still be starting" }
try {
    $null = Invoke-WebRequest "http://localhost:$FRONTEND_PORT" -TimeoutSec 15 -UseBasicParsing
    $frontendOk = $true
    Write-OK "Frontend http://localhost:$FRONTEND_PORT  reachable"
} catch { Write-Warn "Frontend HTTP not yet ready — may still be compiling" }

Stop-Transcript -ErrorAction SilentlyContinue

# ═══════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  ════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "    NEW TABLET SETUP COMPLETE" -ForegroundColor Green
Write-Host "  ════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "  Everything runs as SYSTEM (full Administrator) automatically:" -ForegroundColor White
Write-Host "   • EcaAfrica-Bridge   — port $BACKEND_PORT  — auto-start, SYSTEM"
Write-Host "   • EcaAfrica-Frontend — port $FRONTEND_PORT  — auto-start, SYSTEM"
Write-Host "   • WireGuard Manager  — auto-start"
Write-Host "   • Chrome opens dashboard 30s after every login"
Write-Host "   • Boot health-check task ensures services survive reboots"
Write-Host "   • UAC suppressed — zero prompts, zero manual clicks"
Write-Host ""
Write-Host "  ── NEXT STEPS (do these after reboot) ─────────────────" -ForegroundColor Yellow
Write-Host ""
Write-Host "  A) Set the FK623 device IP (if different from $DEVICE_IP):"
Write-Host "     Open http://localhost:$FRONTEND_PORT → sidebar → Developer"
Write-Host "     Password: admin1234 → update IP Address"
Write-Host ""
Write-Host "  B) Register this tablet in Super Admin portal:"
Write-Host "     https://backend.ecareafrica.net → Tablets → Add Tablet"
Write-Host "     Then edit $BACKEND_DIR\.env"
Write-Host "     Set: TABLET_UUID=<paste UUID here>"
Write-Host "     Run: Restart-Service EcaAfrica-Bridge"
Write-Host ""
Write-Host "  C) Set up WireGuard VPN:"
Write-Host "     http://localhost:$FRONTEND_PORT → sidebar → WireGuard VPN"
Write-Host "     Password: admin1234 → follow Steps 1-5"
Write-Host ""
Write-Host "  Setup log: $LOG_FILE" -ForegroundColor Gray
Write-Host ""

$reboot = Read-Host "Reboot now to apply all settings? (recommended) [y/n]"
if ($reboot -match "^[Yy]") {
    Write-Host "  Rebooting in 10 seconds..." -ForegroundColor Yellow
    Start-Sleep 10
    Restart-Computer -Force
} else {
    Write-Host "  Reboot manually when ready." -ForegroundColor Yellow
    Read-Host "  Press Enter to close"
}
