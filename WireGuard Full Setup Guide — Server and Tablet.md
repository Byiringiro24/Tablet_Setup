# EcaAfrica — WireGuard VPN Full Setup Guide
## Server + Tablet Configuration with Examples

**Version:** 2.0  
**Server:** `169.58.124.150` (EcaAfrica production server)  
**VPN Subnet:** `10.0.0.0/16` (supports 65,534 tablets)  
**Tunnel name on every tablet:** `EcareAfrica`  
**WireGuard port:** `51820/UDP`

---

## Architecture Overview

```
School A                        Internet (encrypted)           EcaAfrica Server
┌──────────────────────┐                                    ┌─────────────────────────┐
│  FK623 Device         │                                    │  169.58.124.150         │
│  IP: 192.168.1.118    │                                    │  VPN IP: 10.0.0.1       │
│  Port: 5005 (SDK)     │                                    │  WireGuard wg0: :51820  │
│         │             │                                    │         │               │
│  Windows Tablet       │  ◄──── WireGuard UDP 51820 ────►  │  Backend API: :5500     │
│  VPN IP: 10.0.0.2     │                                    │  (nginx → 5500)         │
│  Node.js: :5000       │                                    │  nginx: :443 HTTPS      │
│  FKBridge.exe         │                                    └─────────────────────────┘
└──────────────────────┘

School B                                                     School C
┌──────────────────────┐                                    ┌──────────────────────┐
│  Tablet VPN: 10.0.0.3│ ◄──────────────────────────────► │  Tablet VPN: 10.0.0.4│
└──────────────────────┘                                    └──────────────────────┘

(up to 65,534 tablets across any number of schools — all same code, different VPN IP)
```

---

## How it Works — End to End

1. Student scans fingerprint/face on FK623 device
2. FKBridge.exe (on tablet) receives the scan via TCP SDK
3. Tablet Node.js backend (`server.js`) picks it up via log poll (every 2 seconds)
4. School server (`bridge-sse.job.ts`) is connected to the tablet via SSE — receives the event in **< 1 second**
5. School server saves it to the database and fires real-time Socket.IO to the school portal
6. Pull-logs job (`pull-logs.job.ts`) runs every 5 seconds as a safety net catch-up

**Everything after initial setup is fully automatic — no manual intervention needed.**

---

## Part 1 — SERVER SETUP (done ONCE by you or a DevOps person via SSH)

This is done once when you first deploy the server. After this, every new tablet is added from the web portal — no more SSH needed.

### Step 1.1 — SSH into the server

```bash
ssh root@169.58.124.150
# Password: EcaProject@2026$
```

### Step 1.2 — Install WireGuard

```bash
apt update && apt install -y wireguard
```

Verify:
```bash
wg --version
# Expected: wireguard-tools v1.0.20210914 or later
```

### Step 1.3 — Find your network interface name

```bash
ip route | grep default
# Example output: default via 169.58.124.1 dev eth0 proto dhcp src 169.58.124.150
# The interface name is: eth0
```

Note this — you need it in Step 1.4.

### Step 1.4 — Generate server key pair

```bash
cd /etc/wireguard

# Generate private key (keep secret — never share this)
wg genkey | tee server_private.key | wg pubkey > server_public.key

# Lock down private key permissions
chmod 600 server_private.key

# Show your keys
echo "Private key: $(cat server_private.key)"
echo "Public key:  $(cat server_public.key)"
```

**Example output:**
```
Private key: 8Jk2mNvPqR3sT4uV5wX6yZ7aB8cD9eF0gH1iJ2kL3mN=
Public key:  gbHhDpRrpbqObBL3Z8idBmuYLJsMAnoTXfy+jg/kWDI=
```

The **public key** is what you paste into the Super Admin portal and give to technicians.  
The **private key** never leaves the server.

### Step 1.5 — Create the WireGuard server config

```bash
nano /etc/wireguard/wg0.conf
```

Paste this (replace `<SERVER_PRIVATE_KEY>` with your actual private key, replace `eth0` with your interface):

```ini
[Interface]
Address    = 10.0.0.1/16
ListenPort = 51820
PrivateKey = <SERVER_PRIVATE_KEY>

# Allow IP forwarding so tablets can reach the backend API through VPN
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
```

**Real example:**
```ini
[Interface]
Address    = 10.0.0.1/16
ListenPort = 51820
PrivateKey = 8Jk2mNvPqR3sT4uV5wX6yZ7aB8cD9eF0gH1iJ2kL3mN=

PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
```

### Step 1.6 — Enable IP forwarding

```bash
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p
# Expected: net.ipv4.ip_forward = 1
```

### Step 1.7 — Open firewall port

```bash
ufw allow 51820/udp
ufw reload
ufw status
# Expected: 51820/udp  ALLOW  Anywhere
```

### Step 1.8 — Start WireGuard and enable on boot

```bash
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
systemctl status wg-quick@wg0
```

**Expected:**
```
● wg-quick@wg0.service
   Active: active (running)
```

Verify the interface is up:
```bash
wg show
# Expected:
# interface: wg0
#   public key: gbHhDpRrpbqObBL3Z8idBmuYLJsMAnoTXfy+jg/kWDI=
#   listening port: 51820
```

### Step 1.9 — Add WireGuard env vars to the backend `.env`

```bash
nano /var/www/ecare/backend/.env
```

Add these lines (they have defaults, but setting them explicitly is recommended):

```env
# WireGuard server config
WG_CONF_PATH=/etc/wireguard/wg0.conf
WG_PUBKEY_PATH=/etc/wireguard/server_public.key
WG_INTERFACE=wg0
VPN_SUBNET=10.0
VPN_CIDR=16
SERVER_VPN_IP=10.0.0.1
SERVER_PUBLIC_IP=169.58.124.150
WG_PORT=51820
```

Restart the backend:
```bash
pm2 restart ecare-backend --update-env
```

**Server setup is now complete. You never need to SSH in again to add tablets — use the web portal.**

---

## Part 2 — ADDING EACH NEW TABLET (Super Admin does this from the web portal)

For every new Windows tablet deployed to a school, the Super Admin follows these steps in the portal. No SSH required.

### Step 2.1 — Log into the Super Admin portal

```
https://ecareafrica.net/login?mode=platform
Email: platform.admin@ecareafrica.test
Password: Admin@123
```

### Step 2.2 — Check the server VPN status

Go to: **Super Admin → Hardware → VPN Setup tab**

Click **Refresh Server Info**. You will see:

| Field | Example |
|---|---|
| Server Public Key | `gbHhDpRrpbqObBL3Z8idBmuYLJsMAnoTXfy+jg/kWDI=` |
| Server Endpoint | `169.58.124.150:51820` |
| Next Available VPN IP | `10.0.0.2` (auto-calculated — first unused IP) |
| VPN Subnet | `10.0.0.0/16` |
| Active Peers | `0` (increases as tablets connect) |

### Step 2.3 — Get the tablet's public key from the technician

The on-site technician will:
1. Install the tablet (see Part 3)
2. Open the WireGuard wizard on the tablet
3. Generate keys
4. Send you the **public key** (e.g. via WhatsApp or email)

**Example tablet public key:** `xYzAb1Cd2Ef3Gh4Ij5Kl6Mn7Op8Qr9St0Uv1Wx2Yz3=`

### Step 2.4 — Add the tablet as a VPN peer

In the VPN Setup tab:

1. **Tablet Public Key** field: paste `xYzAb1Cd2Ef3Gh4Ij5Kl6Mn7Op8Qr9St0Uv1Wx2Yz3=`
2. **Assign VPN IP**: use the suggested next IP, e.g. `10.0.0.2`
3. **Comment** (optional): `Green Hills Academy - Main Gate`
4. Click **Add Peer to VPN**

✅ A green box appears: "Peer added — tablet VPN IP is 10.0.0.2. Now go to the Tablets tab and register this tablet."

### Step 2.5 — Register the tablet in the Tablets tab

Go to: **Super Admin → Hardware → Tablets tab**

Fill in:
| Field | Example |
|---|---|
| School | Green Hills Academy |
| Tablet Name | `Main Gate Tablet` |
| WireGuard VPN IP | `10.0.0.2` |
| Port | `5000` |
| Location | `Main Gate` |

Click **Register Tablet**.

The UUID is generated (e.g. `a1b2c3d4-e5f6-7890-abcd-ef1234567890`). **Copy it — give it to the technician.**

### Step 2.6 — Tell the technician these three things

```
Server Public Key:  gbHhDpRrpbqObBL3Z8idBmuYLJsMAnoTXfy+jg/kWDI=
Assigned VPN IP:    10.0.0.2
Tablet UUID:        a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

That's all the Super Admin needs to do. The server will automatically start pulling logs from this tablet once the tunnel is active.

---

## Part 3 — TABLET SETUP (Technician does this on-site)

Every tablet runs **the same code** from the repository. The only things that change per tablet:
- `TABLET_UUID` in `backend/.env`
- The VPN IP assigned in Step 2.4

### Step 3.1 — Prerequisites on the Windows tablet

Install these first:

1. **.NET 8 Runtime** → https://dotnet.microsoft.com/download/dotnet/8.0
2. **Node.js 20 LTS** → https://nodejs.org
3. **WireGuard for Windows** → https://www.wireguard.com/install/ *(can also be installed from the wizard)*

### Step 3.2 — Copy the tablet code

Copy the `Tablet Setup` folder to the tablet. Recommended location: `C:\EcaAfrica\`

```
C:\EcaAfrica\
├── FKBridge\           ← .NET 8 bridge — talks to FK623
│   └── FKBridge.exe
├── backend\            ← Node.js server (port 5000)
│   ├── server.js
│   └── .env            ← YOU CONFIGURE THIS
└── frontend\           ← Next.js UI (port 3000)
    ├── app\page.tsx
    └── .env.local      ← always localhost:5000
```

Or clone from GitHub (replace `YOUR_TOKEN`):
```cmd
git clone -b Testing-Branch https://Byiringiro24:YOUR_TOKEN@github.com/Byiringiro24/Tablet_Setup.git C:\EcaAfrica
```

### Step 3.3 — Configure `backend/.env`

Edit `C:\EcaAfrica\backend\.env`:

```env
# Port (always 5000)
PORT=5000

# School server URL
SERVER_API_URL=https://backend.ecareafrica.net/api/v1

# Tablet UUID from portal (Step 2.5)
TABLET_UUID=a1b2c3d4-e5f6-7890-abcd-ef1234567890

# WireGuard settings (these match the server automatically)
WG_SERVER_ENDPOINT=169.58.124.150:51820
VPN_ALLOWED_IPS=10.0.0.0/16
WG_DNS=1.1.1.1
```

> **For each new tablet, only `TABLET_UUID` changes.**  
> All other settings are the same on every tablet.

### Step 3.4 — Install Node.js dependencies

Open Command Prompt **as Administrator**:

```cmd
cd C:\EcaAfrica\backend
npm install

cd C:\EcaAfrica\frontend
npm install
```

### Step 3.5 — Start the three services

Open **three** Command Prompt windows **as Administrator** (WireGuard requires admin):

**Window 1 — FKBridge:**
```cmd
cd C:\EcaAfrica\FKBridge
FKBridge.exe
```
✓ `FK Attendance Bridge started`

**Window 2 — Tablet Backend:**
```cmd
cd C:\EcaAfrica\backend
node server.js
```
✓ `FK Attendance Backend running on http://localhost:5000`
✓ `Auto-connect attempt #1: 192.168.1.118:5005` ← starts trying to reach FK623

**Window 3 — Tablet Frontend:**
```cmd
cd C:\EcaAfrica\frontend
npm run dev
```
✓ `ready - started server on http://localhost:3000`

Open browser: **http://localhost:3000**

### Step 3.6 — Connect the FK623 device

1. On `http://localhost:3000` — click the **gear icon** (bottom of sidebar) to open Developer Settings
2. Password: `admin1234`
3. Fill in:
   - **FK623 IP**: `192.168.1.118` (the device's LAN IP)
   - **Port**: `5005`
   - **License**: `1261` (from your FK623 documentation)
   - **Device ID**: `DV-KGL-01` (any unique label)
4. Click **Save & Connect**

✅ Status shows **Connected** with serial number, user count, log count.

### Step 3.7 — Set up WireGuard VPN

1. In the Developer panel, click **WireGuard VPN** (shield icon)
2. **Step 1 — Install**: WireGuard is already installed → click "WireGuard is installed → Next"
3. **Step 2 — Generate Keys**: click **Generate Keys**
   - Public key appears, e.g. `xYzAb1Cd2Ef3Gh4Ij5Kl6Mn7Op8Qr9St0Uv1Wx2Yz3=`
   - Click **Copy** → send this key to the Super Admin
   - Wait for Super Admin to add the peer (Steps 2.3–2.6 above)
   - When done, click **Next → Configure**
4. **Step 3 — Configure**:
   - **Server Public Key**: paste what Super Admin gave you, e.g. `gbHhDpRrpbqObBL3Z8idBmuYLJsMAnoTXfy+jg/kWDI=`
   - **Server Endpoint**: already filled: `169.58.124.150:51820` ← from your `.env`
   - **Tablet VPN IP**: `10.0.0.2` ← what Super Admin assigned
   - **DNS**: `1.1.1.1` ← leave as default
   
   Config preview:
   ```ini
   [Interface]
   PrivateKey = <saved on tablet>
   Address    = 10.0.0.2/32
   DNS        = 1.1.1.1

   [Peer]
   PublicKey           = gbHhDpRrpbqObBL3Z8idBmuYLJsMAnoTXfy+jg/kWDI=
   AllowedIPs          = 10.0.0.0/16
   Endpoint            = 169.58.124.150:51820
   PersistentKeepalive = 25
   ```
   
   Click **Save & Activate Tunnel**

5. **Step 4 — Activate**: tunnel should show **Active — EcareAfrica**
   - VPN IP: `10.0.0.2`
   - Last handshake: `a few seconds ago`

6. **Step 5 — Ping Test**:
   - Target: `10.0.0.1` (already filled)
   - Click **Ping**
   
   ✅ Green result:
   ```
   Pinging 10.0.0.1 with 32 bytes of data:
   Reply from 10.0.0.1: bytes=32 time=14ms TTL=64
   Reply from 10.0.0.1: bytes=32 time=12ms TTL=64
   ```
   
   ✅ Panel shows: **"Setup Complete — VPN tunnel is live"**
   - "School server will detect this tablet within 30 seconds"
   - "Every scan on the FK623 will be sent in real-time"
   - "This setup survives Windows reboots"
   
   Click **Close — Tablet is ready**

### Step 3.8 — What happens automatically after this

| Time | What happens |
|---|---|
| T+0 | Ping succeeds, tunnel active |
| T+3s | Server's `bridge-sse.job.ts` detects new tablet (refresh every 30s) |
| T+3-30s | Server opens SSE connection to `http://10.0.0.2:5000/api/events` |
| T+5s | Server's `pull-logs.job.ts` pulls first log batch from tablet |
| Any scan | FK623 → FKBridge → server.js → SSE → school server → DB + Socket.IO |

**Nothing else to do. The tablet is live.**

---

## Part 4 — VPN IP ASSIGNMENT (for 100+ tablets)

Each tablet gets a unique IP in the `10.0.0.0/16` subnet. The server is always `.0.1`.

| IP | Device |
|---|---|
| `10.0.0.1` | EcaAfrica server |
| `10.0.0.2` | Tablet 1 — Green Hills Academy, Main Gate |
| `10.0.0.3` | Tablet 2 — Green Hills Academy, Side Gate |
| `10.0.0.4` | Tablet 3 — Kigali Primary, Main Gate |
| `10.0.0.5` | Tablet 4 — Kigali Primary, Dormitory A |
| `10.0.1.1` | Tablet 256 — (third octet increments after 254) |
| … | … |
| `10.0.255.254` | Tablet 65,534 (maximum) |

The Super Admin portal **auto-suggests the next available IP** — you never calculate this manually.

**The only thing that differs between tablets in `.env`:**
```
TABLET_UUID=<unique per tablet — from portal>
```

**Everything else in `.env` is identical across all tablets.**

---

## Part 5 — SECOND TABLET EXAMPLE (tablet 2 at same school)

Super Admin portal:
1. Gets tablet public key from technician: `mnOpQr1St2Uv3Wx4Yz5Ab6Cd7Ef8Gh9Ij0Kl1Mn2=`
2. VPN Setup tab → paste key → assign IP `10.0.0.3` → Add Peer to VPN
3. Tablets tab → register: name `Side Gate Tablet`, IP `10.0.0.3`, port `5000`
4. Gives technician: server public key, VPN IP `10.0.0.3`, UUID `b2c3d4e5-...`

Technician sets `backend/.env` on the second tablet:
```env
PORT=5000
SERVER_API_URL=https://backend.ecareafrica.net/api/v1
TABLET_UUID=b2c3d4e5-f6a7-8901-bcde-f23456789012    ← only this changes
WG_SERVER_ENDPOINT=169.58.124.150:51820
VPN_ALLOWED_IPS=10.0.0.0/16
WG_DNS=1.1.1.1
```

In the WireGuard wizard, sets VPN IP to `10.0.0.3`.

**Both tablets run simultaneously — fully independent — both auto-connect and send logs.**

---

## Part 6 — VERIFYING EVERYTHING IS WORKING

### On the server (SSH)

```bash
# Show all active VPN peers and their last handshake
wg show
# Expected (one block per tablet):
# interface: wg0
#   public key: gbHhDpRrpbqObBL3Z8idBmuYLJsMAnoTXfy+jg/kWDI=
#   listening port: 51820
#
# peer: xYzAb1Cd2Ef3Gh4Ij5Kl6Mn7Op8Qr9St0Uv1Wx2Yz3=
#   endpoint: <school-public-ip>:xxxxx
#   allowed ips: 10.0.0.2/32
#   latest handshake: 14 seconds ago    ← means tunnel is live
#   transfer: 1.23 MiB received, 456 KiB sent

# Ping tablet from server
ping 10.0.0.2
# Expected: Reply from 10.0.0.2 bytes=32 time=18ms

# Check backend logs for this tablet
pm2 logs ecare-backend --lines 20 --nostream | grep "10.0.0.2\|bridge-sse\|pull-logs"
```

### In the school portal

1. Login as School Admin → Boarding → Devices
2. Tablet should show **Online** with a recent `last_health_check` timestamp
3. Under Device Sessions → Attendance History: scans appear within 5 seconds

### On the tablet

```
http://localhost:3000
```
- Status badge shows **Online** (green)
- Sidebar logs list fills with scans as students scan
- Full-screen flash shows student name + photo when a scan happens

---

## Part 7 — TROUBLESHOOTING

| Problem | Cause | Fix |
|---|---|---|
| Ping fails (Step 5) | Server hasn't added this tablet as a peer | Super Admin: VPN Setup → paste public key → Add Peer |
| Ping fails (Step 5) | Firewall blocking UDP 51820 | SSH: `ufw allow 51820/udp && ufw reload` |
| "Failed to install tunnel" | Backend not running as Administrator | Close and reopen Command Prompt as Administrator |
| Tunnel shows Inactive | Server public key pasted wrong | Re-generate keys (Step 2), redo wizard |
| FK623 not connecting | Wrong IP in Developer Settings | Check FK623's LAN IP on the device screen → re-enter |
| School server shows tablet Offline | Tablet VPN IP in portal doesn't match `.env` | Check portal IP vs `WireGuard VPN IP` in wizard |
| Tablet drops after reboot | Normal — WireGuard service auto-starts | Wait 10-15s after Windows boot for tunnel to come up |
| Server can't pull logs | Tablet UUID not set | Edit `backend/.env`, set `TABLET_UUID=`, restart `node server.js` |
| Two tablets same VPN IP | Human error in assignment | VPN Setup → remove duplicate → re-add with different IP |

---

## Part 8 — AUTO-STARTUP ON WINDOWS BOOT

To make everything start automatically when Windows reboots:

1. Press `Win + R` → type `shell:startup` → Enter
2. Create these three shortcuts in the Startup folder:

**`1-FKBridge.bat`:**
```bat
@echo off
cd /d "C:\EcaAfrica\FKBridge"
FKBridge.exe
```

**`2-Backend.bat`:**
```bat
@echo off
cd /d "C:\EcaAfrica\backend"
node server.js
```

**`3-Frontend.bat`:**
```bat
@echo off
cd /d "C:\EcaAfrica\frontend"
npm run start
```

> Both FKBridge.exe and `node server.js` need **Run as Administrator**. Right-click each shortcut → Properties → Advanced → check "Run as administrator".

---

## Part 9 — COMPLETE CHECKLIST

### Server (done once):
- [ ] WireGuard installed (`apt install wireguard`)
- [ ] Server key pair generated (`/etc/wireguard/server_public.key`)
- [ ] `wg0.conf` created with `/16` subnet and PostUp/PostDown rules
- [ ] IP forwarding enabled (`net.ipv4.ip_forward = 1`)
- [ ] Firewall open (`ufw allow 51820/udp`)
- [ ] `wg-quick@wg0` service enabled and running
- [ ] Backend `.env` has `SERVER_PUBLIC_IP`, `WG_PORT`, `VPN_SUBNET=10.0`, `VPN_CIDR=16`

### Per tablet (Super Admin portal):
- [ ] Got tablet public key from technician
- [ ] Added as WireGuard peer (VPN Setup tab)
- [ ] Registered in Tablets tab with VPN IP + port 5000
- [ ] Gave technician: server public key, VPN IP, Tablet UUID

### Per tablet (technician on-site):
- [ ] .NET 8 installed
- [ ] Node.js 20 installed
- [ ] WireGuard for Windows installed
- [ ] `backend/.env` configured (`TABLET_UUID`, port 5000, server URL)
- [ ] `npm install` done in backend and frontend
- [ ] FKBridge.exe running (as Administrator)
- [ ] `node server.js` running (as Administrator)
- [ ] FK623 device configured in Developer Settings
- [ ] WireGuard wizard completed (Steps 1–5)
- [ ] Ping test shows green ✓
- [ ] "Close — Tablet is ready" clicked

---

## Quick Reference Card

```
SUPER ADMIN gets from technician:
  → Tablet Public Key (44 chars base64 ending in =)

SUPER ADMIN gives to technician:
  → Server Public Key  (from portal VPN Setup tab)
  → Assigned VPN IP    (e.g. 10.0.0.2)
  → Tablet UUID        (from Tablets tab after registration)

TECHNICIAN sets in backend/.env:
  TABLET_UUID=<from portal>
  (everything else is same on all tablets)

TECHNICIAN sets in wizard Step 3:
  Server Public Key = <from super admin>
  VPN IP           = <from super admin, e.g. 10.0.0.2>
  (server endpoint auto-filled from .env)
```

---

*EcaAfrica Development Team — September 2026*  
*Server: `169.58.124.150` · VPN: `10.0.0.0/16` · Max tablets: 65,534*
