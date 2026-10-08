<#
  update-repos.ps1
  Non-interactive updater: re-clones configured repos into a temp folder and
  copies their latest files into C:\EcaAfrica (overwrite). Designed for
  repeatable updates on laptops/tablets. Keeps a small backup before applying.

  Usage:
    powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\update-repos.ps1
#>

Param(
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Write-Log { param($m) Write-Output "[update] $m" }

$target = 'C:\EcaAfrica'
$tmpRoot = Join-Path $env:TEMP "ecaupdate_$(Get-Date -Format yyyyMMdd_HHmmss)"
New-Item -Path $tmpRoot -ItemType Directory -Force | Out-Null

# Same repo list as deploy-repos.ps1 — update if you change deploy config
$repos = @(
  @{ url = 'https://github.com/MbarushimanaFabrice/Ecareafrica_backend.git'; branch = 'New_Serverr' },
  @{ url = 'https://github.com/MbarushimanaFabrice/Ecareafrica_frontend.git'; branch = 'New_Serverr' },
  @{ url = 'https://github.com/Byiringiro24/Tablet_Setup.git'; branch = 'main' }
)

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Error "git not found"; exit 2 }

if (-not (Test-Path $target)) { Write-Error "$target does not exist — run deploy-repos.ps1 first"; exit 3 }

$backup = "$target.backup.$(Get-Date -Format yyyyMMdd_HHmmss)"
Write-Log "Backing up $target -> $backup"
Move-Item -LiteralPath $target -Destination $backup -Force
New-Item -Path $target -ItemType Directory -Force | Out-Null

try {
  foreach ($r in $repos) {
    $name = ([IO.Path]::GetFileNameWithoutExtension($r.url)) -replace '[^a-zA-Z0-9_.-]',''
    $dest = Join-Path $tmpRoot $name
    Write-Log "Cloning $($r.url)#$($r.branch) -> $dest"
    git clone --depth 1 --branch $r.branch $r.url $dest
    Write-Log "Copying files from $dest -> $target (excluding .git)"
    Get-ChildItem -Path $dest -Force | Where-Object { $_.Name -ne '.git' } | ForEach-Object {
      $src = $_.FullName
      $dst = Join-Path $target $_.Name
      if (Test-Path $dst) { Remove-Item -LiteralPath $dst -Recurse -Force -ErrorAction SilentlyContinue }
      Copy-Item -Path $src -Destination $dst -Recurse -Force
    }
  }
  Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
  Write-Log "Update complete"
  exit 0
} catch {
  Write-Error "Update failed: $_"
  if (Test-Path $backup) {
    if (Test-Path $target) { Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue }
    Move-Item -LiteralPath $backup -Destination $target -Force
    Write-Log "Restored backup to $target"
  }
  exit 10
}
