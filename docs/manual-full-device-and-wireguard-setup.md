# Manual Full Device and WireGuard Setup

**Date**: September 2026  
**Purpose**: Complete manual setup of a Windows tablet for EcaAfrica — no scripts, every command typed by hand  
**Install path**: `C:\EcaAfrica`  
**Time needed**: 20–30 minutes

---

## Overview — What This Document Covers

1. Install all required software (Node.js, .NET 8, Git, WireGuard, Chrome)
2. Clone the code from GitHub
3. Write all configuration files
4. Build the frontend and FKBridge
5. Start and test manually
6. Install as auto-start Windows services (NSSM)
7. Set up WireGuard VPN tunnel
8. Configure Chrome to open automatically on every login (kiosk mode)

> Run all commands in **PowerShell as Administrator**.  
> Open Start Menu → search "PowerShell" → right-click → "Run as Administrator"

---

## Part 1 — Install Required Software

### 1.1 Node.js

Download and install Node.js LTS (v20):

```
https://nodejs.org/dist/v20.19.0/node-v20.19.0-x64.msi
```

Run the installer. Accept all defaults. Ensure "Add to PATH" is checked.

Verify:

```powershell
node --version
npm --version
```

Expected: `v20.x.x` and `10.x.x` or higher.

---

### 1.2 .NET 8 Desktop Runtime x86

The FK623 biometric device DLL is 32-bit. You need the **x86** runtime — the 64-bit version will not work.

Download:

```
https://aka.ms/dotnet/8.0/windowsdesktop-runtime-win-x86.exe
```

Run the installer silently or with defaults.

Also download the .NET 8 SDK x86 (needed to compile FKBridge):

```
https://aka.ms/dotnet/8.0/dotnet-sdk-win-x86.exe
```

Verify:

```powershell
& "C:\Program Files (x86)\dotnet\dotnet.exe" --list-runtimes
& "C:\Program Files (x86)\dotnet\dotnet.exe" --list-sdks
```

You should see lines containing `8.0` in both outputs.

---

### 1.3 Git

Download:

```
https://github.com/git-for-windows/git/releases/download/v2.47.0.windows.1/Git-2.47.0-64-bit.exe
```

Run the installer. Accept all defaults.

Verify:

```powershell
git --version
```

---

### 1.4 WireGuard

Download:

```
https://download.wireguard.com/windows-client/wireguard-installer.exe
```

Run the installer. Accept the UAC prompt. WireGuard installs silently.

Verify:

```powershell
Test-Path "C:\Program Files\WireGuard\wireguard.exe"
Test-Path "C:\Program Files\WireGuard\wg.exe"
```

Both must return `True`.

---

### 1.5 Google Chrome

Download:

```
https://dl.google.com/chrome/install/ChromeSetup.exe
```

Run the installer.

Verify:

```powershell
Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe"
```

Must return `True`.

---

### 1.6 Refresh PATH after installs

After all installs, reload PATH so new tools are available in the current session:

```powershell
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
```

---

## Part 2 — Get the Code

### 2.1 Clone from GitHub

```powershell
git clone --branch Testing-Branch https://github.com/Byiringiro24/Tablet_Setup.git C:\EcaAfrica
```

If `C:\EcaAfrica` already exists and has old files, remove it first:

```powershell
Remove-Item C:\EcaAfrica -Recurse -Force
git clone --branch Testing-Branch https://github.com/Byiringiro24/Tablet_Setup.git C:\EcaAfrica
```

### 2.2 Create required folders

```powershell
New-Item -ItemType Directory -Force -Path C:\EcaAfrica\logs
New-Item -ItemType Directory -Force -Path C:\EcaAfrica\tools
New-Item -ItemType Directory -Force -Path C:\EcaAfrica\backups
New-Item -ItemType Directory -Force -Path C:\EcaAfrica\backend\data
New-Item -ItemType Directory -Force -Path C:\EcaAfrica\backend\cache\photos\all-rooms
```

---

## Part 3 — Write Configuration Files

### 3.1 Backend environment file

Create `C:\EcaAfrica\backend\.env`:

```powershell
@"
PORT=5000
SERVER_API_URL=https://backend.ecareafrica.net/api/v1
TABLET_UUID=
DEV_PASSWORD=admin1234
WG_SERVER_ENDPOINT=169.58.124.150:51820
VPN_ALLOWED_IPS=10.0.0.0/16
WG_DNS=1.1.1.1
"@ | Set-Content C:\EcaAfrica\backend\.env -Encoding UTF8
```

> Fill in `TABLET_UUID=` after registering the tablet in the Super Admin portal.

---

### 3.2 Device config

Create `C:\EcaAfrica\backend\data\device-config.json`:

```powershell
@"
{
  "ipAddress": "192.168.1.76",
  "port": 5005,
  "license": 1261,
  "deviceId": "DV-KGL-01",
  "netPassword": 0,
  "protocolType": -1,
  "timeoutMs": 10000
}
"@ | Set-Content C:\EcaAfrica\backend\data\device-config.json -Encoding UTF8
```

> Replace `192.168.1.76` with the actual IP of the FK623 device on this school's network.  
> Replace `DV-KGL-01` with a label for this gate (e.g. `DV-KGL-02`, `DV-MUS-01`).

---

### 3.3 Frontend environment file

```powershell
"NEXT_PUBLIC_API_URL=http://localhost:5000" | Set-Content C:\EcaAfrica\frontend\.env.local -Encoding UTF8
```

---

### 3.4 Create empty students file if missing

```powershell
if (-not (Test-Path C:\EcaAfrica\backend\data\students.json)) {
    "[]" | Set-Content C:\EcaAfrica\backend\data\students.json -Encoding UTF8
}
```

---

## Part 4 — Install Dependencies and Build

### 4.1 Backend npm install

```powershell
cd C:\EcaAfrica\backend
npm install
```

---

### 4.2 Build FKBridge (.NET)

```powershell
$dotnet = "C:\Program Files (x86)\dotnet\dotnet.exe"
cd C:\EcaAfrica\FKBridge
& $dotnet restore FKBridge.csproj
& $dotnet build FKBridge.csproj -c Release --no-restore
```

Confirm the output file exists:

```powershell
Test-Path C:\EcaAfrica\FKBridge\bin\Release\net8.0\FKBridge.exe
```

Must return `True`.

---

### 4.3 Frontend npm install and build

```powershell
cd C:\EcaAfrica\frontend
npm install
npm run build
```

The build takes 2–3 minutes. You should see `✓ Compiled successfully` at the end.

Confirm the build output exists:

```powershell
Test-Path C:\EcaAfrica\frontend\.next
```

Must return `True`.

---

## Part 5 — Manual Test Run

Before installing as services, verify everything works manually.

### 5.1 Start the backend

Open a new PowerShell window as Administrator:

```powershell
cd C:\EcaAfrica\backend
node server.js
```

You should see:

```
FK Attendance Backend running on http://localhost:5000
Starting FK bridge: ...FKBridge.exe
FK bridge ready
Auto-connect attempt #1: 192.168.1.76:5005
Auto-connect: connected successfully to 192.168.1.76
[Time Sync] Device clock synced to tablet time: ...
```

### 5.2 Start the frontend

Open another PowerShell window as Administrator:

```powershell
cd C:\EcaAfrica\frontend
npm run start
```

You should see:

```
▲ Next.js
- Local: http://localhost:3000
✓ Ready
```

### 5.3 Health check

```powershell
Invoke-RestMethod http://localhost:5000/api/health | ConvertTo-Json
```

Expected: `"status": "ok"`, `"bridgeReady": true`

### 5.4 Open the dashboard

Open Chrome and go to: **http://localhost:3000**

Confirm the dashboard loads and the device shows as Online.

If everything works, press `Ctrl+C` in both PowerShell windows to stop the servers, then continue to Part 6.

---

## Part 6 — Install as Auto-Start Windows Services

Services run automatically on every boot as **SYSTEM** (full Administrator) — no manual start ever needed.

### 6.1 Download NSSM

NSSM wraps any executable as a Windows service.

```powershell
# Download
Invoke-WebRequest -Uri "https://nssm.cc/release/nssm-2.24.zip" -OutFile "$env:TEMP\nssm.zip" -UseBasicParsing

# Extract
Expand-Archive -Path "$env:TEMP\nssm.zip" -DestinationPath $env:TEMP -Force

# Copy the 64-bit version to tools folder
Copy-Item "$env:TEMP\nssm-2.24\win64\nssm.exe" C:\EcaAfrica\tools\nssm.exe -Force
```

Verify:

```powershell
C:\EcaAfrica\tools\nssm.exe version
```

---

### 6.2 Find the Node.js executable path

```powershell
$nodeExe = (Get-Command node.exe).Source
Write-Output $nodeExe
```

Save this path — you will use it in the next steps. It is usually:
`C:\Program Files\nodejs\node.exe`

---

### 6.3 Install EcaAfrica-Bridge service (backend)

```powershell
$nssm    = "C:\EcaAfrica\tools\nssm.exe"
$nodeExe = (Get-Command node.exe).Source

# Install service
& $nssm install EcaAfrica-Bridge $nodeExe "server.js"
& $nssm set EcaAfrica-Bridge AppDirectory     "C:\EcaAfrica\backend"
& $nssm set EcaAfrica-Bridge DisplayName      "EcaAfrica Bridge (FK623 + WireGuard)"
& $nssm set EcaAfrica-Bridge Description      "Manages FK623 biometric device, WireGuard VPN, attendance sync"
& $nssm set EcaAfrica-Bridge Start            SERVICE_AUTO_START
& $nssm set EcaAfrica-Bridge ObjectName       LocalSystem
& $nssm set EcaAfrica-Bridge AppStdout        "C:\EcaAfrica\logs\bridge.log"
& $nssm set EcaAfrica-Bridge AppStderr        "C:\EcaAfrica\logs\bridge-err.log"
& $nssm set EcaAfrica-Bridge AppRotateFiles   1
& $nssm set EcaAfrica-Bridge AppRotateBytes   10485760
& $nssm set EcaAfrica-Bridge AppRestartDelay  3000
& $nssm set EcaAfrica-Bridge DependOnService  Tcpip

# Crash recovery — restart at 5s, 10s, 30s
sc.exe failure EcaAfrica-Bridge reset= 86400 actions= restart/5000/restart/10000/restart/30000
```

---

### 6.4 Install EcaAfrica-Frontend service

```powershell
$nssm    = "C:\EcaAfrica\tools\nssm.exe"
$nodeExe = (Get-Command node.exe).Source
$nextBin = "C:\EcaAfrica\frontend\node_modules\next\dist\bin\next"

# Install service
& $nssm install EcaAfrica-Frontend $nodeExe "`"$nextBin`" start --port 3000"
& $nssm set EcaAfrica-Frontend AppDirectory     "C:\EcaAfrica\frontend"
& $nssm set EcaAfrica-Frontend DisplayName      "EcaAfrica Frontend (tablet dashboard)"
& $nssm set EcaAfrica-Frontend Description      "Serves the attendance dashboard on http://localhost:3000"
& $nssm set EcaAfrica-Frontend Start            SERVICE_AUTO_START
& $nssm set EcaAfrica-Frontend ObjectName       LocalSystem
& $nssm set EcaAfrica-Frontend AppStdout        "C:\EcaAfrica\logs\frontend.log"
& $nssm set EcaAfrica-Frontend AppStderr        "C:\EcaAfrica\logs\frontend-err.log"
& $nssm set EcaAfrica-Frontend AppRotateFiles   1
& $nssm set EcaAfrica-Frontend AppRotateBytes   10485760
& $nssm set EcaAfrica-Frontend AppRestartDelay  3000
& $nssm set EcaAfrica-Frontend DependOnService  EcaAfrica-Bridge

sc.exe failure EcaAfrica-Frontend reset= 86400 actions= restart/5000/restart/10000/restart/30000
```

---

### 6.5 Start the services

```powershell
Start-Service EcaAfrica-Bridge
Start-Sleep 5
Start-Service EcaAfrica-Frontend
```

---

### 6.6 Verify services are running

```powershell
Get-Service EcaAfrica-Bridge, EcaAfrica-Frontend
```

Both must show `Status: Running`.

Check the health endpoint:

```powershell
Start-Sleep 10
Invoke-RestMethod http://localhost:5000/api/health | Select-Object status, bridgeReady
```

---

### 6.7 Service management commands (for future use)

```powershell
# Check status
Get-Service EcaAfrica-Bridge, EcaAfrica-Frontend

# Stop
Stop-Service EcaAfrica-Bridge
Stop-Service EcaAfrica-Frontend

# Start
Start-Service EcaAfrica-Bridge
Start-Service EcaAfrica-Frontend

# Restart
Restart-Service EcaAfrica-Bridge
Restart-Service EcaAfrica-Frontend

# View logs
Get-Content C:\EcaAfrica\logs\bridge-err.log -Tail 50
Get-Content C:\EcaAfrica\logs\frontend-err.log -Tail 50

# Remove a service completely
C:\EcaAfrica\tools\nssm.exe remove EcaAfrica-Bridge confirm
C:\EcaAfrica\tools\nssm.exe remove EcaAfrica-Frontend confirm
```

---

## Part 7 — System Hardening

These commands make the services fully automatic — no prompts, no manual starts after reboots.

### 7.1 Suppress UAC (dedicated kiosk tablet)

```powershell
$uacKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty $uacKey EnableLUA                  0 -Type DWord
Set-ItemProperty $uacKey ConsentPromptBehaviorAdmin 0 -Type DWord
Set-ItemProperty $uacKey PromptOnSecureDesktop      0 -Type DWord
```

> This removes all UAC prompts. Only do this on a dedicated attendance tablet.

---

### 7.2 Disable Fast Startup

Fast Startup can cause services to miss their auto-start on shutdown/boot.

```powershell
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" HiberbootEnabled 0 -Type DWord
```

---

### 7.3 Extend service startup timeout

Prevents Windows from killing slow-starting services:

```powershell
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control" ServicesPipeTimeout 120000 -Type DWord
```

---

### 7.4 Allow PowerShell scripts to run without prompts

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force
```

---

### 7.5 Register WireGuard Manager for auto-start

```powershell
Set-Service WireGuardManager -StartupType Automatic
sc.exe failure WireGuardManager reset= 86400 actions= restart/3000/restart/5000/restart/10000
Start-Service WireGuardManager -ErrorAction SilentlyContinue
```

---

### 7.6 Add firewall rule for FK623 device

```powershell
New-NetFirewallRule -DisplayName "EcaAfrica Device TCP 5005" `
    -Direction Inbound -Protocol TCP -LocalPort 5005 -Action Allow -Profile Any
```

---

### 7.7 Create boot health-check scheduled task

This task runs 90 seconds after every boot and login. It restarts any stopped service automatically.

```powershell
# Write the health check script
@'
Start-Sleep -Seconds 90
$services = @('EcaAfrica-Bridge','EcaAfrica-Frontend','WireGuardManager')
foreach ($s in $services) {
    $svc = Get-Service $s -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -ne 'Running') { Start-Service $s -ErrorAction SilentlyContinue }
}
$wg = Get-Service 'WireGuardTunnel$EcareAfrica' -ErrorAction SilentlyContinue
if ($wg -and $wg.Status -ne 'Running') { Start-Service 'WireGuardTunnel$EcareAfrica' -ErrorAction SilentlyContinue }
'@ | Set-Content C:\EcaAfrica\tools\boot-check.ps1 -Encoding UTF8

# Register the scheduled task
$action   = New-ScheduledTaskAction -Execute "powershell.exe" `
                -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"C:\EcaAfrica\tools\boot-check.ps1`""
$trigger1 = New-ScheduledTaskTrigger -AtStartup
$trigger2 = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
                -StartWhenAvailable -RunOnlyIfNetworkAvailable:$false -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask "EcaAfrica-Boot-Ensure" `
    -Action $action -Trigger @($trigger1, $trigger2) `
    -Settings $settings -Principal $principal `
    -Description "Ensures EcaAfrica + WireGuard start on every boot" -Force
```

---

## Part 8 — WireGuard VPN Setup

Do this after the services are running. Open Chrome → **http://localhost:3000** and use the WireGuard VPN wizard in the sidebar. The commands below are what happens behind the scenes and what you need to run on the server.

### 8.1 Generate keys (on the tablet)

In the dashboard sidebar, click **WireGuard VPN** → enter password `admin1234` → click **Generate Keys**.

This runs internally:

```
wg genkey > private.key
wg pubkey < private.key > public.key
```

Keys are saved to:
- `C:\EcaAfrica\backend\data\wireguard-private.key` (never share)
- `C:\EcaAfrica\backend\data\wireguard-public.key` (send to Super Admin)

---

### 8.2 Add tablet as peer on the server (Super Admin does this)

SSH into the server and run:

```bash
ssh root@169.58.124.150

# Replace with the tablet's actual public key and assigned VPN IP
wg set wg0 peer <TABLET_PUBLIC_KEY> allowed-ips <TABLET_VPN_IP>/32

# Example:
wg set wg0 peer x9zmQduWk7C2q47KYLwH3Xm/o+2aJZzlVKikrJt6I1M= allowed-ips 10.0.0.2/32

# Save so it persists after server reboot
wg-quick save wg0

# Confirm peer was added
wg show
```

Get the server's public key to give back to the technician:

```bash
cat /etc/wireguard/server_public.key
```

---

### 8.3 Write the WireGuard config file (on the tablet)

Replace `<PRIVATE_KEY>` with contents of `wireguard-private.key`, `<SERVER_PUBLIC_KEY>` with what the Super Admin gave you, and `<TABLET_VPN_IP>` with your assigned IP (e.g. `10.0.0.2`):

```powershell
@"
[Interface]
PrivateKey = <PRIVATE_KEY>
Address = <TABLET_VPN_IP>/24
DNS = 1.1.1.1

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
AllowedIPs = 10.0.0.0/16
Endpoint = 169.58.124.150:51820
PersistentKeepalive = 25
"@ | Set-Content "C:\ProgramData\WireGuard\EcareAfrica.conf" -Encoding UTF8
```

> Alternatively, use the WireGuard wizard in the dashboard (Step 3 — Configure) which writes this file automatically.

---

### 8.4 Install the WireGuard tunnel as a Windows service

```powershell
# Requires Administrator — runs elevated via Start-Process
Start-Process -FilePath "C:\Program Files\WireGuard\wireguard.exe" `
    -ArgumentList "/installtunnelservice","C:\ProgramData\WireGuard\EcareAfrica.conf" `
    -Verb RunAs -Wait
```

Set tunnel to auto-start on boot:

```powershell
sc.exe config "WireGuardTunnel`$EcareAfrica" start= auto
sc.exe failure "WireGuardTunnel`$EcareAfrica" reset= 86400 actions= restart/5000/restart/10000/restart/30000
```

---

### 8.5 Verify the tunnel is active

```powershell
# Check VPN IP is assigned
ipconfig | Select-String "10\.0\."

# Check Windows service
sc.exe query "WireGuardTunnel`$EcareAfrica" | Select-String "STATE"

# Ping the server through the VPN
ping -n 4 10.0.0.1
```

Expected: `Reply from 10.0.0.1: bytes=32 time=XXXms TTL=64`

If ping fails:
- Confirm the server added this tablet as a peer (`wg show` on server)
- Confirm `ufw allow 51820/udp` was run on the server
- Check the server firewall: `ufw status`

---

### 8.6 Stop / remove the tunnel (if needed)

```powershell
Start-Process -FilePath "C:\Program Files\WireGuard\wireguard.exe" `
    -ArgumentList "/uninstalltunnelservice","EcareAfrica" `
    -Verb RunAs -Wait
```

---

## Part 9 — Chrome Kiosk Auto-Open on Login

Chrome opens the attendance dashboard automatically 30 seconds after every login.

### 9.1 Register Chrome as a scheduled task (opens 30s after login)

```powershell
$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$chromeArgs = "--kiosk http://localhost:3000 --disable-infobars --no-first-run --disable-session-crashed-bubble"

$action    = New-ScheduledTaskAction -Execute $chromePath -Argument $chromeArgs
$trigger   = New-ScheduledTaskTrigger -AtLogOn
$trigger.Delay = "PT30S"   # 30-second delay so services start first

$settings  = New-ScheduledTaskSettingsSet `
                -ExecutionTimeLimit (New-TimeSpan -Hours 12) `
                -MultipleInstances IgnoreNew

$principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest

Register-ScheduledTask "EcaAfrica-OpenDashboard" `
    -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal `
    -Description "Opens EcaAfrica dashboard in Chrome 30s after login" -Force
```

Verify:

```powershell
Get-ScheduledTask "EcaAfrica-OpenDashboard" | Select-Object TaskName, State
```

---

### 9.2 Remove the Chrome task (if needed)

```powershell
Unregister-ScheduledTask "EcaAfrica-OpenDashboard" -Confirm:$false
```

---

## Part 10 — Set Tablet UUID After Portal Registration

After the Super Admin registers this tablet in the portal:

```powershell
# Edit .env — replace YOUR-UUID-HERE with the UUID from the portal
$envFile = "C:\EcaAfrica\backend\.env"
$content = Get-Content $envFile -Raw
$content = $content -replace "TABLET_UUID=.*", "TABLET_UUID=YOUR-UUID-HERE"
Set-Content $envFile $content -Encoding UTF8

# Restart the backend service to apply the change
Restart-Service EcaAfrica-Bridge
```

---

## Part 11 — Update Code (Future)

When new code is available on GitHub:

```powershell
# Stop services
Stop-Service EcaAfrica-Frontend
Stop-Service EcaAfrica-Bridge
Get-Process FKBridge -ErrorAction SilentlyContinue | Stop-Process -Force

# Pull latest code
cd C:\EcaAfrica
git pull origin Testing-Branch

# Install any new backend dependencies
cd C:\EcaAfrica\backend
npm install

# Rebuild FKBridge if changed
$dotnet = "C:\Program Files (x86)\dotnet\dotnet.exe"
cd C:\EcaAfrica\FKBridge
& $dotnet build FKBridge.csproj -c Release

# Rebuild frontend if changed
cd C:\EcaAfrica\frontend
npm install
npm run build

# Restart services
Start-Service EcaAfrica-Bridge
Start-Sleep 5
Start-Service EcaAfrica-Frontend
```

---

## Part 12 — Complete Checklist

Use this to verify everything is set up correctly:

```
INSTALLED SOFTWARE
[ ] Node.js v20+          — node --version
[ ] .NET 8 SDK x86        — C:\Program Files (x86)\dotnet\dotnet.exe --list-sdks
[ ] Git                   — git --version
[ ] WireGuard             — C:\Program Files\WireGuard\wg.exe --version
[ ] Google Chrome         — C:\Program Files\Google\Chrome\Application\chrome.exe

CODE
[ ] C:\EcaAfrica\backend\server.js exists
[ ] C:\EcaAfrica\FKBridge\bin\Release\net8.0\FKBridge.exe exists
[ ] C:\EcaAfrica\frontend\.next exists

CONFIG FILES
[ ] C:\EcaAfrica\backend\.env exists (TABLET_UUID filled after portal registration)
[ ] C:\EcaAfrica\backend\data\device-config.json exists (correct FK623 IP)
[ ] C:\EcaAfrica\frontend\.env.local exists

SERVICES
[ ] EcaAfrica-Bridge   — Get-Service EcaAfrica-Bridge   → Running
[ ] EcaAfrica-Frontend — Get-Service EcaAfrica-Frontend → Running
[ ] WireGuardManager   — Get-Service WireGuardManager   → Running

HEALTH CHECK
[ ] http://localhost:5000/api/health → status: ok, bridgeReady: true
[ ] http://localhost:3000            → dashboard loads

WIREGUARD
[ ] Tunnel installed — sc.exe query WireGuardTunnel$EcareAfrica → RUNNING
[ ] Ping server VPN  — ping 10.0.0.1 → Reply from 10.0.0.1
[ ] Tablet public key sent to Super Admin
[ ] Super Admin confirmed peer added on server

KIOSK
[ ] Chrome task registered — Get-ScheduledTask EcaAfrica-OpenDashboard → Ready
[ ] Reboot tablet — Chrome opens dashboard automatically after 30s
```

---

## Passwords and Keys Reference

| Item | Value | Where used |
|------|-------|-----------|
| Developer modal password | `admin1234` | Dashboard → Developer / WireGuard VPN buttons |
| WireGuard private key | `C:\EcaAfrica\backend\data\wireguard-private.key` | Never share |
| WireGuard public key | `C:\EcaAfrica\backend\data\wireguard-public.key` | Send to Super Admin |
| Tablet UUID | Set in `C:\EcaAfrica\backend\.env` | From Super Admin portal |
| FK623 device IP | Set in `device-config.json` | Local school network |
| Server URL | `https://backend.ecareafrica.net/api/v1` | Can change via Developer modal |

---

*EcaAfrica Biometric Attendance System — Manual Full Setup Guide*  
*September 2026*
