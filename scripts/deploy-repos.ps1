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
  [switch]$Force,
  [switch]$ForceStop  # when provided, attempt to stop known services/processes that lock files
)

$ErrorActionPreference = 'Stop'

function Write-Log { param($m) Write-Output "[deploy] $m" }

$target = 'C:\EcaAfrica'
$timestamp = Get-Date -Format yyyyMMdd_HHmmss
$tmpRoot = Join-Path $env:TEMP "ecadeploy_clone_$timestamp"
New-Item -Path $tmpRoot -ItemType Directory -Force | Out-Null

# Staging area where we assemble the full deployment before switching
$staging = Join-Path $env:TEMP "ecadeploy_staging_$timestamp"
New-Item -Path $staging -ItemType Directory -Force | Out-Null

# Repositories to pull and their branches (order matters: later repos overwrite earlier files)
$repos = @(
  @{ url = 'https://github.com/MbarushimanaFabrice/Ecareafrica_backend.git'; branch = 'New_Serverr' },
  @{ url = 'https://github.com/MbarushimanaFabrice/Ecareafrica_frontend.git'; branch = 'New_Serverr' },
  @{ url = 'https://github.com/Byiringiro24/Tablet_Setup.git'; branch = 'main' }
)

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Error "git not found on PATH. Please install Git for Windows and re-run."; exit 2
}

try {
  # Clone each repo into tmpRoot and merge into staging
  foreach ($r in $repos) {
    $name = ([IO.Path]::GetFileNameWithoutExtension($r.url)) -replace '[^a-zA-Z0-9_.-]',''
    $dest = Join-Path $tmpRoot $name
    Write-Log "Cloning $($r.url)#$($r.branch) -> $dest"
    git clone --depth 1 --branch $r.branch $r.url $dest
    Write-Log "Merging files from $dest -> $staging (excluding .git)"
    Get-ChildItem -Path $dest -Force | Where-Object { $_.Name -ne '.git' } | ForEach-Object {
      $src = $_.FullName
      $dst = Join-Path $staging $_.Name
      if (Test-Path $dst) { Remove-Item -LiteralPath $dst -Recurse -Force -ErrorAction SilentlyContinue }
      Write-Log "Copying: $src -> $dst"
      try {
        Copy-Item -Path $src -Destination $dst -Recurse -Force -ErrorAction Stop
      } catch {
        Write-Error "Copy failed for $src -> $dst : $_"
        Write-Log "Aborting deployment due to copy error. Staging remains at: $staging"
        exit 30
      }
    }
  }

  # Prepare new target folder and populate it from staging
  $newTarget = "$target.new.$timestamp"
  Write-Log "Creating new target $newTarget and copying staged files"
  if (Test-Path $newTarget) { Remove-Item -LiteralPath $newTarget -Recurse -Force -ErrorAction SilentlyContinue }
  New-Item -Path $newTarget -ItemType Directory -Force | Out-Null
  # Copy each staged child individually with diagnostics to surface conflicts
  Get-ChildItem -Path $staging -Force | ForEach-Object {
    $srcChild = $_.FullName
    $dstChild = Join-Path $newTarget $_.Name
    Write-Log "Copying staged item: $srcChild -> $dstChild"
    try {
      if (Test-Path $dstChild) { Remove-Item -LiteralPath $dstChild -Recurse -Force -ErrorAction SilentlyContinue }
      Copy-Item -Path $srcChild -Destination $dstChild -Recurse -Force -ErrorAction Stop
    } catch {
      Write-Error "Failed copying staged item: $srcChild -> $dstChild : $_"
      Write-Log "Staging is available at: $staging for manual inspection"
      exit 31
    }
  }

  # Optional: attempt to stop known processes that commonly lock files when requested
  if ($ForceStop) {
    Write-Log "ForceStop requested — attempting to terminate FKBridge and node processes to avoid file locks"
    Get-Process -Name FKBridge -ErrorAction SilentlyContinue | ForEach-Object { Try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } Catch {} }
    Get-Process -Name node -ErrorAction SilentlyContinue | ForEach-Object { Try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } Catch {} }
    Start-Sleep -Seconds 2
  }

  # Attempt atomic switch: move old target to backup, then move newTarget to target
  $backup = "$target.backup.$timestamp"
  if (Test-Path $target) {
    Write-Log "Backing up existing $target -> $backup"
    try {
      Move-Item -LiteralPath $target -Destination $backup -Force
      Write-Log "Existing target moved to backup"
    } catch {
      Write-Error "Failed to move existing target to backup: $_"
      Write-Log "Listing top-level files in $target for diagnostics"
      Get-ChildItem -Path $target -Force | Select-Object Name,Mode,Length | ForEach-Object { Write-Output " - $($_.Name)" }
      Write-Log "Deployment aborted: cannot safely replace $target while files are locked. New deployment is available at: $newTarget"
      Write-Log "If you want the script to attempt stopping services that may lock files, re-run with -ForceStop"
      exit 20
    }
  }

  # Move staged new into place
  Write-Log "Switching new deployment into place: $newTarget -> $target"
  Move-Item -LiteralPath $newTarget -Destination $target -Force

  # Cleanup temp clones and staging
  Write-Log "Cleaning temp folders: $tmpRoot, $staging"
  Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue

  # Optional post-deploy cleanup: remove development-only files to keep tablet root small
  Write-Log "Removing development files to shrink installation (docs, .git, .github, tests, .vscode)"
  $devPatterns = @('.git', '.github', 'docs', 'test', 'tests', '.vscode')
  foreach ($p in $devPatterns) {
    $pathToRemove = Join-Path $target $p
    if (Test-Path $pathToRemove) { Remove-Item -LiteralPath $pathToRemove -Recurse -Force -ErrorAction SilentlyContinue }
  }

  Write-Log "Deploy complete. Files are now in $target"
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
