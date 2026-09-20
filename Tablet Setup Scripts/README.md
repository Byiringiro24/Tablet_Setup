Scripts to install dependencies and start components individually with robust fallbacks.

Files:
- `install-deps.ps1` : Installs/checks Node/Git and runs `npm.cmd install` for backend/frontend. Prefers `npm.cmd` and falls back to using `cmd /c` to avoid PowerShell execution policy blocking `npm.ps1`.
- `start-fkbridge.ps1`: Builds (dotnet) and runs `FKBridge.exe` if present.
- `start-backend.ps1`: Starts backend via `npm.cmd run dev` or `node server.js`. Performs a /api/health check.
- `start-frontend.ps1`: Starts frontend via `npm.cmd run dev` or `npm.cmd run start`. Performs a simple HTTP check on port 3000.

Usage examples:
PowerShell:
```
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
cd 'Tablet Setup Scripts'
.\install-deps.ps1
.\start-fkbridge.ps1
.\start-backend.ps1
.\start-frontend.ps1
```

Notes:
- These scripts try multiple ways to execute `npm` to accommodate tablets where PowerShell blocks `npm.ps1`.
- They are intentionally simple; you can wire them into NSSM or scheduled tasks once validated on a device.
# EcaAfrica Tablet Setup

This package prepares a Windows tablet for the EcaAfrica biometric attendance system.

Repository:
https://github.com/Byiringiro24/Tablet_Setup.git

Branch:
Testing-Branch

---

## What this package does

This setup installs and verifies the required software, configures the local tablet environment, and prepares the EcaAfrica services for startup and automatic kiosk operation.

Included components:
- Git
- Node.js LTS
- npm
- .NET 8 x86 SDK
- Google Chrome
- WireGuard
- application folders and runtime config
- Windows Firewall rule for TCP 5005
- scheduled startup task
- GitHub update check and rollback flow

---

## Package structure

Keep all files together in one folder:

EcaAfrica-Setup/
  - Run-Setup.cmd
  - Setup-EcaAfrica.ps1
  - Start-EcaAfrica.ps1
  - README.md

Do not separate the files before running setup.

---

## Quick installation

On the tablet:

1. Copy the EcaAfrica-Setup folder to the device.
2. Open the folder.
3. Double-click Run-Setup.cmd.
4. Click Yes when Windows asks for Administrator permission.
5. Wait for setup to finish.
6. Restart the tablet when prompted.

---

## Manual installation

Open PowerShell as Administrator and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
cd "C:\path\to\EcaAfrica-Setup"
.\Setup-EcaAfrica.ps1
```

The script automatically re-prompts for Administrator access when needed.

---

## What the setup creates

The setup creates the following base folder structure:

- C:\EcaAfrica
- C:\EcaAfrica\scripts
- C:\EcaAfrica\logs
- C:\EcaAfrica\chrome-profile

These folders are created automatically and do not need to be manually prepared.

---

## Required tablet environment

The tablet should meet these minimum requirements:
- Windows 10 64-bit or Windows 11
- 4 GB RAM or more
- 10 GB free disk space
- internet connection
- local Administrator access

---

## Important .NET requirement

FKBridge requires the x86 .NET runtime environment. The setup checks for:

C:\Program Files (x86)\dotnet\dotnet.exe

Do not replace the x86 installation with only the x64 runtime. The tablet can still run on a 64-bit Windows OS, but the x86 .NET SDK is required for the FKBridge component.

---

## npm and PATH notes

PowerShell can sometimes block npm.ps1 because of execution policy restrictions. The setup therefore prefers npm.cmd instead of npm when locating Node.js tools.

The scripts also search common installation paths and refresh the PATH automatically when software is installed but not visible to the shell.

---

## Troubleshooting

- If Git, Node.js, or .NET are not installed, the setup attempts to install them automatically.
- If WireGuard is not available, the script installs it and configures automatic startup.
- If the frontend build fails, the script retries with dependency repair logic.
- If port 5005 is blocked, the script creates the required Windows Firewall rule.
- If GitHub has a newer version, the setup checks for updates and rolls back safely if validation fails.

---

## Startup order

After login, the system starts in this order:

WireGuard -> FKBridge -> Backend -> Frontend -> Chrome
