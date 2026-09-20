# EcaAfrica — Complete System Guide
## Architecture, Setup, and Operations Manual

**Version:** September 2026  
**Server:** 169.58.124.150 (Contabo VPS, Ubuntu 24.04)  
**Domain:** https://ecareafrica.net  
**Backend API:** https://backend.ecareafrica.net  

---

## 1. SYSTEM ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────────┐
│                    ECAFRICA CLOUD SERVER                        │
│                    169.58.124.150                               │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────────────────────────┐ │
│  │  Nginx (80/443) │    │  Node.js Backend (PM2, port 5500)   │ │
│  │  SSL via nginx  │    │  PostgreSQL database                │ │
│  │  Serves React   │    │  Redis (jobs/queues)                │ │
│  │  frontend dist  │    │  WireGuard VPN (port 51820/UDP)     │ │
│  └─────────────────┘    └─────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
              ▲                          ▲
              │ HTTPS                    │ WireGuard VPN (10.0.x.x)
              │                          │
    ┌─────────────────┐        ┌─────────────────────────────────┐
    │  School Browser │        │  Windows Tablet (at school)     │
    │  Chrome/Edge    │        │                                 │
    │  Any device     │        │  ┌──────────────┐               │
    │                 │        │  │ FK623 Device │ (LAN)         │
    │  Portals:       │        │  │ biometric    │               │
    │  - Super Admin  │        │  └──────┬───────┘               │
    │  - School Admin │        │         │ TCP 5005              │
    │  - DOD          │        │  ┌──────▼───────┐               │
    │  - DOS          │        │  │ FKBridge.exe │               │
    │  - Patron       │        │  │ (bridge app) │               │
    │  - Gate Keeper  │        │  └──────┬───────┘               │
    │  - Teacher      │        │         │ HTTP 5000             │
    │  - Finance      │        │  ┌──────▼───────┐               │
    │  - Staff        │        │  │ server.js    │               │
    └─────────────────┘        │  │ Node backend │               │
                               │  └──────┬───────┘               │
                               │         │ HTTP 3000             │
                               │  ┌──────▼───────┐               │
                               │  │ Next.js UI   │               │
                               │  │ Tablet App   │               │
                               │  └──────────────┘               │
                               └─────────────────────────────────┘
```

### Components

| Component | Location | Purpose |
|---|---|---|
| **Ecareafrica_backend** | `/var/www/ecare/backend` | REST API, auth, school data, WireGuard management |
| **Ecareafrica_frontend** | `/var/www/ecare/frontend` | React SPA served by nginx |
| **Tablet Setup/backend** | Windows tablet `C:\EcaAfrica\backend` | Bridge between FK623 device and cloud |
| **Tablet Setup/frontend** | Windows tablet `C:\EcaAfrica\frontend` | Tablet UI (Next.js) |
| **FKBridge.exe** | Windows tablet | Controls FK623 fingerprint device via SDK |
| **PostgreSQL** | localhost on server | All school data |
| **Redis** | localhost on server | Job queues (SMS, notifications) |
| **WireGuard wg0** | Server + tablets | Private VPN tunnel (10.0.0.0/16) |

---

## 2. GIT REPOSITORIES

| Repo | Branch | Purpose |
|---|---|---|
| `github.com/MbarushimanaFabrice/Ecareafrica_backend` | `New_Serverr` | Backend API |
| `github.com/MbarushimanaFabrice/Ecareafrica_frontend` | `New_Serverr` | Frontend SPA |
| `github.com/Byiringiro24/Tablet_Setup` | `Testing-Branch` | Tablet bridge + UI |

---

## 3. PORTS AND URLS

### Production (server)
| Service | Port | URL |
|---|---|---|
| Nginx (HTTPS) | 443 | https://ecareafrica.net |
| Backend API | 5500 | https://backend.ecareafrica.net/api/v1 |
| WireGuard VPN | 51820/UDP | 169.58.124.150:51820 |
| PostgreSQL | 5432 | localhost only |
| Redis | 6379 | localhost only |

### Local development
| Service | Port | URL |
|---|---|---|
| Backend | 5500 | http://localhost:5500/api/v1 |
| Frontend | 5173 | http://localhost:5173 |

### Tablet (Windows PC at school)
| Service | Port | URL |
|---|---|---|
| Tablet backend (server.js) | 5000 | http://localhost:5000 |
| Tablet frontend (Next.js) | 3000 | http://localhost:3000 |
| FK623 biometric device | 5005 | TCP (LAN IP of device) |

---

## 4. USER ROLES AND PORTALS

| Role | Login URL | Goes To | Key Responsibilities |
|---|---|---|---|
| **Platform Admin** | /login?mode=platform | /super-admin | All schools, tablets, VPN, billing |
| **School Admin** | /login | /dashboard | Full school — students, staff, fees, all modules |
| **Director of Discipline (DOD)** | /login | /dod/dashboard | Boarding — leave, dormitories, dining, attendance |
| **Director of Studies (DOS)** | /login | /dos/dashboard | Academic — timetable, exams, class attendance, staff |
| **Patron / Matron** | /login | /patron/dashboard | Assigned dormitories — attendance sessions, dining |
| **Gate Keeper** | /login | /gate-keeper/dashboard | Gate exits, visitor management, biometric attendance |
| **Teacher** | /login | /teacher/dashboard | Class attendance, exams, marks |
| **Finance Officer** | /login | /finance | Fees, expenses, payroll, invoices |
| **Staff** | /login | /staff/dashboard | Boarding overview, visitors, gate |

### User Creation Rules
- **School Admin** — can create ALL roles
- **DOD** — can create: patron, matron, gate_keeper, teacher, staff, director_of_studies, finance_officer
- **DOS** — can create: teacher, staff
- **Staff Management page** — `/staff/management` (accessible by school_admin, DOD, DOS)

---

## 5. LOCAL DEVELOPMENT SETUP

### Prerequisites
- Node.js 20+
- PostgreSQL 15+
- Redis (optional — jobs will fail silently without it)
- Git

### Step 1 — Clone repos

```bash
git clone https://github.com/MbarushimanaFabrice/Ecareafrica_backend.git
cd Ecareafrica_backend && git checkout New_Serverr

git clone https://github.com/MbarushimanaFabrice/Ecareafrica_frontend.git
cd Ecareafrica_frontend && git checkout New_Serverr
```

### Step 2 — Backend setup

```bash
cd Ecareafrica_backend
npm install

# Create local .env
cat > .env << 'EOF'
DATABASE_URL="postgresql://postgres:yourpassword@localhost:5432/ECAREAFRICA?schema=public"
JWT_SECRET=1b1a90a340949c666a212b212de76a9c7e14d24a5cd9c6b1de32d517668501b1
JWT_REFRESH_SECRET=hk3BkIhG-cEMddfdK3FIGsAgRL_16mQWxKDgnaRvdRwzbWC9ICwhQO0Kashg-DQEWjCnKz3tpxaG-K9Y2gyHrg
PLATFORM_JWT_SECRET=Gqwfm4cF1q3S2uX5nvdRkUZRQU40ZmcGRCBs4H666mgez6mNaU5iS7Mhjo3wSvKssqV2Sa0B7sFOk49181MEEw
PLATFORM_JWT_REFRESH_SECRET=CL3gr3UNYYqfdcs8zdzvbMWkLn3rFRQn_BbkxOfOgFy1
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d
PORT=5500
NODE_ENV=development
CORS_ORIGIN=http://localhost:5173,http://localhost:3000
RATE_LIMIT_ENABLED=false
APP_BASE_URL=http://localhost:5500
EOF

# Run migrations and seed
npm run prisma:migrate:deploy
npm run seed

# Start backend
npm run dev
# → API running at http://localhost:5500/api/v1
```

### Step 3 — Frontend setup

```bash
cd Ecareafrica_frontend
npm install

# Create local .env
echo "VITE_API_BASE_URL=http://localhost:5500/api/v1" > .env

# Start frontend
npm run dev
# → http://localhost:5173
```

### Step 4 — Verify local login

Open http://localhost:5173/login and use:

| Email | Password | Role |
|---|---|---|
| `admin@1.ecare.test` | `Password@123` | School Admin |
| `dod@1.ecare.test` | `Password@123` | DOD |
| `dos@1.ecare.test` | `Password@123` | DOS |
| `patron@1.ecare.test` | `Password@123` | Patron |
| `gatekeeper@1.ecare.test` | `Password@123` | Gate Keeper |
| `teacher1@1.ecare.test` | `Password@123` | Teacher |
| `finance@1.ecare.test` | `Password@123` | Finance |
| `platform.admin@ecareafrica.test` | `Admin@123` | Platform Admin |

---

## 6. PRODUCTION SERVER SETUP (FIRST TIME)

### Prerequisites on Ubuntu 24.04
```bash
# Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
apt-get install -y nodejs

# PostgreSQL
apt install -y postgresql postgresql-contrib
sudo -u postgres createdb ecareafrica
sudo -u postgres psql -c "CREATE USER ecare WITH PASSWORD 'yourpass';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ecareafrica TO ecare;"

# Redis
apt install -y redis-server
systemctl enable redis-server && systemctl start redis-server

# PM2
npm install -g pm2

# Nginx
apt install -y nginx

# WireGuard
apt install -y wireguard
```

### Deploy backend
```bash
mkdir -p /var/www/ecare
cd /var/www/ecare
git clone https://github.com/MbarushimanaFabrice/Ecareafrica_backend.git backend
cd backend
git checkout New_Serverr
npm install --production=false

# Create production .env (see section 8)
# Then:
npm run prisma:migrate:deploy
npm run build   # or: npx tsc -p tsconfig.json
pm2 start ecosystem.config.js --env production
pm2 save
pm2 startup
```

### Deploy frontend
```bash
cd /var/www/ecare
git clone https://github.com/MbarushimanaFabrice/Ecareafrica_frontend.git frontend
cd frontend
git checkout New_Serverr
echo "VITE_API_BASE_URL=https://backend.ecareafrica.net/api/v1" > .env
npm install
npm run build
# dist/ folder is now ready for nginx
```

### Nginx configuration
```nginx
# /etc/nginx/sites-available/ecareafrica
server {
    listen 80;
    server_name ecareafrica.net www.ecareafrica.net;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name ecareafrica.net www.ecareafrica.net;

    ssl_certificate     /etc/letsencrypt/live/ecareafrica.net/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ecareafrica.net/privkey.pem;

    root /var/www/ecare/frontend/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}

server {
    listen 443 ssl;
    server_name backend.ecareafrica.net;

    ssl_certificate     /etc/letsencrypt/live/backend.ecareafrica.net/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/backend.ecareafrica.net/privkey.pem;

    location / {
        proxy_pass http://localhost:5500;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;  # for SSE connections
    }
}
```

---

## 7. REGULAR DEPLOYMENT (UPDATES)

SSH into the server and run this block:

```bash
set -e

# Backend
cd /var/www/ecare/backend
git fetch origin && git reset --hard origin/New_Serverr
npm install --production=false
npm run prisma:migrate:deploy
npx tsc -p tsconfig.json
pm2 restart ecare-backend
echo "✓ Backend done"

# Frontend
cd /var/www/ecare/frontend
git fetch origin && git reset --hard origin/New_Serverr
echo "VITE_API_BASE_URL=https://backend.ecareafrica.net/api/v1" > .env
npm install
npm run build
echo "✓ Frontend built"

nginx -t && systemctl reload nginx
pm2 list
echo "=== DONE ==="
```

**Note:** `npm run build` calls `tsc` — if it fails with `tsc: not found`, use `npx tsc -p tsconfig.json` instead.

---

## 8. PRODUCTION `.env` FILE

Location: `/var/www/ecare/backend/.env`

```env
# Database
DATABASE_URL="postgresql://ecare:yourpass@localhost:5432/ecareafrica?schema=public"

# JWT
JWT_SECRET=1b1a90a340949c666a212b212de76a9c7e14d24a5cd9c6b1de32d517668501b1
JWT_REFRESH_SECRET=hk3BkIhG-cEMddfdK3FIGsAgRL_16mQWxKDgnaRvdRwzbWC9ICwhQO0Kashg-DQEWjCnKz3tpxaG-K9Y2gyHrg
PLATFORM_JWT_SECRET=Gqwfm4cF1q3S2uX5nvdRkUZRQU40ZmcGRCBs4H666mgez6mNaU5iS7Mhjo3wSvKssqV2Sa0B7sFOk49181MEEw
PLATFORM_JWT_REFRESH_SECRET=CL3gr3UNYYqfdcs8zdzvbMWkLn3rFRQn_BbkxOfOgFy1
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d

# Server
PORT=5500
NODE_ENV=production
TZ=Africa/Kigali
TRUST_PROXY=true

# CORS
CORS_ORIGIN=https://ecareafrica.net,https://www.ecareafrica.net,https://backend.ecareafrica.net

# App
APP_BASE_URL=https://ecareafrica.net

# Redis
REDIS_URL=redis://localhost:6379

# WireGuard VPN
WG_CONF_PATH=/etc/wireguard/wg0.conf
WG_PUBKEY_PATH=/etc/wireguard/server_public.key
WG_PRIVKEY_PATH=/etc/wireguard/server_private.key
WG_INTERFACE=wg0
VPN_SUBNET=10.0
VPN_CIDR=16
SERVER_VPN_IP=10.0.0.1
SERVER_PUBLIC_IP=169.58.124.150
WG_PORT=51820
```

---

## 9. WIREGUARD VPN SETUP

WireGuard creates a private tunnel between the school server and Windows tablets.
- Server VPN IP: `10.0.0.1`
- Tablets: `10.0.0.2`, `10.0.0.3`, … up to `10.0.255.254` (65534 tablets)
- Port: `51820/UDP`

### Server setup (one-time or after key regeneration)

```bash
# Install
apt install -y wireguard

# Generate server keys
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
chmod 600 /etc/wireguard/server_private.key

# Create wg0.conf
PRIVKEY=$(cat /etc/wireguard/server_private.key)
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $PRIVKEY
Address = 10.0.0.1/16
ListenPort = 51820

EOF
chmod 600 /etc/wireguard/wg0.conf

# Start and enable
wg-quick up wg0
systemctl enable wg-quick@wg0

# Open firewall
ufw allow 51820/udp

# Verify
wg show
cat /etc/wireguard/server_public.key
```

### Add a tablet as a peer (via Super Admin UI — no SSH needed)

1. Open https://ecareafrica.net/super-admin/hardware → **VPN Setup** tab
2. Click **Refresh** — shows server public key and next available IP
3. On the tablet, open http://localhost:3000 → **Settings → WireGuard wizard**
4. Generate keys on tablet → copy the tablet public key
5. Back in super admin → paste tablet public key → click **Add Peer to VPN**
6. Copy server public key + assigned VPN IP → paste into tablet wizard
7. Tablet activates tunnel → ping `10.0.0.1` → should succeed

### Add a peer manually (via SSH)

```bash
# Replace KEY and IP with actual values
wg set wg0 peer "TABLET_PUBLIC_KEY=" allowed-ips 10.0.0.2/32
wg-quick save wg0
wg show
```

### Remove a peer

**Via Super Admin UI:**
Click the trash icon next to the peer in VPN Setup tab — removes from live interface and wg0.conf instantly.

**Via SSH:**
```bash
wg set wg0 peer "TABLET_PUBLIC_KEY=" remove
wg-quick save wg0
grep -c "PEER_KEY" /etc/wireguard/wg0.conf || echo "Removed from conf"
```

### Regenerate server keys (fresh start)

```bash
wg-quick down wg0
rm -f /etc/wireguard/server_private.key /etc/wireguard/server_public.key /etc/wireguard/wg0.conf

wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
chmod 600 /etc/wireguard/server_private.key

PRIVKEY=$(cat /etc/wireguard/server_private.key)
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $PRIVKEY
Address = 10.0.0.1/16
ListenPort = 51820

EOF
chmod 600 /etc/wireguard/wg0.conf

wg-quick up wg0
wg show
cat /etc/wireguard/server_public.key
```
**Note:** This does NOT affect the main website or school system. All tablets will need to re-register their keys after this.

---

## 10. TABLET SETUP (WINDOWS PC AT SCHOOL)

### Prerequisites
- Windows 10/11 (any edition)
- Node.js 20+ installed
- WireGuard for Windows installed from https://www.wireguard.com/install/
- FK623 biometric device connected to the same LAN
- FKBridge.exe compiled from source (or provided binary in `Tablet Setup/FKBridge/`)

### Clone and setup

```bash
git clone https://github.com/Byiringiro24/Tablet_Setup.git
cd "Tablet Setup"
git checkout Testing-Branch
```

### Configure environment

Create `backend/.env`:
```env
# Tablet bridge port
PORT=5000

# School server API
SERVER_API_URL=https://backend.ecareafrica.net/api/v1

# WireGuard VPN config
VPN_ALLOWED_IPS=10.0.0.0/16
WG_SERVER_ENDPOINT=169.58.124.150:51820
WG_DNS=1.1.1.1

# Assigned after registering in super admin
TABLET_UUID=
```

Create `frontend/.env.local`:
```env
NEXT_PUBLIC_API_URL=http://localhost:5000
```

### Start the tablet

Open two terminals (both as Administrator):

**Terminal 1 — Backend:**
```bash
cd "Tablet Setup/backend"
npm install
node server.js
# → FK Attendance Backend running on http://localhost:5000
```

**Terminal 2 — Frontend:**
```bash
cd "Tablet Setup/frontend"
npm install
npm run dev   # development
# OR for production:
npm run build && npm run start
# → http://localhost:3000
```

Open Chrome/Edge → http://localhost:3000

### Install as Windows services (auto-start on boot)

Run in an **Administrator** terminal:
```bash
cd "Tablet Setup"
powershell -ExecutionPolicy Bypass -File install-services.ps1
```
After this, the bridge and frontend start automatically when Windows boots — no manual intervention needed.

### Device configuration

In the tablet UI → **Settings (gear icon)** → enter:
- **IP Address:** LAN IP of the FK623 device (e.g. `192.168.1.118`)
- **Port:** `5005` (default FK623 port)
- **License:** license number from device label
- **Device ID:** unique ID (e.g. `DV-KGL-01`)
- **Location:** descriptive name (e.g. `Main Gate`)
- Click **Save & Reconnect**

### WireGuard VPN on tablet

In the tablet UI → sidebar → **WireGuard VPN** button:
1. **Step 1:** Install WireGuard if not installed
2. **Step 2:** Generate key pair (copies public key)
3. **Paste public key in super admin** → super admin assigns VPN IP
4. **Step 3:** Paste server public key + VPN IP from super admin
5. **Step 4:** Activate tunnel
6. **Step 5:** Ping `10.0.0.1` — green = connected

---

## 11. TABLET UI — PANELS AND FEATURES

| Panel | Access | Features |
|---|---|---|
| **Dashboard** | All | Live attendance feed, stats, device status, pull logs, push students |
| **Students** | All | Register students, assign to device, list enrolled |
| **Gate Keeper** | No password | Approved exit list with photos, CONFIRM GATE EXIT, CONFIRM RETURN |
| **Attendance** | School login required | Manual attendance by class or dormitory, photo display, auto-save |
| **Users** | School login required | Create/edit/delete school users (respects role permissions) |
| **WireGuard VPN** | Developer password | Full VPN setup wizard |
| **Developer Settings** | Password: `admin1234` | Device IP, port, license, location |

---

## 12. DATABASE MIGRATIONS

Prisma is used for database migrations. Schema is at `src/models/schema.prisma`.

```bash
# Apply pending migrations (production — no downtime)
npm run prisma:migrate:deploy

# Create a new migration (development only)
npm run prisma:migrate -- --name my_migration_name

# Regenerate Prisma client after schema change
npm run prisma:generate

# Check migration status
npx prisma migrate status --schema src/models/schema.prisma
```

---

## 13. BOARDING MANAGEMENT FLOW

```
Super Admin
  → Registers tablet to school (Hardware tab)
  → Adds tablet as WireGuard peer (VPN Setup tab)

School Admin / DOD
  → Creates dormitories (DOD → Dormitories)
  → Creates patrons/matrons (DOD → Staff Management)
  → Assigns patrons to dormitories (DOD → Dormitories → Assign)
  → Assigns devices to locations (DOD → Device Locations)
    → students auto-pushed to tablet on assignment

DOD
  → Approves/rejects leave requests (DOD → Leave Management)
  → Views boarding attendance windows (DOD → Boarding Attendance)
  → Monitors gate exits (DOD → Gate Exits)

Patron/Matron
  → Opens attendance session (Patron → Attendance → New Session)
  → Students tick present/absent (auto-saves, 800ms debounce)
  → Exports session to Excel

Gate Keeper
  → Views approved exits with student photo
  → Confirms physical exit (CONFIRM GATE EXIT button)
  → Confirms student return

Tablet (biometric)
  → FK623 scans fingerprint/face/card
  → SSE pushes live attendance to screen instantly
  → Shows student photo + name + class on live screen
  → School server records attendance via auto-pull job
```

---

## 14. ACADEMIC MANAGEMENT FLOW (DOS)

```
DOS → Dashboard      → Stats, attendance alert, quick actions
DOS → Timetable      → Manage Periods tab (create periods)
                     → Timetable Grid tab (add/delete slots)
DOS → Classes        → Create classes and subjects
DOS → Subject Assignments → Assign teachers to sections+subjects
DOS → Teaching Staff → View and create teachers/staff
DOS → Exam Overview  → Quick links to schedule/review/report cards
DOS → Exam Schedule  → Create and manage exam sessions
DOS → Review Results → Approve/reject teacher-submitted results
DOS → Report Cards   → Generate and publish student report cards
DOS → Grade Requests → Handle grade change requests
DOS → Reports        → Attendance charts, exam stats, structure
```

---

## 15. EXPORT — ALL PORTALS

Every major data page has an **Export** button that downloads an `.xlsx` file:

| Portal | Page | Export Contains |
|---|---|---|
| School Admin | Students | Filtered student list |
| School Admin | Attendance/Manual | Session attendance |
| School Admin | Device Attendance | Gate log |
| DOD | Reports | Daily attendance, leave, students outside |
| DOD | Dormitories | Dormitory list |
| DOD | Leaves | Leave records per tab |
| Patron | Attendance | Session attendance records |
| Patron | Dormitories | Student list per dorm |
| Gate Keeper | Attendance | In/out gate log |
| Gate Keeper | Boarding Leave | Approved exits list |
| DOS | Reports | Attendance chart, exam summary, structure |
| Teacher | Attendance | Class attendance history |

---

## 16. TROUBLESHOOTING

### Backend won't start
```bash
pm2 logs ecare-backend --lines 50
# Common causes:
# - Database not running: systemctl start postgresql
# - Port conflict: lsof -i :5500
# - Schema BOM: sed -i '1s/^\xEF\xBB\xBF//' src/models/schema.prisma
```

### Frontend shows blank page
```bash
# Check nginx is serving the dist folder
ls /var/www/ecare/frontend/dist/
nginx -t && systemctl reload nginx
```

### Login fails with "Failed to fetch"
```bash
# Check backend is running
curl http://localhost:5500/api/v1/app/health
# Check CORS — must include frontend domain
grep CORS_ORIGIN /var/www/ecare/backend/.env
# Check API base URL in frontend .env
cat /var/www/ecare/frontend/.env
```

### WireGuard tunnel not connecting
```bash
wg show             # check interface is up
ufw status          # check port 51820/udp is open
cat /etc/wireguard/server_public.key   # verify key matches VPN Setup tab
# Tablet side: check AllowedIPs = 10.0.0.0/16 (not /24)
# Tablet side: check server public key matches exactly
```

### Peer still in wg0.conf after delete
```bash
# Manual removal
wg set wg0 peer "PUBLIC_KEY=" remove
CONF=$(cat /etc/wireguard/wg0.conf)
# The API automatically rewrites the file — check backend logs
pm2 logs ecare-backend --lines 20 | grep wireguard
```

### Tablet device not connecting
```bash
# On tablet, check FK623 is reachable
ping 192.168.1.118   # FK623 LAN IP
# Check FKBridge is running
curl http://localhost:5000/api/health
# Check bridge logs in terminal window
```

### tsc: not found on server
```bash
# Use npx instead
npx tsc -p tsconfig.json
# Or install globally
npm install -g typescript
```

---

## 17. SECURITY NOTES

- All JWT secrets must be kept private — never commit to git
- WireGuard private keys are in `/etc/wireguard/` — chmod 600, root only
- The FK device password (Developer modal) is `admin1234` — change in production
- Platform admin credentials should use strong unique passwords
- CORS is restricted to `ecareafrica.net` domains in production
- Rate limiting is enabled in production (`RATE_LIMIT_ENABLED=true`)
- Trust proxy is set (`TRUST_PROXY=true`) — nginx handles SSL termination

---

## 18. QUICK REFERENCE

### Start everything locally
```bash
# Terminal 1 — Backend
cd Ecareafrica_backend && npm run dev

# Terminal 2 — Frontend
cd Ecareafrica_frontend && npm run dev

# Terminal 3 — Tablet backend (on Windows tablet)
cd "Tablet Setup/backend" && node server.js

# Terminal 4 — Tablet frontend (on Windows tablet)
cd "Tablet Setup/frontend" && npm run dev
```

### Check production status
```bash
ssh root@169.58.124.150
pm2 list
pm2 logs ecare-backend --lines 20
wg show
curl -s http://localhost:5500/api/v1/app/health
```

### Full redeploy to production
```bash
ssh root@169.58.124.150
cd /var/www/ecare/backend && git fetch origin && git reset --hard origin/New_Serverr
npm install --production=false && npx tsc -p tsconfig.json && pm2 restart ecare-backend
cd /var/www/ecare/frontend && git fetch origin && git reset --hard origin/New_Serverr
echo "VITE_API_BASE_URL=https://backend.ecareafrica.net/api/v1" > .env
npm install && npm run build
nginx -t && systemctl reload nginx
echo "Deploy complete"
```

---

*EcaAfrica System Guide — September 2026*  
*Repos: Ecareafrica_backend · Ecareafrica_frontend · Tablet_Setup*
