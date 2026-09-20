$src = 'D:\Projectts 2026\Latest EcaAfrica 7-8-2026\Tablet Setup\setup-new-tablet.ps1'
$lines = Get-Content $src
for ($start = 0; $start -lt $lines.Count; $start += 100) {
    $end = [Math]::Min($start + 99, $lines.Count - 1)
    $chunk = $lines[$start..$end] -join [Environment]::NewLine
    $tmp = [System.IO.Path]::GetTempFileName() + '.ps1'
    Set-Content -Path $tmp -Value $chunk -NoNewline
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($tmp, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors) {
        Write-Host ('CHUNK {0}-{1}: FAIL' -f ($start + 1), ($end + 1))
        $errors | ForEach-Object { Write-Host ('  {0} at line {1}, col {2}' -f $_.Message, $_.Extent.StartLineNumber, $_.Extent.StartColumnNumber) }
    }
    else {
        Write-Host ('CHUNK {0}-{1}: OK' -f ($start + 1), ($end + 1))
    }
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
}
