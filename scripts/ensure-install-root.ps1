Param(
  [switch]$Force,
  [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'

$target = 'C:\EcaAfrica'
$cwd = (Get-Location).ProviderPath.TrimEnd('\')

Write-Output "Current location: $cwd"
Write-Output "Desired install root: $target"

if ($cwd -eq $target) {
  Write-Output "Already running from $target — nothing to do."
  exit 0
}

if ($cwd -like "$target\*") {
  Write-Error "Repository appears nested under $target (path: $cwd). Please move the repository root to $target, not a subfolder."
  exit 2
}

if (-not (Test-Path $target)) {
  Write-Output "Creating target folder $target"
  New-Item -Path $target -ItemType Directory -Force | Out-Null
}

# If target contains a git repo or files, avoid accidental overwrite unless forced
if ((Test-Path (Join-Path $target '.git')) -and -not $Force) {
  Write-Error "$target already contains a git repository. Use -Force to overwrite/replace."
  exit 3
}

if ((Get-ChildItem -LiteralPath $target -Force | Where-Object { $_.Name -ne '.' -and $_.Name -ne '..' } | Measure-Object).Count -gt 0 -and -not $Force) {
  Write-Error "$target exists and is not empty. Use -Force to overwrite."
  exit 4
}

try {
  Write-Output "Preparing to move files..."

  # Move .git first if present to preserve history
  $gitDir = Join-Path $cwd '.git'
  if (Test-Path $gitDir) {
    Write-Output "Moving .git directory to target..."
    if (Test-Path (Join-Path $target '.git')) { Remove-Item -LiteralPath (Join-Path $target '.git') -Recurse -Force -ErrorAction SilentlyContinue }
    Move-Item -LiteralPath $gitDir -Destination (Join-Path $target '.git') -Force
  }

  # Move all other items
  Get-ChildItem -LiteralPath $cwd -Force | Where-Object { $_.Name -ne '.git' } | ForEach-Object {
    $src = $_.FullName
    $dest = Join-Path $target $_.Name
    if (Test-Path $dest) { Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Output "Moving $src -> $dest"
    Move-Item -LiteralPath $src -Destination $dest -Force
  }

  Write-Output "Move complete. Changing location to $target"
  Set-Location $target
  Write-Output "Repository is now at: $(Get-Location)"
  exit 0
} catch {
  Write-Error "Failed to move repository: $_"
  exit 10
}
