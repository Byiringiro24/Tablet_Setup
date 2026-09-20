# Super Admin — Hardware Setup Guide
## Biometric Attendance System (FK623 + Windows Tablet + WireGuard VPN)

**System:** EcareAfrica  
**Date:** August 2026  
**Who uses this:** Super Admin only  
**Where:** `https://ecareafrica.net` → Super Admin → Tablets & Devices

---

## How It Works (Big Picture)

```
Student scans finger/face on FK623 reader
        ↓
FK623 biometric device (school LAN e.g. 192.168.1.118)
        ↓  TCP on port 5005
Windows tablet (bridge app FKBridge.exe on port 5000)
        ↓  WireGuard VPN tunnel (e.g. 10.0.0.2)
EcareAfrica backend server (169.58.124.150)
        ↓  every 5 seconds
attendance_logs + gate_logs saved to database
        ↓  instantly
SMS sent to parent + Live Monitor updates in browser
```

**Once setup is done, everything is automatic.** The super admin does not need to do anything daily.

---

## What You Need Before Starting

Collect this information from the school before you begin:

| Info needed | Example | Where to get it |
|---|---|---|
| FK623 device IP (school LAN) | `192.168.1.118` | School IT staff or check router |
| FK623 port | `5005` | Default — rarely changes |
| FK623 license number | `1261` | Label on the device or FK623 software |
| FK623 device serial | `S1000250228115` | Label on the device |
| Windows tablet WireGuard VPN IP | `10.0.0.2` | From WireGuard setup (each tablet gets a unique 10.0.0.x) |
| School name | `Green Hills Academy` | Already registered in the system |

---

## Step-by-Step Setup

### Step 1 — Register the Tablet (Windows PC at the school)

Go to: **Super Admin → Tablets & Devices → Tablets tab**

Fill in the form on the left:

| Field | What to enter | Example |
|---|---|---|
| School | Select from list | Green Hills Academy |
| Tablet Name | Descriptive name | Main Gate Tablet |
| WireGuard VPN IP | The 10.0.0.x IP assigned to this tablet | `10.0.0.2` |
| Bridge API Port | Leave as `5000` unless changed | `5000` |
| Location | Where the tablet is placed | Main Gate |
| Notes | Optional | Installed August 2026 |

Click **Register Tablet**.

✅ You will see the tablet appear in the list on the right.  
✅ The status shows "online" if the WireGuard VPN and bridge app are running on the Windows PC.

> **Note:** If status shows "offline" after registration, it means the VPN tunnel or bridge app is not running on the Windows PC. The auto-pull will still activate once those are started — no need to re-register.

---

### Step 2 — Register the FK623 Device

Go to: **Super Admin → Tablets & Devices → Devices tab**

Fill in the form on the left:

| Field | What to enter | Example |
|---|---|---|
| School | Same school as the tablet | Green Hills Academy |
| Device Name | Descriptive name | Main Gate Reader |
| Device UID | Unique identifier you assign | `FK623-GATE-01` |
| Mode | How it is used | Gate (entry/exit) |
| Location | Where the reader is mounted | Main Gate |
| Serial Number | From label on device | `S1000250228115` |
| Product Name | From label or FK623 docs | `Pollo` |
| Device IP (LAN) | FK623 IP on school network | `192.168.1.118` |
| Device Port | FK623 TCP port | `5005` |
| License No. | FK623 license number | `1261` |
| **Tablet (Windows Bridge)** | **Select the tablet from Step 1** | **Main Gate Tablet (10.0.0.2:5000)** |

The last field (Tablet) is the key one — **selecting it here links and connects everything automatically.**

Click **Register & Connect Device**.

✅ The system will:
1. Save the device to the database
2. Link it to the selected tablet
3. Send a connect command to the bridge app over the VPN
4. The bridge app establishes a TCP connection to the FK623
5. Auto-pull starts within 5 seconds

> **If you see "Device registered, linked and connected to FK623 — auto-pull is now active ✓"** — you are done. Logs will appear automatically.

> **If you see "Device registered and linked. Bridge connect will retry automatically"** — the VPN or bridge is not fully ready yet. The system retries every 5 seconds automatically.

---

### Step 3 — Verify Everything Is Working

Go to: **Super Admin → Tablets & Devices → Assign tab**

Look at the status cards at the top:
- **Linked to tablet** — should show 1/1 (or the count of your devices)
- **FK623 connected** — should show 1/1 once the bridge connects
- **Incomplete setup** — should show 0

Look at the **Assignments Overview** table at the bottom:

| Column | What you want to see |
|---|---|
| Linked Tablet | Name of the tablet (not "Not linked") |
| Auto-pull | **Active** (green badge) |
| Status | **Online** (green) |
| Action | **✓ Active** (not a "Connect" button) |

If Auto-pull shows **Active** and Status shows **Online**, logs will flow automatically.

---

### Step 4 — Push Students to the Device (if not already enrolled)

Students must be registered on the FK623 device before it can recognize their fingerprints.

Go to: **School Admin → Devices → [Select the device] → Push Students**

Select students by class or individually and click Push. The bridge app sends each student's biometric profile to the FK623.

> This is done by the school admin, not the super admin. Instruct the school admin to do this after hardware setup is complete.

---

## Real Example — Green Hills Academy

**Scenario:** Setting up attendance tracking at the main gate of Green Hills Academy.

**What you have:**
- FK623 device at `192.168.1.118:5005` with license `1261`
- Windows tablet with WireGuard VPN IP `10.0.0.2`
- Bridge app running on the tablet at port `5000`

**Step 1 — Register tablet:**
```
School:           Green Hills Academy
Tablet Name:      Main Gate Tablet
WireGuard VPN IP: 10.0.0.2
Port:             5000
Location:         Main Gate
```
→ Click Register Tablet

**Step 2 — Register device:**
```
School:            Green Hills Academy
Device Name:       Main Gate Reader
Device UID:        FK623-GATE-01
Mode:              Gate (entry/exit)
Location:          Main Gate
Device IP (LAN):   192.168.1.118
Device Port:       5005
License No.:       1261
Tablet:            Main Gate Tablet (10.0.0.2:5000)  ← select this
```
→ Click Register & Connect Device

**Result:** Within 5 seconds the system begins pulling logs. When a student scans, the log appears in the gate monitor within 10 seconds and an SMS is sent to the parent.

---

## Adding a Second School

Repeat Steps 1–2 for the new school. Each tablet gets a unique WireGuard VPN IP:
- School 1 tablet: `10.0.0.2`
- School 2 tablet: `10.0.0.3`
- School 3 tablet: `10.0.0.4`

On the server, add each new tablet as a WireGuard peer before registration:
```bash
# On the server (SSH)
sudo wg set wg0 peer <NEW_TABLET_PUBLIC_KEY> allowed-ips 10.0.0.3/32
wg-quick save wg0
```

---

## Moving a Tablet to a Different School

Go to: **Super Admin → Tablets & Devices → Assign tab → Assign Tablet to School**

Select the tablet and the new school, then click **Move Tablet**.

The system automatically:
- Moves the tablet and all linked devices to the new school
- Resets the connection so it reconnects under the new school context
- Auto-pull resumes for the new school within one sweep cycle (5 seconds)

---

## Troubleshooting

### Tablet shows "offline" after registration

The WireGuard tunnel or bridge app is not active on the Windows PC. Check:
1. WireGuard is installed and the tunnel is **Active** on the Windows PC
2. FKBridge.exe is running (check Windows task manager)
3. From the server: `ping 10.0.0.2` — should get replies

Auto-pull retries automatically every 5 seconds. Once the bridge comes online, logs will start flowing without any action needed.

### Device shows "Offline" / Connect button appears

Click the **Connect FK623** button (blue lightning bolt) in the Devices list or Assign tab. This triggers the bridge to establish a TCP connection to the FK623.

If it times out:
- Check the FK623 device is powered on
- Verify the IP address is correct (`192.168.1.118`)
- Verify the FK623 is reachable from the Windows tablet (open cmd on the tablet: `ping 192.168.1.118`)

### Logs not appearing in the gate monitor

Check in order:
1. **Assign tab → status cards** — is "FK623 connected" showing 1/1?
2. **Devices tab** — does the device show "Auto-pull active"?
3. On the server: `pm2 logs ecare-backend --lines 20 --nostream` — look for `[pull-logs] Pull complete { saved: N }`
4. Verify students are enrolled on the FK623 (biometric profiles pushed)

### "Connect FK623" fails with "Timeout"

The WireGuard VPN is down or the bridge is not running. The system will retry automatically every 5 seconds once both are back online.

---

## What Happens Automatically (No Action Required)

Once setup is complete, the following happens with zero manual intervention:

| Event | Automatic action |
|---|---|
| Student scans fingerprint/face | Log recorded on FK623 |
| Backend polls every 5 seconds | Log pulled from bridge, saved to DB |
| Log saved | SMS sent to parent within seconds |
| Log saved | Live Monitor in gate page updates instantly |
| Tablet VPN drops and reconnects | Auto-pull resumes within one cycle |
| FK623 TCP connection drops | Bridge reconnects and pull resumes |
| Server restart | Pull job restarts automatically via PM2 |

---

## Summary Checklist

Use this when setting up a new school:

- [ ] School registered in Super Admin → Schools
- [ ] Windows tablet has WireGuard VPN installed and tunnel active (10.0.0.x assigned)
- [ ] FKBridge.exe running on the Windows tablet, listening on port 5000
- [ ] `curl http://10.0.0.x:5000/api/health` returns `"bridgeRunning": true` from the server
- [ ] Tablet registered in Tablets tab with correct VPN IP
- [ ] FK623 device registered in Devices tab with LAN IP, port, license, and linked to tablet
- [ ] Assign tab shows: Linked=1, Connected=1, Auto-pull=Active
- [ ] School admin has pushed students to the FK623 device
- [ ] Test scan performed — log appears in gate monitor within 10 seconds

---

**Document prepared by:** System Administrator  
**Last updated:** August 7, 2026
