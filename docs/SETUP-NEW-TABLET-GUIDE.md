# EcaAfrica Tablet Setup Guide

This file was merged into the main guide at the project root. See [../README.md](../README.md) for the current setup and troubleshooting instructions.

The folder has been cleaned up to keep only the essential, non-duplicated documentation.

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
