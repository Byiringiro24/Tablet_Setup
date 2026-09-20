<#
.SYNOPSIS
    Install required tooling and install/build frontend/backend packages with robust npm fallbacks.
.
USAGE
    .\install-deps.ps1 [-InstallNode] [-InstallGit]
#>
param(
    [switch]$InstallNode,
    [switch]$InstallGit,
    [switch]$DryRun
)

Set-StrictMode -Off
$ErrorActionPreference = 'Continue'

Set-StrictMode -Off
$ErrorActionPreference = 'Continue'

# Logging
$INSTALL_DIR = 'C:\EcaAfrica'
$LOG_DIR = Join-Path $INSTALL_DIR 'logs'
if (-not (Test-Path $LOG_DIR)) { New-Item -ItemType Directory -Force -Path $LOG_DIR | Out-Null }
$LOG_FILE = Join-Path $LOG_DIR 'install-deps.log'
function _Log($lvl, $m) { $line = "$(Get-Date -Format o) [$lvl] $m"; Add-Content -Path $LOG_FILE -Value $line; Write-Host $line }
function Write-OK($m){ _Log 'OK' $m }
function Write-Warn($m){ _Log 'WARN' $m }
function Write-Info($m){ _Log 'INFO' $m }

function Refresh-Path {
    $machine = [System.Environment]::GetEnvironmentVariable('PATH','Machine')
    if (-not $machine) { $machine = '' }
    $user = [System.Environment]::GetEnvironmentVariable('PATH','User')
    if (-not $user) { $user = '' }
    $env:PATH = "$machine;$user;C:\Program Files\nodejs;C:\Program Files\Git\cmd;$env:APPDATA\npm"
}

function Find-Exe($name) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        "C:\Program Files\nodejs\$name.exe",
        "C:\Program Files (x86)\nodejs\$name.exe",
        "$env:LOCALAPPDATA\Programs\nodejs\$name.exe",
        "C:\Program Files\nodejs\$name.cmd",
        "C:\Program Files (x86)\nodejs\$name.cmd",
        "$env:LOCALAPPDATA\Programs\nodejs\$name.cmd"
    )
    foreach ($p in $candidates) { if (Test-Path $p) { return $p } }
    return $null
}

function Resolve-NpmCandidate() {
    Refresh-Path
    $cmdNpmCmd = Find-Exe 'npm'
    if ($cmdNpmCmd) { return $cmdNpmCmd }
    # Prefer explicit npm.cmd if available
    $explicit = @(
        'npm.cmd','npm'
    )
    foreach ($c in $explicit) {
        $p = Get-Command $c -ErrorAction SilentlyContinue
        if ($p) { return $p.Source }
    }
    return 'npm.cmd'
}

function Invoke-NpmSafe {
    param([string[]]$Args)
    $candidates = @()
    $resolved = Resolve-NpmCandidate
    if ($resolved) { $candidates += $resolved }
    $candidates += 'npm.cmd','npm'

    foreach ($cand in $candidates | Select-Object -Unique) {
        try {
            if ($cand -match '\.(ps1|psm1)$') { continue }
            if ($cand -match '\.(cmd|bat|exe)$' -or (Test-Path $cand)) {
                Write-Info "Trying $cand $($Args -join ' ')"
                if ($cand -match '\.cmd$' -or $cand -match '\.exe$') {
                    & $cand @Args
                } else {
                    cmd /d /s /c ('"' + $cand + '" ' + ($Args -join ' '))
                }
                if ($LASTEXITCODE -eq 0) { Write-OK "Command succeeded with $cand"; return $true }
            } else {
                # try via cmd /c so PowerShell execution policy cannot block
                Write-Info "Trying cmd /c $cand $($Args -join ' ')"
                cmd /d /s /c ('"' + $cand + '" ' + ($Args -join ' '))
                if ($LASTEXITCODE -eq 0) { Write-OK "Command succeeded via cmd /c $cand"; return $true }
            }
        } catch {
            Write-Warn "Candidate $cand failed: $($_.Exception.Message)"
        }
    }
    return $false
}

Refresh-Path

if ($InstallNode) {
    if (-not (Find-Exe 'node')) {
        Write-Info 'Node missing — downloading Node LTS (x64)'
        $u = 'https://nodejs.org/dist/v20.19.0/node-v20.19.0-x64.msi'
        $f = "$env:TEMP\node-lts.msi"
        try { 
            if ($DryRun) { Write-Info "Dry-run: would download $u to $f"; Write-OK 'Dry-run: Node installer skipped' } 
            else { Invoke-WebRequest -Uri $u -OutFile $f -UseBasicParsing; Start-Process msiexec.exe -ArgumentList "/i `"$f`" /quiet /norestart" -Wait; Refresh-Path; Write-OK 'Node installer attempted' }
        } catch { Write-Warn 'Node download failed' }
    } else { Write-OK 'Node present' }
}

if ($InstallGit) {
    if (-not (Find-Exe 'git')) {
        Write-Info 'Git missing — user install required or provide installer.'
    } else { Write-OK 'Git present' }
}

# Install frontend/backend deps
$root = (Get-Location).ProviderPath
$backend = Join-Path $root 'backend'
$frontend = Join-Path $root 'frontend'

if (Test-Path $backend) {
    Write-Info 'Installing backend deps (will prefer npm.cmd)'
    Push-Location $backend
    if ($DryRun) { Write-Info 'Dry-run: would run backend npm install' } else { if (-not (Invoke-NpmSafe @('install','--prefer-offline'))) { Write-Warn 'Backend npm install failed on all candidates' } }
    Pop-Location
} else { Write-Warn 'Backend folder not found; skipping backend install' }

if (Test-Path $frontend) {
    Write-Info 'Installing frontend deps'
    Push-Location $frontend
    if ($DryRun) { Write-Info 'Dry-run: would run frontend npm install and build' } else { if (-not (Invoke-NpmSafe @('install'))) { Write-Warn 'Frontend npm install failed on all candidates' } ; if (-not (Invoke-NpmSafe @('run','build'))) { Write-Warn 'Frontend build failed via npm; consider running npm.cmd manually' } }
    Pop-Location
} else { Write-Warn 'Frontend folder not found; skipping frontend install' }

Write-OK 'install-deps.ps1 finished'
