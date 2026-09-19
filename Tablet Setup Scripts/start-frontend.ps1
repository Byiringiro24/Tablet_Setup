<#
.SYNOPSIS
    Start frontend (dev) or run a production start with fallbacks. Performs basic HTTP check.
#>
param([switch]$DryRun)

Set-StrictMode -Off
$ErrorActionPreference = 'Continue'

Set-StrictMode -Off
$ErrorActionPreference = 'Continue'

# Logging
$INSTALL_DIR = 'C:\EcaAfrica'
$LOG_DIR = Join-Path $INSTALL_DIR 'logs'
if (-not (Test-Path $LOG_DIR)) { New-Item -ItemType Directory -Force -Path $LOG_DIR | Out-Null }
$LOG_FILE = Join-Path $LOG_DIR 'start-frontend.log'
function _Log($lvl, $m) { $line = "$(Get-Date -Format o) [$lvl] $m"; Add-Content -Path $LOG_FILE -Value $line; Write-Host $line }
function Write-OK($m){ _Log 'OK' $m }
function Write-Warn($m){ _Log 'WARN' $m }
function Write-Info($m){ _Log 'INFO' $m }

function Invoke-NpmCmd([string[]]$args) {
    $candidates = @('npm.cmd','npm')
    foreach ($c in $candidates) {
        $p = Get-Command $c -ErrorAction SilentlyContinue
        if ($p) {
            Write-Info "Trying $c $($args -join ' ')"
            if ($c -eq 'npm') { cmd /d /s /c ('npm ' + ($args -join ' ')); if ($LASTEXITCODE -eq 0) { return $true } }
            else { & $p.Source @args; if ($LASTEXITCODE -eq 0) { return $true } }
        }
    }
    return $false
}

 $candidates = @((Get-Location).ProviderPath, 'C:\EcaAfrica')
 $frontend = $null
 foreach ($r in $candidates) { if (Test-Path (Join-Path $r 'frontend')) { $frontend = Join-Path $r 'frontend'; break } }
 if (-not $frontend) { Write-Warn "frontend folder missing in repo or C:\EcaAfrica"; exit 1 }

 Push-Location $frontend
if (Test-Path 'package.json') {
    $pkg = Get-Content package.json -Raw | ConvertFrom-Json
    if ($pkg.scripts -and $pkg.scripts.dev) {
        if ($DryRun) { Write-Info 'Dry-run: would run npm run dev (frontend)'; Write-OK 'Dry-run: frontend start skipped'; Pop-Location; return }
        if (Invoke-NpmCmd @('run','dev')) { Write-OK 'Frontend dev started via npm run dev'; Pop-Location; return }
    }
    if ($pkg.scripts -and $pkg.scripts.start) {
        if ($DryRun) { Write-Info 'Dry-run: would run npm run start (frontend)'; Write-OK 'Dry-run: frontend start skipped'; Pop-Location; return }
        if (Invoke-NpmCmd @('run','start')) { Write-OK 'Frontend started via npm run start'; Pop-Location; return }
    }
}

Write-Warn 'No npm start/dev script available or all attempts failed'

# Health check for localhost:3000
Start-Sleep -Seconds 3
try {
    $null = Invoke-WebRequest 'http://localhost:3000' -TimeoutSec 5 -UseBasicParsing
    Write-OK 'Frontend reachable at http://localhost:3000'
} catch { Write-Warn 'Frontend HTTP check failed' }

Pop-Location
