# EcaAfrica — Windows Tablet Setup Guide

**Purpose:** This Windows tablet acts as a bridge between the FK623 biometric device and the EcaAfrica school server.

```
FK623 Device  ──TCP──▶  FKBridge.exe  ──STDIN/STDOUT──▶  Node.js Backend (port 5000)
                                                                      │
                                        Next.js Frontend (port 3000) ◀┘
                                                                      │
                              EcaAfrica School Server ◀───────────────┘
                              (https://backend.ecareafrica.net)
```

---

## What Each Part Does

| Component | Location | Purpose |
|---|---|---|
| `FKBridge\FKBridge.exe` | `FKBridge/` | .NET 8 app — talks to FK623 via TCP SDK. Runs in background. |
| `backend\server.js` | `backend/` | Node.js Express server on port 5000. Bridges FKBridge ↔ school server. |
| `frontend\app\page.tsx` | `frontend/` | Next.js app on port 3000. Staff UI for registration, live attendance, device control. |

---

## Prerequisites

Install these on the Windows tablet BEFORE running anything:

1. **.NET 8 Runtime** (for FKBridge.exe)
   → https://dotnet.microsoft.com/download/dotnet/8.0
   → Download: ".NET 8.0 Runtime" for Windows x64

2. **Node.js 20 LTS** (for backend and frontend)
   → https://nodejs.org/en/download
   → Download: "LTS" version for Windows x64

3. **WireGuard** (if the server is remote — not on same LAN)
   → https://www.wireguard.com/install/
   → Download: "Windows" installer

---

## Installation Steps

### Step 1 — Clone or copy this folder to the tablet

```
C:\EcaAfrica\
├── FKBridge\        ← copy FKBridge folder here
├── backend\         ← copy backend folder here
└── frontend\        ← copy frontend folder here
```

Or clone from GitHub (requires token):
```cmd
git clone -b Testing-Branch https://YOUR_TOKEN@github.com/Byiringiro24/Tablet_Setup.git C:\EcaAfrica
```

### Step 2 — Configure the backend

Edit `C:\EcaAfrica\backend\.env`:

```env
PORT=5000
SERVER_API_URL=https://backend.ecareafrica.net/api/v1
TABLET_UUID=                    ← fill this in after Step 6
```

The frontend `.env.local` does NOT need editing — it always uses `localhost:5000`.

### Step 3 — Install Node.js dependencies

Open **Command Prompt as Administrator** and run:

```cmd
cd C:\EcaAfrica\backend
npm install

cd C:\EcaAfrica\frontend
npm install
```

### Step 4 — Run the three services

You need **three terminal windows** open at the same time:

**Terminal 1 — FKBridge (run as Administrator):**
```cmd
cd C:\EcaAfrica\FKBridge
FKBridge.exe
```
✓ You should see: `FK Attendance Bridge started`

**Terminal 2 — Tablet Backend:**
```cmd
cd C:\EcaAfrica\backend
node server.js
```
✓ You should see: `FK Attendance Backend running on http://localhost:5000`

**Terminal 3 — Tablet Frontend:**
```cmd
cd C:\EcaAfrica\frontend
npm run dev
```
✓ You should see: `ready - started server on http://localhost:3000`

Now open a browser on the tablet: **http://localhost:3000**

### Step 5 — Register this tablet in the portal

1. Open https://ecareafrica.net on any computer
2. Login as **Platform Admin**: `platform.admin@ecareafrica.test` / `Admin@123`
3. Go to **Super Admin → Hardware → Tablets**
4. Click **Add Tablet**:
   - **Name**: e.g. `Main Gate Tablet`
   - **IP**: this tablet's IP or VPN IP (e.g. `10.0.0.2`)
   - **Port**: `5000`
   - **Location**: e.g. `Main Gate`
5. Click **Create** — copy the **UUID** shown

### Step 6 — Paste the UUID into the tablet .env

Edit `C:\EcaAfrica\backend\.env`:
```env
TABLET_UUID=paste-uuid-here
```
Restart the backend: press `Ctrl+C` in Terminal 2, then run `node server.js` again.

### Step 7 — Register the FK623 device

1. Still in the portal → **Hardware → Devices**
2. Click **Register Device**:
   - **School**: your school
   - **Device Name**: e.g. `Main Gate FK623`
   - **Device UID**: e.g. `FK623-GATE-01`
   - **Mode**: `gate` (for main gate) or `boarding` (for dormitory)
   - **Device IP**: FK623's LAN IP (e.g. `192.168.1.118`)
   - **Device Port**: `5005`
   - **License No.**: from your FK623 documentation
   - **Link to Tablet**: select the tablet you registered in Step 5
3. Click **Register**

### Step 8 — Connect to the FK623

1. Open **http://localhost:3000** on the tablet
2. Click the **Settings** icon (gear/developer button)
3. Enter password: **`admin1234`**
4. Enter:
   - **FK623 IP**: the device's LAN IP
   - **Port**: `5005`
   - **License**: your license number
   - **Device ID**: e.g. `FK623-GATE-01`
5. Click **Save** — the tablet connects and shows device stats

### Step 9 — Push students from the portal

1. Login to the school portal as **School Admin** or **Boarding Officer**
2. Go to **Boarding → Devices → [select device] → Push Students**
3. Choose **All Boarding Students** → **Push**
4. Students physically walk to the FK623 and enroll their fingerprint/face

### Step 10 — Test a scan

Ask a student to scan their finger at the FK623.

You should see:
- Live attendance flash on the tablet frontend (`http://localhost:3000`)
- The scan appear in **Boarding → Device Sessions → Attendance History** on the portal

---

## Daily Operation (Auto — No Action Needed)

Once set up, the tablet runs automatically:

- FKBridge holds a persistent TCP connection to the FK623
- Any scan is picked up in real time via Server-Sent Events
- The tablet backend auto-polls every 2 seconds for new logs
- The school server pulls logs from the tablet every 5 seconds
- Missing attendance → DOD + Patron notified → 1hr escalation → parent SMS

---

## Auto-Start on Windows Boot

To make the tablet start automatically when Windows boots:

1. Press `Win + R` → type `shell:startup` → Enter
2. Create shortcuts in that folder for:
   - `FKBridge.exe`
   - A `.bat` file for the backend:
     ```bat
     @echo off
     cd /d C:\EcaAfrica\backend
     node server.js
     ```
   - A `.bat` file for the frontend:
     ```bat
     @echo off
     cd /d C:\EcaAfrica\frontend
     npm run start
     ```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `FKBridge.exe not found` | Copy the `FKBridge/` folder to `C:\EcaAfrica\` |
| `Device connection failed` | Check FK623 IP/port in Developer Settings; verify device is powered and on LAN |
| `Port 5000 already in use` | Another app is using port 5000. Close it or change `PORT=5001` in `.env` and update tablet registration in portal |
| Frontend shows "Backend offline" | Backend (`node server.js`) is not running |
| Scans not syncing to portal | Check `TABLET_UUID` is set in `.env`; check portal has this tablet registered |
| WireGuard not connecting | Verify server added this tablet as a peer; check tunnel config IP matches portal registration |

---

## Network Setup Summary

| Scenario | Tablet IP | Server URL in .env |
|---|---|---|
| **Same LAN** (school network) | LAN IP e.g. `192.168.1.50` | `http://192.168.x.x:5000/api/v1` |
| **Remote via VPN** | VPN IP e.g. `10.0.0.2` | `https://backend.ecareafrica.net/api/v1` |
| **Testing on laptop** | localhost | `http://localhost:5000/api/v1` |

---

*EcaAfrica — August 2026*
