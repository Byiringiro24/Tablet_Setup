# EcaAfrica Biometric Attendance System
## New Windows Tablet — Complete Installation & Autostart Guide

> Fresh Windows tablet → prerequisites → repository → configuration → build → manual testing → Windows services → Chrome kiosk autostart → verification → troubleshooting

**Production services:** `EcaAfrica-Backend` · `EcaAfrica-FKBridge` · `EcaAfrica-Frontend`  
**Chrome autostart:** 5 seconds after login · kiosk mode · `http://localhost:3000/`

---

## Architecture

```
POWER ON → WINDOWS → USER LOGIN
                          ↓
              ┌───────────┴───────────┐
              ↓                       ↓
    EcaAfrica-Backend      EcaAfrica-FKBridge
              │                       │
              └───────────┬───────────┘
                          ↓
               EcaAfrica-Frontend
                          ↓
                    WAIT 5 SECONDS
                          ↓
               CHROME — KIOSK MODE
                          ↓
             http://localhost:3000/
                          ↓
              ECAAFRICA DASHBOARD ✓
```

---

## 1. Requirements

| Requirement | Detail |
|---|---|
| OS | Windows 10 64-bit or Windows 11 |
| RAM | 4 GB minimum |
| Storage | 10 GB free |
| Internet | Required — downloads ~500 MB |
| Privileges | Administrator access required |
| Repository | `Byiringiro24/Tablet_Setup` — branch `Testing-Branch` |

---

## 2. Open VS Code as Administrator

Open VS Code → Terminal → New Terminal → select **PowerShell**.

Always start VS Code with **Run as administrator** for installation and service commands.

```powershell
$PSVersionTable.PSVersion
```

---

## 3. Install Prerequisites

Check winget:

```powershell
winget --version
```

Install all tools:

```powershell
winget install --id Git.Git -e --source winget
winget install --id OpenJS.NodeJS.LTS -e --source winget
winget install --id Microsoft.DotNet.SDK.8 -e --source winget
winget install --id WireGuard.WireGuard -e --source winget
winget install --id Google.Chrome -e --source winget
```

> **Close and reopen VS Code terminal after Git installs.**

> **IMPORTANT — .NET x86:** The FK623 DLL is 32-bit. Install **.NET 8 Desktop Runtime x86** and **.NET 8 SDK x86**. A 64-bit-only installation is not sufficient.

Verify everything:

```powershell
git --version
node --version
npm --version
dotnet --version
dotnet --list-sdks
dotnet --list-runtimes
where.exe git
where.exe node
where.exe dotnet
```

---

## 4. Clone the Repository

```powershell
New-Item -ItemType Directory -Path "C:\EcaAfrica" -Force
cd C:\EcaAfrica
git clone --branch Testing-Branch https://github.com/Byiringiro24/Tablet_Setup.git .
```

Verify:

```powershell
git status
dir
```

Expected folders: `backend` `frontend` `FKBridge` `docs` `tools` `logs` `install-services.ps1` `setup-new-tablet.ps1`

---

## 5. Configure the FK623 Device

File: `C:\EcaAfrica\backend\data\device-config.json`

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

> Update `ipAddress` to match your actual FK623 device IP if different.

Test connectivity:

```powershell
ping 192.168.1.76
```

> The IP can also be changed later: **Dashboard → Developer → password `admin1234` → IP Address → Save & Reconnect**

---

## 6. Configure Environment Files

**`C:\EcaAfrica\backend\.env`**

```env
PORT=5000
SERVER_API_URL=https://backend.ecareafrica.net/api/v1
TABLET_UUID=
WG_SERVER_ENDPOINT=169.58.124.150:51820
VPN_ALLOWED_IPS=10.0.0.0/16
WG_DNS=1.1.1.1
```

> Leave `TABLET_UUID` empty until you register the tablet in Super Admin.

**`C:\EcaAfrica\frontend\.env.local`**

```env
NEXT_PUBLIC_API_URL=http://localhost:5000
```

---

## 7. Install Dependencies and Build

**Backend:**

```powershell
cd C:\EcaAfrica\backend
npm install
```

**FKBridge:**

```powershell
cd C:\EcaAfrica\FKBridge
dotnet build -c Release
```

Expected: `C:\EcaAfrica\FKBridge\bin\Release\net8.0\FKBridge.exe`

> If you see `It was not possible to find any installed .NET Core SDKs` — install the x86 .NET 8 components, close and reopen VS Code, then retry.

**Frontend:**

```powershell
cd C:\EcaAfrica\frontend
npm install
npm run build
```

---

## 8. Manual Testing Before Autostart

Open **three separate terminals**:

**Terminal 1 — Backend:**

```powershell
cd C:\EcaAfrica\backend
npm run dev
```

Test:

```powershell
curl http://localhost:5000/api/health
```

Expected: `{ "status": "ok" }`

> **Port 5000 already in use?** Check before killing anything:
> ```powershell
> Get-NetTCPConnection -LocalPort 5000 -State Listen | Select-Object LocalAddress,LocalPort,OwningProcess
> Get-Process -Id <PID>
> ```
> If `curl http://localhost:5000/api/health` returns 200 — the backend is already running. Do not start a second instance.

**Terminal 2 — FKBridge:**

```powershell
cd C:\EcaAfrica\FKBridge
.\bin\Release\net8.0\FKBridge.exe
```

**Terminal 3 — Frontend:**

```powershell
cd C:\EcaAfrica\frontend
npm run dev
```

Open **http://localhost:3000** — verify the dashboard loads.

> **Port 3000 already in use?**
> ```powershell
> Get-NetTCPConnection -LocalPort 3000 -State Listen | Select-Object LocalAddress,LocalPort,OwningProcess
> Get-Process -Id <PID>
> ```
> If `curl http://localhost:3000` responds — do not start a second frontend.

---

## 9. Install Production Windows Services

After manual build succeeds:

```powershell
cd C:\EcaAfrica
powershell -ExecutionPolicy Bypass -File .\install-services.ps1
```

For full automated setup on a new tablet:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-new-tablet.ps1
```

> Check first before running both:
> ```powershell
> Get-Service *EcaAfrica*
> ```

**Service configuration:**

| Setting | EcaAfrica-Backend | EcaAfrica-FKBridge | EcaAfrica-Frontend |
|---|---|---|---|
| Application | `node server.js` | FKBridge executable | `node next start --port 3000` |
| Working dir | `C:\EcaAfrica\backend` | `C:\EcaAfrica\FKBridge\...` | `C:\EcaAfrica\frontend` |
| Port | 5000 | — | 3000 |
| Startup | Automatic | Automatic | Automatic |
| Account | LocalSystem | LocalSystem | LocalSystem |

---

## 10. Verify Windows Services

```powershell
Get-Service *EcaAfrica*
```

Expected:

```
Running  EcaAfrica-Backend
Running  EcaAfrica-FKBridge
Running  EcaAfrica-Frontend
```

Start if stopped:

```powershell
Start-Service EcaAfrica-Backend
Start-Service EcaAfrica-FKBridge
Start-Service EcaAfrica-Frontend
```

Restart:

```powershell
Restart-Service EcaAfrica-Backend
Restart-Service EcaAfrica-FKBridge
Restart-Service EcaAfrica-Frontend
```

View logs:

```powershell
Get-Content C:\EcaAfrica\logs\EcaAfrica-Backend.err.log  -Tail 100
Get-Content C:\EcaAfrica\logs\EcaAfrica-FKBridge.err.log -Tail 100
Get-Content C:\EcaAfrica\logs\EcaAfrica-Frontend.err.log -Tail 100
```

---

## 11. Chrome Kiosk Autostart — 5 Seconds After Login

> **Best method: Windows Scheduled Task.** Reliable, has a configurable delay, survives reboots, works for any user account. Use this in production.

Run PowerShell **as Administrator**:

```powershell
$action = New-ScheduledTaskAction `
    -Execute "C:\Program Files\Google\Chrome\Application\chrome.exe" `
    -Argument '--kiosk "http://localhost:3000/" --disable-infobars --no-first-run --disable-session-crashed-bubble --disable-restore-session-state'

$trigger = New-ScheduledTaskTrigger -AtLogOn

$trigger.Delay = "PT5S"

Register-ScheduledTask `
    -TaskName "EcaAfrica-OpenDashboard" `
    -Action $action `
    -Trigger $trigger `
    -Description "Open EcaAfrica dashboard in Chrome kiosk mode 5 seconds after login" `
    -User "$env:USERDOMAIN\$env:USERNAME" `
    -RunLevel Limited `
    -Force
```

Verify:

```powershell
Get-ScheduledTask -TaskName "EcaAfrica-OpenDashboard"
```

Check the delay is `PT5S`:

```powershell
(Get-ScheduledTask -TaskName "EcaAfrica-OpenDashboard").Triggers |
    Select-Object AtLogOn, Delay
```

Test without restarting:

```powershell
Start-ScheduledTask -TaskName "EcaAfrica-OpenDashboard"
```

Chrome should open in full kiosk mode — no address bar, no browser controls.

---

## 12. Adjust the Delay (if needed)

If Chrome opens before services are ready, increase the delay:

```powershell
$task = Get-ScheduledTask -TaskName "EcaAfrica-OpenDashboard"
$task.Triggers[0].Delay = "PT15S"
$task | Set-ScheduledTask
```

| Delay | ISO value |
|---|---|
| 5 seconds | `PT5S` |
| 10 seconds | `PT10S` |
| 15 seconds | `PT15S` |
| 30 seconds | `PT30S` |
| 1 minute | `PT1M` |

---

## 13. Full Real-World Autostart Test

```powershell
Restart-Computer
```

After reboot:
1. Log into the EcaAfrica Windows account
2. Do **not** open Chrome manually
3. Wait 5 seconds
4. Chrome opens automatically at `http://localhost:3000/` in kiosk mode
5. EcaAfrica dashboard appears — ready for use

---

## 14. Optional System Hardening (Dedicated Kiosk Only)

Includes UAC suppression, Fast Startup disabled, `ServicesPipeTimeout` increase, boot health checks.

> **Warning:** UAC suppression reduces Windows security. Only apply on a dedicated managed tablet.

```powershell
powershell -ExecutionPolicy Bypass -File C:\EcaAfrica\set-admin-permanent.ps1
```

---

## 15. Register the Tablet in Super Admin

1. Open **https://ecareafrica.net → Super Admin → Hardware → Tablets → Add Tablet**
2. Enter school, location, device label
3. Copy the generated `TABLET_UUID`
4. Edit `C:\EcaAfrica\backend\.env`:

```env
TABLET_UUID=<paste generated UUID here>
```

5. Restart backend:

```powershell
Restart-Service EcaAfrica-Backend
```

---

## 16. WireGuard VPN Setup

In tablet UI → **WireGuard VPN**:

1. Generate keys on tablet → copy the **tablet public key**
2. Send public key to Super Admin
3. Super Admin registers the peer on server:

```bash
# On server via SSH
wg set wg0 peer <TABLET_PUBLIC_KEY> allowed-ips <TABLET_VPN_IP>/32
wg-quick save wg0
```

4. Enter server public key + assigned VPN IP in tablet wizard
5. Save & Activate → ping `10.0.0.1` — should succeed

---

## 17. Final Verification Checklist

```
☐ Windows boots and user can log in
☐ Git installed, repo on Testing-Branch
☐ C:\EcaAfrica exists
☐ Backend dependencies installed
☐ FKBridge built (.NET x86 components present)
☐ Frontend built
☐ FK623 IP correct and reachable (ping OK)
☐ Backend responds: http://localhost:5000/api/health
☐ Frontend responds: http://localhost:3000
☐ EcaAfrica-Backend is Running
☐ EcaAfrica-FKBridge is Running
☐ EcaAfrica-Frontend is Running
☐ All services start automatically on boot
☐ Frontend starts after backend
☐ EcaAfrica-OpenDashboard scheduled task exists
☐ Chrome starts 5 seconds after login
☐ Chrome opens http://localhost:3000/ in kiosk mode
☐ TABLET_UUID is populated in backend/.env
☐ WireGuard tunnel configured and ping test succeeds
☐ FK623 shows Online in the dashboard
```

---

## 18. Troubleshooting

**All services:**

```powershell
Get-Service *EcaAfrica*
```

**Logs:**

```powershell
Get-Content C:\EcaAfrica\logs\EcaAfrica-Backend.err.log  -Tail 100
Get-Content C:\EcaAfrica\logs\EcaAfrica-FKBridge.err.log -Tail 100
Get-Content C:\EcaAfrica\logs\EcaAfrica-Frontend.err.log -Tail 100
```

**Port in use:**

```powershell
# Port 5000
Get-NetTCPConnection -LocalPort 5000 -State Listen
Get-Process -Id (Get-NetTCPConnection -LocalPort 5000 -State Listen).OwningProcess
curl http://localhost:5000/api/health

# Port 3000
Get-NetTCPConnection -LocalPort 3000 -State Listen
Get-Process -Id (Get-NetTCPConnection -LocalPort 3000 -State Listen).OwningProcess
curl http://localhost:3000
```

**Rebuild frontend:**

```powershell
Stop-Service EcaAfrica-Frontend
cd C:\EcaAfrica\frontend
npm run build
Start-Service EcaAfrica-Frontend
```

**FK623 not reachable:**

```powershell
ping 192.168.1.76
```

Update `C:\EcaAfrica\backend\data\device-config.json` or use **Dashboard → Developer → IP Address → Save & Reconnect**.

**Chrome autostart issues:**

```powershell
# Check task
Get-ScheduledTask -TaskName "EcaAfrica-OpenDashboard"

# Check last run (0 = success)
Get-ScheduledTaskInfo -TaskName "EcaAfrica-OpenDashboard" |
    Select-Object LastRunTime, LastTaskResult

# Verify delay
(Get-ScheduledTask -TaskName "EcaAfrica-OpenDashboard").Triggers |
    Select-Object AtLogOn, Delay

# Test immediately
Start-ScheduledTask -TaskName "EcaAfrica-OpenDashboard"

# Verify Chrome location
Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe"
where.exe chrome
```

**Remove and recreate the task:**

```powershell
Unregister-ScheduledTask -TaskName "EcaAfrica-OpenDashboard" -Confirm:$false
```

Then re-run the creation block from Section 11.

---

## 19. Files Reference

| File | Purpose |
|---|---|
| `SETUP-NEW-TABLET.bat` | Main one-click entry point |
| `setup-new-tablet.ps1` | Full automated setup |
| `install-services.ps1` | Installs Windows services |
| `set-admin-permanent.ps1` | Dedicated-tablet hardening |
| `uninstall-services.ps1` | Removes services before reinstall |
| `backend/.env` | Server / tablet / WireGuard config |
| `backend/data/device-config.json` | FK623 device configuration |
| `frontend/.env.local` | Local API URL |
| `logs/*.err.log` | Service error logs |
| `tools/boot-check.ps1` | Boot health check |
| `tools/nssm/nssm.exe` | NSSM service wrapper |

---

## 20. Complete Command Sequence — Copy and Run

Run all of these in PowerShell **as Administrator**:

```powershell
# ── STEP 1: Install prerequisites ────────────────────────────
winget --version
winget install --id Git.Git -e --source winget
winget install --id OpenJS.NodeJS.LTS -e --source winget
winget install --id Microsoft.DotNet.SDK.8 -e --source winget
winget install --id WireGuard.WireGuard -e --source winget
winget install --id Google.Chrome -e --source winget
# Reopen terminal after Git installs, then:
git --version; node --version; npm --version; dotnet --version

# ── STEP 2: Clone repository ──────────────────────────────────
New-Item -ItemType Directory -Path "C:\EcaAfrica" -Force
cd C:\EcaAfrica
git clone --branch Testing-Branch https://github.com/Byiringiro24/Tablet_Setup.git .

# ── STEP 3: Build all components ─────────────────────────────
cd C:\EcaAfrica\backend;  npm install
cd C:\EcaAfrica\FKBridge; dotnet build -c Release
cd C:\EcaAfrica\frontend; npm install; npm run build

# ── STEP 4: Manual test (run in separate terminals) ───────────
# Terminal 1: cd C:\EcaAfrica\backend && npm run dev
# Terminal 2: cd C:\EcaAfrica\FKBridge && .\bin\Release\net8.0\FKBridge.exe
# Terminal 3: cd C:\EcaAfrica\frontend && npm run dev
# Then open http://localhost:3000

# ── STEP 5: Install Windows services ─────────────────────────
cd C:\EcaAfrica
powershell -ExecutionPolicy Bypass -File .\install-services.ps1
Get-Service *EcaAfrica*

# ── STEP 6: Test production endpoints ────────────────────────
curl http://localhost:5000/api/health
curl http://localhost:3000

# ── STEP 7: Create Chrome kiosk autostart (5-second delay) ───
$action = New-ScheduledTaskAction `
    -Execute "C:\Program Files\Google\Chrome\Application\chrome.exe" `
    -Argument '--kiosk "http://localhost:3000/" --disable-infobars --no-first-run --disable-session-crashed-bubble --disable-restore-session-state'
$trigger = New-ScheduledTaskTrigger -AtLogOn
$trigger.Delay = "PT5S"
Register-ScheduledTask `
    -TaskName "EcaAfrica-OpenDashboard" `
    -Action $action `
    -Trigger $trigger `
    -Description "Open EcaAfrica dashboard in Chrome kiosk mode 5 seconds after login" `
    -User "$env:USERDOMAIN\$env:USERNAME" `
    -RunLevel Limited `
    -Force
# Verify:
Get-ScheduledTask -TaskName "EcaAfrica-OpenDashboard"
# Test:
Start-ScheduledTask -TaskName "EcaAfrica-OpenDashboard"

# ── STEP 8: Register tablet UUID ─────────────────────────────
# 1. Go to https://ecareafrica.net → Super Admin → Hardware → Tablets → Add Tablet
# 2. Copy the generated TABLET_UUID
# 3. Edit C:\EcaAfrica\backend\.env → set TABLET_UUID=<value>
# 4. Then:
Restart-Service EcaAfrica-Backend

# ── STEP 9: Final check ───────────────────────────────────────
Get-Service *EcaAfrica*
curl http://localhost:5000/api/health
curl http://localhost:3000
```

---

## APPENDIX A — Chrome Kiosk Flag Reference

| Flag | Effect |
|---|---|
| `--kiosk` | Full-screen kiosk — no address bar, no controls |
| `--disable-infobars` | Hides "Chrome is being controlled" banner |
| `--no-first-run` | Skips first-run welcome dialog |
| `--disable-session-crashed-bubble` | Hides "Chrome didn't shut down correctly" popup |
| `--disable-restore-session-state` | Prevents session restore prompts |
| `--start-fullscreen` | Fullscreen (fallback if `--kiosk` causes issues) |
| `--incognito` | Kiosk in incognito mode — no cached data |
| `--window-size=1920,1080` | Force specific screen resolution |

**Exit kiosk mode:**

| Action | Keys |
|---|---|
| Exit kiosk | `Alt + F4` |
| Task Manager | `Ctrl + Shift + Esc` |
| Close window | `Ctrl + W` |

---

## APPENDIX B — Alternative Chrome Autostart Methods

> **Method 1 (Section 11) is recommended for production.** These are fallbacks only.

### B1 — Startup Folder Shortcut (no delay control)

```powershell
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut(
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\EcaAfrica.lnk"
)
$Shortcut.TargetPath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$Shortcut.Arguments  = '--kiosk "http://localhost:3000/" --disable-infobars --no-first-run'
$Shortcut.Save()
```

Remove:

```powershell
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\EcaAfrica.lnk"
```

### B2 — Registry Run Key (current user, no delay)

```powershell
Set-ItemProperty `
    -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
    -Name "EcaAfrica" `
    -Value '"C:\Program Files\Google\Chrome\Application\chrome.exe" --kiosk "http://localhost:3000/" --disable-infobars --no-first-run'
```

Remove:

```powershell
Remove-ItemProperty `
    -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
    -Name "EcaAfrica"
```

### B3 — All Users (requires Administrator)

```powershell
$principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Limited
$action = New-ScheduledTaskAction `
    -Execute "C:\Program Files\Google\Chrome\Application\chrome.exe" `
    -Argument '--kiosk "http://localhost:3000/" --disable-infobars --no-first-run'
$trigger = New-ScheduledTaskTrigger -AtLogOn
$trigger.Delay = "PT5S"
Register-ScheduledTask `
    -TaskName "EcaAfrica-OpenDashboard" `
    -Action $action -Trigger $trigger -Principal $principal `
    -Description "EcaAfrica kiosk autostart for all users" -Force
```

---

## APPENDIX C — One-Liner Chrome Kiosk Setup

Single paste — creates the scheduled task in one command:

```powershell
$a=New-ScheduledTaskAction -Execute "C:\Program Files\Google\Chrome\Application\chrome.exe" -Argument '--kiosk "http://localhost:3000/" --disable-infobars --no-first-run --disable-session-crashed-bubble'; $t=New-ScheduledTaskTrigger -AtLogOn; $t.Delay="PT5S"; Register-ScheduledTask -TaskName "EcaAfrica-OpenDashboard" -Action $a -Trigger $t -Description "EcaAfrica kiosk 5s after login" -User "$env:USERDOMAIN\$env:USERNAME" -RunLevel Limited -Force; Write-Host "Done. Test: Start-ScheduledTask -TaskName EcaAfrica-OpenDashboard"
```

---

*EcaAfrica Tablet Installation Guide — September 2026*  
*Merged from: EcaAfrica 16-9-2026.md + Chrome Kiosk Autostart — EcaAfrica.md*
