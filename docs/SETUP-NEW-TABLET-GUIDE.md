# EcaAfrica — New Tablet Setup Guide

**Document**: SETUP-NEW-TABLET-GUIDE  
**Date**: September 12, 2026  
**Applies to**: Any brand new Windows 10/11 tablet being deployed to a school  
**Setup method**: Single double-click — fully automated

---

## The Short Version

Copy the EcaAfrica folder to the tablet, then:

```
Double-click → SETUP-NEW-TABLET.bat → Click YES → Wait 5-10 minutes → Reboot
```

That is the entire setup. Everything else is automatic.

---

## What Gets Installed and Configured Automatically

When you double-click `SETUP-NEW-TABLET.bat`, the script runs 10 steps automatically with no human input:

| Step | What happens |
|------|-------------|
| 1 | Installs Node.js, .NET 8 SDK x86, Git, WireGuard, Google Chrome |
| 2 | Downloads the latest EcaAfrica code from GitHub (Testing-Branch) |
| 3 | Writes `device-config.json`, `backend/.env`, `frontend/.env.local` |
| 4 | Runs `npm install` (backend + frontend), `dotnet build` (FKBridge), `npm run build` (frontend) |
| 5 | Downloads NSSM (service manager) |
| 6 | Installs `EcaAfrica-Bridge` and `EcaAfrica-Frontend` as Windows services that run as SYSTEM |
| 7 | Sets WireGuard Manager and tunnel to auto-start with crash-restart |
| 8 | Suppresses UAC, disables Fast Startup, creates boot health-check task |
| 9 | Adds Chrome scheduled task — opens dashboard 30 seconds after every login |
| 10 | Starts all services and does an HTTP health check |

---

## Before You Start

### Requirements

| Item | Details |
|------|---------|
| OS | Windows 10 64-bit or Windows 11 |
| RAM | 4 GB minimum |
| Storage | 10 GB free |
| Internet | Required — downloads ~500 MB of software |
| Time | 5–10 minutes |

### How to get the EcaAfrica folder on the tablet

**Option A — USB drive** (no internet needed at this step):  
Copy the entire `EcaAfrica` folder from another tablet or from a USB stick.

**Option B — Download from GitHub**:  
Open a browser on the tablet and go to:  
`https://github.com/Byiringiro24/Tablet_Setup/archive/refs/heads/Testing-Branch.zip`  
Extract the ZIP anywhere (e.g. `C:\EcaAfrica-setup`).

Either way, find `SETUP-NEW-TABLET.bat` in the folder and double-click it.

> The script always clones fresh code from GitHub to `C:\EcaAfrica` regardless of where you run it from. The source folder is only needed for the `.bat` and `.ps1` files.

---

## Step-by-Step Explanation

### Step 1 — Software Installation

The script downloads and silently installs each required tool:

**Node.js v20 LTS** — the backend server runs on Node.js.  
Downloaded from: `https://nodejs.org/dist/v20.19.0/node-v20.19.0-x64.msi`  
If already installed, this step is skipped automatically.

**.NET 8 Desktop Runtime x86** — the FK623 biometric device DLL is 32-bit and requires the x86 runtime specifically. The 64-bit runtime will not work.  
Downloaded from: `https://aka.ms/dotnet/8.0/windowsdesktop-runtime-win-x86.exe`

**.NET 8 SDK x86** — needed to compile `FKBridge.exe` from source code.  
Downloaded from: `https://aka.ms/dotnet/8.0/dotnet-sdk-win-x86.exe`

**Git** — used to clone and update the code from GitHub.  
Downloaded from: `https://github.com/git-for-windows/git/releases`

**WireGuard** — VPN client for secure connection to the EcaAfrica server.  
Downloaded from: `https://download.wireguard.com/windows-client/wireguard-installer.exe`

**Google Chrome** — the dashboard runs at `http://localhost:3000` and opens in Chrome automatically.  
Downloaded from: `https://dl.google.com/chrome/install/ChromeSetup.exe`

All installs are silent — no windows appear, no clicks needed.

---

### Step 2 — Clone Code from GitHub

The script clones the repository to `C:\EcaAfrica`:

```
git clone --branch Testing-Branch https://github.com/Byiringiro24/Tablet_Setup.git C:\EcaAfrica
```

If `C:\EcaAfrica` already exists and is a git repo, it runs `git pull` instead.  
If it exists but is not a git repo, it removes it and clones fresh.

The folder structure after cloning:
```
C:\EcaAfrica\
├── backend\           ← Node.js backend (port 5000)
├── frontend\          ← Next.js frontend (port 3000)
├── FKBridge\          ← C# bridge to FK623 DLL
├── docs\              ← Documentation
├── tools\             ← NSSM downloaded here
├── logs\              ← Service logs written here
└── SETUP-NEW-TABLET.bat
```

---

### Step 3 — Configuration Files

Three files are written automatically:

**`C:\EcaAfrica\backend\data\device-config.json`**  
Contains the FK623 biometric device IP address and connection settings.

```json
{
  "ipAddress": "192.168.1.76",
  "port": 5005,
  "license": 1261,
  "deviceId": "DV-KGL-01",
  "netPassword": 0,
  "protocolType": -1,
  "timeoutMs": 10000
}
```

> **Important**: The default IP is `192.168.1.76`. If the FK623 device on your school network has a different IP, update it after setup via the Developer panel in the dashboard, or edit this file directly.

**`C:\EcaAfrica\backend\.env`**  
Contains server URL, tablet identity, and WireGuard settings.

```env
PORT=5000
SERVER_API_URL=https://backend.ecareafrica.net/api/v1
TABLET_UUID=                         ← fill this after Step B below
WG_SERVER_ENDPOINT=169.58.124.150:51820
VPN_ALLOWED_IPS=10.0.0.0/16
WG_DNS=1.1.1.1
```

**`C:\EcaAfrica\frontend\.env.local`**  
Tells the frontend where the backend API is.

```env
NEXT_PUBLIC_API_URL=http://localhost:5000
```

---

### Step 4 — Build

Three build commands run automatically:

```powershell
# Backend dependencies
cd C:\EcaAfrica\backend
npm install

# FKBridge — compiles the C# bridge to FKBridge.exe
cd C:\EcaAfrica\FKBridge
dotnet build -c Release
# Output: C:\EcaAfrica\FKBridge\bin\Release\net8.0\FKBridge.exe

# Frontend — builds the Next.js dashboard for production
cd C:\EcaAfrica\frontend
npm install
npm run build
# Output: C:\EcaAfrica\frontend\.next\
```

The frontend build takes 2–3 minutes. This is normal.

---

### Step 5 — NSSM

NSSM (Non-Sucking Service Manager) is a tool that wraps any executable as a Windows service. It is downloaded from `https://nssm.cc/release/nssm-2.24.zip` and saved to `C:\EcaAfrica\tools\nssm.exe`.

---

### Step 6 — Windows Services

Two services are installed using NSSM:

**`EcaAfrica-Bridge`** (port 5000)
- Runs: `node server.js` in `C:\EcaAfrica\backend`
- Account: LocalSystem (= full Administrator)
- Startup: Automatic
- Crash recovery: restarts at 5s, 10s, 30s
- Logs: `C:\EcaAfrica\logs\EcaAfrica-Bridge.err.log`

**`EcaAfrica-Frontend`** (port 3000)
- Runs: `node next start --port 3000` in `C:\EcaAfrica\frontend`
- Account: LocalSystem (= full Administrator)
- Startup: Automatic (depends on EcaAfrica-Bridge)
- Crash recovery: restarts at 5s, 10s, 30s
- Logs: `C:\EcaAfrica\logs\EcaAfrica-Frontend.err.log`

Because both services run as **LocalSystem (SYSTEM)**, they have full administrator rights automatically — this is why WireGuard tunnel installation works from the dashboard without UAC prompts.

To manage services manually:

```powershell
# Check status
Get-Service EcaAfrica-Bridge, EcaAfrica-Frontend

# Restart
Restart-Service EcaAfrica-Bridge
Restart-Service EcaAfrica-Frontend

# View logs
Get-Content C:\EcaAfrica\logs\EcaAfrica-Bridge.err.log -Tail 50
Get-Content C:\EcaAfrica\logs\EcaAfrica-Frontend.err.log -Tail 50
```

---

### Step 7 — WireGuard Auto-Start

The script sets WireGuard Manager to auto-start on boot:

```powershell
sc.exe config WireGuardManager start= auto
sc.exe failure WireGuardManager reset= 86400 actions= restart/3000/restart/5000/restart/10000
```

The WireGuard **tunnel** (`WireGuardTunnel$EcareAfrica`) is NOT configured here because the keys and server details don't exist yet on a new tablet. The tunnel is set up later using the WireGuard wizard in the dashboard (see After Reboot steps below).

Once the tunnel is configured via the wizard, it installs itself as a Windows service and auto-starts from then on.

---

### Step 8 — System Hardening

Four registry and system changes are made:

**UAC suppressed**  
```
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System
  EnableLUA = 0
  ConsentPromptBehaviorAdmin = 0
  PromptOnSecureDesktop = 0
```
This is appropriate for a dedicated kiosk/attendance tablet. It means no UAC prompts ever appear — WireGuard installs silently from the dashboard.

**Fast Startup disabled**  
```
HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power
  HiberbootEnabled = 0
```
Windows Fast Startup can cause services to not start after a shutdown because it hibernates the kernel. Disabling it ensures a clean boot every time.

**Service startup timeout extended**  
```
HKLM\SYSTEM\CurrentControlSet\Control
  ServicesPipeTimeout = 120000 (2 minutes)
```
Prevents Windows from killing slow-starting services (especially the frontend build on first boot).

**Boot health-check scheduled task**  
A PowerShell script `C:\EcaAfrica\tools\boot-check.ps1` is registered as a scheduled task that runs 90 seconds after every boot and every login, as SYSTEM. It checks if any service is stopped and restarts it. This is the safety net for edge cases where a service misses its auto-start.

**PowerShell ExecutionPolicy set to Bypass**  
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine -Force
```
Ensures PowerShell scripts always run without prompts on this machine.

---

### Step 9 — Chrome Kiosk Auto-Open

A Windows scheduled task `EcaAfrica-OpenDashboard` is created:
- Trigger: At logon (for all users)
- Delay: 30 seconds (waits for services to finish starting)
- Action: Opens Chrome in kiosk mode at `http://localhost:3000`

```
chrome.exe --kiosk http://localhost:3000 --disable-infobars --no-first-run
```

The 30-second delay is critical — without it Chrome opens before the frontend service is ready and shows a connection error.

---

### Step 10 — Start and Verify

Services are started and HTTP checks confirm everything is working:

```
http://localhost:5000/api/health  → {"status":"ok","bridgeReady":true,...}
http://localhost:3000             → dashboard HTML
```

---

## After Reboot — 3 Manual Steps

After the script finishes and you reboot, three things still need manual action:

### A — Update the FK623 Device IP (if different from 192.168.1.76)

1. Open Chrome → `http://localhost:3000`
2. Hover the sidebar → click **Developer** (bottom, amber icon)
3. Enter password: `admin1234`
4. Update **IP Address** to the correct FK623 device IP
5. Click **Save & Reconnect**

---

### B — Register Tablet and Set TABLET_UUID

1. Open `https://backend.ecareafrica.net` (Super Admin portal)
2. Go to **Hardware → Tablets → Add Tablet**
3. Fill in: school name, location, device label
4. Copy the **TABLET_UUID** generated
5. Open `C:\EcaAfrica\backend\.env` in Notepad
6. Set: `TABLET_UUID=<paste UUID here>`
7. Save the file, then run in PowerShell:
   ```powershell
   Restart-Service EcaAfrica-Bridge
   ```

---

### C — Set Up WireGuard VPN

1. Open Chrome → `http://localhost:3000`
2. Hover the sidebar → click **WireGuard VPN** (shield icon)
3. Enter password: `admin1234`
4. The wizard opens — follow Steps 1–5:

| Wizard Step | Action |
|------------|--------|
| 1 — Install | Confirms WireGuard is installed — already done |
| 2 — Keys | Click **Generate Keys** → copy the public key → send to Super Admin |
| 3 — Configure | Paste server public key + VPN IP from Super Admin |
| 4 — Activate | Click **Save & Activate Tunnel** — tunnel installs as Windows service |
| 5 — Ping Test | Click **Ping** → confirm green result |

The Super Admin adds the tablet on the server:
```bash
ssh root@169.58.124.150
wg set wg0 peer <TABLET_PUBLIC_KEY> allowed-ips <TABLET_VPN_IP>/32
wg-quick save wg0
```

---

## Troubleshooting

### Services won't start

```powershell
# Check status
Get-Service EcaAfrica-Bridge, EcaAfrica-Frontend

# Read error log
Get-Content C:\EcaAfrica\logs\EcaAfrica-Bridge.err.log -Tail 100

# Common causes:
# - Port 5000 or 3000 already in use: Stop-Process -Name node -Force
# - .NET x86 not installed: run setup again
# - FKBridge.exe missing: cd C:\EcaAfrica\FKBridge && dotnet build -c Release
```

### Frontend build fails or .next folder missing

```powershell
Stop-Service EcaAfrica-Frontend
cd C:\EcaAfrica\frontend
npm run build
Start-Service EcaAfrica-Frontend
```

### Node.js not found after install

Close the terminal, open a new PowerShell as Administrator and run:
```powershell
$env:PATH += ";C:\Program Files\nodejs"
node --version
```
If it works, run `Restart-Service EcaAfrica-Bridge` — the service doesn't need PATH because it uses the full path to `node.exe` internally.

### WireGuard tunnel not activating

The tunnel requires the backend service to run as SYSTEM (which it does). If activation fails:
```powershell
# Check if SYSTEM is running the service
sc.exe qc EcaAfrica-Bridge | findstr "ACCOUNT"
# Should show: SERVICE_START_NAME : LocalSystem

# Re-run Step 8 from set-admin-permanent.ps1
powershell -ExecutionPolicy Bypass -File C:\EcaAfrica\set-admin-permanent.ps1
```

### Dashboard shows "Device Offline"

The FK623 biometric device IP is wrong or the device is off. Check:
```powershell
# Ping the device
ping 192.168.1.76

# If no response, find the correct IP from your router's DHCP table
# Then update via: Developer modal → IP Address field
```

---

## Files Reference

| File | Purpose |
|------|---------|
| `SETUP-NEW-TABLET.bat` | **Entry point** — double-click this |
| `setup-new-tablet.ps1` | Full automated setup script (10 steps) |
| `install-services.ps1` | Installs services only (existing tablet update) |
| `set-admin-permanent.ps1` | Hardens existing tablet (SYSTEM, no UAC) |
| `run-as-admin.bat` | Runs backend manually as Admin (debug use) |
| `uninstall-services.ps1` | Removes all services (before reinstall) |
| `C:\EcaAfrica\backend\.env` | Tablet config — edit TABLET_UUID here |
| `C:\EcaAfrica\backend\data\device-config.json` | FK623 device IP |
| `C:\EcaAfrica\logs\*.err.log` | Service error logs |
| `C:\EcaAfrica\tools\boot-check.ps1` | Boot health-check (auto-generated) |

---

## Passwords Reference

| Password | Where used |
|----------|-----------|
| `admin1234` | Developer panel in dashboard (device IP, settings) |
| `admin1234` | WireGuard VPN wizard in dashboard |

---

*Document: SETUP-NEW-TABLET-GUIDE*  
*EcaAfrica Biometric Attendance System*
