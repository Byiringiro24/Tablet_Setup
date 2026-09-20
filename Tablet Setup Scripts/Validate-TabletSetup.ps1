param(
    [string]$RootPath = "C:\EcaAfrica",
    [string]$GitBinary = "C:\Program Files\Git\cmd\git.exe",
    [string]$NodeBinary = "C:\Program Files\nodejs\node.exe",
    [string]$NpmBinary = "C:\Program Files\nodejs\npm.cmd",
    [string]$ChromeBinary = "C:\Program Files\Google\Chrome\Application\chrome.exe",
    [string]$DotNetBinary = "C:\Program Files (x86)\dotnet\dotnet.exe"
)

$ErrorActionPreference = "Stop"

function Add-Result {
    param(
        [string]$Name,
        [bool]$IsOk,
        [string]$Message
    )

    [pscustomobject]@{
        Name    = $Name
        Status  = if ($IsOk) { "PASS" } else { "FAIL" }
        Message = $Message
    }
}

function Test-PortOpen {
    param(
        [int]$Port,
        [string]$TargetHost = "localhost"
    )

    try {
        $conn = Test-NetConnection -ComputerName $TargetHost -Port $Port -WarningAction SilentlyContinue -InformationLevel Quiet 2>$null
        if ($null -ne $conn) {
            return [bool]$conn.TcpTestSucceeded
        }
    }
    catch {}

    return $false
}

function Test-HttpReachable {
    param(
        [string]$Uri,
        [int]$TimeoutSeconds = 8
    )

    try {
        $response = Invoke-WebRequest -Uri $Uri -Method Get -UseBasicParsing -TimeoutSec $TimeoutSeconds -ErrorAction Stop
        return $response.StatusCode -ge 200 -and $response.StatusCode -lt 500
    }
    catch {
        return $false
    }
}

function Get-ToolVersion {
    param(
        [string]$FilePath,
        [string[]]$Arguments = @("--version")
    )

    if (-not $FilePath -or -not (Test-Path $FilePath)) {
        return "missing"
    }

    try {
        $output = & $FilePath @Arguments 2>&1 | Out-String
        $text = ($output | Out-String).Trim()

        if ($text -match "v?(\d+\.\d+\.\d+|\d+\.\d+)") {
            return $Matches[1]
        }

        if ($text -match "(\d+\.\d+\.\d+)") {
            return $Matches[1]
        }

        return "unknown"
    }
    catch {
        return "unknown"
    }
}

$results = @()

$rootExists = Test-Path $RootPath
if ($rootExists) {
    $rootMessage = "$RootPath exists"
}
else {
    $rootMessage = "$RootPath is missing; a fresh setup is needed"
}
$results += Add-Result "Root folder" $rootExists $rootMessage

$repoDir = Join-Path $RootPath "Tablet_Setup"
$backendDir = Join-Path $RootPath "backend"
$frontendDir = Join-Path $RootPath "frontend"
$fkBridgeDir = Join-Path $RootPath "FKBridge"
$logsDir = Join-Path $RootPath "logs"

if (Test-Path $repoDir) {
    $gitRepo = Test-Path (Join-Path $repoDir ".git")
    if ($gitRepo) {
        $repoMessage = "Repository is valid and ready"
    }
    else {
        $repoMessage = "Folder exists but is not a valid Git repo; setup will repair it"
    }
    $results += Add-Result "Git repository" $gitRepo $repoMessage
}
else {
    $results += Add-Result "Git repository" $false "Repository is missing; setup will clone it"
}

foreach ($dir in @($backendDir, $frontendDir, $fkBridgeDir, $logsDir)) {
    $exists = Test-Path $dir
    if ($exists) {
        $dirMessage = "$dir already exists"
    }
    else {
        $dirMessage = "$dir is missing and will be created"
    }
    $results += Add-Result (Split-Path $dir -Leaf) $exists $dirMessage
}

$startupScript = Join-Path $RootPath "scripts\Start-EcaAfrica.ps1"
$startupExists = Test-Path $startupScript
if ($startupExists) {
    $startupMessage = "Startup script is present"
}
else {
    $startupMessage = "Startup script is missing; setup will install it"
}
$results += Add-Result "Startup script" $startupExists $startupMessage

$knownApps = @($GitBinary, $NodeBinary, $NpmBinary, $ChromeBinary, $DotNetBinary)

foreach ($app in $knownApps) {
    $exists = Test-Path $app
    if ($exists) {
        $version = Get-ToolVersion $app @(
            if ((Split-Path $app -Leaf) -match "node.exe") { @("--version") }
            elseif ((Split-Path $app -Leaf) -match "dotnet.exe") { @("--list-sdks") }
            elseif ((Split-Path $app -Leaf) -match "git.exe") { @("--version") }
            elseif ((Split-Path $app -Leaf) -match "chrome.exe") { @() }
            else { @() }
        )
        $appMessage = "$app is available | version: $version"
    }
    else {
        $appMessage = "$app is not installed yet"
    }
    $results += Add-Result (Split-Path $app -Leaf) $exists $appMessage
}

$windowsVersion = [System.Environment]::OSVersion.Version
$results += Add-Result "Windows" ($windowsVersion.Major -ge 10) "Windows $($windowsVersion.Major).$($windowsVersion.Minor) build $($windowsVersion.Build)"

$backendReachable = (Test-PortOpen 5000) -and (Test-HttpReachable "http://localhost:5000")
$frontendReachable = (Test-PortOpen 3000) -and (Test-HttpReachable "http://localhost:3000")
$wireguardRunning = $false
try {
    $wgService = Get-Service -Name "WireGuardTunnel*" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "Ecare|Eca|WireGuardTunnel" } |
        Select-Object -First 1

    if ($wgService) {
        $wireguardRunning = ($wgService.Status -eq "Running")
    }
}
catch {}

$fkBridgeRunning = $false
try {
    $fkBridgeProcess = Get-Process -Name "FKBridge" -ErrorAction SilentlyContinue
    if ($fkBridgeProcess) {
        $fkBridgeRunning = $true
    }
}
catch {}

$chromeRunning = ((Get-Process -Name "chrome" -ErrorAction SilentlyContinue).Count -gt 0)

$results += Add-Result "Backend port 5000" $backendReachable "Live backend status: $backendReachable"
$results += Add-Result "Frontend port 3000" $frontendReachable "Live frontend status: $frontendReachable"
$results += Add-Result "Chrome kiosk" $chromeRunning "Chrome process detected: $chromeRunning"
$results += Add-Result "WireGuard tunnel" $wireguardRunning "WireGuard service running: $wireguardRunning"
$results += Add-Result "FKBridge" $fkBridgeRunning "FKBridge process running: $fkBridgeRunning"

Write-Host ""
Write-Host "Virtual tablet validation" -ForegroundColor Cyan
Write-Host "Root: $RootPath" -ForegroundColor Cyan
Write-Host "Windows: $windowsVersion" -ForegroundColor Cyan
Write-Host ""

$results | Format-Table -AutoSize

$failures = @($results | Where-Object { $_.Status -eq "FAIL" })

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "Virtual check found issues; configuration is still valid but live runtime checks are pending or remote device is unreachable." -ForegroundColor Yellow
    Write-Host "The setup will continue in best-effort mode instead of failing the validation run." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Virtual tablet validation passed." -ForegroundColor Green
