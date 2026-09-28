# EcaAfrica Tablet Setup

This is the single source of truth for setting up a Windows tablet for the EcaAfrica attendance system.

## What this folder contains

- `backend/` — Node.js service that talks to the FK623 device and relays attendance data to the server
- `frontend/` — web dashboard served locally on the tablet
- `FKBridge/` — .NET bridge used to connect to the biometric device
- `docs/` — only the current setup documentation
- `README.md` — consolidated setup and troubleshooting guide

## Canonical installation path

Always install and run the project from:

```text
C:\EcaAfrica
```

If the project is downloaded elsewhere, move it into `C:\EcaAfrica` before building or starting services.

## Architecture

```text
FK623 device -> FKBridge -> backend -> frontend -> local browser
                           |
                           +-> EcaAfrica server over HTTPS / WireGuard
```

## Requirements

Install the following before setup:

- Windows 10/11
- Node.js LTS
- .NET 8 SDK x86 and Desktop Runtime x86
- Git
- WireGuard
- Google Chrome
- Administrator rights

## Standard setup flow

### 1) Prepare the folder

```powershell
New-Item -ItemType Directory -Path "C:\EcaAfrica" -Force
```

Copy or clone the `Tablet Setup` project into `C:\EcaAfrica`.

### 2) Install dependencies

```powershell
cd C:\EcaAfrica\backend
npm install

cd C:\EcaAfrica\frontend
npm install
```

### 3) Build the bridge

```powershell
cd C:\EcaAfrica\FKBridge
dotnet build -c Release
```

### 4) Validate environment files

Check that the backend `.env` and frontend config point to the local tablet runtime and the remote EcaAfrica server as required.

### 5) Start the services

Open separate terminals:

```powershell
cd C:\EcaAfrica\backend
node server.js
```

```powershell
cd C:\EcaAfrica\FKBridge
FKBridge.exe
```

```powershell
cd C:\EcaAfrica\frontend
npm run dev
```

Then open:

```text
http://localhost:3000
```

## Auto-start and deployment

The tablet should be configured to start automatically after Windows login, using a scheduled task or startup shortcut. The system must be started in the correct order:

1. backend
2. FKBridge
3. frontend
4. Chrome kiosk

## WireGuard and server connectivity

The tablet may connect to the central EcaAfrica system through WireGuard. If VPN is required:

- keep the tunnel config stable
- ensure the tablet is assigned a valid VPN IP
- confirm the server endpoint and public key match the active deployment
- verify the backend is running with administrator permissions when required

## Common troubleshooting

### Port already in use

```powershell
Get-NetTCPConnection -LocalPort 5000 -State Listen
```

If another process is using the port, stop it or change the port configuration and update any related server registration.

### FKBridge fails to start

- confirm the `.NET 8 x86` runtime is installed
- confirm the project lives under `C:\EcaAfrica`
- rebuild the bridge project

### Frontend shows backend offline

- start the backend first
- confirm the API URL is reachable locally
- confirm Node.js is running and no port conflicts exist

### Photo or student-image issues

Use the local cache and room-scoped sync flow already implemented in the tablet backend/frontend. This keeps image loading reliable even when the remote server is slow or the device is intermittently offline.

## Recommended folder cleanup

This project should keep only the files needed for running, maintaining, and supporting the tablet deployment. Temporary files, duplicate guides, and stale notes should be removed.

## Final note

This guide replaces older duplicate setup documents in this folder. Keep the structure simple: one main README, one setup guide, clean runtime folders, and no duplicate instructions.

---

EcaAfrica Tablet Setup — consolidated guide
