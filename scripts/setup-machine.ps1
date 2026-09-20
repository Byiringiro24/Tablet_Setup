Param(
  [string]$TemplateDir = 'C:\EcaAfrica\git-templates',
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

Write-Output "Setting up machine git template hooks at: $TemplateDir"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Error "git is not available on PATH. Please install Git for Windows first."; exit 2
}

if (-not (Test-Path $TemplateDir)) { New-Item -Path $TemplateDir -ItemType Directory -Force | Out-Null }

$src = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) 'git-templates'
if (-not (Test-Path $src)) { Write-Error "Expected template source not found in repo: $src"; exit 3 }

Write-Output "Copying template hooks from repo ($src) to $TemplateDir"
Copy-Item -Path (Join-Path $src '*') -Destination $TemplateDir -Recurse -Force

Write-Output "Configuring git to use template dir"
git config --global init.templateDir "$TemplateDir"

Write-Output "Template hooks installed. New clones on this machine will get the hooks automatically."
Write-Output "Note: existing local clones will not be modified; run scripts\install-git-hooks.ps1 inside them to install hooks." 

exit 0
