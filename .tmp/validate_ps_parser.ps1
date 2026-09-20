$path = 'D:\Projectts 2026\Latest EcaAfrica 7-8-2026\Tablet Setup\setup-new-tablet.ps1'
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors) {
    $errors | ForEach-Object { $_.Message + ' at line ' + $_.Extent.StartLineNumber + ', col ' + $_.Extent.StartColumnNumber }
    exit 1
}
'PARSE OK: setup-new-tablet.ps1'
