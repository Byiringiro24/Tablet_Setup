$path = 'Tablet Setup/setup-new-tablet.ps1'
$lines = Get-Content $path
for ($i=0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -match '[^\x00-\x7F]') {
        $num = $i + 1
        Write-Host ([string]::Format('Line {0}: {1}', $num, $line))
    }
}
