# ============================================================
# EcaAfrica - Setup-EcaAfrica.ps1
# One-time installation and configuration
# ============================================================

$ErrorActionPreference = "Continue"
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

$Global:SetupWarnings = @()
$Global:SetupErrors = @()

function Invoke-ResilientStep {
    param(
        [string]$StepName,
        [scriptblock]$Action,
        [bool]$Critical = $false
    )

    try {
        & $Action
        return $true
    }
    catch {
        $message = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] STEP FAILED: $StepName - $($_.Exception.Message)"
        Write-Host $message -ForegroundColor Yellow
        Add-Content -Path $LogFile -Value $message -ErrorAction SilentlyContinue

        if ($Critical) {
            $Global:SetupErrors += $StepName
            throw
        }

        $Global:SetupWarnings += $StepName
        return $false
    }
}

$EcaRoot       = "C:\EcaAfrica"
$ScriptsDir    = Join-Path $EcaRoot "scripts"
$LogsDir       = Join-Path $EcaRoot "logs"
$ChromeProfile = Join-Path $EcaRoot "chrome-profile"

$RepoUrl       = "https://github.com/Byiringiro24/Tablet_Setup.git"
$Branch        = "Testing-Branch"

$StartScriptSource = Join-Path $PSScriptRoot "Start-EcaAfrica.ps1"
$StartScriptTarget = Join-Path $ScriptsDir "Start-EcaAfrica.ps1"

$LogFile = Join-Path $LogsDir "Setup.log"

# ------------------------------------------------------------
# Logging and helpers
# ------------------------------------------------------------

function Write-Log {
    param(
        [string]$Message
    )

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$time] $Message"

    Write-Host $line

    try {
        Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
    }
    catch {}
}

function Write-Step {
    param(
        [string]$Message
    )

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Log $Message
}

function Ensure-Directory {
    param(
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Stop-StaleEcaAfricaProcesses {
    $processNames = @("FKBridge", "chrome", "node", "npm", "next")

    foreach ($name in $processNames) {
        try {
            $matching = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.Name -ieq $name -or
                    $_.CommandLine -match "C:\\EcaAfrica" -or
                    $_.CommandLine -match "FKBridge" -or
                    $_.CommandLine -match "next build" -or
                    $_.CommandLine -match "node.*server.js"
                }

            foreach ($proc in $matching) {
                try {
                    Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
                }
                catch {}
            }
        }
        catch {}
    }
}

# ------------------------------------------------------------
# Administrator check
# ------------------------------------------------------------

function Test-IsAdministrator {

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

if (-not (Test-IsAdministrator)) {

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "Administrator permission is required."
    Write-Host "Restarting setup as Administrator..."
    Write-Host "============================================================"
    Write-Host ""

    Start-Process powershell.exe `
        -Verb RunAs `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""

    exit
}

# ------------------------------------------------------------
# Create directories
# ------------------------------------------------------------

Write-Host ""
Write-Host "Creating EcaAfrica directories..." -ForegroundColor Cyan

New-Item -ItemType Directory -Path $EcaRoot -Force | Out-Null
New-Item -ItemType Directory -Path $ScriptsDir -Force | Out-Null
New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
New-Item -ItemType Directory -Path $ChromeProfile -Force | Out-Null

Write-Log "EcaAfrica directories created."

# ------------------------------------------------------------
# Refresh PATH
# ------------------------------------------------------------

function Update-PathEnvironment {

    $machinePath = [Environment]::GetEnvironmentVariable(
        "Path",
        "Machine"
    )

    $userPath = [Environment]::GetEnvironmentVariable(
        "Path",
        "User"
    )

    $env:Path = "$machinePath;$userPath"
}

Update-PathEnvironment

# ------------------------------------------------------------
# Add directory to PATH if missing
# ------------------------------------------------------------

function Add-ToMachinePath {

    param(
        [string]$PathToAdd
    )

    if (-not (Test-Path $PathToAdd)) {
        return
    }

    $current = [Environment]::GetEnvironmentVariable(
        "Path",
        "Machine"
    )

    $parts = $current -split ";" |
        Where-Object { $_ -and $_.Trim() }

    $exists = $parts |
        Where-Object {
            $_.Trim().TrimEnd("\") -ieq
            $PathToAdd.Trim().TrimEnd("\")
        }

    if (-not $exists) {

        Write-Log "Adding to machine PATH: $PathToAdd"

        [Environment]::SetEnvironmentVariable(
            "Path",
            (($parts + $PathToAdd) -join ";"),
            "Machine"
        )
    }
}

# ------------------------------------------------------------
# Known software locations
# ------------------------------------------------------------

$KnownGit = @(
    "C:\Program Files\Git\cmd\git.exe",
    "C:\Program Files\Git\bin\git.exe",
    "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe"
)

$KnownNode = @(
    "C:\Program Files\nodejs\node.exe",
    "$env:LOCALAPPDATA\Programs\nodejs\node.exe"
)

$KnownNpm = @(
    "C:\Program Files\nodejs\npm.cmd",
    "$env:LOCALAPPDATA\Programs\nodejs\npm.cmd"
)

$KnownChrome = @(
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)

# ------------------------------------------------------------
# Find executable
# ------------------------------------------------------------

function Find-Executable {

    param(
        [string[]]$KnownPaths,
        [string]$CommandName
    )

    foreach ($path in $KnownPaths) {

        if (-not $path) { continue }

        if (Test-Path $path) {
            return $path
        }
    }

    $searchRoots = @(
        $env:SystemRoot,
        $env:ProgramFiles,
        ${env:ProgramFiles(x86)},
        $env:LOCALAPPDATA,
        "C:\Program Files",
        "C:\Program Files (x86)",
        "$env:LOCALAPPDATA\Programs"
    )

    foreach ($root in $searchRoots) {
        if (-not $root) { continue }

        try {
            $candidate = Get-ChildItem -Path $root -Filter $CommandName -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1 -ExpandProperty FullName

            if ($candidate) {
                return $candidate
            }
        }
        catch {}
    }

    try {

        $cmd = Get-Command $CommandName -ErrorAction Stop

        if ($cmd.Path) {
            return $cmd.Path
        }
    }
    catch {}

    return $null
}

function Get-ExecutableVersion {
    param(
        [string]$Path,
        [string[]]$Arguments = @("--version")
    )

    if (-not $Path -or -not (Test-Path $Path)) {
        return $null
    }

    try {
        $output = & $Path @Arguments 2>&1 | Out-String

        if (-not $output) {
            $fileVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path).FileVersion
            if ($fileVersion) {
                return $fileVersion
            }
            return "unknown"
        }

        $text = $output.Trim()

        $versionMatch = [regex]::Match($text, '(\d+)[\.,](\d+)(?:[\.,](\d+))?')
        if ($versionMatch.Success) {
            $major = $versionMatch.Groups[1].Value
            $minor = $versionMatch.Groups[2].Value
            $patch = $versionMatch.Groups[3].Value

            if ($patch) {
                return "$major.$minor.$patch"
            }

            return "$major.$minor"
        }

        return $text.Split([Environment]::NewLine)[0].Trim()
    }
    catch {
        try {
            $fileVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path).FileVersion
            if ($fileVersion) {
                return $fileVersion
            }
        }
        catch {}

        return "unknown"
    }
}

function Resolve-DotNetSdkPath {
    $candidates = @(
        "C:\Program Files (x86)\dotnet\dotnet.exe",
        "${env:ProgramFiles(x86)}\dotnet\dotnet.exe",
        "C:\Program Files\dotnet\dotnet.exe",
        "$env:ProgramFiles\dotnet\dotnet.exe",
        "$env:LOCALAPPDATA\Microsoft\dotnet\dotnet.exe"
    )

    foreach ($candidate in $candidates) {
        if (-not (Test-Path $candidate)) { continue }

        try {
            $sdkOutput = & $candidate --list-sdks 2>$null | Out-String
            if ($sdkOutput -match '\d+\.\d+') {
                $archHint = $candidate.ToLower()
                if ($archHint.Contains('program files (x86)') -or $archHint.Contains('x86')) {
                    return $candidate
                }
                return $candidate
            }
        }
        catch {}
    }

    try {
        $found = Get-ChildItem -Path "C:\Program Files (x86)", "C:\Program Files", "$env:LOCALAPPDATA" -Filter "dotnet.exe" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName

        if ($found) { return $found }
    }
    catch {}

    return "C:\Program Files (x86)\dotnet\dotnet.exe"
}

function Resolve-DotNetX86Path {
    $candidates = @(
        "C:\Program Files (x86)\dotnet\dotnet.exe",
        "${env:ProgramFiles(x86)}\dotnet\dotnet.exe",
        "C:\Program Files\dotnet\dotnet.exe",
        "$env:ProgramFiles\dotnet\dotnet.exe"
    )

    foreach ($candidate in $candidates) {
        if (-not (Test-Path $candidate)) { continue }

        try {
            $sdkOutput = & $candidate --list-sdks 2>&1 | Out-String
            if ($sdkOutput -match '\d+\.\d+') {
                $lower = $candidate.ToLower()
                if ($lower.Contains('program files (x86)') -or $lower.Contains('x86')) {
                    return $candidate
                }
            }
        }
        catch {}
    }

    return $null
}

function Install-DotNetX86Sdk {
    param(
        [string]$RootPath = "C:\EcaAfrica"
    )

    $installerFiles = @(
        "dotnet-sdk-10.0.401-win-x86.exe",
        "dotnet-sdk-10-win-x86.exe",
        "dotnet-sdk-win-x86.exe"
    )

    foreach ($installerName in $installerFiles) {
        $candidate = Join-Path $RootPath $installerName
        if (Test-Path $candidate) {
            Write-Log "Found local .NET x86 SDK installer: $candidate"
            try {
                $proc = Start-Process -FilePath $candidate -ArgumentList "/quiet /norestart /install" -Wait -PassThru
                if ($proc -and ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010)) {
                    return $true
                }
            }
            catch {
                Write-Log "Local .NET x86 installer failed: $($_.Exception.Message)"
            }
        }
    }

    $downloadUrl = "https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.401/dotnet-sdk-10.0.401-win-x86.exe"
    $localInstaller = Join-Path $RootPath "dotnet-sdk-10.0.401-win-x86.exe"

    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $localInstaller -UseBasicParsing -TimeoutSec 180 | Out-Null
        if (Test-Path $localInstaller) {
            Write-Log "Downloaded .NET x86 SDK installer to $localInstaller"
            $proc = Start-Process -FilePath $localInstaller -ArgumentList "/quiet /norestart /install" -Wait -PassThru
            if ($proc -and ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010)) {
                return $true
            }
        }
    }
    catch {
        Write-Log "Automatic .NET x86 SDK download failed: $($_.Exception.Message)"
    }

    return $false
}

function Test-MinimumNodeVersion {
    param(
        [string]$NodePath,
        [int]$MinimumMajor = 18
    )

    if (-not $NodePath -or -not (Test-Path $NodePath)) {
        return $false
    }

    $version = Get-ExecutableVersion $NodePath @("--version")

    if (-not $version -or $version -eq "unknown") {
        return $false
    }

    if ($version -match "v?(\d+)") {
        return [int]$Matches[1] -ge $MinimumMajor
    }

    return $false
}

function Test-NodeMajorSupported {
    param(
        [string]$NodePath,
        [int[]]$SupportedMajors = @(18, 20, 22)
    )

    if (-not $NodePath -or -not (Test-Path $NodePath)) {
        return $false
    }

    $version = Get-ExecutableVersion $NodePath @("--version")
    if (-not $version -or $version -eq "unknown") {
        return $false
    }

    if ($version -match "v?(\d+)") {
        $major = [int]$Matches[1]
        return $SupportedMajors -contains $major
    }

    return $false
}

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

function Test-WindowsVersion {
    $osVersion = [System.Environment]::OSVersion.Version
    return $osVersion.Major -ge 10
}

# ------------------------------------------------------------
# Install with winget
# ------------------------------------------------------------

function Install-WingetPackage {

    param(
        [string]$Id,
        [string]$Name,
        [string]$Architecture = ""
    )

    Write-Host ""
    Write-Host "Checking $Name..." -ForegroundColor Cyan

    $wingetCmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $wingetCmd) {
        $fallbackWinget = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
        if (Test-Path $fallbackWinget) {
            $wingetCmd = $fallbackWinget
        }
    }

    if (-not $wingetCmd) {
        Write-Log "WARNING: winget is not available for $Name. Skipping installation."
        return $false
    }

    $args = @("install", "--id", $Id, "--exact", "--silent", "--accept-package-agreements", "--accept-source-agreements")
    if ($Architecture) {
        $args += @("--architecture", $Architecture)
    }

    try {
        & $wingetCmd @args
        $code = $LASTEXITCODE
        Update-PathEnvironment
        return ($code -eq 0)
    }
    catch {
        Write-Log "WARNING: winget install failed for ${Name}: $($_.Exception.Message)"
        return $false
    }
}

# ------------------------------------------------------------
# Windows version check
# ------------------------------------------------------------

if (-not (Test-WindowsVersion)) {
    Write-Log "WARNING: Windows 10 or newer is required. Current OS: $([System.Environment]::OSVersion.Version)"
    Write-Log "Continuing with best-effort compatibility checks. Some features may be unavailable."
}
else {
    Write-Log "Windows version verified: $([System.Environment]::OSVersion.Version)"
}

# ------------------------------------------------------------
# Check winget
# ------------------------------------------------------------

$Winget = Get-Command winget.exe -ErrorAction SilentlyContinue

if (-not $Winget) {

    Write-Log "WARNING: winget was not found."
    Write-Host ""
    Write-Host "Windows Package Manager (winget) was not found." -ForegroundColor Yellow
    Write-Host "Please install/update App Installer from Microsoft Store." -ForegroundColor Yellow
    Write-Host ""

}
else {

    Write-Log "winget found."
}

# ------------------------------------------------------------
# Git
# ------------------------------------------------------------

$Git = Find-Executable $KnownGit "git.exe"

if (-not $Git) {

    Write-Log "Git not found. Installing Git..."

    if ($Winget) {
        try {
            Install-WingetPackage `
                -Id "Git.Git" `
                -Name "Git"
        }
        catch {
            Write-Log "Git installation failed: $($_.Exception.Message)"
        }
    }

    Update-PathEnvironment

    $Git = Find-Executable $KnownGit "git.exe"
}

if (-not $Git) {
    Write-Log "WARNING: Git could not be installed or located. Git features will be skipped."
}
else {
    Add-ToMachinePath (Split-Path $Git)

    $GitVersion = Get-ExecutableVersion $Git @("--version")
    Write-Log "Git: $Git | version: $GitVersion"
}

# ------------------------------------------------------------
# Node.js
# ------------------------------------------------------------

$Node = Find-Executable $KnownNode "node.exe"

if (-not $Node) {
    $fallbackNode = @(
        "$env:ProgramFiles\nodejs\node.exe",
        "${env:ProgramFiles(x86)}\nodejs\node.exe",
        "$env:LOCALAPPDATA\Programs\nodejs\node.exe"
    )

    foreach ($candidate in $fallbackNode) {
        if (Test-Path $candidate) {
            $Node = $candidate
            break
        }
    }
}

if (-not $Node) {

    Write-Log "Node.js not found. Installing Node.js LTS..."

    if ($Winget) {
        try {
            Install-WingetPackage `
                -Id "OpenJS.NodeJS.LTS" `
                -Name "Node.js LTS"
        }
        catch {
            Write-Log "Node.js installation failed: $($_.Exception.Message)"
        }
    }

    Update-PathEnvironment

    $Node = Find-Executable $KnownNode "node.exe"
}

if (-not $Node) {
    Write-Log "WARNING: Node.js could not be installed or located. JavaScript steps will be skipped."
}
else {
    Add-ToMachinePath (Split-Path $Node)

    $NodeVersion = Get-ExecutableVersion $Node @("--version")
    Write-Log "Node.js: $Node | version: $NodeVersion"

    if (-not (Test-MinimumNodeVersion $Node 18)) {
        Write-Log "WARNING: Node.js version is below the recommended 18.x minimum. Installing LTS if available."
        if ($Winget) {
            try {
                Install-WingetPackage -Id "OpenJS.NodeJS.LTS" -Name "Node.js LTS"
                $Node = Find-Executable $KnownNode "node.exe"
                if ($Node) {
                    $NodeVersion = Get-ExecutableVersion $Node @("--version")
                    Write-Log "Updated Node.js version: $NodeVersion"
                }
            }
            catch {
                Write-Log "Node.js version repair failed: $($_.Exception.Message)"
            }
        }
    }

    if (-not (Test-NodeMajorSupported $Node @(18, 20, 22))) {
        Write-Log "WARNING: Node.js major version is outside the supported tablet LTS range (18/20/22). Best-effort startup will continue but LTS is recommended."
    }
}

# ------------------------------------------------------------
# npm
# ------------------------------------------------------------

$Npm = Find-Executable $KnownNpm "npm.cmd"

if (-not $Npm) {

    if ($Node) {
        $nodeDirectory = Split-Path $Node

        $possibleNpm = @(
            (Join-Path $nodeDirectory "npm.cmd"),
            (Join-Path $nodeDirectory "npx.cmd"),
            "$env:ProgramFiles\nodejs\npm.cmd",
            "${env:ProgramFiles(x86)}\nodejs\npm.cmd",
            "$env:LOCALAPPDATA\Programs\nodejs\npm.cmd"
        )

        foreach ($candidate in $possibleNpm) {
            if (Test-Path $candidate) {
                $Npm = $candidate
                break
            }
        }
    }
}

if (-not $Npm) {
    Write-Log "WARNING: npm.cmd could not be located. npm operations will be skipped."
}
else {
    Write-Log "npm: $Npm"
}

# ------------------------------------------------------------
# Chrome
# ------------------------------------------------------------

$Chrome = Find-Executable $KnownChrome "chrome.exe"

if (-not $Chrome) {

    Write-Log "Google Chrome not found."

    if ($Winget) {
        try {
            Install-WingetPackage `
                -Id "Google.Chrome" `
                -Name "Google Chrome"
        }
        catch {
            Write-Log "Chrome installation failed: $($_.Exception.Message)"
        }
    }

    Update-PathEnvironment

    $Chrome = Find-Executable $KnownChrome "chrome.exe"
}

if (-not $Chrome) {
    Write-Log "WARNING: Google Chrome could not be installed or located. Browser launch will be skipped."
}
else {
    Write-Log "Chrome: $Chrome"
}

# ------------------------------------------------------------
# WireGuard
# ------------------------------------------------------------

$WireGuardExe = @(
    "C:\Program Files\WireGuard\wireguard.exe",
    "C:\Program Files (x86)\WireGuard\wireguard.exe",
    "$env:ProgramFiles\WireGuard\wireguard.exe",
    "${env:ProgramFiles(x86)}\WireGuard\wireguard.exe"
)

$WireGuard = Find-Executable $WireGuardExe "wireguard.exe"

if (-not $WireGuard) {

    Write-Log "WireGuard not found."

    if ($Winget) {

        Install-WingetPackage `
            -Id "WireGuard.WireGuard" `
            -Name "WireGuard"
    }

    Update-PathEnvironment

    $WireGuard = Find-Executable $WireGuardExe "wireguard.exe"
}

if ($WireGuard) {
    $wireguardVersion = Get-ExecutableVersion $WireGuard
    Write-Log "WireGuard: $WireGuard | version: $wireguardVersion"
}
else {

    Write-Log "WARNING: WireGuard was not located."
}

# ------------------------------------------------------------
# .NET x86
# ------------------------------------------------------------

Write-Host ""
Write-Host "Checking .NET x86 SDK (8/10)..." -ForegroundColor Cyan

$DotNetX86 = Resolve-DotNetX86Path

if (-not (Test-Path $DotNetX86) -or -not (Test-MinimumDotNetSdk $DotNetX86 8)) {

    Write-Log ".NET x86 SDK not found or below supported minimum. Installing .NET SDK 10 x86 if needed."

    if ($Winget) {
        try {
            Install-WingetPackage `
                -Id "Microsoft.DotNet.SDK.10" `
                -Name ".NET 10 SDK x86" `
                -Architecture "x86"
        }
        catch {
            Write-Log ".NET installation failed: $($_.Exception.Message)"
        }
    }

    $installSucceeded = Install-DotNetX86Sdk -RootPath $EcaRoot
    if ($installSucceeded) {
        Write-Log ".NET x86 SDK installation attempted successfully."
    }

    $DotNetX86 = Resolve-DotNetX86Path
    Update-PathEnvironment
}

if (-not (Test-Path $DotNetX86)) {
    Write-Log "WARNING: .NET x86 SDK was not found. FKBridge build will be skipped."
}
else {
    $DotNetVersion = Get-ExecutableVersion $DotNetX86 @("--list-sdks")
    Write-Log ".NET x86: $DotNetX86 | versions: $DotNetVersion"

    if (-not (Test-MinimumDotNetSdk $DotNetX86 8)) {
        Write-Log "WARNING: .NET x86 SDK is not installed or is below the expected minimum. Retrying detection after repair."

        try {
            $sdkOutput = & $DotNetX86 --list-sdks 2>&1 | Out-String
            if ($sdkOutput -match '(\d+)[\.,](\d+)') {
                $sdkMajor = [int]$Matches[1]
                if ($sdkMajor -ge 8) {
                    Write-Log ".NET x86 SDK recovered and verified after repair."
                }
            }
        }
        catch {
            Write-Log "Automatic .NET verification retry failed. Setup will continue in best-effort mode."
        }
    }
}

# ------------------------------------------------------------
# .NET x86 verification
# ------------------------------------------------------------

try {

    if (Test-Path $DotNetX86) {
        $sdkOutput = & $DotNetX86 --list-sdks 2>&1

        if ($sdkOutput -match "^(8|10)\.") {
            Write-Log ".NET x86 SDK verified (8.x/10.x)."
        }
        else {
            Write-Log "WARNING: .NET x86 SDK was not detected, but the installer will continue with best-effort setup."
        }
    }
    else {
        Write-Log "WARNING: .NET x86 path is unavailable; skip verification and continue best-effort."
    }
}
catch {

    Write-Log "WARNING: The x86 .NET SDK could not be verified, but setup will continue."
}

# ------------------------------------------------------------
# Firewall rule
# ------------------------------------------------------------

Write-Host ""
Write-Host "Configuring Windows Firewall..." -ForegroundColor Cyan

$FirewallName = "EcaAfrica Device 5005"

$existingFirewall = Get-NetFirewallRule `
    -DisplayName $FirewallName `
    -ErrorAction SilentlyContinue

if (-not $existingFirewall) {

    New-NetFirewallRule `
        -DisplayName $FirewallName `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 5005 `
        -Action Allow `
        -Profile Any `
        -Description "Allow EcaAfrica biometric device communication on TCP port 5005."

    Write-Log "Firewall rule created: TCP 5005"
}
else {

    Write-Log "Firewall rule already exists: TCP 5005"
}

# ------------------------------------------------------------
# WireGuard automatic startup
# ------------------------------------------------------------

Write-Host ""
Write-Host "Configuring WireGuard..." -ForegroundColor Cyan

$WireGuardServicePattern = "WireGuardTunnel*"

$wgServices = Get-Service `
    -Name $WireGuardServicePattern `
    -ErrorAction SilentlyContinue

if ($wgServices) {

    foreach ($service in $wgServices) {

        try {

            Set-Service `
                -Name $service.Name `
                -StartupType Automatic

            Write-Log "WireGuard service set to Automatic: $($service.Name)"

            if ($service.Status -ne "Running") {

                Start-Service `
                    -Name $service.Name `
                    -ErrorAction SilentlyContinue

                Write-Log "Started WireGuard service: $($service.Name)"
            }
        }
        catch {

            Write-Log "Could not automatically start WireGuard service: $($service.Name)"
        }
    }
}
else {

    Write-Log "No WireGuard tunnel service found yet."
    Write-Log "If the tunnel is imported later, its tunnel service must also be set to Automatic."
}

# ------------------------------------------------------------
# Clone / update repository
# ------------------------------------------------------------

$RepoDir = Join-Path $EcaRoot "Tablet_Setup"

if ($Git) {
    if (Test-Path $RepoDir) {

        if (Test-Path (Join-Path $RepoDir ".git")) {

            Write-Host ""
            Write-Host "Repository already exists and is valid." -ForegroundColor Cyan

            Push-Location $RepoDir

            try {
                & $Git fetch origin

                if ($LASTEXITCODE -ne 0) {
                    Write-Log "Git fetch failed on existing repo; continuing with local copy."
                }
                else {
                    & $Git checkout $Branch

                    if ($LASTEXITCODE -ne 0) {
                        Write-Log "Branch checkout failed. Trying to create or reset branch."
                        & $Git checkout -B $Branch "origin/$Branch"
                    }

                    & $Git reset --hard "origin/$Branch"

                    if ($LASTEXITCODE -ne 0) {
                        Write-Log "Hard reset failed. Continuing with local repo state."
                    }
                }
            }
            catch {
                Write-Log "Repository update failed: $($_.Exception.Message)"
            }
            finally {
                Pop-Location
            }
        }
        else {

            Write-Host ""
            Write-Host "Found an existing folder but not a valid Git repository. Repairing it..." -ForegroundColor Yellow

            $backupRepoDir = "$RepoDir-backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
            try {
                Rename-Item -Path $RepoDir -NewName (Split-Path $backupRepoDir -Leaf)
                Write-Log "Moved stale repo folder to $backupRepoDir"

                & $Git clone `
                    --branch $Branch `
                    --single-branch `
                    $RepoUrl `
                    $RepoDir

                if ($LASTEXITCODE -ne 0) {
                    Write-Log "Git clone failed after repairing stale repository folder."
                    Write-Host ""
                    Write-Host "Repository download failed. You can clone the repo manually into: $RepoDir" -ForegroundColor Yellow
                    Write-Host "Then rerun this script and it will continue from the downloaded repo." -ForegroundColor Yellow
                    Write-Host "GitHub: $RepoUrl" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Log "Repair clone failed: $($_.Exception.Message)"
                Write-Host ""
                Write-Host "Repository repair failed. You can download the repo manually to: $RepoDir" -ForegroundColor Yellow
                Write-Host "Then rerun this script to continue automatically." -ForegroundColor Yellow
            }
        }
    }
    else {

        Write-Host ""
        Write-Host "Cloning EcaAfrica repository..." -ForegroundColor Cyan

        try {
            & $Git clone `
                --branch $Branch `
                --single-branch `
                $RepoUrl `
                $RepoDir

            if ($LASTEXITCODE -ne 0) {
                Write-Log "Git clone failed. The installer will continue with local setup if the repo folder already exists."
                Write-Host ""
                Write-Host "Clone failed. You can download the repo manually to: $RepoDir" -ForegroundColor Yellow
                Write-Host "Then run this script again and it will continue." -ForegroundColor Yellow
                Write-Host "GitHub: $RepoUrl" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Log "Git clone error: $($_.Exception.Message)"
            Write-Host ""
            Write-Host "Repository could not be downloaded automatically." -ForegroundColor Yellow
            Write-Host "Download it manually to $RepoDir, then rerun the setup script." -ForegroundColor Yellow
            Write-Host "GitHub: $RepoUrl" -ForegroundColor Yellow
        }
    }
}
else {
    Write-Log "WARNING: Git is unavailable, so repository sync and update checks are skipped."
    Write-Host ""
    Write-Host "Git is not available. Download the repo manually into C:\EcaAfrica\Tablet_Setup and rerun the script." -ForegroundColor Yellow
}

# ------------------------------------------------------------
# Expected application directories
# ------------------------------------------------------------

$BackendDir = Join-Path $EcaRoot "backend"
$FrontendDir = Join-Path $EcaRoot "frontend"
$FKBridgeDir = Join-Path $EcaRoot "FKBridge"

Ensure-Directory $BackendDir
Ensure-Directory $FrontendDir
Ensure-Directory $FKBridgeDir

# If repository contains these directories, use them.
if (Test-Path (Join-Path $RepoDir "backend")) {
    Copy-Item `
        (Join-Path $RepoDir "backend\*") `
        $BackendDir `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue
}

if (Test-Path (Join-Path $RepoDir "frontend")) {
    Copy-Item `
        (Join-Path $RepoDir "frontend\*") `
        $FrontendDir `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue
}

if (Test-Path (Join-Path $RepoDir "FKBridge")) {
    Copy-Item `
        (Join-Path $RepoDir "FKBridge\*") `
        $FKBridgeDir `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue
}

foreach ($appName in @("backend", "frontend", "FKBridge")) {
    $duplicateAppDir = Join-Path $RepoDir $appName
    if (Test-Path $duplicateAppDir) {
        Write-Log "Removing duplicate runtime folder to keep only C:\EcaAfrica\$appName"
        Remove-Item $duplicateAppDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ------------------------------------------------------------
# Copy startup script
# ------------------------------------------------------------

if (Test-Path $StartScriptSource) {

    Copy-Item `
        $StartScriptSource `
        $StartScriptTarget `
        -Force

    Write-Log "Start-EcaAfrica.ps1 installed."
}
else {

    Write-Log "WARNING: Start-EcaAfrica.ps1 was not found beside setup script."
    Write-Host ""
    Write-Host "Place Start-EcaAfrica.ps1 in the same EcaAfrica-Setup folder." -ForegroundColor Yellow
}

# ------------------------------------------------------------
# Device configuration
# ------------------------------------------------------------

$DeviceConfig = Join-Path $EcaRoot "device-config.json"

if (-not (Test-Path $DeviceConfig)) {

@'
{
  "ipAddress": "192.168.1.76",
  "port": 5005,
  "license": 1261,
  "deviceId": "DV-KGL-01",
  "netPassword": 0,
  "protocolType": -1,
  "timeoutMs": 10000
}
'@ | Set-Content `
    -Path $DeviceConfig `
    -Encoding UTF8

    Write-Log "Created device-config.json"
}
else {

    Write-Log "Existing device-config.json preserved."
}

# ------------------------------------------------------------
# Backend .env
# ------------------------------------------------------------

$BackendEnv = Join-Path $BackendDir ".env"

if (-not (Test-Path $BackendEnv)) {

@'
PORT=5000
SERVER_API_URL=https://backend.ecareafrica.net/api/v1
TABLET_UUID=
WG_SERVER_ENDPOINT=169.58.124.150:51820
VPN_ALLOWED_IPS=10.0.0.0/16
WG_DNS=1.1.1.1
'@ | Set-Content `
    -Path $BackendEnv `
    -Encoding UTF8

    Write-Log "Created backend .env"
}
else {

    Write-Log "Existing backend .env preserved."
}

# ------------------------------------------------------------
# Frontend .env.local
# ------------------------------------------------------------

$FrontendEnv = Join-Path $FrontendDir ".env.local"

if (-not (Test-Path $FrontendEnv)) {

@'
NEXT_PUBLIC_API_URL=http://localhost:5000
'@ | Set-Content `
    -Path $FrontendEnv `
    -Encoding UTF8

    Write-Log "Created frontend .env.local"
}
else {

    Write-Log "Existing frontend .env.local preserved."
}

# ------------------------------------------------------------
# npm install helper
# ------------------------------------------------------------

function Install-NpmDependencies {

    param(
        [string]$Directory
    )

    if (-not $Npm) {
        throw "npm is not available."
    }

    if (-not (Test-Path (Join-Path $Directory "package.json"))) {

        Write-Log "No package.json found in $Directory"
        return
    }

    $nodeModules = Join-Path $Directory "node_modules"
    $packageLock = Join-Path $Directory "package-lock.json"

    Push-Location $Directory

    Write-Log "Installing npm dependencies in $Directory"

    try {
        Stop-StaleEcaAfricaProcesses
        Get-Process -Name "node","chrome","npm","next" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    catch {}

    if (Test-Path $nodeModules) {
        Remove-Item $nodeModules -Recurse -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path $packageLock) {
        Remove-Item $packageLock -Force -ErrorAction SilentlyContinue
    }

    $installAttempts = @(
        @("install", "--legacy-peer-deps", "--no-audit", "--no-fund"),
        @("install", "--legacy-peer-deps", "--force", "--no-audit", "--no-fund"),
        @("install", "--legacy-peer-deps", "--force", "--no-audit", "--no-fund", "--prefer-offline")
    )

    $installSucceeded = $false
    foreach ($args in $installAttempts) {
        try {
            & $Npm @args
            if ($LASTEXITCODE -eq 0) {
                $installSucceeded = $true
                break
            }
            Write-Log "npm install retry with fallback flags failed (exit $LASTEXITCODE)."
        }
        catch {
            Write-Log "npm install attempt failed: $($_.Exception.Message)"
        }
    }

    if (-not $installSucceeded) {
        Pop-Location
        throw "npm dependency installation failed in $Directory"
    }

    Pop-Location
}

# ------------------------------------------------------------
# Install backend/frontend dependencies
# ------------------------------------------------------------

if ($Npm) {
    try {
        Install-NpmDependencies $BackendDir
    }
    catch {
        Write-Log "Backend npm install failed but setup continues: $($_.Exception.Message)"
    }

    try {
        Install-NpmDependencies $FrontendDir
    }
    catch {
        Write-Log "Frontend npm install failed but setup continues: $($_.Exception.Message)"
    }
}
else {
    Write-Log "WARNING: npm is unavailable. Dependency installation was skipped."
}

# ------------------------------------------------------------
# Build FKBridge
# ------------------------------------------------------------

$FKProject = Get-ChildItem `
    -Path $FKBridgeDir `
    -Filter "*.csproj" `
    -Recurse `
    -ErrorAction SilentlyContinue |
    Select-Object -First 1

if ($FKProject -and (Test-Path $DotNetX86)) {

    Write-Host ""
    Write-Host "Building FKBridge using .NET x86..." -ForegroundColor Cyan

    try {
        Stop-StaleEcaAfricaProcesses
        Push-Location $FKProject.Directory.FullName

        & $DotNetX86 restore $FKProject.FullName

        if ($LASTEXITCODE -ne 0) {
            throw "FKBridge restore failed."
        }

        & $DotNetX86 build `
            $FKProject.FullName `
            -c Release `
            --no-restore

        if ($LASTEXITCODE -ne 0) {
            throw "FKBridge build failed."
        }

        Pop-Location

        Write-Log "FKBridge build completed."
    }
    catch {
        if ($null -ne (Get-Location)) {
            try { Pop-Location } catch {}
        }
        Write-Log "WARNING: FKBridge build failed but setup continues: $($_.Exception.Message)"
    }
}
else {

    Write-Log "WARNING: FKBridge .csproj was not found or .NET x86 is not available."
}

# ------------------------------------------------------------
# Build frontend
# ------------------------------------------------------------

function Clear-FrontendBuildCache {
    param(
        [string]$Directory
    )

    try {
        Stop-StaleEcaAfricaProcesses
        Get-Process -Name "node","chrome","npm","next" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    catch {}

    Start-Sleep -Seconds 2

    $nextDir = Join-Path $Directory ".next"
    $standaloneDir = Join-Path $nextDir "standalone"

    foreach ($path in @($standaloneDir, $nextDir)) {
        if (Test-Path $path) {
            try {
                cmd /c "rmdir /s /q `"$path`"" 2>$null | Out-Null
                Start-Sleep -Seconds 1
            }
            catch {}
            try {
                Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
            }
            catch {}
        }
    }

    foreach ($cacheFile in @("next-env.d.ts", "tsconfig.tsbuildinfo")) {
        $p = Join-Path $Directory $cacheFile
        if (Test-Path $p) {
            Remove-Item $p -Force -ErrorAction SilentlyContinue
        }
    }

    if (Test-Path $nextDir) {
        Write-Log "WARNING: frontend .next cache could not be fully cleared; build will continue in best-effort mode."
    }
    else {
        Write-Log "Removed stale frontend .next cache."
    }
}

if ((Test-Path (Join-Path $FrontendDir "package.json")) -and $Npm) {

    $frontendPortLive = Test-PortOpen -Port 3000
    $frontendHttpLive = Test-HttpReachable "http://localhost:3000" 8

    if ($frontendPortLive -and $frontendHttpLive) {
        Write-Log "Frontend already running on port 3000; skipping redundant build and install." 
    }
    else {
        try {
            Push-Location $FrontendDir

            Write-Host ""
            Write-Host "Building frontend..." -ForegroundColor Cyan

            Stop-StaleEcaAfricaProcesses
            Get-Process -Name "node","chrome","npm","next" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

            Clear-FrontendBuildCache $FrontendDir

            & $Npm run build

        if ($LASTEXITCODE -ne 0) {

            Write-Log "Frontend build failed. Reinstalling dependencies and clearing cache."
            Clear-FrontendBuildCache $FrontendDir
            & $Npm install --legacy-peer-deps --no-audit --no-fund
            & $Npm run build
        }

            if ($LASTEXITCODE -ne 0) {
                throw "Frontend build failed."
            }

            Pop-Location

            Write-Log "Frontend build completed."
        }
        catch {
            try { Pop-Location } catch {}
            Write-Log "WARNING: Frontend build failed but setup continues: $($_.Exception.Message)"
        }
    }
}

# ------------------------------------------------------------
# Scheduled Task
# ------------------------------------------------------------

Write-Host ""
Write-Host "Creating EcaAfrica startup task..." -ForegroundColor Cyan

$TaskName = "EcaAfrica Kiosk"

$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Write-Log "Scheduled task already exists: $TaskName. Updating it without duplicating the task."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
}

$PowerShellPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$StartScriptTarget`""

$Action = New-ScheduledTaskAction `
    -Execute $PowerShellPath `
    -Argument $Arguments `
    -WorkingDirectory $EcaRoot

$LogOnTrigger = New-ScheduledTaskTrigger `
    -AtLogOn `
    -User $CurrentUser

$StartupTrigger = New-ScheduledTaskTrigger `
    -AtStartup

$Principal = New-ScheduledTaskPrincipal `
    -UserId $CurrentUser `
    -LogonType Interactive `
    -RunLevel Highest

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -MultipleInstances IgnoreNew

try {
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $Action `
        -Trigger @($LogOnTrigger, $StartupTrigger) `
        -Principal $Principal `
        -Settings $Settings `
        -Force | Out-Null

    Write-Log "Scheduled task created: $TaskName"
}
catch {
    Write-Log "WARNING: scheduled task registration failed. Best-effort setup will continue; startup can still be launched manually: $($_.Exception.Message)"
}

# ------------------------------------------------------------
# Runtime health validation
# ------------------------------------------------------------

function Test-PortOpen {
    param(
        [int]$Port,
        [string]$TargetHost = "localhost",
        [int]$TimeoutMs = 1500
    )

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $result = $client.BeginConnect($TargetHost, $Port, $null, $null)
        $wait = $result.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if ($wait -and $client.Connected) {
            $client.EndConnect($result)
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
    finally {
        try { $client.Close() } catch {}
    }
}

function Test-HttpReachable {
    param(
        [string]$Uri,
        [int]$TimeoutSeconds = 8
    )

    try {
        $handler = New-Object System.Net.Http.HttpClient
        $handler.Timeout = [System.TimeSpan]::FromSeconds($TimeoutSeconds)
        $response = $handler.GetAsync($Uri).GetAwaiter().GetResult()
        return ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500)
    }
    catch {
        return $false
    }
}

$HealthBackend = (Test-PortOpen -Port 5000)
$HealthFrontend = (Test-PortOpen -Port 3000)
$HealthChrome = ((Get-Process -Name "chrome" -ErrorAction SilentlyContinue).Count -gt 0)
$HealthWireGuard = $false
$HealthFKBridge = $false

try {
    $wireguardService = Get-Service -Name "WireGuardTunnel*" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "Ecare|Eca|WireGuardTunnel" } |
        Select-Object -First 1

    if ($wireguardService) {
        $HealthWireGuard = ($wireguardService.Status -eq "Running")
    }
}
catch {
    $HealthWireGuard = $false
}

try {
    $fkBridgeProcess = Get-Process -Name "FKBridge" -ErrorAction SilentlyContinue
    if ($fkBridgeProcess) {
        $HealthFKBridge = $true
    }
}
catch {
    $HealthFKBridge = $false
}

$HealthBackend = $HealthBackend -and (Test-HttpReachable "http://localhost:5000" 8)
$HealthFrontend = $HealthFrontend -and (Test-HttpReachable "http://localhost:3000" 8)

$SetupHealthSummary = @(
    "Backend 5000: $HealthBackend",
    "Frontend 3000: $HealthFrontend",
    "Chrome kiosk: $HealthChrome",
    "WireGuard tunnel: $HealthWireGuard",
    "FKBridge running: $HealthFKBridge"
)

Write-Host ""
Write-Host "Checking live service health..." -ForegroundColor Cyan
$SetupHealthSummary | ForEach-Object { Write-Host "  $_" }

$HealthFailures = @(
    $HealthBackend,
    $HealthFrontend,
    $HealthChrome,
    $HealthWireGuard,
    $HealthFKBridge
) | Where-Object { $_ -eq $false }

Write-Host ""
Write-Host "============================================================"
if ($HealthFailures.Count -eq 0) {
    Write-Host "              EcaAfrica SETUP COMPLETED AND VERIFIED"
}
else {
    Write-Host "        EcaAfrica CONFIGURATION READY, RUNTIME CHECKS STILL PENDING"
}
Write-Host "============================================================"
Write-Host ""

Write-Host "EcaAfrica root:"
Write-Host "  $EcaRoot"

Write-Host ""
Write-Host "Scripts:"
Write-Host "  $ScriptsDir"

Write-Host ""
Write-Host "Startup script:"
Write-Host "  $StartScriptTarget"

Write-Host ""
Write-Host "Firewall:"
Write-Host "  TCP 5005 allowed"

Write-Host ""
Write-Host "Scheduled Task:"
Write-Host "  $TaskName"

Write-Host ""
Write-Host "Next step:"
Write-Host "  Restart the tablet or run Start-EcaAfrica.ps1 after login."

Write-Host ""
Write-Host "After login:"
Write-Host "  WireGuard -> FKBridge -> Backend -> Frontend -> Chrome"

Write-Host ""
Write-Host "Setup log:"
Write-Host "  $LogFile"

if ($HealthFailures.Count -gt 0) {
    Write-Host ""
    Write-Host "Health-check warnings:" -ForegroundColor Yellow
    Write-Host "  The application is configured, but the live runtime checks are not all green yet."
    Write-Host "  Run Start-EcaAfrica.ps1 after login to check and repair the startup sequence." -ForegroundColor Yellow
    Write-Host "  Device/network unreachable is treated as a warning, not a fatal setup failure." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================================"

if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected -and -not $env:NO_PROMPT) {
    Read-Host "Press ENTER to finish"
}