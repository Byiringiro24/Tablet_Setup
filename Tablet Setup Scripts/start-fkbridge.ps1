<#
.SYNOPSIS
    Build and run FKBridge.exe with checks and fallbacks.
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
$LOG_FILE = Join-Path $LOG_DIR 'start-fkbridge.log'
function _Log($lvl, $m) { $line = "$(Get-Date -Format o) [$lvl] $m"; Add-Content -Path $LOG_FILE -Value $line; Write-Host $line }
function Write-OK($m){ _Log 'OK' $m }
function Write-Warn($m){ _Log 'WARN' $m }
function Write-Info($m){ _Log 'INFO' $m }

function Find-Exe($name) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

 $candidates = @((Get-Location).ProviderPath, 'C:\EcaAfrica')
 $fk = $null
 foreach ($r in $candidates) { if (Test-Path (Join-Path $r 'FKBridge')) { $fk = Join-Path $r 'FKBridge'; break } }
 if (-not $fk) { Write-Warn "FKBridge folder not found in repo or C:\EcaAfrica"; exit 1 }

Push-Location $fk
Write-Info 'Running dotnet restore/build (Release)'
$dotnet = Find-Exe 'dotnet'
if ($dotnet) {
    if ($DryRun) { Write-Info "Dry-run: would run: $dotnet build -c Release" } else { & $dotnet build -c Release 2>&1 | ForEach-Object { Write-Host $_ }; if ($LASTEXITCODE -ne 0) { Write-Warn 'dotnet build reported errors' } }
} else { Write-Warn 'dotnet not found; cannot build FKBridge' }

$exe = Join-Path $fk 'bin\Release\net8.0\FKBridge.exe'
if (Test-Path $exe) {
    Write-Info "Starting FKBridge: $exe"
    if ($DryRun) { Write-Info "Dry-run: would start $exe"; Write-OK 'Dry-run: FKBridge start skipped' } else { $p = Start-Process -FilePath $exe -PassThru -NoNewWindow -RedirectStandardOutput $LOG_FILE -RedirectStandardError $LOG_FILE; Start-Sleep 1; if ($p -and -not $p.HasExited) { Write-OK "FKBridge running pid=$($p.Id)" } else { Write-Warn 'FKBridge failed to start' } }
} else {
    Write-Warn "FKBridge.exe not found at $exe"
}
Pop-Location
