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

$hookPath = Join-Path $gitDir 'hooks\post-merge'

$hookContent = "@echo off`r`n" +
"powershell -NoProfile -ExecutionPolicy Bypass -File \"%~dp0..\\..\\scripts\\ensure-install-root.ps1\" -NonInteractive`r`n"

if (Test-Path $hookPath -and -not $Force) {
  Write-Output "A post-merge hook already exists at $hookPath. Use -Force to overwrite."
  exit 3
}

Set-Content -Path $hookPath -Value $hookContent -Encoding ASCII
Write-Output "Installed post-merge hook at: $hookPath"
