$path = 'd:\Projectts 2026\Latest EcaAfrica 7-8-2026\Tablet Setup\setup-new-tablet.ps1'
$t = Get-Content -LiteralPath $path -Raw
$outChars = New-Object System.Text.StringBuilder
foreach ($c in $t.ToCharArray()) {
    if ([int]$c -lt 128) { [void]$outChars.Append($c) }
}
Set-Content -LiteralPath $path -Value $outChars.ToString() -Encoding UTF8
Write-Host 'Stripped non-ASCII characters from' $path
