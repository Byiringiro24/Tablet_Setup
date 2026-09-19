param([string]$Path)
$full = Get-Content -LiteralPath $Path -ErrorAction Stop
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $Path).ProviderPath, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors) { foreach ($e in $errors) { Write-Host 'ERROR:' $e.Message; Write-Host 'At line' $e.Extent.StartLineNumber, 'col' $e.Extent.StartColumnNumber } exit 1 } else { Write-Host 'PARSE OK' }