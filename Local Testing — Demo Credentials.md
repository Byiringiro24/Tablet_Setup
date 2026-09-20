# EcaAfrica — Local Testing Credentials

**Database:** `ECAREAFRICA` (PostgreSQL on localhost)  
**Backend:** http://localhost:5000  
**Frontend:** http://localhost:5173

---

## Platform Admin (Super Admin Panel)

Login at: **http://localhost:5173/login?mode=platform**

| Email | Password | Dashboard |
|---|---|---|
| `platform.admin@ecareafrica.test` | `Admin@123` | `/super-admin` |
| `admin@platform.test` | `Admin@123` | `/super-admin` |

---

## School: Nexus Demo School (School ID = 1)

Login at: **http://localhost:5173/login**

| Email | Password | Role | Goes To |
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

## School: Ecare Africa Pilot (School ID = 2)

Login at: **http://localhost:5173/login**

| Email | Password | Role | Goes To |
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
| `staff2@2.ecare.test` | `Password@123` | Staff | `/staff/dashboard` |
| `parent1@2.ecare.test` | `Password@123` | Parent | (Parent App) |
| `parent2@2.ecare.test` | `Password@123` | Parent | (Parent App) |
| `parent3@2.ecare.test` | `Password@123` | Parent | (Parent App) |

---

## Password Summary

| Account Type | Password |
|---|---|
| Platform Admin | `Admin@123` |
| All school users | `Password@123` |

---

## Role Capabilities Quick Reference

| Role | Key Actions |
|---|---|
| **Platform Admin** | Register tablets/devices, manage all schools, VPN, billing |
| **School Admin** | Full school management — all modules |
| **Director of Discipline** | Approve/reject leave, boarding attendance windows, dormitories, dining, patron assignments |
| **Director of Studies** | Class attendance monitoring, exams, timetable, academic staff |
| **Patron / Matron** | Own assigned dormitories only — attendance, dining, create leave requests |
| **Boarding Officer** | Boarding overview, roll calls, student dorm assignments |
| **Gate Keeper** | View approved exits with student photo, **CONFIRM GATE EXIT** button |
| **Teacher** | Class attendance, exams, grades, timetable |
| **Finance Officer** | Fees, expenses, payroll, invoices |
| **Staff** | Gate management, boarding overview |
| **Parent** | Own children only — attendance, leave status, notifications |

---

## Local Servers

| Service | URL | Status |
|---|---|---|
| Frontend | http://localhost:5173 | ✓ Running |
| Backend API | http://localhost:5000/api/v1 | ✓ Running |
| Database | `ECAREAFRICA` on localhost:5432 | ✓ Connected |
