<#
.SYNOPSIS
    Start backend server with robust npm fallbacks and perform a health check.
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
$LOG_FILE = Join-Path $LOG_DIR 'start-backend.log'
function _Log($lvl, $m) { $line = "$(Get-Date -Format o) [$lvl] $m"; Add-Content -Path $LOG_FILE -Value $line; Write-Host $line }
function Write-OK($m){ _Log 'OK' $m }
function Write-Warn($m){ _Log 'WARN' $m }
function Write-Info($m){ _Log 'INFO' $m }

function Invoke-CmdFallback($cmd, $args) {
    try { & $cmd $args -ErrorAction Stop; return $true } catch { return $false }
}

function Invoke-NpmCmd([string[]]$args) {
    # Prefer npm.cmd to avoid PowerShell execution policy blocks
    $root = (Get-Location).ProviderPath
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

# Try repo root or C:\EcaAfrica (tablet runtime)
$candidates = @((Get-Location).ProviderPath, 'C:\EcaAfrica')
$backend = $null
foreach ($r in $candidates) { if (Test-Path (Join-Path $r 'backend')) { $backend = Join-Path $r 'backend'; break } }
if (-not $backend) { Write-Warn "backend folder missing in repo or C:\EcaAfrica"; exit 1 }

Push-Location $backend
# Prefer starting via npm.cmd run dev, fallback to node server.js
if (Test-Path 'package.json') {
    $pkg = Get-Content package.json -Raw | ConvertFrom-Json
    if ($pkg.scripts -and $pkg.scripts.dev) {
        if ($DryRun) { Write-Info 'Dry-run: would run npm run dev (backend)'; Write-OK 'Dry-run: backend start skipped'; Pop-Location; return }
        if (Invoke-NpmCmd @('run','dev')) { Write-OK 'Backend started via npm run dev'; Pop-Location; return }
    }
}

if (Test-Path 'server.js') {
    Write-Info 'Starting backend via node server.js'
    $node = Get-Command node -ErrorAction SilentlyContinue
    if ($node) { if ($DryRun) { Write-Info 'Dry-run: would start node server.js'; Write-OK 'Dry-run: backend start skipped' } else { Start-Process -FilePath $node.Source -ArgumentList 'server.js' -PassThru -NoNewWindow | Out-Null; Write-OK 'Backend started (node server.js)'; } }
    else { Write-Warn 'node.exe not found; cannot start backend' }
} else { Write-Warn 'No server.js and no npm dev script found' }

# Wait for health endpoint
Start-Sleep -Seconds 5
try {
    $h = Invoke-RestMethod "http://localhost:5000/api/health" -TimeoutSec 5
    Write-OK "Backend health: $($h.status)"
} catch { Write-Warn 'Backend health check failed (not yet ready)'
}

Pop-Location
