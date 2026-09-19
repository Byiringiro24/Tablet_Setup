$path = "Tablet Setup/setup-new-tablet.ps1"
$full = Get-Content $path
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $path).ProviderPath, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors) {
    foreach ($e in $errors) {
        Write-Host 'ERROR: ' $e.Message
        $s = [Math]::Max(1, $e.Extent.StartLineNumber-3)
        $t = [Math]::Min($full.Count, $e.Extent.StartLineNumber+3)
        Write-Host 'At line' $e.Extent.StartLineNumber, 'col' $e.Extent.StartColumnNumber
        for ($i=$s; $i -le $t; $i++) {
            $ln = $full[$i-1]
            Write-Host ('{0,4}: {1}' -f $i, $ln)
        }
        Write-Host '----'
    }
    exit 1
} else { Write-Host 'PARSE OK' } 
