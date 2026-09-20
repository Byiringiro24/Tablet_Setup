# ============================================================
# EcaAfrica - Start-EcaAfrica.ps1
# Automatic startup / update / rollback / self-healing
# ============================================================

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "EcaAfrica Tablet Startup" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$EcaRoot    = "C:\EcaAfrica"
$LogsDir    = Join-Path $EcaRoot "logs"

$RepoDir    = Join-Path $EcaRoot "Tablet_Setup"
$BackendDir = Join-Path $EcaRoot "backend"
$FrontendDir = Join-Path $EcaRoot "frontend"
$FKBridgeDir = Join-Path $EcaRoot "FKBridge"

$Branch = "Testing-Branch"

$Git = "C:\Program Files\Git\cmd\git.exe"
$Node = "C:\Program Files\nodejs\node.exe"
$Npm = "C:\Program Files\nodejs\npm.cmd"
$DotNetX86 = "C:\Program Files (x86)\dotnet\dotnet.exe"
$Chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe"

$BackendLog = Join-Path $LogsDir "Backend.log"
$FrontendLog = Join-Path $LogsDir "Frontend.log"
$FKBridgeLog = Join-Path $LogsDir "FKBridge.log"
$StartupLog = Join-Path $LogsDir "Startup.log"

$KnownGoodFile = Join-Path $EcaRoot "known-good-commit.txt"

$ScriptFileName = [System.IO.Path]::GetFileName($PSCommandPath)

$existingStartup = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -match "powershell.exe" -and
        $_.ProcessId -ne $PID -and
        (
            $_.CommandLine -match [regex]::Escape($ScriptFileName) -or
            $_.CommandLine -match "C:\\EcaAfrica" -or
            $_.CommandLine -match "EcaAfrica"
        )
    }

if ($existingStartup) {
    foreach ($proc in $existingStartup) {
        try {
            Log "Stopping stale EcaAfrica process PID $($proc.ProcessId) before relaunch."
            Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
        }
        catch {
            Log "Could not stop stale process PID $($proc.ProcessId): $($_.Exception.Message)"
        }
    }
}

New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null

# ------------------------------------------------------------
# Logging
# ------------------------------------------------------------

function Log {
    param(
        [string]$Message
    )

    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"

    Add-Content -Path $StartupLog -Value $line

    Write-Host $line
}

# ------------------------------------------------------------
# Refresh PATH
# ------------------------------------------------------------

function Update-PathEnvironment {

    $machine = [Environment]::GetEnvironmentVariable(
        "Path",
        "Machine"
    )

    $user = [Environment]::GetEnvironmentVariable(
        "Path",
        "User"
    )

    $env:Path = "$machine;$user"
}

Update-PathEnvironment

# ------------------------------------------------------------
# Locate tools
# ------------------------------------------------------------

function Find-Tool {

    param(
        [string]$Name,
        [string[]]$Paths
    )

    foreach ($p in $Paths) {

        if (Test-Path $p) {
            return $p
        }
    }

    try {

        $cmd = Get-Command $Name -ErrorAction Stop

        if ($cmd.Path) {
            return $cmd.Path
        }
    }
    catch {}

    return $null
}

$Git = Find-Tool "git.exe" @(
    $Git,
    "C:\Program Files\Git\bin\git.exe",
    "C:\Program Files\Git\cmd\git.exe",
    "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe"
)

$Node = Find-Tool "node.exe" @(
    $Node,
    "$env:ProgramFiles\nodejs\node.exe",
    "${env:ProgramFiles(x86)}\nodejs\node.exe",
    "$env:LOCALAPPDATA\Programs\nodejs\node.exe"
)

$Npm = Find-Tool "npm.cmd" @(
    $Npm,
    "$env:ProgramFiles\nodejs\npm.cmd",
    "${env:ProgramFiles(x86)}\nodejs\npm.cmd",
    "$env:LOCALAPPDATA\Programs\nodejs\npm.cmd",
    "C:\Program Files\nodejs\npm.cmd",
    "C:\Program Files (x86)\nodejs\npm.cmd"
)

$Chrome = Find-Tool "chrome.exe" @(
    $Chrome,
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)

# ------------------------------------------------------------
# Verify tools
# ------------------------------------------------------------

function Test-MinimumDotNetSdk {
    param(
        [string]$DotNetPath,
        [int]$MinimumMajor = 8
    )

    if (-not $DotNetPath -or -not (Test-Path $DotNetPath)) {
        return $false
    }

    try {
        $sdkOutput = & $DotNetPath --list-sdks 2>&1 | Out-String
        $sdkMatch = [regex]::Match($sdkOutput, '(\d+)[\.,](\d+)(?:[\.,](\d+))?')
        if ($sdkMatch.Success) {
            return [int]$sdkMatch.Groups[1].Value -ge $MinimumMajor
        }
    }
    catch {}

    return $false
}

function Repair-NpmDependencies {
    param(
        [string]$Directory
    )

    if (-not (Test-Path $Directory)) {
        return
    }

    if (-not $Npm) {
        throw "npm is not available."
    }

    $nodeModules = Join-Path $Directory "node_modules"
    $packageLock = Join-Path $Directory "package-lock.json"

    if (Test-Path $nodeModules) {
        Remove-Item $nodeModules -Recurse -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path $packageLock) {
        Remove-Item $packageLock -Force -ErrorAction SilentlyContinue
    }

    Get-Process -Name "node" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    $attempts = @(
        @("cache", "clean", "--force"),
        @("install", "--legacy-peer-deps", "--no-audit", "--no-fund"),
        @("install", "--legacy-peer-deps", "--force", "--no-audit", "--no-fund"),
        @("install", "--legacy-peer-deps", "--force", "--no-audit", "--no-fund", "--prefer-offline")
    )

    Push-Location $Directory
    try {
        foreach ($args in $attempts) {
            try {
                & $Npm @args
                if ($LASTEXITCODE -eq 0) {
                    return
                }
            }
            catch {
                Log "npm fallback failed for ${Directory}: $($_.Exception.Message)"
            }
        }

        throw "npm dependency repair failed in $Directory"
    }
    finally {
        try { Pop-Location } catch {}
    }
}

$startupCriticalMissing = $false

if (-not $Git) {
    Log "WARNING: Git not found. Git-based update checks will be skipped."
    $startupCriticalMissing = $true
}

if (-not $Node) {
    Log "WARNING: Node.js not found. JS app startup will be skipped."
    $startupCriticalMissing = $true
}

if (-not $Npm) {
    Log "WARNING: npm.cmd not found. npm startup steps will be skipped."
    $startupCriticalMissing = $true
}

if ($startupCriticalMissing) {
    Log "Some startup dependencies are missing; continuing in best-effort mode."
}

if (-not (Test-Path $DotNetX86)) {
    Log "WARNING: .NET x86 not found. FKBridge startup will be skipped."
    $startupCriticalMissing = $true
}

if (-not $Chrome) {
    Log "WARNING: Chrome not found. Kiosk launch will be skipped."
}

Log "Git: $Git"
Log "Node: $Node"
Log "npm: $Npm"
Log ".NET x86: $DotNetX86"
Log "Chrome: $Chrome"

# ------------------------------------------------------------
# Port check
# ------------------------------------------------------------

function Test-Port {

    param(
        [int]$Port
    )

    try {

        $connection = Get-NetTCPConnection `
            -LocalPort $Port `
            -State Listen `
            -ErrorAction SilentlyContinue

        if ($null -eq $connection) {
            return $false
        }

        foreach ($entry in $connection) {
            if ($entry.LocalPort -eq $Port) {
                $owner = Get-Process -Id $entry.OwningProcess -ErrorAction SilentlyContinue
                if ($owner -and $owner.ProcessName -match "node|chrome|dotnet|java|powershell") {
                    return $true
                }
            }
        }

        return $false
    }
    catch {

        return $false
    }
}

function Wait-Port {

    param(
        [int]$Port,
        [int]$TimeoutSeconds = 60
    )

    $start = Get-Date

    while (((Get-Date) - $start).TotalSeconds -lt $TimeoutSeconds) {

        if (Test-Port $Port) {
            return $true
        }

        Start-Sleep -Seconds 2
    }

    return $false
}

# ------------------------------------------------------------
# Stop previous EcaAfrica processes
# ------------------------------------------------------------

function Stop-EcaAfricaProcesses {

    Log "Checking for existing EcaAfrica processes."

    $currentPid = $PID

    $processes = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue

    foreach ($p in $processes) {

        $commandLine = $p.CommandLine

        if (-not $commandLine) {
            continue
        }

        if ($p.ProcessId -eq $currentPid) {
            continue
        }

        if ($commandLine -match [regex]::Escape($PSScriptRoot)) {
            continue
        }

        $shouldStop = (
            $commandLine -like "*C:\EcaAfrica*" -or
            $commandLine -match "FKBridge" -or
            $commandLine -match "next build" -or
            $commandLine -match "node.*server.js" -or
            $commandLine -match "next start" -or
            $commandLine -match "npm.*start"
        )

        if ($shouldStop) {

            try {
                Log "Stopping process PID $($p.ProcessId)"

                Stop-Process `
                    -Id $p.ProcessId `
                    -Force `
                    -ErrorAction SilentlyContinue
            }
            catch {}
        }
    }
}

# ------------------------------------------------------------
# Git repository
# ------------------------------------------------------------

if ($Git -and (Test-Path $RepoDir)) {
    try {
        Push-Location $RepoDir

        $currentCommit = (& $Git rev-parse HEAD).Trim()

        Log "Current commit: $currentCommit"

        try {
            & $Git fetch origin

            if ($LASTEXITCODE -ne 0) {
                throw "Git fetch failed."
            }

            $remoteCommit = (& $Git rev-parse "origin/$Branch").Trim()
        }
        catch {
            Log "GitHub update check failed."
            Log "Continuing with current local version."
            $remoteCommit = $currentCommit
        }
        finally {
            try { Pop-Location } catch {}
        }

        Log "Remote commit: $remoteCommit"

        $updateRequired = $currentCommit -ne $remoteCommit
    }
    catch {
        Log "Repository validation failed: $($_.Exception.Message)"
        $updateRequired = $false
    }
}
else {
    Log "Git repository check skipped because Git or repo folder is unavailable."
    $updateRequired = $false
}

# ------------------------------------------------------------
# Save known-good commit
# ------------------------------------------------------------

if (-not (Test-Path $KnownGoodFile)) {

    Set-Content `
        -Path $KnownGoodFile `
        -Value $currentCommit `
        -Encoding ASCII

    Log "Initial known-good commit saved."
}

$knownGood = (Get-Content $KnownGoodFile -Raw).Trim()

Log "Known-good commit: $knownGood"

# ------------------------------------------------------------
# Update
# ------------------------------------------------------------

$backendHealthy = (Test-Port 5000) -and (Test-HttpReachable "http://localhost:5000")
$frontendHealthy = (Test-Port 3000) -and (Test-HttpReachable "http://localhost:3000")

if ($updateRequired) {

    Log "New version detected."

    try {
        Stop-EcaAfricaProcesses
    }
    catch {
        Log "Process cleanup warning: $($_.Exception.Message)"
    }

    if ($Git -and (Test-Path $RepoDir)) {
        try {
            Push-Location $RepoDir

            & $Git checkout $Branch

            & $Git reset --hard "origin/$Branch"

            if ($LASTEXITCODE -ne 0) {
                throw "Git reset failed."
            }

            $newCommit = (& $Git rev-parse HEAD).Trim()

            Log "Updated to commit: $newCommit"

            # ----------------------------------------------------
            # Dependencies
            # ----------------------------------------------------

            if ($Npm -and (Test-Path (Join-Path $BackendDir "package.json"))) {
                try {
                    Log "Updating backend dependencies."
                    Repair-NpmDependencies $BackendDir
                    Log "Backend dependencies repaired."
                }
                catch {
                    Log "Backend dependency repair failed: $($_.Exception.Message)"
                }
            }

            if ($Npm -and (Test-Path (Join-Path $FrontendDir "package.json"))) {
                try {
                    Log "Updating frontend dependencies."
                    Repair-NpmDependencies $FrontendDir
                    Log "Frontend dependencies repaired."
                }
                catch {
                    Log "Frontend dependency repair failed: $($_.Exception.Message)"
                }
            }

            # ----------------------------------------------------
            # Build frontend
            # ----------------------------------------------------

            if ($Npm -and (Test-Path (Join-Path $FrontendDir "package.json"))) {
                try {
                    Push-Location $FrontendDir
                    Log "Building frontend."
                    & $Npm run build
                    if ($LASTEXITCODE -ne 0) {
                        Log "Frontend build failed. Repairing dependencies and retrying."
                        Repair-NpmDependencies $FrontendDir
                        & $Npm run build
                    }
                    if ($LASTEXITCODE -ne 0) { throw "Frontend build failed." }
                    Pop-Location
                }
                catch {
                    try { Pop-Location } catch {}
                    Log "Frontend build repair failed: $($_.Exception.Message)"
                }
            }

            # ----------------------------------------------------
            # Build FKBridge
            # ----------------------------------------------------

            if ((Test-Path $DotNetX86) -and (Get-ChildItem -Path $FKBridgeDir -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue)) {
                $project = Get-ChildItem -Path $FKBridgeDir -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

                try {
                    if (-not (Test-MinimumDotNetSdk $DotNetX86 8)) {
                        Log "WARNING: .NET 8 x86 SDK is missing or incompatible; FKBridge rebuild will continue best-effort."
                    }

                    Push-Location $project.Directory.FullName
                    Log "Building FKBridge with .NET x86."
                    & $DotNetX86 restore $project.FullName
                    if ($LASTEXITCODE -ne 0) { throw "FKBridge restore failed." }
                    & $DotNetX86 build $project.FullName -c Release --no-restore
                    if ($LASTEXITCODE -ne 0) { throw "FKBridge build failed." }
                    Pop-Location
                }
                catch {
                    try { Pop-Location } catch {}
                    Log "FKBridge rebuild failed but setup continues: $($_.Exception.Message)"
                }
            }

            Set-Content -Path $KnownGoodFile -Value $newCommit -Encoding ASCII
            Log "New commit validated and marked known-good."

        }
        catch {
            Log "UPDATE FAILED."
            Log $_.Exception.Message

            if ($Git) {
                Log "Rolling back to known-good commit: $knownGood"
                try { & $Git reset --hard $knownGood } catch { Log "Rollback reset failed: $($_.Exception.Message)" }
            }

            try { Pop-Location } catch {}

            if ($Npm -and (Test-Path (Join-Path $BackendDir "package.json"))) {
                try { Push-Location $BackendDir; & $Npm install --legacy-peer-deps; Pop-Location } catch { Log "Backend rollback install failed." }
            }

            if ($Npm -and (Test-Path (Join-Path $FrontendDir "package.json"))) {
                try { Push-Location $FrontendDir; & $Npm install --legacy-peer-deps; & $Npm run build; Pop-Location } catch { Log "Frontend rollback install failed." }
            }

            Log "Rollback completed with warnings."
        }
    }
    else {
        Log "Update skipped because repository or Git is unavailable."
    }
}
else {

    Log "No application update required."

    if ($backendHealthy -and $frontendHealthy) {
        Log "Existing backend/frontend are already healthy; skipping redundant dependency and build work."
    }
}

# ------------------------------------------------------------
# Start FKBridge
# ------------------------------------------------------------

try {
    Stop-EcaAfricaProcesses
}
catch {
    Log "Process cleanup warning: $($_.Exception.Message)"
}

Start-Sleep -Seconds 2

$FKBridgeExe = Join-Path `
    $FKBridgeDir `
    "bin\Release\net8.0\FKBridge.exe"

if (-not (Test-Path $FKBridgeExe)) {

    Log "WARNING: FKBridge.exe not found. Continuing without the device bridge."
}
else {
    Log "Starting FKBridge."

    try {
        Start-Process `
            -FilePath $FKBridgeExe `
            -WorkingDirectory $FKBridgeDir `
            -WindowStyle Hidden `
            -RedirectStandardOutput $FKBridgeLog `
            -RedirectStandardError $FKBridgeLog
    }
    catch {
        Log "FKBridge start failed: $($_.Exception.Message)"
    }
}

# ------------------------------------------------------------
# Start backend
# ------------------------------------------------------------

$ServerJs = Join-Path $BackendDir "server.js"

if (-not (Test-Path $ServerJs)) {

    Log "WARNING: backend server.js not found. Backend startup skipped."
}
else {
    if (-not (Test-Port 5000)) {

        Log "Starting backend."

        try {
            Start-Process `
                -FilePath $Node `
                -ArgumentList "`"$ServerJs`"" `
                -WorkingDirectory $BackendDir `
                -WindowStyle Hidden `
                -RedirectStandardOutput $BackendLog `
                -RedirectStandardError $BackendLog
        }
        catch {
            Log "Backend start failed: $($_.Exception.Message)"
        }
    }
    else {

        Log "Backend port 5000 already active."
    }

    if (-not (Wait-Port 5000 60)) {

        Log "WARNING: Backend port 5000 did not become ready. Continuing without blocking startup."
    }
    else {
        Log "Backend is ready on port 5000."
    }
}

# ------------------------------------------------------------
# Start frontend
# ------------------------------------------------------------

if (-not (Test-Port 3000)) {

    if ($Npm -and (Test-Path (Join-Path $FrontendDir "package.json"))) {
        Log "Starting frontend."

        try {
            Start-Process `
                -FilePath $Npm `
                -ArgumentList "start" `
                -WorkingDirectory $FrontendDir `
                -WindowStyle Hidden `
                -RedirectStandardOutput $FrontendLog `
                -RedirectStandardError $FrontendLog
        }
        catch {
            Log "Frontend start failed: $($_.Exception.Message)"
        }
    }
    else {
        Log "WARNING: Frontend package.json or npm is unavailable. Frontend startup skipped."
    }
}
else {

    Log "Frontend port 3000 already active."
}

if (-not (Wait-Port 3000 90)) {

    Log "WARNING: Frontend port 3000 did not become ready. Continuing without blocking kiosk launch."
}
else {
    Log "Frontend is ready on port 3000."
}

# ------------------------------------------------------------
# Wait before Chrome
# ------------------------------------------------------------

Log "Waiting 5 seconds before launching Chrome."

Start-Sleep -Seconds 5

# ------------------------------------------------------------
# Chrome kiosk
# ------------------------------------------------------------

function Test-HttpReachable {
    param(
        [string]$Uri,
        [int]$TimeoutSeconds = 8
    )

    try {
        $response = Invoke-WebRequest -Uri $Uri -Method Get -TimeoutSec $TimeoutSeconds -UseBasicParsing -ErrorAction Stop
        return $response.StatusCode -ge 200 -and $response.StatusCode -lt 500
    }
    catch {
        return $false
    }
}

if ($Chrome) {
    $ChromeProfile = Join-Path `
        $EcaRoot `
        "chrome-profile"

    New-Item `
        -ItemType Directory `
        -Path $ChromeProfile `
        -Force |
        Out-Null

    $ChromeArguments = @(
        "--kiosk"
        "--no-first-run"
        "--no-default-browser-check"
        "--disable-session-crashed-bubble"
        "--disable-infobars"
        "--user-data-dir=`"$ChromeProfile`""
        "http://localhost:3000"
    )

    Log "Starting Chrome kiosk."

    try {
        Start-Process `
            -FilePath $Chrome `
            -ArgumentList $ChromeArguments `
            -WindowStyle Maximized
    }
    catch {
        Log "Chrome kiosk launch failed: $($_.Exception.Message)"
    }
}
else {
    Log "WARNING: Chrome is unavailable. Kiosk launch skipped."
}

# ------------------------------------------------------------
# Runtime health validation
# ------------------------------------------------------------

$backendLive = (Test-Port 5000) -and (Test-HttpReachable "http://localhost:5000")
$frontendLive = (Test-Port 3000) -and (Test-HttpReachable "http://localhost:3000")
$chromeLive = ((Get-Process -Name "chrome" -ErrorAction SilentlyContinue | Where-Object { $_.Path -match "chrome.exe" }).Count -gt 0)
$wireguardLive = $false
$fkBridgeLive = $false

try {
    $wgService = Get-Service -Name "WireGuardTunnel*" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "Ecare|Eca|WireGuardTunnel" } |
        Select-Object -First 1

    if ($wgService) {
        $wireguardLive = ($wgService.Status -eq "Running")
    }
}
catch {}

try {
    $fkProcesses = Get-Process -Name "FKBridge" -ErrorAction SilentlyContinue
    if ($fkProcesses) {
        $fkBridgeLive = $true
    }
    elseif (Test-Path (Join-Path $FKBridgeDir "bin\Release\net8.0\FKBridge.exe")) {
        $fkBridgeLive = $true
    }
}
catch {}

$overallHealth = $backendLive -and $frontendLive -and $chromeLive -and $wireguardLive -and $fkBridgeLive

Log "Health checks: Backend= $backendLive | Frontend= $frontendLive | Chrome= $chromeLive | WireGuard= $wireguardLive | FKBridge= $fkBridgeLive"

if ($overallHealth) {
    Log "HEALTH CHECK PASS: backend, frontend, Chrome kiosk, WireGuard tunnel, and FKBridge are all active."
}
else {
    Log "HEALTH CHECK WARNING: not all runtime checks are green yet. This is not a final success state."
}

Log "============================================================"
Log "ECAFRICA STARTUP ATTEMPT COMPLETED."
Log "============================================================"