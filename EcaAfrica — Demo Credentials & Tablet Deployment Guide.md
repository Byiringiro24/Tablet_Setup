# EcaAfrica — Demo Credentials & Tablet Deployment Guide

**Version:** 1.0 | Local Development Build | August 2026

---

## Part 1 — Demo User Credentials

All demo accounts are seeded automatically. Every school user password is:

**`Password@123`**

Platform Admin password:

**`Admin@123`**

---

### Platform Admin (Super Admin)

Used to manage all schools, register devices, set up VPN, view billing.

| Email | Password | Role | Portal URL |
|---|---|---|---|
| `platform.admin@ecareafrica.test` | `Admin@123` | Platform Admin | `/login?mode=platform` |
| `admin@platform.test` | `Admin@123` | Platform Admin | `/login?mode=platform` |

---

### School: Nexus Demo School (ID = 1)

Login at: `http://localhost:5173/login`

| Email | Password | Role | Dashboard |
|---|---|---|---|
| `admin@1.ecare.test` | `Password@123` | School Admin | `/dashboard` |
| `dod@1.ecare.test` | `Password@123` | Director of Discipline | `/dod/dashboard` |
| `dos@1.ecare.test` | `Password@123` | Director of Studies | `/dos/dashboard` |
| `patron@1.ecare.test` | `Password@123` | Patron | `/patron/dashboard` |
| `matron@1.ecare.test` | `Password@123` | Matron | `/patron/dashboard` |
| `boarding@1.ecare.test` | `Password@123` | Boarding Officer | `/boarding-officer/dashboard` |
| `gatekeeper@1.ecare.test` | `Password@123` | Gate Keeper | `/gate-keeper/dashboard` |
| `teacher1@1.ecare.test` | `Password@123` | Teacher | `/teacher/dashboard` |
| `teacher2@1.ecare.test` | `Password@123` | Teacher | `/teacher/dashboard` |
| `finance@1.ecare.test` | `Password@123` | Finance Officer | `/finance` |
| `staff1@1.ecare.test` | `Password@123` | Staff | `/staff/dashboard` |
| `staff2@1.ecare.test` | `Password@123` | Staff | `/staff/dashboard` |
| `parent1@1.ecare.test` | `Password@123` | Parent | (Parent App) |
| `parent2@1.ecare.test` | `Password@123` | Parent | (Parent App) |
| `parent3@1.ecare.test` | `Password@123` | Parent | (Parent App) |

---

### School: Ecare Africa Pilot (ID = 2)

Login at: `http://localhost:5173/login`

| Email | Password | Role | Dashboard |
|---|---|---|---|
| `admin@2.ecare.test` | `Password@123` | School Admin | `/dashboard` |
| `dod@2.ecare.test` | `Password@123` | Director of Discipline | `/dod/dashboard` |
| `dos@2.ecare.test` | `Password@123` | Director of Studies | `/dos/dashboard` |
| `patron@2.ecare.test` | `Password@123` | Patron | `/patron/dashboard` |
| `matron@2.ecare.test` | `Password@123` | Matron | `/patron/dashboard` |
| `boarding@2.ecare.test` | `Password@123` | Boarding Officer | `/boarding-officer/dashboard` |
| `gatekeeper@2.ecare.test` | `Password@123` | Gate Keeper | `/gate-keeper/dashboard` |
| `teacher1@2.ecare.test` | `Password@123` | Teacher | `/teacher/dashboard` |
| `teacher2@2.ecare.test` | `Password@123` | Teacher | `/teacher/dashboard` |
| `finance@2.ecare.test` | `Password@123` | Finance Officer | `/finance` |
| `staff1@2.ecare.test` | `Password@123` | Staff | `/staff/dashboard` |
| `staff2@2.ecare.test` | `Password@123` | Parent | `/staff/dashboard` |
| `parent1@2.ecare.test` | `Password@123` | Parent | (Parent App) |
| `parent2@2.ecare.test` | `Password@123` | Parent | (Parent App) |
| `parent3@2.ecare.test` | `Password@123` | Parent | (Parent App) |

---

## Part 2 — What Each Role Can Do

| Role | Responsibilities |
|---|---|
| **Platform Admin** | Register tablets/devices, manage schools, VPN setup, billing |
| **School Admin** | Full school management, all reports, override any setting |
| **Director of Discipline** | Approve/reject leave, configure boarding windows, manage dormitories and patron assignments, dining schedules |
| **Director of Studies** | Monitor class attendance, exams, timetable, academic staff |
| **Patron / Matron** | Manage assigned dormitories only — attendance, dining, submit leave requests to DOD |
| **Boarding Officer** | Boarding overview, roll calls, student dormitory assignments |
| **Gate Keeper** | Verify student identity, **CONFIRM GATE EXIT**, view approved exits with photos |
| **Teacher** | Class attendance, exams, grades, timetable |
| **Finance Officer** | Fees, expenses, payroll, invoices |
| **Staff** | Gate management, boarding overview |
| **Parent** | View own child only — attendance, leave status, notifications |

---

## Part 3 — Tablet Deployment (Step-by-Step)

### What's in `Tablet Setup\`

```
Tablet Setup\
├── FKBridge\              ← .NET 8 app — bridge between FK623 device and Node backend
│   ├── FKBridge.exe       ← Run this first
│   └── FK623Attend.dll    ← FK623 SDK
├── backend\               ← Node.js Express server (port 5000)
│   ├── server.js
│   ├── .env               ← YOU MUST CONFIGURE THIS
│   └── data\
│       ├── device-config.json      ← Auto-created after first device connect
│       └── attendance-settings.json
└── frontend\              ← Next.js app (port 3000)
    ├── app\page.tsx
    ├── .env.local         ← Points to backend on localhost:5000
    └── lib\api.ts
```

---

### Step 1 — Prerequisites on the Windows Tablet

Install these before copying files:

1. **.NET 8 Runtime** — https://dotnet.microsoft.com/download/dotnet/8.0  
   (needed to run FKBridge.exe)

2. **Node.js 20+** — https://nodejs.org  
   (needed to run the tablet backend and frontend)

3. **WireGuard for Windows** (only if server is remote) — https://www.wireguard.com/install/

---

### Step 2 — Copy Files to Tablet

Copy the entire `Tablet Setup\` folder to the tablet. Recommended location:

```
C:\EcaAfrica\
```

So you have:
```
C:\EcaAfrica\FKBridge\FKBridge.exe
C:\EcaAfrica\backend\server.js
C:\EcaAfrica\frontend\app\page.tsx
```

---

### Step 3 — Configure the Backend `.env`

Edit `C:\EcaAfrica\backend\.env`:

```env
PORT=5000
SERVER_API_URL=http://<YOUR_SERVER_IP>:5000/api/v1
TABLET_UUID=
```

**For local testing on the same network:**
```env
SERVER_API_URL=http://192.168.1.75:5000/api/v1
```

**For production (server deployed):**
```env
SERVER_API_URL=https://backend.ecareafrica.net/api/v1
```

Leave `TABLET_UUID=` blank for now — you'll fill it in after Step 6.

---

### Step 4 — Install Node dependencies

Open a terminal on the tablet and run:

```cmd
cd C:\EcaAfrica\backend
npm install

cd C:\EcaAfrica\frontend
npm install
```

---

### Step 5 — Start the Tablet Services

Open **three** terminal windows and run each command:

**Terminal 1 — FKBridge:**
```cmd
cd C:\EcaAfrica\FKBridge
FKBridge.exe
```
You should see: `FK Attendance Bridge started on port 5001`

**Terminal 2 — Tablet Backend:**
```cmd
cd C:\EcaAfrica\backend
node server.js
```
You should see: `FK Attendance Backend running on http://localhost:5000`

**Terminal 3 — Tablet Frontend:**
```cmd
cd C:\EcaAfrica\frontend
npm run dev
```
You should see: `ready started server on http://localhost:3000`

Open a browser on the tablet: **http://localhost:3000**

---

### Step 6 — Register the Tablet in the Portal

1. Open the **School Management Portal** on any computer
2. Log in as **Platform Admin**: `platform.admin@ecareafrica.test` / `Admin@123`
3. Go to **Super Admin → Hardware → Tablets tab**
4. Click **Add Tablet** and fill in:
   - **Name**: e.g. `Main Gate Tablet`
   - **IP**: The tablet's IP address on the network (e.g. `192.168.1.50`)
   - **Port**: `5001` (this is FKBridge's port)
   - **Location**: e.g. `Main Gate`
5. Click **Create** — copy the **UUID** that appears
6. Paste the UUID into `C:\EcaAfrica\backend\.env` under `TABLET_UUID=`
7. Restart the backend: `node server.js`

---

### Step 7 — Register the FK623 Device

1. Still in the portal as Platform Admin
2. Go to **Hardware → Devices tab**
3. Click **Register Device**:
   - **School**: Select the school
   - **Device Name**: e.g. `Main Gate FK623`
   - **Device UID**: e.g. `FK623-GATE-01`
   - **Mode**: `gate` (or `boarding` for dormitory)
   - **Device IP**: The FK623's LAN IP (e.g. `192.168.1.118`)
   - **Device Port**: `5005`
   - **License No.**: From your FK623 documentation
   - **Link to Tablet**: Select the tablet you just registered
4. Click **Register**

---

### Step 8 — Assign Device to Location

1. Go to **Hardware → Device Locations tab**
2. Find the device and click **Assign**
3. Set:
   - **Location Type**: `gate` or `dormitory`
   - **Dormitory**: If boarding, select which dormitory block
   - **Location Label**: e.g. `Boys Block A — South Door`
4. Save

---

### Step 9 — Connect to the FK623 from the Tablet UI

1. Open **http://localhost:3000** on the tablet
2. Click **Developer Settings** (password: `admin1234`)
3. Enter:
   - **FK623 IP**: e.g. `192.168.1.118`
   - **Port**: `5005`
   - **License**: Your license number
   - **Device ID**: e.g. `FK623-GATE-01`
4. Click **Save & Connect**
5. The UI should show **Connected** with device details (serial, users count, logs count)

---

### Step 10 — Push Students to the FK623

1. In the **School Portal** → **Boarding → Devices** → select the device
2. Click **Push Students** → choose **All Boarding Students**
3. Wait for completion — each student gets a `device_user_id`
4. Students physically walk to the FK623 and enroll their fingerprint/face using the device's touchscreen
5. Once enrolled, test by scanning — the tablet UI will show the student's name and attendance status

---

### Step 11 — Create an Attendance Session

For boarding attendance:
1. Log in as **DOD** (`dod@1.ecare.test`)
2. Go to **DOD → Boarding Attendance → Attendance Windows**
3. Click **Add Window**:
   - Name: `Evening Roll Call`
   - Start: `20:00`, End: `21:00`
   - Grace: `15 mins`, Escalation: `60 mins`
4. Save

For gate attendance:
1. Log in as **School Admin** or **Boarding Officer**
2. Go to **Boarding → Device Sessions**
3. Create a session, add time windows, click **Activate**

---

### Auto-Pull (No Action Needed)

The tablet backend auto-pulls FK623 logs every **5 seconds**. Each scan is automatically:
- Matched to a student
- Recorded in `attendance_logs` and `gate_logs`
- Sent to the portal via Socket.IO in real time
- Triggers SMS/notification if configured

---

## Part 4 — Running Locally (Development Mode)

Both servers are already running on this machine:

| Service | URL | Status |
|---|---|---|
| **Backend API** | http://localhost:5000 | Running |
| **School Portal** | http://localhost:5173 | Running |
| **Network (tablets/devices on same WiFi)** | http://192.168.1.75:5173 | Running |

To test the tablet interface locally without a physical tablet:
- Open http://localhost:3000 (after starting tablet backend + frontend)
- The tablet frontend connects to its own backend on port 5000
- That backend talks to the FK623 if connected, or simulates in dev mode

---

## Part 5 — Troubleshooting Quick Reference

| Problem | Fix |
|---|---|
| Tablet UI shows "Backend offline" | Start `node server.js` in `backend\` folder |
| FKBridge not running | Run `FKBridge.exe` from the `FKBridge\` folder |
| FK623 shows "Connection failed" | Check device IP/port in Developer Settings; verify FK623 is powered and on LAN |
| Student scan not matching | Push students again from portal; verify `device_user_id` is populated |
| Portal can't reach tablet | Check tablet IP in portal matches actual IP; if remote, check WireGuard tunnel |
| "Unauthorized" on API calls | Token expired — log out and log back in |

---

## Part 6 — Local Development URLs Summary

```
School Portal:      http://localhost:5173
Backend API:        http://localhost:5000/api/v1
Tablet Frontend:    http://localhost:3000
Tablet Backend:     http://localhost:5000 (tablet's own backend — same port, different machine)
```

> **Note:** On the production server, `Tablet Backend port 5000` conflicts with the school backend.  
> The tablet backend uses port 5000 locally on the tablet itself — it does NOT run on the server.  
> The school backend runs on the server. These are two separate machines.

---

*EcaAfrica Development Team — August 2026*
