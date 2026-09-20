Param(
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Get-GitDir {
  try {
    $gd = (& git rev-parse --git-dir) 2>$null
    if ($gd) { return (Resolve-Path $gd).ProviderPath }
  } catch { }
  return $null
}

$gitDir = Get-GitDir
if (-not $gitDir) { Write-Error "Not a git repository (cannot find .git). Run this from repo root."; exit 2 }

# Copy all hooks from repo templates into the repository hooks directory
$templateHooks = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) 'git-templates\hooks'
if (-not (Test-Path $templateHooks)) { Write-Error "Template hooks folder not found: $templateHooks"; exit 4 }

Get-ChildItem -Path $templateHooks -File | ForEach-Object {
  $destHook = Join-Path $gitDir ('hooks\' + $_.Name)
  if (Test-Path $destHook -and -not $Force) {
    Write-Output "Hook $($_.Name) already exists at $destHook — use -Force to overwrite."
  } else {
    Copy-Item -Path $_.FullName -Destination $destHook -Force
    # Ensure hooks are executable (on Windows batch/ps1 hooks will run)
    Write-Output "Installed hook: $destHook"
  }
}

Write-Output "All template hooks copied to: $gitDir\hooks"
