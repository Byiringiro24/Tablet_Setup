# EcaAfrica — Full System Test Checklist

**Backend:** http://localhost:5000/api/v1  
**Frontend:** http://localhost:5173  
**Tablet:** http://localhost:3000  

---

## 1. BACKEND HEALTH

```bash
# Is backend running?
curl http://localhost:5000/api/v1/app/health

# Check PM2 process on server
pm2 list
pm2 logs ecare-backend --lines 30

# Check database connection (run from backend directory)
npx prisma db pull --schema src/models/schema.prisma
```

---

## 2. LOGIN — ALL ROLES

```bash
BASE=http://localhost:5000/api/v1

# School Admin
curl -s -X POST $BASE/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@1.ecare.test","password":"Password@123"}' | jq '.data.user.role'

# DOD
curl -s -X POST $BASE/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"dod@1.ecare.test","password":"Password@123"}' | jq '.data.user.role'

# DOS
curl -s -X POST $BASE/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"dos@1.ecare.test","password":"Password@123"}' | jq '.data.user.role'

# Patron
curl -s -X POST $BASE/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"patron@1.ecare.test","password":"Password@123"}' | jq '.data.user.role'

# Matron
curl -s -X POST $BASE/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"matron@1.ecare.test","password":"Password@123"}' | jq '.data.user.role'

# Gate Keeper
curl -s -X POST $BASE/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"gatekeeper@1.ecare.test","password":"Password@123"}' | jq '.data.user.role'

# Teacher
curl -s -X POST $BASE/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"teacher1@1.ecare.test","password":"Password@123"}' | jq '.data.user.role'

# Finance Officer
curl -s -X POST $BASE/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"finance@1.ecare.test","password":"Password@123"}' | jq '.data.user.role'

# Staff
curl -s -X POST $BASE/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"staff1@1.ecare.test","password":"Password@123"}' | jq '.data.user.role'
```

**Expected:** Each returns `200` with the correct role string.  
**Login URL (frontend):** http://localhost:5173/login

---

## 3. USER CREATION PERMISSIONS

```bash
# Get tokens first
ADMIN_TOKEN=$(curl -s -X POST $BASE/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@1.ecare.test","password":"Password@123"}' | jq -r '.data.access_token')

DOD_TOKEN=$(curl -s -X POST $BASE/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"dod@1.ecare.test","password":"Password@123"}' | jq -r '.data.access_token')

DOS_TOKEN=$(curl -s -X POST $BASE/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"dos@1.ecare.test","password":"Password@123"}' | jq -r '.data.access_token')

# School Admin creates DOD (expect 201)
curl -s -X POST $BASE/users \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"New DOD","email":"newdod@test.com","role":"director_of_discipline","password":"Test@12345"}' | jq '.data.role'

# School Admin creates Patron (expect 201)
curl -s -X POST $BASE/users \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"New Patron","email":"newpatron@test.com","role":"patron","password":"Test@12345"}' | jq '.data.role'

# DOD creates Patron (expect 201)
curl -s -X POST $BASE/users \
  -H "Authorization: Bearer $DOD_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"DOD Patron","email":"dodpatron@test.com","role":"patron","password":"Test@12345"}' | jq '.data.role'

# DOD tries school_admin (expect 403)
curl -s -X POST $BASE/users \
  -H "Authorization: Bearer $DOD_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Bad","email":"bad@test.com","role":"school_admin","password":"Test@12345"}' | jq '.error'

# DOS creates Teacher (expect 201)
curl -s -X POST $BASE/users \
  -H "Authorization: Bearer $DOS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"DOS Teacher","email":"dosteacher@test.com","role":"teacher","password":"Test@12345"}' | jq '.data.role'

# DOS tries Patron (expect 403)
curl -s -X POST $BASE/users \
  -H "Authorization: Bearer $DOS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Bad","email":"bad2@test.com","role":"patron","password":"Test@12345"}' | jq '.error'

# All created users visible to all roles (same school)
curl -s "$BASE/users?limit=20" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '[.data[].role]'
```

---

## 4. SCHOOL ADMIN PORTAL — http://localhost:5173/dashboard

### Pages to check
```
http://localhost:5173/dashboard            → Main dashboard (stats cards, charts)
http://localhost:5173/students             → Student list + Register + Export
http://localhost:5173/classes              → Classes list + create class
http://localhost:5173/timetable            → Full timetable grid
http://localhost:5173/subject-assignments  → Teacher → section → subject assignment
http://localhost:5173/attendance           → Attendance tabs
http://localhost:5173/attendance/manual    → Manual attendance + Export Excel
http://localhost:5173/attendance/device-attendance → Device logs + Export
http://localhost:5173/staff                → Staff HR list
http://localhost:5173/staff/management     → Create/edit all users (school admin)
http://localhost:5173/boarding/devices     → Device management
http://localhost:5173/boarding/device-sessions → Attendance sessions
http://localhost:5173/boarding/device-students → Push students to devices
http://localhost:5173/exams                → Exam list
http://localhost:5173/exams/schedule       → Schedule exams
http://localhost:5173/exams/review         → Review results
http://localhost:5173/exams/report-cards   → Generate report cards
http://localhost:5173/exams/terms          → Term management
http://localhost:5173/fees                 → Fee management
http://localhost:5173/finance              → Finance dashboard
http://localhost:5173/finance/invoices     → Invoices
http://localhost:5173/finance/payments     → Payments
http://localhost:5173/finance/expenses     → Expenses
http://localhost:5173/finance/payroll      → Payroll
http://localhost:5173/finance/reports      → Finance reports
http://localhost:5173/parents              → Parents list
http://localhost:5173/visitors             → Visitor management
http://localhost:5173/leaves               → Leave requests
http://localhost:5173/notifications        → Notifications
http://localhost:5173/settings             → School settings
http://localhost:5173/reports              → Reports
http://localhost:5173/devices              → Device list
http://localhost:5173/tablets              → Tablet list
```

### Key API calls to verify
```bash
# Students
curl -s "$BASE/students?limit=10" -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.data | length'

# Classes
curl -s "$BASE/classes?limit=10" -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.data | length'

# Sections
curl -s "$BASE/sections?limit=10" -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.data | length'

# Subjects
curl -s "$BASE/subjects?limit=10" -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.data | length'

# Timetable periods
curl -s "$BASE/timetable-periods?limit=20" -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.'

# Timetable slots
curl -s "$BASE/timetable-slots?limit=20" -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.'

# Exams
curl -s "$BASE/exams?limit=10" -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.data | length'

# Report cards
curl -s "$BASE/report-cards?limit=5" -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.'

# Terms
curl -s "$BASE/terms?limit=10" -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.'

# Devices
curl -s "$BASE/devices?limit=10" -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.'

# Tablets
curl -s "$BASE/tablets?limit=10" -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.'
```

### Buttons/features to manually click
- [ ] Register New Student → fill form → submit → student appears in list
- [ ] Export Students (Excel) → file downloads
- [ ] Register Staff → all roles visible in dropdown (Teacher, Staff, Gate Keeper, DOD, DOS, Patron, Matron, Finance Officer, School Admin)
- [ ] User Management sidebar → create user as admin → appears in list
- [ ] Attendance Manual → select date/section → tick students → Export Excel
- [ ] Device Attendance → filter by date → Export

---

## 5. DOD PORTAL — http://localhost:5173/dod/dashboard

### Pages to check
```
http://localhost:5173/dod/dashboard         → Stats: total boarders, on leave, late returns
http://localhost:5173/dod/leaves            → Leave requests: Pending/Outside/All tabs + Export
http://localhost:5173/dod/gate-exits        → Students outside school
http://localhost:5173/dod/attendance        → Boarding attendance windows + config
http://localhost:5173/dod/dormitories       → Dormitory list + rooms + assign patron
http://localhost:5173/dod/patrons           → Patrons & matrons + dorm assignments
http://localhost:5173/dod/devices           → Device location assignment
http://localhost:5173/dod/dining            → Dining management
http://localhost:5173/dod/alerts            → Boarding alerts
http://localhost:5173/dod/reports           → Boarding reports (daily/leave/outside) + Export
http://localhost:5173/staff/management      → Staff management (DOD subset)
```

### Key API calls
```bash
DOD_TOKEN=<from login step>

# Boarding students
curl -s "$BASE/students?student_type=boarding&limit=10" \
  -H "Authorization: Bearer $DOD_TOKEN" | jq '.data | length'

# Dormitories
curl -s "$BASE/boarding/dormitories?limit=10" \
  -H "Authorization: Bearer $DOD_TOKEN" | jq '.'

# Leave requests
curl -s "$BASE/boarding/student-leaves?limit=10" \
  -H "Authorization: Bearer $DOD_TOKEN" | jq '.data | length'

# Boarding attendance sessions
curl -s "$BASE/boarding/attendance/sessions?limit=5" \
  -H "Authorization: Bearer $DOD_TOKEN" | jq '.'

# Assign patron to dormitory
DOD_PATRON_ID=<patron_user_id>
DOD_DORM_ID=<dormitory_id>
curl -s -X POST "$BASE/boarding/patrons/assign" \
  -H "Authorization: Bearer $DOD_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"user_id\":\"$DOD_PATRON_ID\",\"dormitory_ids\":[\"$DOD_DORM_ID\"]}" | jq '.'
```

### Buttons/features
- [ ] Leave Management → Approve a pending leave → status changes to approved
- [ ] Leave Management → Export current tab (Excel)
- [ ] Dormitories → Add Dormitory → fills in list → Export
- [ ] Dormitories → Assign Patron → patron appears in dorm
- [ ] Device Locations → assign device to dormitory → students auto-pushed
- [ ] DOD creates Patron via Staff Management → patron visible to all

---

## 6. DOS PORTAL — http://localhost:5173/dos/dashboard

### Pages to check
```
http://localhost:5173/dos/dashboard           → Stats + quick actions + attendance alert
http://localhost:5173/dos/attendance          → Class attendance sessions by date + Export
http://localhost:5173/dos/timetable           → Timetable grid (Mon-Fri × Periods) + Manage Periods tab
http://localhost:5173/dos/classes             → Classes & Subjects tabs + Create Class/Subject
http://localhost:5173/subject-assignments     → Teacher → Section → Subject assignment
http://localhost:5173/dos/staff               → Teaching staff list + Create Staff
http://localhost:5173/dos/exams               → Exam overview + quick links
http://localhost:5173/exams/schedule          → Full exam schedule
http://localhost:5173/exams/review            → Review pending results
http://localhost:5173/exams/report-cards      → Report card generation
http://localhost:5173/exams/grade-update-requests → Grade change requests
http://localhost:5173/dos/reports             → Academic reports (Attendance/Exams/Structure tabs)
```

### Key API calls
```bash
DOS_TOKEN=<from login step>

# Classes
curl -s "$BASE/classes?limit=20" -H "Authorization: Bearer $DOS_TOKEN" | jq '.'

# Sections
curl -s "$BASE/sections?limit=20" -H "Authorization: Bearer $DOS_TOKEN" | jq '.'

# Timetable periods (CORRECT URL)
curl -s "$BASE/timetable-periods?limit=20" -H "Authorization: Bearer $DOS_TOKEN" | jq '.'

# Timetable slots for a section
SECTION_ID=<section_id>
curl -s "$BASE/timetable-slots?section_id=$SECTION_ID&limit=50" \
  -H "Authorization: Bearer $DOS_TOKEN" | jq '.'

# Create a timetable period
curl -s -X POST "$BASE/timetable-periods" \
  -H "Authorization: Bearer $DOS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Period 1","start_time":"07:00","end_time":"07:45","is_break":false,"sort_order":1}' | jq '.'

# Create a timetable slot
curl -s -X POST "$BASE/timetable-slots" \
  -H "Authorization: Bearer $DOS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"section_id\":\"$SECTION_ID\",\"period_id\":\"<period_id>\",\"subject_id\":\"<subject_id>\",\"teacher_id\":\"<teacher_id>\",\"day_of_week\":1}" | jq '.'

# Subject assignments
curl -s "$BASE/teacher-section-subjects?limit=20" \
  -H "Authorization: Bearer $DOS_TOKEN" | jq '.'

# Attendance sessions (DOS)
curl -s "$BASE/attendance/sessions?date=$(date +%Y-%m-%d)&limit=50" \
  -H "Authorization: Bearer $DOS_TOKEN" | jq '.data | length'
```

### Buttons/features
- [ ] Timetable → select section → grid shows Mon–Fri × periods
- [ ] Timetable → click "+" cell → Add Slot modal → fills subject, teacher, room → slot appears in grid
- [ ] Timetable → hover slot → X button → slot removed
- [ ] Timetable → "Manage Periods" tab → Add Period → appears in list
- [ ] Classes & Subjects → Add Class → appears in Classes tab
- [ ] Classes & Subjects → Add Subject → appears in Subjects tab
- [ ] Subject Assignments → select teacher → assign section+subject → save
- [ ] Teaching Staff → Create Staff (teacher/staff) → appears in list + visible to school admin
- [ ] Academic Reports → Attendance tab → bar chart renders
- [ ] Academic Reports → Export button → Excel downloads
- [ ] All sidebar links navigate to correct pages (no stuck-on-dashboard behaviour)

---

## 7. PATRON / MATRON PORTAL — http://localhost:5173/patron/dashboard

### Pages to check
```
http://localhost:5173/patron/dashboard     → Assigned dorms summary
http://localhost:5173/patron/attendance    → Sessions list + manual tick + Export
http://localhost:5173/patron/dormitories   → Students in assigned dorms + Export
http://localhost:5173/patron/dining        → Dining session management
http://localhost:5173/patron/leaves        → View leave requests for assigned dorms
```

### Key API calls
```bash
PATRON_TOKEN=<from login step>
PATRON_ID=<patron_user_id>

# Patron's dorm assignments
curl -s "$BASE/boarding/patrons/$PATRON_ID/assignments" \
  -H "Authorization: Bearer $PATRON_TOKEN" | jq '.'

# Boarding attendance sessions for a dorm
DORM_ID=<dormitory_id>
curl -s "$BASE/boarding/attendance/sessions?dormitory_id=$DORM_ID&limit=10" \
  -H "Authorization: Bearer $PATRON_TOKEN" | jq '.'

# Open a new attendance session
curl -s -X POST "$BASE/boarding/attendance/sessions" \
  -H "Authorization: Bearer $PATRON_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"dormitory_id\":\"$DORM_ID\",\"session_date\":\"$(date +%Y-%m-%d)\",\"session_name\":\"Evening Roll Call\",\"location_type\":\"dormitory\"}" | jq '.'
```

### Buttons/features
- [ ] Select dormitory → sessions load
- [ ] New Session → name + type → opens session
- [ ] Click student row → toggle present/absent → auto-saves (debounced)
- [ ] Export → attendance Excel downloads
- [ ] Dormitories → select dorm → student list → Export
- [ ] Dining → open session → mark students

---

## 8. GATE KEEPER PORTAL — http://localhost:5173/gate-keeper/dashboard

### Pages to check
```
http://localhost:5173/gate-keeper/dashboard                      → Stats cards
http://localhost:5173/gate-keeper/attendance/device-attendance   → Gate log + Export
http://localhost:5173/gate-keeper/boarding-leave                 → Approved exits + Export + Confirm Exit
http://localhost:5173/gate-keeper/visitors                       → Visitor management
http://localhost:5173/gate-keeper/device-status                  → Device connectivity
http://localhost:5173/gate-keeper/support                        → Support tickets
```

### Key API calls
```bash
GATE_TOKEN=<from login step>

# Gate logs (today)
curl -s "$BASE/gate/logs?limit=50&sort=scanned_at&order=desc" \
  -H "Authorization: Bearer $GATE_TOKEN" | jq '.data | length'

# Approved exits (boarding leave)
curl -s "$BASE/boarding/student-leaves?status=approved&limit=20" \
  -H "Authorization: Bearer $GATE_TOKEN" | jq '.'

# Visitors on campus
curl -s "$BASE/visitor-visits?limit=20" \
  -H "Authorization: Bearer $GATE_TOKEN" | jq '.'

# Confirm a gate exit
LEAVE_ID=<leave_id>
curl -s -X POST "$BASE/boarding/student-leaves/$LEAVE_ID/confirm-exit" \
  -H "Authorization: Bearer $GATE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}' | jq '.'
```

### Buttons/features
- [ ] Gate attendance → filter by date → table shows entries/exits → Export
- [ ] Boarding Leave → "Awaiting Exit" tab → student card shows photo
- [ ] Boarding Leave → CONFIRM GATE EXIT → status updates
- [ ] Boarding Leave → Export → Excel downloads
- [ ] Visitor check-in/check-out

---

## 9. TEACHER PORTAL — http://localhost:5173/teacher/dashboard

### Pages to check
```
http://localhost:5173/teacher/dashboard     → Schedule + upcoming exams
http://localhost:5173/teacher/attendance    → Mark attendance per section + Export Excel
http://localhost:5173/teacher/classes       → Assigned classes
http://localhost:5173/teacher/exams         → Manage exams + enter results
http://localhost:5173/teacher/schedule      → Timetable view
http://localhost:5173/teacher/profile       → Profile update
```

### Key API calls
```bash
TEACHER_TOKEN=<from login step>

# Teacher's sections
curl -s "$BASE/sections?teacher=true&limit=50" \
  -H "Authorization: Bearer $TEACHER_TOKEN" | jq '.'

# Teacher's exams
curl -s "$BASE/exams/teacher/exams?limit=20" \
  -H "Authorization: Bearer $TEACHER_TOKEN" | jq '.'

# Mark attendance
SESSION_ID=<session_id>
STUDENT_ID=<student_id>
curl -s -X POST "$BASE/attendance/records" \
  -H "Authorization: Bearer $TEACHER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"session_id\":\"$SESSION_ID\",\"student_id\":\"$STUDENT_ID\",\"status\":\"present\"}" | jq '.'
```

---

## 10. FINANCE PORTAL — http://localhost:5173/finance

### Pages to check
```
http://localhost:5173/finance              → Finance dashboard
http://localhost:5173/finance/invoices     → Student invoices
http://localhost:5173/finance/payments     → Payment records
http://localhost:5173/finance/expenses     → Expense tracking + Export CSV
http://localhost:5173/finance/payroll      → Staff payroll
http://localhost:5173/finance/salary-management → Salary management
http://localhost:5173/finance/fee-structure     → Fee configuration
http://localhost:5173/finance/reports      → Financial reports + Export CSV
http://localhost:5173/finance/audit        → Audit log
http://localhost:5173/finance/inventory    → Inventory
```

---

## 11. STAFF PORTAL — http://localhost:5173/staff/dashboard

### Pages to check
```
http://localhost:5173/staff/dashboard      → Overview
http://localhost:5173/staff/boarding       → Boarding overview
http://localhost:5173/staff/alerts         → Absence alerts + Export CSV
http://localhost:5173/staff/gate           → Gate management
http://localhost:5173/staff/leaves         → Leave management
http://localhost:5173/staff/visitors       → Visitor log
http://localhost:5173/staff/my-attendance  → Own attendance + Export CSV
http://localhost:5173/staff/students       → Student records
http://localhost:5173/staff/profile        → Profile
```

---

## 12. SUPER ADMIN PORTAL — http://localhost:5173/super-admin

**Login at:** http://localhost:5173/login?mode=platform

```bash
# Platform login
PLATFORM_TOKEN=$(curl -s -X POST $BASE/auth/platform/login \
  -H "Content-Type: application/json" \
  -d '{"email":"platform.admin@ecareafrica.test","password":"Admin@123"}' | jq -r '.data.access_token')

# List schools
curl -s "$BASE/platform/schools?limit=10" \
  -H "Authorization: Bearer $PLATFORM_TOKEN" | jq '.[].name'

# List tablets (global)
curl -s "$BASE/tablets?limit=10" \
  -H "Authorization: Bearer $PLATFORM_TOKEN" | jq '.'
```

### Pages to check
```
http://localhost:5173/super-admin                    → Overview
http://localhost:5173/super-admin/schools            → All schools
http://localhost:5173/super-admin/subscriptions      → Subscriptions
http://localhost:5173/super-admin/billing            → Billing
http://localhost:5173/super-admin/hardware           → Hardware/tablet registration
http://localhost:5173/super-admin/analytics          → Analytics
http://localhost:5173/super-admin/audit              → Audit log
http://localhost:5173/super-admin/sms-usage          → SMS usage
http://localhost:5173/super-admin/manage-sms         → SMS templates
http://localhost:5173/super-admin/plans              → Subscription plans
http://localhost:5173/super-admin/support            → Support tickets
http://localhost:5173/super-admin/system             → System settings
http://localhost:5173/super-admin/announcements      → Announcements
http://localhost:5173/super-admin/demo-requests      → Demo requests
```

---

## 13. BOARDING API — COMPLETE ENDPOINT TEST

```bash
ADMIN_TOKEN=<school admin token>

# Dormitories CRUD
curl -s "$BASE/boarding/dormitories?limit=10" -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.'
curl -s -X POST "$BASE/boarding/dormitories" \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"Block A","gender":"male","capacity":60}' | jq '.data.id'

# Rooms
curl -s "$BASE/boarding/rooms?limit=10" -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.'

# Student dorm assignments
curl -s "$BASE/boarding/assignments?is_active=true&limit=20" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.data | length'

# Attendance windows
curl -s "$BASE/boarding/attendance/windows" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.'

# Patron assignments
curl -s "$BASE/boarding/patrons/assignments?limit=10" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.'

# Dining menus
curl -s "$BASE/boarding/dining/menus?limit=10" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.'

# Leave requests
curl -s "$BASE/boarding/student-leaves?limit=10" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.data | length'

# Device assignments (DOD assigns device to location)
DEVICE_ID=<device_id>
curl -s "$BASE/devices/$DEVICE_ID/assigned-students" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq '.'
```

---

## 14. TABLET APP — http://localhost:3000

### Prerequisites
```bash
# Start tablet backend (from Tablet Setup/backend)
node server.js

# Start tablet frontend (from Tablet Setup/frontend)
npm run dev   # or: npm run start
```

### Pages / panels
```
http://localhost:3000             → Live Attendance Screen (fingerprint scan view)
Sidebar: Gate Keeper              → Gate Keeper portal (NO password required)
Sidebar: Manual Attendance        → Manual tick list (students from pushed group)
Sidebar: Users                    → Manage tablet users
Sidebar: Diagnostics              → WireGuard status, ping, register key
Settings (gear icon)              → Device config: IP, Port, License, Device ID, Location
```

### Tablet API calls to verify
```bash
TABLET_BASE=http://localhost:5005

# Health
curl -s $TABLET_BASE/health | jq '.'

# Students on tablet
curl -s $TABLET_BASE/api/students | jq '. | length'

# Attendance logs
curl -s $TABLET_BASE/api/attendance | jq '. | length'

# Device config
curl -s $TABLET_BASE/api/config | jq '.'

# Photo proxy (check student photo loads)
curl -s "$TABLET_BASE/api/school/photo?url=https://backend.ecareafrica.net/uploads/photo.jpg" -o /tmp/photo_test.jpg
echo "Photo status: $?"

# WireGuard status
curl -s $TABLET_BASE/api/wireguard/status | jq '.'
```

### Tablet features to check
- [ ] Open http://localhost:3000 → live scan screen appears
- [ ] Sidebar → Gate Keeper → opens without password
- [ ] Sidebar → Manual Attendance → shows students from pushed groups
- [ ] Settings → fill IP/Port/License/Device ID → Save → toast immediately (non-blocking)
- [ ] Diagnostics → WireGuard → shows status (up/down) + last handshake
- [ ] Diagnostics → Ping 10.0.0.1 → returns result
- [ ] Student scan → shows photo + name + class + dormitory

---

## 15. WIREGUARD TUNNEL (SERVER)

```bash
# On server: check tunnel is up
wg show

# Verify each tablet's public key + allowed-ips
wg show wg0

# Ping tablets from server
ping -c 3 10.0.0.2   # tablet 1
ping -c 3 10.0.0.3   # tablet 2

# From tablet: ping server
# (run on tablet)
ping 10.0.0.1

# Check tunnel interface
ip addr show wg0

# Re-register a tablet key (if handshake is stale)
wg set wg0 peer <NEW_PUBLIC_KEY> allowed-ips <TABLET_IP>/32
wg-quick save wg0
```

---

## 16. EXPORT FUNCTIONALITY — ALL PORTALS

| Page | Format | Test |
|---|---|---|
| School Admin → Students | `.xlsx` | Click Export → file downloads |
| School Admin → Attendance/Manual | `.xlsx` | Select date → Export |
| School Admin → Device Attendance | `.xlsx` | Export Records button |
| DOD → Reports | `.xlsx` | Export on each tab |
| DOD → Leaves | `.xlsx` | Export button in toolbar |
| DOD → Dormitories | `.xlsx` | Export button in header |
| Patron → Attendance | `.xlsx` | Export when session selected |
| Patron → Dormitories | `.xlsx` | Export button per dorm |
| Gate Keeper → Attendance | `.xlsx` | Export button in toolbar |
| Gate Keeper → Boarding Leave | `.xlsx` | Export button in toolbar |
| DOS → Reports | `.xlsx` | Export per tab |
| Teacher → Attendance | `.xlsx` | Export button |
| Finance → Expenses | `.csv` | Export |
| Finance → Reports | `.csv` | Export |
| Staff → Alerts | `.csv` | Export |

---

## 17. QUICK SMOKE TEST SCRIPT (bash — run on server)

```bash
#!/bin/bash
BASE="http://localhost:5000/api/v1"

echo "=== EcaAfrica Smoke Test ==="

# Backend alive?
STATUS=$(curl -s -o /dev/null -w "%{http_code}" $BASE/app/health)
echo "Backend health: $STATUS"

# Login all roles
for role_email in \
  "admin@1.ecare.test:school_admin" \
  "dod@1.ecare.test:director_of_discipline" \
  "dos@1.ecare.test:director_of_studies" \
  "patron@1.ecare.test:patron" \
  "matron@1.ecare.test:matron" \
  "gatekeeper@1.ecare.test:gate_keeper" \
  "teacher1@1.ecare.test:teacher" \
  "finance@1.ecare.test:finance_officer" \
  "staff1@1.ecare.test:staff"
do
  EMAIL="${role_email%%:*}"
  EXPECTED="${role_email##*:}"
  RESP=$(curl -s -X POST $BASE/auth/login \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$EMAIL\",\"password\":\"Password@123\"}")
  ROLE=$(echo $RESP | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('user',{}).get('role','ERROR'))" 2>/dev/null)
  if [ "$ROLE" = "$EXPECTED" ]; then
    echo "  OK  $EMAIL -> $ROLE"
  else
    echo "  FAIL $EMAIL -> got '$ROLE', expected '$EXPECTED'"
  fi
done

# Key data endpoints
ADMIN_TOKEN=$(curl -s -X POST $BASE/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@1.ecare.test","password":"Password@123"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['access_token'])")

for endpoint in \
  "/students?limit=1" \
  "/classes?limit=1" \
  "/sections?limit=1" \
  "/subjects?limit=1" \
  "/timetable-periods?limit=1" \
  "/timetable-slots?limit=1" \
  "/exams?limit=1" \
  "/boarding/dormitories?limit=1" \
  "/boarding/student-leaves?limit=1" \
  "/devices?limit=1" \
  "/tablets?limit=1"
do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$BASE$endpoint")
  echo "  $STATUS  GET $endpoint"
done

echo "=== Done ==="
```

---

## 18. KNOWN ISSUES LOG

| # | Issue | Status | Fix |
|---|---|---|---|
| 1 | `boarding_officer` role removed | ✅ Fixed | DOD absorbs all boarding functions |
| 2 | DOS sidebar links stuck on current page | ✅ Fixed | Use `<a href>` for cross-namespace routes |
| 3 | Timetable API 404 (`/timetable/periods`) | ✅ Fixed | Corrected to `/timetable-periods` |
| 4 | Login redirect not working for some roles | ✅ Fixed | Use `window.location.href` |
| 5 | `staff.management` blocked by staff guard | ✅ Fixed | `staff.tsx` now allows admin/DOD/DOS |
| 6 | DOS student count always 0 | ✅ Fixed | Use `meta.total` from API response |
| 7 | Export buttons were stubs on many pages | ✅ Fixed | ExcelJS export added to all portals |
| 8 | Backend boarding routes crashing | ✅ Fixed | Missing `requireRole` import added |
| 9 | Prisma schema BOM character on server | ✅ Fixed | `sed -i '1s/^\xEF\xBB\xBF//' schema.prisma` |
| 10 | `routeTree.gen.ts` missing new routes | ✅ Fixed | Updated with all new route registrations |

---

*Generated: September 10, 2026 — EcaAfrica v2.0 (New_Serverr branch)*
