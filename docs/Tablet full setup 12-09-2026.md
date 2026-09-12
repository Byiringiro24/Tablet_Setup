# Tablet Full Setup — 12-09-2026

**Project**: EcaAfrica Biometric Attendance System  
**Document version**: 1.0  
**Date**: September 12, 2026  
**Prepared by**: EcaAfrica DevOps  

---

## Overview

This document covers the complete setup of a Windows tablet for the EcaAfrica attendance system — from a fresh Windows machine to a fully running, auto-starting production setup including the biometric device bridge, web frontend, WireGuard VPN, and all required software.

**What runs on the tablet:**

```
┌─────────────────────────────────────────────────────────┐
│  Web Browser → http://localhost:3000                    │
│  EcaAfrica-Frontend  (Next.js  — port 3000)             │
│         ↕                                               │
│  EcaAfrica-Bridge    (Node.js  — port 5000)             │
│         ↕                                               │
│  FKBridge.exe        (.NET 8 — auto-spawned)            │
│         ↕  TCP                                          │
│  FK623 Biometric Device  (LAN — port 5005)              │
│         ↕  WireGuard VPN (UDP 51820)                    │
│  EcaAfrica Server    (169.58.124.150)                   │
└─────────────────────────────────────────────────────────┘
```

---

## Part 1 — Prerequisites

### 1.1 Hardware Requirements

| Item | Minimum |
|------|---------|
| OS | Windows 10 64-bit or Windows 11 |
| RAM | 4 GB |
| Storage | 10 GB free |
| Network | WiFi or Ethernet — must reach the FK623 device and the internet |

### 1.2 Required Software Downloads

Download all of these before starting — saves time if there is no internet on-site.

| Software | URL | Version |
|----------|-----|---------|
| Node.js | https://nodejs.org/en/download | v18 LTS or higher |
| .NET 8 Runtime | https://dotnet.microsoft.com/download/dotnet/8.0 | .NET 8 Desktop Runtime x86 (32-bit) |
| Git | https://git-scm.com/download/win | Latest |
| WireGuard | https://www.wireguard.com/install/ | Latest |
| Google Chrome | https://www.google.com/chrome/ | Latest |

> **Important**: Install the **.NET 8 x86 (32-bit)** runtime — the FK623 DLL is 32-bit and will not work with the 64-bit runtime.

---

## Part 2 — Install Required Software

### 2.1 Install Node.js

1. Run the Node.js installer (`node-v*.msi`)
2. Accept all defaults — ensure "Add to PATH" is checked
3. Verify after install — open Command Prompt and run:

```cmd
node --version
npm --version
```

Expected output: `v20.x.x` and `10.x.x` (or higher)

### 2.2 Install .NET 8 Runtime (x86)

1. Run the installer for **.NET 8 Desktop Runtime x86**
2. Accept defaults — no configuration needed
3. Verify:

```cmd
dotnet --list-runtimes
```

You should see a line containing `Microsoft.NETCore.App 8.0` in the list.

### 2.3 Install Git

1. Run the Git installer
2. Accept all defaults
3. Verify:

```cmd
git --version
```

### 2.4 Install WireGuard

1. Run `wireguard-installer.exe`
2. Accept the UAC prompt
3. WireGuard installs silently — no configuration at this step
4. Verify:

```cmd
"C:\Program Files\WireGuard\wg.exe" --version
```

Expected: `wireguard-tools v1.x.x`

---

## Part 3 — Get the Code

### 3.1 Clone the Repository

Open Command Prompt as Administrator and run:

```cmd
cd C:\
git clone https://github.com/Byiringiro24/Tablet_Setup.git EcaAfrica
cd EcaAfrica
git checkout Testing-Branch
```

> The project folder is now at `C:\EcaAfrica\`

### 3.2 Install Backend Dependencies

```cmd
cd C:\EcaAfrica\backend
npm install
```

### 3.3 Install Frontend Dependencies

```cmd
cd C:\EcaAfrica\frontend
npm install
```

### 3.4 Build the Frontend

```cmd
cd C:\EcaAfrica\frontend
npm run build
```

This takes 1–3 minutes. You should see:
```
✓ Compiled successfully
```

### 3.5 Build FKBridge (.NET)

```cmd
cd C:\EcaAfrica\FKBridge
dotnet build -c Release
```

Expected output:
```
Build succeeded.
    0 Warning(s)
    0 Error(s)
```

---

## Part 4 — Configure the Tablet

### 4.1 Set the Biometric Device IP

Edit `C:\EcaAfrica\backend\data\device-config.json`:

```json
{
  "ipAddress": "192.168.1.XX",
  "port": 5005,
  "license": 1261,
  "deviceId": "DV-KGL-01",
  "netPassword": 0,
  "protocolType": -1,
  "timeoutMs": 10000
}
```

Replace `192.168.1.XX` with the actual IP address of the FK623 biometric device on the local network. You can find it on the device screen or from the router's DHCP table.

### 4.2 Set Environment Variables

Edit `C:\EcaAfrica\backend\.env`:

```env
PORT=5000
SERVER_API_URL=https://backend.ecareafrica.net/api/v1
TABLET_UUID=                         ← fill in after registering in portal
WG_SERVER_ENDPOINT=169.58.124.150:51820
VPN_ALLOWED_IPS=10.0.0.0/16
WG_DNS=1.1.1.1
```

The `TABLET_UUID` is generated when you register this tablet in the Super Admin portal. Leave it blank for now and fill it in after Step 7.

### 4.3 Set Frontend URL

Check `C:\EcaAfrica\frontend\.env.local`:

```env
NEXT_PUBLIC_API_URL=http://localhost:5000
```

This file should already exist after the pull. If it doesn't, create it with the line above.

---

## Part 5 — Test Run (Before Installing as Services)

Before installing as auto-start services, verify everything works manually first.

### 5.1 Start the Backend

Open Command Prompt as Administrator:

```cmd
cd C:\EcaAfrica\backend
node server.js
```

You should see:
```
FK Attendance Backend running on http://localhost:5000
Starting FK bridge: ...FKBridge.exe
FK bridge ready
Auto-connect attempt #1: 192.168.1.XX:5005
Auto-connect: connected successfully to 192.168.1.XX
[Time Sync] Device clock synced to tablet time: ...
```

### 5.2 Start the Frontend

Open a second Command Prompt:

```cmd
cd C:\EcaAfrica\frontend
npm run start
```

You should see:
```
▲ Next.js
- Local: http://localhost:3000
✓ Ready
```

### 5.3 Open the Web UI

Open Chrome and go to: **http://localhost:3000**

You should see the SmartAttend FK dashboard with the device status showing "Online".

### 5.4 Verify the API

```cmd
curl http://localhost:5000/api/health
```

Expected response includes: `"status":"ok","bridgeReady":true`

If everything works, stop both processes (`Ctrl+C` in each window) and proceed to install as services.

---

## Part 6 — Install as Windows Auto-Start Services

This is the production setup. After this, both the backend and frontend start automatically on every Windows boot — no manual action needed.

### 6.1 Run the Installer

Navigate to `C:\EcaAfrica\` in File Explorer and **double-click**:

```
INSTALL (double-click me).bat
```

This will:
1. Request Administrator privileges automatically (UAC prompt appears)
2. Download NSSM (service manager) if not already present
3. Build the frontend if not already built
4. Install `EcaAfrica-Bridge` (Node.js backend) as a Windows service
5. Install `EcaAfrica-Frontend` (Next.js frontend) as a Windows service
6. Start both services immediately
7. Verify they are running with a health check

You should see at the end:
```
============================================================
  SETUP COMPLETE
============================================================
  Both services are now installed and will start automatically
  on every Windows boot — no manual action needed.

  Bridge (backend):   http://localhost:5000
  Frontend (web UI):  http://localhost:3000
```

### 6.2 Verify Services Are Running

Open PowerShell and run:

```powershell
Get-Service EcaAfrica-Bridge, EcaAfrica-Frontend
```

Expected output:
```
Status   Name                  DisplayName
------   ----                  -----------
Running  EcaAfrica-Bridge      EcaAfrica Bridge (FK623 attendance)
Running  EcaAfrica-Frontend    EcaAfrica Frontend (tablet web UI)
```

### 6.3 Service Management Commands

```powershell
# Check status
Get-Service EcaAfrica-Bridge, EcaAfrica-Frontend

# Stop a service
Stop-Service EcaAfrica-Bridge

# Start a service
Start-Service EcaAfrica-Bridge

# Restart a service
Restart-Service EcaAfrica-Bridge

# View logs
Get-Content C:\EcaAfrica\logs\bridge-err.log -Tail 50
Get-Content C:\EcaAfrica\logs\frontend-err.log -Tail 50

# Uninstall all services (before reinstalling or moving folder)
C:\EcaAfrica\uninstall-services.ps1
```

### 6.4 What Happens on Reboot

After a Windows restart:
1. Windows starts `EcaAfrica-Bridge` automatically (runs as SYSTEM — full admin)
2. `EcaAfrica-Bridge` spawns `FKBridge.exe` and connects to the FK623 device
3. `EcaAfrica-Frontend` starts after `EcaAfrica-Bridge` is running
4. Open Chrome → `http://localhost:3000` — dashboard is live

---

## Part 7 — Register the Tablet in the Portal

1. Log in to the Super Admin portal at `https://backend.ecareafrica.net`
2. Navigate to **Hardware → Tablets → Add Tablet**
3. Fill in: School name, gate location, device label
4. The portal generates a **TABLET_UUID** — copy it
5. Edit `C:\EcaAfrica\backend\.env` and paste the UUID:
   ```env
   TABLET_UUID=your-uuid-here
   ```
6. Restart the backend service:
   ```powershell
   Restart-Service EcaAfrica-Bridge
   ```

---

## Part 8 — WireGuard VPN Setup

The VPN connects the tablet to the EcaAfrica server so attendance data syncs securely. WireGuard is already installed (Part 2.4). The rest is done from the web UI.

### 8.1 Open the WireGuard Wizard

1. Open Chrome → `http://localhost:3000`
2. Hover over the left sidebar to reveal it
3. Click **WireGuard VPN** (shield icon at the bottom of the sidebar)
4. Enter the admin password: `admin1234`
5. The wizard opens — it auto-detects WireGuard is installed and jumps to Step 2

### 8.2 Step 2 — Generate Keys

1. Click **Generate Keys**
2. The system generates a real Curve25519 key pair using `wg genkey` + `wg pubkey`
3. You see:
   - **Private Key** — masked, saved to `backend/data/wireguard-private.key` (never leaves tablet)
   - **Public Key** — shown in full, click **Copy** to copy it
4. **Send the public key to the Super Admin** via WhatsApp, email, or the portal
5. The wizard shows the exact command the Super Admin needs to run on the server

### 8.3 Step 3 — Configure (after Super Admin confirms peer added)

Wait for the Super Admin to confirm they have added this tablet on the server, then:

1. Paste the **Server Public Key** (get it from Super Admin — from `cat /etc/wireguard/server_public.key` on server)
2. **Server Endpoint** is pre-filled: `169.58.124.150:51820` — leave as-is
3. **Tablet VPN IP** — enter the IP assigned by Super Admin (e.g. `10.0.0.2`)
4. **DNS** — leave as `1.1.1.1`
5. Click **Save & Activate Tunnel**

The wizard writes `C:\ProgramData\WireGuard\EcareAfrica.conf` and installs the tunnel as a Windows service.

### 8.4 Step 4 — Verify Tunnel Active

The wizard moves to Step 4 and shows:
- **Tunnel Active — EcareAfrica** ✅
- **VPN IP**: 10.0.0.2

If it shows inactive:
- Confirm the Super Admin ran `wg set wg0 peer ... allowed-ips 10.0.0.2/32` on the server
- Check server firewall: `ufw allow 51820/udp`
- The backend service runs as SYSTEM (admin) so it can manage WireGuard

### 8.5 Step 5 — Ping Test

1. Click **Test Connection →**
2. Target IP is pre-filled: `10.0.0.1` (server VPN IP)
3. Click **Ping**
4. If successful: green banner — **VPN tunnel fully verified** ✅
5. If timeout: the server has not added this tablet as a peer yet

### 8.6 What the Super Admin Runs on the Server

The Super Admin needs to SSH into the server and run:

```bash
ssh root@169.58.124.150

# Add this tablet as a peer (replace key and IP with the tablet's values)
wg set wg0 peer <TABLET_PUBLIC_KEY> allowed-ips <TABLET_VPN_IP>/32

# Example:
wg set wg0 peer mzSRuHOimKUlUZWmWJRKDbURXTFrqOX2YAqSfXZUcXU= allowed-ips 10.0.0.2/32

# Save so it persists on reboot
wg-quick save wg0

# Confirm peer added
wg show
```

### 8.7 WireGuard Auto-Start

The WireGuard tunnel installs as a Windows service automatically when you click **Save & Activate Tunnel** in the wizard. It starts on every boot with no manual action needed.

To verify:
```cmd
sc query WireGuardTunnel$EcareAfrica
```

---

## Part 9 — Set Tablet to Auto-Login (Optional but Recommended)

For a kiosk-style setup where the tablet shows the dashboard automatically after boot:

### 9.1 Enable Auto-Login

```cmd
netplwiz
```

1. Uncheck "Users must enter a username and password"
2. Click OK
3. Enter the Windows password when prompted

### 9.2 Open Chrome at Startup

1. Press `Win + R` → type `shell:startup` → Enter
2. Right-click in the folder → New → Shortcut
3. Location: `"C:\Program Files\Google\Chrome\Application\chrome.exe" --kiosk http://localhost:3000`
4. Name it: `EcaAfrica Dashboard`

After this, every reboot will:
1. Auto-login Windows
2. Services start automatically (EcaAfrica-Bridge, EcaAfrica-Frontend)
3. Chrome opens full-screen at `http://localhost:3000`

---

## Part 10 — Updating the Software

When a new version is available on GitHub:

```cmd
cd C:\EcaAfrica

# Stop services first
powershell -Command "Stop-Service EcaAfrica-Frontend, EcaAfrica-Bridge"

# Pull latest
git pull origin Testing-Branch

# Reinstall backend dependencies if package.json changed
cd backend && npm install && cd ..

# Rebuild frontend
cd frontend && npm install && npm run build && cd ..

# Rebuild FKBridge if Program.cs changed
cd FKBridge && dotnet build -c Release && cd ..

# Restart services
powershell -Command "Start-Service EcaAfrica-Bridge; Start-Sleep 3; Start-Service EcaAfrica-Frontend"
```

---

## Part 11 — Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Dashboard not loading | Services not started | Run `Get-Service EcaAfrica-*` — check status, check `logs\bridge-err.log` |
| Device shows "Offline" | Wrong IP in device-config.json | Update IP in Developer modal or edit `backend/data/device-config.json` |
| `FK bridge did not start` | FKBridge.exe not built or wrong path | Run `dotnet build -c Release` in FKBridge folder |
| WireGuard tunnel inactive | Server hasn't added tablet as peer | Super Admin runs `wg set wg0 peer ...` on `169.58.124.150` |
| Ping to `10.0.0.1` fails | Tunnel active but no handshake | Server firewall — run `ufw allow 51820/udp` on server |
| `EADDRINUSE :5000` | Port 5000 already in use | Stop old Node process: `Stop-Process -Name node -Force` |
| `dotnet: command not found` | .NET not installed or wrong arch | Install .NET 8 x86 Runtime from dotnet.microsoft.com |
| Frontend build fails | Node.js version too old | Install Node.js v18 LTS or higher |
| Services fail to start after update | .next folder missing or stale | Run `npm run build` in frontend folder, then restart services |

---

## Part 12 — File Structure Reference

```
C:\EcaAfrica\
│
├── INSTALL (double-click me).bat    ← Double-click to install auto-start services
├── install-services.ps1             ← Service installer script
├── uninstall-services.ps1           ← Service uninstaller script
│
├── backend\
│   ├── server.js                    ← Node.js backend (port 5000)
│   ├── .env                         ← Environment config (TABLET_UUID, VPN settings)
│   └── data\
│       ├── device-config.json       ← FK623 device IP and port
│       ├── students.json            ← Registered students
│       ├── attendance-settings.json ← Attendance time rules
│       ├── wireguard-private.key    ← VPN private key (never share)
│       └── wireguard-public.key     ← VPN public key (share with Super Admin)
│
├── frontend\
│   ├── app\page.tsx                 ← Main dashboard
│   ├── components\                  ← UI components
│   ├── .env.local                   ← Frontend API URL
│   └── .next\                       ← Built frontend (auto-generated)
│
├── FKBridge\
│   ├── Program.cs                   ← C# bridge to FK623 DLL
│   └── bin\Release\net8.0\
│       └── FKBridge.exe             ← Built bridge executable
│
├── docs\
│   ├── Tablet full setup 12-09-2026.md    ← This document
│   └── wireguard-full-setup-guide.md      ← WireGuard detail guide
│
├── logs\                            ← Created by installer
│   ├── bridge-out.log
│   ├── bridge-err.log
│   ├── frontend-out.log
│   └── frontend-err.log
│
└── tools\
    └── nssm.exe                     ← Downloaded by installer
```

---

## Quick Setup Checklist

Use this as a field checklist when deploying a new tablet:

```
PRE-INSTALL
[ ] Windows 10/11 64-bit — clean install or factory reset
[ ] Node.js v18+ installed
[ ] .NET 8 x86 Runtime installed
[ ] Git installed
[ ] WireGuard installed
[ ] Google Chrome installed

CODE SETUP
[ ] git clone https://github.com/Byiringiro24/Tablet_Setup.git C:\EcaAfrica
[ ] git checkout Testing-Branch
[ ] cd backend && npm install
[ ] cd frontend && npm install && npm run build
[ ] cd FKBridge && dotnet build -c Release

CONFIGURATION
[ ] device-config.json — correct FK623 IP address set
[ ] backend/.env — TABLET_UUID filled (from Super Admin portal)
[ ] Test run manually — backend + frontend start, device connects

SERVICE INSTALL
[ ] Double-click INSTALL (double-click me).bat
[ ] Confirm both services show Running
[ ] Open http://localhost:3000 — dashboard loads, device Online

WIREGUARD VPN
[ ] Open WireGuard wizard from dashboard sidebar
[ ] Generate keys — copy public key, send to Super Admin
[ ] Super Admin adds tablet as peer on server (wg set wg0 peer ...)
[ ] Paste server public key and VPN IP in wizard Step 3
[ ] Click Save & Activate — tunnel shows Active
[ ] Ping 10.0.0.1 — green result

FINAL
[ ] Auto-login configured (optional)
[ ] Chrome startup shortcut created (optional)
[ ] Reboot tablet — verify everything starts automatically
[ ] Dashboard accessible at http://localhost:3000
```

---

*Document: Tablet Full Setup 12-09-2026*  
*EcaAfrica Biometric Attendance System*  
*Confidential — Internal Use Only*
