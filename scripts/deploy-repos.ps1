<#
  deploy-repos.ps1
  Non-interactive deploy: clones configured repos and copies their contents
  into C:\EcaAfrica (root). Designed for tablets and laptops where a
  single deployment folder is required. Preserves a timestamped backup
  of the previous C:\EcaAfrica content before overwriting.

  Usage (run as admin recommended):
    powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy-repos.ps1

  Edit the $repos array below to adjust repo URLs and branches.
#>

Param(
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Write-Log { param($m) Write-Output "[deploy] $m" }

$target = 'C:\EcaAfrica'
$tmpRoot = Join-Path $env:TEMP "ecadeploy_$(Get-Date -Format yyyyMMdd_HHmmss)"
New-Item -Path $tmpRoot -ItemType Directory -Force | Out-Null

# Repositories to pull and their branches (order matters: later repos overwrite earlier files)
$repos = @(
  @{ url = 'https://github.com/MbarushimanaFabrice/Ecareafrica_backend.git'; branch = 'New_Serverr' },
  @{ url = 'https://github.com/MbarushimanaFabrice/Ecareafrica_frontend.git'; branch = 'New_Serverr' },
  @{ url = 'https://github.com/Byiringiro24/Tablet_Setup.git'; branch = 'Testing-Branch' }
)

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Error "git not found on PATH. Please install Git for Windows and re-run."; exit 2
}

if (Test-Path $target) {
  $backup = "$target.backup.$(Get-Date -Format yyyyMMdd_HHmmss)"
  Write-Log "Backing up existing $target -> $backup"
  if (Test-Path $backup) { Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction SilentlyContinue }
  Move-Item -LiteralPath $target -Destination $backup -Force
}

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

  Write-Log "Deploy complete. Cleaning temp: $tmpRoot"
  Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
  Write-Log "Success. Files are now in $target"
  exit 0
} catch {
  Write-Error "Deployment failed: $_"
  Write-Log "Attempting to restore backup if present"
  if (Test-Path $backup) {
    if (Test-Path $target) { Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue }
    Move-Item -LiteralPath $backup -Destination $target -Force
    Write-Log "Restored backup to $target"
  }
  exit 10
}
