# ============================================================
#  Enroll-Tablet.ps1
#  Per-tablet provisioning - set device ID and FK623 IP.
#
#  Usage examples:
#    .\Enroll-Tablet.ps1 -BiometricDeviceIp 192.168.1.76
#    .\Enroll-Tablet.ps1 -BiometricDeviceIp 192.168.1.76 -DeviceId ECA-KGL-001
#    .\Enroll-Tablet.ps1 -BiometricDeviceIp 192.168.1.76 -Port 5005 -License 1261
#
#  What it does:
#   - Writes C:\EcaAfrica\provisioning\device.json
#   - Writes C:\EcaAfrica\backend\data\device-config.json
#   - Both files are read by Setup and Start scripts automatically
#   - Run Setup (option 1) after enrolling to apply changes
# ============================================================

param(
    [Parameter(Mandatory)][string]$BiometricDeviceIp,
    [int]   $Port     = 5005,
    [int]   $License  = 1261,
    [string]$DeviceId = '',        # Leave blank to auto-generate from hardware
    [string]$TabletUuid = '',      # Optional: set in backend .env as TABLET_UUID
    [switch]$NoPrompt
)

$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\Common-EcaAfrica.ps1"

$LOG = Join-Path $script:LogDir 'setup.log'
Ensure-EcaDirs

function L([string]$m, [string]$lv = 'INFO') { Write-Log $m $lv $LOG }

Require-Admin

# Auto-generate device ID from hardware serial if not provided
if ([string]::IsNullOrWhiteSpace($DeviceId)) {
    $id       = Get-TabletIdentity
    $DeviceId = $id.DeviceId
    L "Auto-generated DeviceId: $DeviceId  (from hardware serial $($id.Serial))"
} else {
    L "Using provided DeviceId: $DeviceId"
}

# ── Write provisioning/device.json ────────────────────────────
$provFile = Join-Path $script:ProvisionDir 'device.json'
$provObj  = [ordered]@{
    Device = [ordered]@{
        DeviceId            = $DeviceId
        BiometricDeviceIp   = $BiometricDeviceIp
        BiometricDevicePort = $Port
        License             = $License
    }
    TabletUuid  = $TabletUuid
    EnrolledAt  = (Get-Date).ToString('o')
    EnrolledBy  = $env:USERNAME
    Hostname    = $env:COMPUTERNAME
}
$provObj | ConvertTo-Json -Depth 5 | Set-Content $provFile -Encoding UTF8
L "Provisioning saved to $provFile"

# ── Write backend/data/device-config.json ─────────────────────
$cfg       = Get-EcaConfig
$dataDir   = Join-Path $script:BackendDir 'data'
Ensure-Dir $dataDir
$devCfg = [ordered]@{
    deviceId     = $DeviceId
    hostname     = $env:COMPUTERNAME
    license      = $License
    ipAddress    = $BiometricDeviceIp
    port         = $Port
    netPassword  = 0
    protocolType = -1
    timeoutMs    = [int]$cfg.Device.TimeoutMs
    localIp      = (Get-LocalIP)
    generatedAt  = (Get-Date).ToString('o')
}
$devCfg | ConvertTo-Json -Depth 5 | Set-Content $script:DeviceCfg -Encoding UTF8
L "device-config.json written to $($script:DeviceCfg)"

# ── Update TABLET_UUID in backend .env if provided ────────────
if (-not [string]::IsNullOrWhiteSpace($TabletUuid)) {
    Set-EnvFile (Join-Path $script:BackendDir '.env') @{ TABLET_UUID = $TabletUuid } -PreserveExisting
    L "TABLET_UUID set in backend .env: $TabletUuid"
}

# ── Print summary ─────────────────────────────────────────────
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Tablet Enrolled Successfully" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Device ID     : $DeviceId"
Write-Host "  FK623 IP      : ${BiometricDeviceIp}:$Port"
Write-Host "  License       : $License"
if ($TabletUuid) { Write-Host "  Tablet UUID   : $TabletUuid" }
Write-Host "  Hostname      : $env:COMPUTERNAME"
Write-Host ""
Write-Host "  Files written:" -ForegroundColor Yellow
Write-Host "   $provFile"
Write-Host "   $($script:DeviceCfg)"
Write-Host ""
Write-Host "  Next: Run Setup (option 1) to apply, or restart the tablet." -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
L "Enrollment complete for $DeviceId"

if (-not $NoPrompt) { Read-Host "Press Enter to close" | Out-Null }
