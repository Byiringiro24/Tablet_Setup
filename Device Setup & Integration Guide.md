# EcaAfrica — Device Setup & Integration Guide

**Version:** 1.0  
**System:** EcaAfrica School Management System  
**Applies to:** FK623 Biometric Fingerprint/Face Reader + Windows Tablet Bridge

---

## Overview

The EcaAfrica biometric device system works as a 3-layer stack:

```
FK623 Hardware Device
        ↓  (LAN TCP/IP)
Windows Tablet running FKBridge.exe + Tablet Frontend
        ↓  (WireGuard VPN or LAN)
EcaAfrica Server (Backend API)
        ↓
School Portal (Web Frontend)
```

Each biometric scan at the device flows through this chain, gets matched to a student, and records attendance in the database. The portal gives school staff real-time visibility.

---

## Part 1 — Hardware: FK623 Biometric Device

### What it is
The FK623 is a standalone fingerprint/face recognition device. It stores users (students) locally and records attendance events (logs) internally when a scan happens.

### Physical placement
Each FK623 device must be placed at a specific location:

| Location Type | Use Case |
|---|---|
| **Gate** | School entry/exit, student arrivals and departures |
| **Dormitory** | Evening boarding attendance — students scan before sleep |
| **Dining Hall** | Meal attendance tracking |
| **Classroom** | Class-level attendance (optional) |

### Network requirements
- The FK623 must be on the **same LAN** as the Windows tablet running FKBridge.exe
- Default FK623 port: **5005** (TCP)
- The tablet connects to the device using its **IP address** and **port**
- If the device is in a remote location, WireGuard VPN is required (see Part 4)

### FK623 key settings to note
| Setting | Typical Value | Notes |
|---|---|---|
| IP Address | e.g. `192.168.1.118` | Set on the device itself |
| Port | `5005` | TCP SDK port |
| License Number | e.g. `1261` | From FK623 documentation |
| Protocol Type | `-1` (auto-detect) | Usually leave as default |

---

## Part 2 — Windows Tablet (FKBridge)

### What it is
The Windows Tablet runs two components:
1. **FKBridge.exe** — a .NET 8 background process that maintains a persistent TCP connection to the FK623 device and exposes a local HTTP API on port **5001**
2. **Tablet Frontend** — a Next.js web app (runs on port **3000**) that the school staff or students interact with at the device location

### Installation steps

#### Step 1 — Install FKBridge.exe
1. Copy `FKBridge\bin\Release\net8.0\` folder to the tablet (e.g. `C:\EcaAfrica\FKBridge\`)
2. Run `FKBridge.exe` — it starts listening on `http://localhost:5001`
3. To run at Windows startup: add a shortcut to `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`

#### Step 2 — Install Node.js and the Tablet Frontend
1. Install Node.js 20+ on the tablet
2. Copy the `Tablet Setup\frontend\` folder to the tablet (e.g. `C:\EcaAfrica\Frontend\`)
3. Run `npm install` inside that folder
4. Run `npm run dev` or `npm run build && npm run start` for production

#### Step 3 — Configure the tablet backend environment
Create `Tablet Setup\backend\.env` with:
```
PORT=5001
SERVER_API_URL=https://backend.ecareafrica.net/api/v1
SERVER_API_KEY=<tablet-api-key-from-super-admin>
```

#### Step 4 — Point FKBridge to the FK623 device
In the Tablet Frontend UI, go to **Developer Settings** and enter:
- **FK623 IP Address** — the device's LAN IP
- **FK623 Port** — default `5005`
- **License Number** — from the device documentation
- **Device ID** — a unique label (e.g. `DV-KGL-GATE-01`)

Click **Save** — FKBridge will attempt to auto-connect on startup.

---

## Part 3 — Server-Side Setup (Super Admin)

### Step 1 — Register the Tablet in the Platform

Login to the portal as **Platform Admin** → go to **Super Admin → Hardware → Tablets tab**.

Fill in:
| Field | Description |
|---|---|
| Tablet Name | Human-readable label, e.g. "Main Gate Tablet" |
| IP Address | The tablet's WireGuard VPN IP (e.g. `10.0.0.2`) or LAN IP |
| Port | `5001` (FKBridge backend port) |
| Location | Physical location description |
| Firmware Version | Optional |
| OS Info | e.g. "Windows 11 Pro" |

Click **Create Tablet** — the system generates a **UUID** for this tablet.

### Step 2 — Register the FK623 Device

Go to **Hardware → Devices tab**. Fill in:

| Field | Description |
|---|---|
| School | Select the school this device belongs to |
| Device Name | e.g. "Main Gate FK623" |
| Device UID | Unique identifier, e.g. `FK623-GATE-01` |
| Mode | **gate** / **boarding** / **classroom** |
| Device IP (LAN) | FK623's LAN IP |
| Device Port | FK623's port (default `5005`) |
| License No. | FK623 license number |
| Link to Tablet | Select the tablet registered in Step 1 |

Click **Register Device** — the device is now linked to the tablet.

### Step 3 — Assign Device to a Location

Go to **Hardware → Device Locations tab**.

For each device, click **Assign** and set:
| Field | Description |
|---|---|
| Location Type | gate / dormitory / dining_hall / classroom / other |
| Dormitory | If mode=boarding, select the specific dormitory |
| Location Label | Descriptive label, e.g. "Boys Block A — Main Door" |

This links the device to a dormitory so biometric scans automatically record boarding attendance for the correct block.

### Step 4 — Assign the Device to a School (School Admin)

School Admins see the device under **Boarding → Devices**.  
They can:
- View device status (online/offline)
- Configure attendance sessions with time windows
- Push enrolled students to the device
- Pull attendance logs manually (or it auto-pulls every 5 minutes)

---

## Part 4 — WireGuard VPN (Remote Tablets)

If the tablet is at a school that is not on the same LAN as the server, WireGuard VPN creates a secure tunnel.

### Server setup
1. Go to **Super Admin → Hardware → VPN Setup tab**
2. Click **Initialize WireGuard on Server** — generates server keys and starts the WireGuard interface
3. Note the **Server Public Key** and **Server VPN IP** (e.g. `10.0.0.1`)

### Tablet setup
1. Install WireGuard for Windows: https://www.wireguard.com/install/
2. In the **Tablet Frontend → Developer Settings → WireGuard tab**:
   - Click **Generate Keys on Tablet** — creates a private/public key pair stored on the tablet
   - Copy the **Tablet Public Key**
3. Back in the **Super Admin Portal → VPN Setup**:
   - Paste the tablet's public key
   - Assign a VPN IP (e.g. `10.0.0.2`)
   - Click **Add Peer** — server now accepts connections from this tablet
4. In the **Tablet Frontend**, click **Download WireGuard Config** and import it into WireGuard on Windows
5. Activate the tunnel — the tablet is now reachable at its VPN IP from the server

### After VPN is active
- Update the tablet's record in **Super Admin → Tablets** to use the VPN IP (e.g. `10.0.0.2`)
- All API calls from the server to FKBridge now go through the encrypted VPN tunnel

---

## Part 5 — Student Enrollment on the Device

Before biometric attendance works, students must be enrolled (fingerprint/face registered) on the FK623.

### Method A — Push from portal (recommended)
1. Go to **Boarding → Devices → [select device] → Push Students**
2. Choose:
   - **All boarding students** — pushes every active boarding student
   - **By class** — pushes a specific class section
   - **Selected students** — individual selection
3. Click **Push Students** — the portal calls the FK623 via the tablet bridge and registers each student's `device_user_id` (derived from their student ID number)
4. The student then physically walks to the device and enrolls their fingerprint/face using the device's touchscreen

### Method B — Enroll at device then sync
1. Students enroll fingerprints/faces directly on the FK623
2. In the portal, go to **Boarding → Devices → [device] → Pull Users**
3. The system reads all enrolled users from the device and matches them to students by `device_user_id`

### Student ID mapping
The system maps students to the device using `students.device_user_id`, which is derived from the numeric part of their `student_id_number`.  
Example: student ID `STU-2026-001` → device user ID `2026001`

---

## Part 6 — Attendance Sessions (School Admin / DOD)

Attendance sessions define **when** scans are valid and **what category** they represent.

### Creating an attendance session
Go to **Boarding → Device Sessions** (or **DOD → Boarding Attendance → Windows**).

| Field | Description |
|---|---|
| Session Name | e.g. "Evening Roll Call", "Morning Gate" |
| Attendance Windows | Time ranges when scans count as "Present" |
| Send SMS | Whether to SMS parents on scan |
| Auto-approve | Automatically mark students present when scanned |

### Activating a session
Only **one session can be active per device** at a time.  
Click **Activate** on the session — all subsequent FK623 scans are tagged to this session.

### Boarding-specific windows (DOD only)
The Director of Discipline configures boarding attendance windows at:  
**DOD → Boarding Attendance → Attendance Windows**

| Field | Description |
|---|---|
| Window Name | e.g. "Evening Check-In" |
| Start Time | e.g. 20:00 |
| End Time | e.g. 21:00 |
| Grace Period | Minutes after end time that still count as "Present" |
| Escalation Delay | Minutes after window closes before parent SMS is sent (default: 60) |
| Dormitory | Apply to a specific dorm or all dorms |

---

## Part 7 — How Attendance Logs Flow

```
Student scans at FK623
        ↓
FKBridge.exe picks up the scan event via TCP SDK
        ↓
Tablet Frontend polls FKBridge every 30 seconds (or real-time via SSE)
        ↓
Tablet Backend sends the scan to Server API:
  POST /api/v1/tablets/:id/device/pull-logs
        ↓
Server matches log to student via device_user_id
        ↓
Writes to:
  - attendance_logs (raw device log, never deleted)
  - gate_logs (gate entry/exit events)
  - boarding_attendance_records (boarding session record)
        ↓
Sends real-time Socket.IO event to portal
        ↓
Triggers SMS/notification if configured
```

### Duplicate prevention
The system uses a unique constraint on `[log_id, device_id]` in `attendance_logs` to prevent duplicate records if the same log is pulled multiple times.

### Offline resilience
If the tablet loses internet connectivity:
- FKBridge continues accepting scans locally on the FK623
- When connectivity is restored, the tablet re-pulls all logs since the last successful sync
- Server deduplicates and accepts the backlogged records

---

## Part 8 — Role-Based Device Access

| Role | What they can do with devices |
|---|---|
| **Platform Admin (Super Admin)** | Register tablets, register devices, assign to schools, VPN setup |
| **School Admin** | View devices, configure sessions, push/pull students/logs |
| **Director of Discipline** | Configure boarding attendance windows, view device status |
| **Boarding Officer** | View device status, manage sessions for boarding |
| **Gate Keeper** | View device status only; processes gate exit confirmations |
| **Patron/Matron** | No direct device access; sees attendance results only |
| **Director of Studies** | No device access; sees class attendance submitted via devices |

---

## Part 9 — Monitoring & Troubleshooting

### Device health check
The portal runs automatic health checks every 60 minutes.  
Manual: Go to **Super Admin → Hardware → Tablets** → click **Check Health** on any tablet.

### Device status meanings
| Status | Meaning |
|---|---|
| `online` | Health check passed — tablet and FKBridge are reachable |
| `offline` | Cannot reach the tablet (network issue, tablet off, FKBridge stopped) |
| `error` | Tablet reachable but FKBridge reports an error connecting to the FK623 |
| `maintenance` | Manually set — device is being serviced |

### Common issues and fixes

**Scan not recording:**
1. Check device is `online` in the portal
2. Check the active session is correct (`Boarding → Device Sessions`)
3. Verify student is enrolled on the device (check `device_sync_status`)
4. Check `attendance_logs` table for the raw log — if it exists, the issue is in session matching

**Device shows `offline`:**
1. Verify FKBridge.exe is running on the tablet
2. Check WireGuard tunnel is active (if remote)
3. Ping the tablet IP from the server
4. Restart FKBridge.exe on the tablet

**Student not matching:**
1. Verify `students.device_user_id` is populated — if not, push students again
2. Check the student's ID number contains a numeric portion
3. In the portal: **Boarding → Devices → Pull Users** to sync device enrollment back to the system

**Duplicate attendance records:**
The deduplication logic prevents exact duplicates. If you see unexpected records, check `attendance_logs.is_flagged` — flagged records have a `flag_reason` explaining why they were not processed.

---

## Part 10 — Complete Setup Checklist

### One-time setup (Platform Admin)
- [ ] Register Windows tablet in **Super Admin → Hardware → Tablets**
- [ ] Set up WireGuard VPN if tablet is remote (**VPN Setup tab**)
- [ ] Register FK623 device in **Hardware → Devices**, link to tablet
- [ ] Assign device to location (dormitory/gate) in **Device Locations tab**

### Per-school setup (School Admin / DOD)
- [ ] Create boarding attendance windows (**DOD → Boarding Attendance**)
- [ ] Create dormitories and assign patrons (**DOD → Dormitories**, **DOD → Patrons**)
- [ ] Create device attendance sessions (**Boarding → Device Sessions**)
- [ ] Push students to the FK623 device (**Boarding → Devices → Push Students**)
- [ ] Have students enroll fingerprints/faces at the device
- [ ] Activate the correct session on the device
- [ ] Run a test scan and verify it appears in **Boarding → Device Sessions → Attendance History**

### Daily operation (auto)
- [ ] Device auto-pulls logs every 5 minutes (configurable)
- [ ] Attendance window closes → system reconciles (present/late/missing)
- [ ] 1 hour after window closes → parent SMS sent for missing students (if configured)

---

## Quick Reference — API Endpoints for Device Operations

| Operation | Endpoint |
|---|---|
| List tablets | `GET /api/v1/tablets` |
| Health check | `GET /api/v1/tablets/:id/health` |
| Connect to FK623 | `POST /api/v1/tablets/:id/device/connect` |
| Pull logs from FK623 | `POST /api/v1/tablets/:id/device/pull-logs` |
| Push students to FK623 | `POST /api/v1/tablets/:id/device/push-students` |
| Get device status | `GET /api/v1/tablets/:id/device/status` |
| Pull all active tablets | `POST /api/v1/tablets/pull-all-logs` |
| Assign device location | `PATCH /api/v1/devices/:id/assign-location` |
| Create boarding att. window | `POST /api/v1/boarding/attendance/windows` |
| Reconcile attendance session | `POST /api/v1/boarding/attendance/sessions/:id/reconcile` |

---

*Document last updated: August 2026 | EcaAfrica Development Team*
