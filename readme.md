# FK Biometric Attendance System - Complete Documentation

**Date**: May 29, 2026  
**Project Path**: `d:\Projectts 2026\project 34`

---

## 📋 Table of Contents
1. [System Architecture](#system-architecture)
2. [Commands Sent to Device](#commands-sent-to-device)
3. [Device Settings & Configuration](#device-settings--configuration)
4. [Files Used in the System](#files-used-in-the-system)
5. [Complete Source Code](#complete-source-code)
6. [Communication Flow](#communication-flow)
7. [DLL Functions Reference](#dll-functions-reference)

---

## System Architecture

The system consists of 4 main layers:

```
┌─────────────────────────────────────────────────────────┐
│                    FRONTEND (Next.js)                   │
│              Web UI for Dashboard & Management            │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│              NODE.JS BACKEND (Port 4000)                │
│         Express server - API proxy to C# bridge          │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│          C# BRIDGE APPLICATION (Port 5001)             │
│      Handles device commands via stdin/stdout           │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│      FK623Attend.dll (Biometric Device SDK)             │
│              P/Invoke DLL Functions                     │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│     FK623 Biometric Device (TCP/IP 5005)               │
│      Fingerprint | Face | Card | Password              │
└─────────────────────────────────────────────────────────┘
```

---

## Commands Sent to Device

### **Device Connection Commands**

#### 1. **CONNECT** - Establish connection to device
```
Command Format: CONNECT|<ip>|<port>|<license>|<deviceId>

Example: CONNECT|10.29.234.16|5005|1261|DV-KGL-01

Parameters:
  - ip          : Device IP address (required)
  - port        : Device port number (default: 5005)
  - license     : License key (default: 1261)
  - deviceId    : Device identifier (optional)

Response:
{
  "success": true,
  "type": "CONNECTED",
  "data": {
    "connected": true,
    "handle": 2,
    "ipAddress": "10.29.234.16",
    "port": 5005,
    "deviceId": "DV-KGL-01",
    "users": 25,
    "fingerprints": 45,
    "passwords": 10,
    "logs": 1250,
    "cards": 5,
    "faces": 30,
    "serialNumber": "FK623-001234",
    "productCode": "FK623",
    "productName": "FK623 Biometric Device"
  }
}
```

#### 2. **DISCONNECT** - Close device connection
```
Command Format: DISCONNECT

Response:
{
  "success": true,
  "type": "DISCONNECTED"
}
```

#### 3. **STATUS** - Check device status
```
Command Format: STATUS

Response:
{
  "success": true,
  "type": "STATUS",
  "data": {
    "connected": true,
    "handle": 2,
    "ipAddress": "10.29.234.16",
    "port": 5005,
    "users": 25,
    "fingerprints": 45,
    "passwords": 10,
    "logs": 1250,
    "cards": 5,
    "faces": 30,
    "serialNumber": "FK623-001234",
    "productCode": "FK623",
    "productName": "FK623 Biometric Device"
  }
}
```

---

### **User Management Commands**

#### 4. **GET_USERS** - Retrieve all users from device
```
Command Format: GET_USERS

Response:
{
  "success": true,
  "type": "USERS",
  "data": {
    "users": [
      {
        "userId": "1",
        "name": "Administrator",
        "backupNumber": 0,
        "privilege": 1,
        "enabled": true
      },
      {
        "userId": "2",
        "name": "John Doe",
        "backupNumber": 0,
        "privilege": 0,
        "enabled": true
      }
    ],
    "count": 2
  }
}
```

#### 5. **ADD_USER** - Add new user to device
```
Command Format: ADD_USER|<userId>|<userName>

Example: ADD_USER|RW-2024-001|John Doe

Response:
{
  "success": true,
  "type": "ADD_USER",
  "data": {
    "userId": "RW-2024-001",
    "name": "John Doe"
  }
}
```

#### 6. **DELETE_USER** - Remove user from device
```
Command Format: DELETE_USER|<userId>

Example: DELETE_USER|RW-2024-001

Response:
{
  "success": true,
  "type": "DELETE_USER",
  "data": {
    "userId": "RW-2024-001"
  }
}
```

---

### **Attendance/Logs Commands**

#### 7. **GET_LOGS** - Retrieve attendance logs
```
Command Format: GET_LOGS|<readMark>

Parameters:
  - readMark: 0 = Read all logs, 1 = Read new logs since last read

Example: GET_LOGS|1

Response:
{
  "success": true,
  "type": "LOGS",
  "data": {
    "logs": [
      {
        "id": "RW-2024-001-20260529140530-0",
        "userId": "RW-2024-001",
        "timestamp": "2026-05-29T14:05:30",
        "verifyMode": 1,
        "method": "FINGERPRINT",
        "inOutMode": 1,
        "direction": "IN",
        "workCode": 0
      },
      {
        "id": "RW-2024-002-20260529143015-1",
        "userId": "RW-2024-002",
        "timestamp": "2026-05-29T14:30:15",
        "verifyMode": 20,
        "method": "FACE",
        "inOutMode": 2,
        "direction": "OUT",
        "workCode": 0
      }
    ],
    "count": 2
  }
}
```

#### 8. **CLEAR_LOGS** - Clear all attendance logs
```
Command Format: CLEAR_LOGS

Response:
{
  "success": true,
  "type": "CLEAR_LOGS"
}
```

---

### **System Management Commands**

#### 9. **SYNC_TIME** - Synchronize device time with server
```
Command Format: SYNC_TIME

Response:
{
  "success": true,
  "type": "SYNC_TIME",
  "data": {
    "syncedAt": "2026-05-29T14:35:22.5000000"
  }
}
```

#### 10. **CLEAR_ALL** - Clear all data from device
```
Command Format: CLEAR_ALL

Response:
{
  "success": true,
  "type": "CLEAR_ALL"
}
```

#### 11. **POWEROFF** - Power off the device
```
Command Format: POWEROFF

Response:
{
  "success": true,
  "type": "POWEROFF"
}
```

#### 12. **EXIT** - Exit bridge application
```
Command Format: EXIT

Response:
{
  "success": true,
  "type": "EXIT"
}
```

---

## Device Settings & Configuration

### **Network Configuration**

| Setting | Value | Description |
|---------|-------|-------------|
| Device IP | `10.29.234.16` | Default device IP address |
| Device Port | `5005` | Default communication port |
| Protocol Type | `0` | Protocol version (0 = Standard) |
| Connection Timeout | `5000` ms | Maximum wait time for connection |
| Machine Number | `1` | Device identifier in network |

### **Authentication Settings**

| Setting | Value | Description |
|---------|-------|-------------|
| License Key | `1261` | FK623 device license |
| Network Password | `0` | Network authentication password |
| Device Enable Flag | `1` | Enable device for operations (1=enabled, 0=disabled) |

### **Device Capabilities (Status Indices)**

| Index | Status Type | Description |
|-------|-------------|-------------|
| 2 | Users Count | Total users enrolled on device |
| 3 | Fingerprints | Total fingerprint templates |
| 4 | Passwords | Total password entries |
| 6 | Logs | Total attendance records |
| 9 | Cards | Total card registrations |
| 10 | Faces | Total face templates |

### **Device Information (Product Data)**

| Index | Product Data | Example |
|-------|--------------|---------|
| 1 | Serial Number | `FK623-001234` |
| 3 | Product Code | `FK623` |
| 4 | Product Name | `FK623 Biometric Device` |

### **Verification Methods**

| Mode Code | Authentication Method |
|-----------|----------------------|
| 1 | Fingerprint |
| 2 | Password |
| 3 | Card |
| 20 | Face Recognition |
| 21 | Face + Card |
| 22 | Face + Password |
| 23 | Card + Face |
| 24 | Password + Face |
| 25 | Face + Fingerprint |
| 26 | Fingerprint + Face |

### **In/Out Modes**

| Mode Code | Direction | Description |
|-----------|-----------|-------------|
| 0-2 | IN | Check-in (entrance) |
| 3-4 | OUT | Check-out (exit) |
| 1,3,5,7 | IN | Alternative IN patterns |
| 2,4,6,8 | OUT | Alternative OUT patterns |

### **Enroll Data Backup Numbers**

Supports backup numbers 0-12 (13 total backups per user):
- **0** - Primary biometric template
- **1-12** - Backup templates

---

## Files Used in the System

### **C# Components** (in `d:\Projectts 2026\project 34\fk-system\`)

| File Path | Purpose | Language |
|-----------|---------|----------|
| `FKBridge/Program.cs` | Main bridge application | C# |
| `FKWebApi/Program.cs` | REST API server | C# |
| `FKBridge/FKBridge.csproj` | Project configuration | XML |
| `FKWebApi/FKWebApi.csproj` | Project configuration | XML |
| `FKWebApi/appsettings.json` | API configuration | JSON |

### **Node.js Components** (in `d:\Projectts 2026\project 34\fk-system\`)

| File Path | Purpose | Language |
|-----------|---------|----------|
| `fk-backend/src/index.ts` | Express backend server | TypeScript |
| `simple-bridge/index.js` | Simple JavaScript bridge | JavaScript |
| `fk-backend/package.json` | Dependencies | JSON |
| `simple-bridge/package.json` | Dependencies | JSON |

### **Frontend Components** (in `d:\Projectts 2026\project 34\fk-system\frontend\`)

| File Path | Purpose | Language |
|-----------|---------|----------|
| `app/page.tsx` | Main dashboard page | TypeScript/React |
| `app/layout.tsx` | Layout wrapper | TypeScript/React |
| `app/globals.css` | Global styles | CSS |
| `lib/api.ts` | API client utilities | TypeScript |
| `package.json` | Frontend dependencies | JSON |
| `tsconfig.json` | TypeScript configuration | JSON |
| `next.config.js` | Next.js configuration | JavaScript |

### **DLL Files** (in `d:\Projectts 2026\project 34\fk-system\DLLs\`)

**Core FK623 Libraries:**
- `FK623Attend.dll` - Main device control library
- `FKAttend.dll` - Additional device interface
- `FKPwdEncDec.dll` - Password encryption/decryption
- `FaceDataConv.dll` - Face template conversion
- `FpDataConv.dll` - Fingerprint template conversion
- `FKViaDev.dll` - Device via interface
- `LFWViaDev.dll` - Live face recognition interface

**System Libraries:**
- `adodb.dll` - ActiveX Data Objects
- `Newtonsoft.Json.dll` - JSON parsing
- `Microsoft.Build.Framework.dll` - Build framework
- `System.Collections.Immutable.dll` - Immutable collections
- `System.Runtime.InteropServices.RuntimeInformation.dll` - Runtime info

**Interop Libraries:**
- `AxInterop.AXIMAGELib.dll` - Image control interop
- `AxInterop.RealSvrOcxTcpLib.dll` - Real server interop
- `Interop.AXIMAGELib.dll` - Image library interop
- `Interop.RealSvrOcxTcpLib.dll` - Real server library interop

### **Configuration Files**

| File | Purpose | Location |
|------|---------|----------|
| `appsettings.json` | API settings | `FKWebApi/` |
| `.env` or `.env.local` | Environment variables | Project root |
| `tsconfig.json` | TypeScript config | Frontend & backends |
| `package.json` | NPM dependencies | Each Node.js project |

### **Database Files**

| File | Purpose | Location |
|------|---------|----------|
| `database/students.json` | Student records | `fk-system/` |

---

## Complete Source Code

### **1. C# Bridge Program** (`FKBridge/Program.cs`)

```csharp
using System.Runtime.InteropServices;
using Newtonsoft.Json;

namespace FKBridge;

public class FKDevice
{
    [DllImport("FK623Attend.dll", CharSet = CharSet.Ansi)]
    public static extern int FK_ConnectNet(int anMachineNo, string astrIpAddress, int anNetPort, int anTimeOut, int anProtocolType, int anNetPassword, int anLicense);

    [DllImport("FK623Attend.dll", CharSet = CharSet.Ansi)]
    public static extern void FK_DisConnect(int anHandleIndex);

    [DllImport("FK623Attend.dll", CharSet = CharSet.Ansi)]
    public static extern int FK_EnableDevice(int anHandleIndex, byte anEnableFlag);

    [DllImport("FK623Attend.dll", CharSet = CharSet.Ansi)]
    public static extern int FK_SetDeviceTime(int anHandleIndex, DateTime anDateTime);

    [DllImport("FK623Attend.dll", CharSet = CharSet.Ansi)]
    public static extern int FK_GetDeviceStatus(int anHandleIndex, int anStatusIndex, ref int apnValue);

    [DllImport("FK623Attend.dll", CharSet = CharSet.Ansi)]
    public static extern int FK_GetProductData(int anHandleIndex, int anDataIndex, [MarshalAs(UnmanagedType.LPStr)] ref string apstrValue);

    [DllImport("FK623Attend.dll", CharSet = CharSet.Ansi)]
    public static extern int FK_ReadAllUserID(int anHandleIndex);

    [DllImport("FK623Attend.dll", CharSet = CharSet.Ansi)]
    public static extern int FK_GetAllUserID(int anHandleIndex, ref UInt32 apnEnrollNumber, ref int apnBackupNumber, ref int apnMachinePrivilege, ref int apnEnable);

    [DllImport("FK623Attend.dll", CharSet = CharSet.Ansi)]
    public static extern int FK_GetAllUserID_StringID(int anHandleIndex, ref string apEnrollNumber, ref int apnBackupNumber, ref int apnMachinePrivilege, ref int apnEnableFlag);

    [DllImport("FK623Attend.dll", CharSet = CharSet.Ansi)]
    public static extern int FK_GetUserName_StringID(int anHandleIndex, string apEnrollNumber, [MarshalAs(UnmanagedType.LPStr)] ref string apstrUserName);

    [DllImport("FK623Attend.dll", CharSet = CharSet.Ansi)]
    public static extern int FK_GetUserName(int anHandleIndex, UInt32 anEnrollNumber, [MarshalAs(UnmanagedType.LPStr)] ref string apstrUserName);

    [DllImport("FK623Attend.dll", CharSet = CharSet.Ansi)]
    public static extern int FK_SetUserName_StringID(int anHandleIndex, string apEnrollNumber, string astrUserName);

    [DllImport("FK623Attend.dll", CharSet = CharSet.Ansi)]
    public static extern int FK_SetUserName(int anHandleIndex, UInt32 anEnrollNumber, string astrUserName);

    [DllImport("FK623Attend.dll", CharSet = CharSet.Ansi)]
    public static extern int FK_DeleteEnrollData_StringID(int anHandleIndex, string apEnrollNumber, int anBackupNumber);

    [DllImport("FK623Attend.dll", CharSet = CharSet.Ansi)]
    public static extern int FK_LoadGeneralLogData(int anHandleIndex, int anReadMark);

    [DllImport("FK623Attend.dll", CharSet = CharSet.Ansi)]
    public static extern int FK_GetGeneralLogData_StringID_Workcode(int anHandleIndex, [MarshalAs(UnmanagedType.LPStr)] ref string apnEnrollNumber, ref int apnVerifyMode, ref int apnInOutMode, ref DateTime apnDateTime, ref int apnWorkCode);

    [DllImport("FK623Attend.dll", CharSet = CharSet.Ansi)]
    public static extern int FK_GetGeneralLogData(int anHandleIndex, ref UInt32 apnEnrollNumber, ref int apnVerifyMode, ref int apnInOutMode, ref DateTime apnDateTime);

    [DllImport("FK623Attend.dll", CharSet = CharSet.Ansi)]
    public static extern int FK_EmptyGeneralLogData(int anHandleIndex);

    [DllImport("FK623Attend.dll", CharSet = CharSet.Ansi)]
    public static extern int FK_ClearKeeperData(int anHandleIndex);

    [DllImport("FK623Attend.dll", CharSet = CharSet.Ansi)]
    public static extern int FK_PowerOffDevice(int anHandleIndex);
}

public record BridgeResult(bool success, string type, object? data = null, string? error = null, int? code = null);

public class Program
{
    private const int RunSuccess = 1;
    private const int DataArrayEnd = -7;
    private static int deviceHandle = -1;
    private static bool connected;
    private static string currentIp = "";
    private static int currentPort;
    private static string deviceId = "";

    public static void Main()
    {
        Console.OutputEncoding = System.Text.Encoding.UTF8;
        Write(new BridgeResult(true, "READY", new { pid = Environment.ProcessId }));

        string? command;
        while ((command = Console.ReadLine()) != null)
        {
            if (string.IsNullOrWhiteSpace(command)) continue;
            try
            {
                Handle(command.Trim());
            }
            catch (Exception ex)
            {
                Write(new BridgeResult(false, "ERROR", error: ex.Message));
            }
        }
    }

    private static void Handle(string command)
    {
        var parts = command.Split('|');
        var action = parts[0].ToUpperInvariant();

        switch (action)
        {
            case "CONNECT":
                Connect(parts.ElementAtOrDefault(1) ?? "", ParseInt(parts.ElementAtOrDefault(2), 5005), ParseInt(parts.ElementAtOrDefault(3), 1261), parts.ElementAtOrDefault(4) ?? "");
                break;
            case "DISCONNECT":
                Disconnect();
                Write(new BridgeResult(true, "DISCONNECTED"));
                break;
            case "STATUS":
                Write(new BridgeResult(true, "STATUS", BuildStatus()));
                break;
            case "GET_USERS":
                GetUsers();
                break;
            case "GET_LOGS":
                GetLogs(ParseInt(parts.ElementAtOrDefault(1), 0));
                break;
            case "SYNC_TIME":
                SyncTime();
                break;
            case "ADD_USER":
                AddUser(parts.ElementAtOrDefault(1) ?? "", parts.ElementAtOrDefault(2) ?? "");
                break;
            case "DELETE_USER":
                DeleteUser(parts.ElementAtOrDefault(1) ?? "");
                break;
            case "CLEAR_LOGS":
                ClearLogs();
                break;
            case "CLEAR_ALL":
                ClearAll();
                break;
            case "POWEROFF":
                PowerOff();
                break;
            case "EXIT":
                Disconnect();
                Write(new BridgeResult(true, "EXIT"));
                Environment.Exit(0);
                break;
            default:
                Write(new BridgeResult(false, action, error: $"Unknown command: {action}"));
                break;
        }
    }

    private static void Connect(string ip, int port, int license, string requestedDeviceId)
    {
        if (connected) Disconnect();
        if (string.IsNullOrWhiteSpace(ip))
        {
            Write(new BridgeResult(false, "CONNECTED", error: "IP address is required"));
            return;
        }

        var result = FKDevice.FK_ConnectNet(1, ip, port, 5000, 0, 0, license);
        if (result > 0)
        {
            deviceHandle = result;
            connected = true;
            currentIp = ip;
            currentPort = port;
            deviceId = requestedDeviceId;
            FKDevice.FK_EnableDevice(deviceHandle, 1);
            Write(new BridgeResult(true, "CONNECTED", BuildStatus()));
            return;
        }

        Write(new BridgeResult(false, "CONNECTED", error: ConnectionError(result), code: result));
    }

    private static void Disconnect()
    {
        if (connected && deviceHandle > 0)
        {
            try
            {
                FKDevice.FK_EnableDevice(deviceHandle, 1);
                FKDevice.FK_DisConnect(deviceHandle);
            }
            catch { }
        }
        connected = false;
        deviceHandle = -1;
    }

    private static void GetUsers()
    {
        if (!EnsureConnected("USERS")) return;
        var users = new List<object>();

        FKDevice.FK_EnableDevice(deviceHandle, 0);
        var readResult = FKDevice.FK_ReadAllUserID(deviceHandle);
        if (readResult != RunSuccess)
        {
            FKDevice.FK_EnableDevice(deviceHandle, 1);
            Write(new BridgeResult(false, "USERS", error: $"FK_ReadAllUserID failed: {readResult}", code: readResult));
            return;
        }

        var firstStringResult = ReadStringUsers(users);
        if (users.Count == 0 && firstStringResult != DataArrayEnd)
        {
            FKDevice.FK_ReadAllUserID(deviceHandle);
            var numericResult = ReadNumericUsers(users);
            if (numericResult != DataArrayEnd && numericResult != RunSuccess)
            {
                FKDevice.FK_EnableDevice(deviceHandle, 1);
                Write(new BridgeResult(false, "USERS", error: $"User read failed. StringID={firstStringResult}, NumericID={numericResult}", code: numericResult));
                return;
            }
        }

        FKDevice.FK_EnableDevice(deviceHandle, 1);
        Write(new BridgeResult(true, "USERS", new { users, count = users.Count }));
    }

    private static int ReadStringUsers(List<object> users)
    {
        while (true)
        {
            string enrollNumber = new(' ', 32);
            int backup = 0;
            int privilege = 0;
            int enabled = 0;
            var result = FKDevice.FK_GetAllUserID_StringID(deviceHandle, ref enrollNumber, ref backup, ref privilege, ref enabled);
            if (result == DataArrayEnd) return result;
            if (result != RunSuccess) return result;

            var userId = Clean(enrollNumber);
            if (string.IsNullOrWhiteSpace(userId)) continue;
            string name = new(' ', 256);
            FKDevice.FK_GetUserName_StringID(deviceHandle, userId, ref name);
            users.Add(new { userId, name = Clean(name), backupNumber = backup, privilege, enabled = enabled == 1 });
        }
    }

    private static int ReadNumericUsers(List<object> users)
    {
        while (true)
        {
            UInt32 enrollNumber = 0;
            int backup = 0;
            int privilege = 0;
            int enabled = 0;
            var result = FKDevice.FK_GetAllUserID(deviceHandle, ref enrollNumber, ref backup, ref privilege, ref enabled);
            if (result == DataArrayEnd) return result;
            if (result != RunSuccess) return result;
            if (enrollNumber == 0) continue;

            string name = new(' ', 256);
            FKDevice.FK_GetUserName(deviceHandle, enrollNumber, ref name);
            users.Add(new { userId = enrollNumber.ToString(), name = Clean(name), backupNumber = backup, privilege, enabled = enabled == 1 });
        }
    }

    private static void GetLogs(int readMark)
    {
        if (!EnsureConnected("LOGS")) return;
        var logs = new List<object>();

        FKDevice.FK_EnableDevice(deviceHandle, 0);
        var loadResult = FKDevice.FK_LoadGeneralLogData(deviceHandle, readMark);
        if (loadResult != RunSuccess)
        {
            FKDevice.FK_EnableDevice(deviceHandle, 1);
            Write(new BridgeResult(false, "LOGS", error: $"FK_LoadGeneralLogData failed: {loadResult}", code: loadResult));
            return;
        }

        var firstStringResult = ReadStringLogs(logs);
        if (logs.Count == 0)
        {
            FKDevice.FK_LoadGeneralLogData(deviceHandle, readMark);
            var numericResult = ReadNumericLogs(logs);
            if (numericResult != DataArrayEnd && numericResult != RunSuccess)
            {
                FKDevice.FK_EnableDevice(deviceHandle, 1);
                Write(new BridgeResult(false, "LOGS", error: $"Log read failed. StringID={firstStringResult}, NumericID={numericResult}", code: numericResult));
                return;
            }
        }

        FKDevice.FK_EnableDevice(deviceHandle, 1);
        Write(new BridgeResult(true, "LOGS", new { logs, count = logs.Count }));
    }

    private static int ReadStringLogs(List<object> logs)
    {
        while (true)
        {
            string enrollNumber = new(' ', 32);
            int verifyMode = 0;
            int inOutMode = 0;
            int workCode = 0;
            DateTime timestamp = DateTime.MinValue;
            var result = FKDevice.FK_GetGeneralLogData_StringID_Workcode(deviceHandle, ref enrollNumber, ref verifyMode, ref inOutMode, ref timestamp, ref workCode);
            if (result == DataArrayEnd) return result;
            if (result != RunSuccess) return result;

            AddLog(logs, Clean(enrollNumber), timestamp, verifyMode, inOutMode, workCode);
        }
    }

    private static int ReadNumericLogs(List<object> logs)
    {
        while (true)
        {
            UInt32 enrollNumber = 0;
            int verifyMode = 0;
            int inOutMode = 0;
            DateTime timestamp = DateTime.MinValue;
            var result = FKDevice.FK_GetGeneralLogData(deviceHandle, ref enrollNumber, ref verifyMode, ref inOutMode, ref timestamp);
            if (result == DataArrayEnd) return result;
            if (result != RunSuccess) return result;
            AddLog(logs, enrollNumber.ToString(), timestamp, verifyMode, inOutMode, 0);
        }
    }

    private static void AddLog(List<object> logs, string userId, DateTime timestamp, int verifyMode, int inOutMode, int workCode)
    {
        if (string.IsNullOrWhiteSpace(userId)) return;
        logs.Add(new
        {
            id = $"{userId}-{timestamp:yyyyMMddHHmmss}-{logs.Count}",
            userId,
            timestamp = timestamp.ToString("o"),
            verifyMode,
            method = VerifyModeName(verifyMode),
            inOutMode,
            direction = DirectionName(inOutMode),
            workCode
        });
    }

    private static void SyncTime()
    {
        if (!EnsureConnected("SYNC_TIME")) return;
        FKDevice.FK_EnableDevice(deviceHandle, 0);
        var result = FKDevice.FK_SetDeviceTime(deviceHandle, DateTime.Now);
        FKDevice.FK_EnableDevice(deviceHandle, 1);
        Write(result == RunSuccess
            ? new BridgeResult(true, "SYNC_TIME", new { syncedAt = DateTime.Now.ToString("o") })
            : new BridgeResult(false, "SYNC_TIME", error: $"FK_SetDeviceTime failed: {result}", code: result));
    }

    private static void AddUser(string userId, string name)
    {
        if (!EnsureConnected("ADD_USER")) return;
        if (string.IsNullOrWhiteSpace(userId))
        {
            Write(new BridgeResult(false, "ADD_USER", error: "User ID is required"));
            return;
        }
        FKDevice.FK_EnableDevice(deviceHandle, 0);
        var result = FKDevice.FK_SetUserName_StringID(deviceHandle, userId, name);
        if (result != RunSuccess && UInt32.TryParse(userId, out var numericUserId))
        {
            result = FKDevice.FK_SetUserName(deviceHandle, numericUserId, name);
        }
        FKDevice.FK_EnableDevice(deviceHandle, 1);
        Write(result == RunSuccess
            ? new BridgeResult(true, "ADD_USER", new { userId, name })
            : new BridgeResult(false, "ADD_USER", error: $"Set user name failed: {result}", code: result));
    }

    private static void DeleteUser(string userId)
    {
        if (!EnsureConnected("DELETE_USER")) return;
        if (string.IsNullOrWhiteSpace(userId))
        {
            Write(new BridgeResult(false, "DELETE_USER", error: "User ID is required"));
            return;
        }
        FKDevice.FK_EnableDevice(deviceHandle, 0);
        for (var backup = 0; backup <= 12; backup++) FKDevice.FK_DeleteEnrollData_StringID(deviceHandle, userId, backup);
        FKDevice.FK_SetUserName_StringID(deviceHandle, userId, "");
        FKDevice.FK_EnableDevice(deviceHandle, 1);
        Write(new BridgeResult(true, "DELETE_USER", new { userId }));
    }

    private static void ClearLogs()
    {
        if (!EnsureConnected("CLEAR_LOGS")) return;
        FKDevice.FK_EnableDevice(deviceHandle, 0);
        var result = FKDevice.FK_EmptyGeneralLogData(deviceHandle);
        FKDevice.FK_EnableDevice(deviceHandle, 1);
        Write(result == RunSuccess ? new BridgeResult(true, "CLEAR_LOGS") : new BridgeResult(false, "CLEAR_LOGS", error: $"FK_EmptyGeneralLogData failed: {result}", code: result));
    }

    private static void ClearAll()
    {
        if (!EnsureConnected("CLEAR_ALL")) return;
        FKDevice.FK_EnableDevice(deviceHandle, 0);
        var result = FKDevice.FK_ClearKeeperData(deviceHandle);
        FKDevice.FK_EnableDevice(deviceHandle, 1);
        Write(result == RunSuccess ? new BridgeResult(true, "CLEAR_ALL") : new BridgeResult(false, "CLEAR_ALL", error: $"FK_ClearKeeperData failed: {result}", code: result));
    }

    private static void PowerOff()
    {
        if (!EnsureConnected("POWEROFF")) return;
        var result = FKDevice.FK_PowerOffDevice(deviceHandle);
        Write(result == RunSuccess ? new BridgeResult(true, "POWEROFF") : new BridgeResult(false, "POWEROFF", error: $"FK_PowerOffDevice failed: {result}", code: result));
    }

    private static bool EnsureConnected(string type)
    {
        if (connected && deviceHandle > 0) return true;
        Write(new BridgeResult(false, type, error: "Device not connected"));
        return false;
    }

    private static object BuildStatus()
    {
        var status = new Dictionary<string, object?>
        {
            ["connected"] = connected,
            ["handle"] = deviceHandle,
            ["ipAddress"] = currentIp,
            ["port"] = currentPort,
            ["deviceId"] = deviceId
        };

        if (connected && deviceHandle > 0)
        {
            status["users"] = GetStatusValue(2);
            status["fingerprints"] = GetStatusValue(3);
            status["passwords"] = GetStatusValue(4);
            status["logs"] = GetStatusValue(6);
            status["cards"] = GetStatusValue(9);
            status["faces"] = GetStatusValue(10);
            status["serialNumber"] = GetProductValue(1);
            status["productCode"] = GetProductValue(3);
            status["productName"] = GetProductValue(4);
        }

        return status;
    }

    private static int? GetStatusValue(int index)
    {
        int value = 0;
        return FKDevice.FK_GetDeviceStatus(deviceHandle, index, ref value) == RunSuccess ? value : null;
    }

    private static string? GetProductValue(int index)
    {
        string value = new(' ', 256);
        return FKDevice.FK_GetProductData(deviceHandle, index, ref value) == RunSuccess ? Clean(value) : null;
    }

    private static string VerifyModeName(int mode) => mode switch
    {
        1 => "FINGERPRINT",
        2 => "PASSWORD",
        3 => "CARD",
        20 => "FACE",
        21 => "FACE_CARD",
        22 => "FACE_PASSWORD",
        23 => "CARD_FACE",
        24 => "PASSWORD_FACE",
        25 => "FACE_FINGERPRINT",
        26 => "FINGERPRINT_FACE",
        _ => $"MODE_{mode}"
    };

    private static string DirectionName(int inOutMode)
    {
        var low = inOutMode & 0x0f;
        var high = inOutMode >> 4;
        if (high == 1) return "IN";
        if (high == 2) return "OUT";
        return low switch { 1 or 3 or 5 or 7 => "IN", 2 or 4 or 6 or 8 => "OUT", _ => "UNKNOWN" };
    }

    private static int ParseInt(string? value, int fallback) => int.TryParse(value, out var parsed) ? parsed : fallback;

    private static string Clean(string value) => value.Replace("\0", "").Trim();

    private static string ConnectionError(int code) => code switch
    {
        -2 => "Device not reachable. Check the IP address, port, network, and that the device is powered on.",
        -3 => "Communication write failed.",
        -4 => "Communication read failed.",
        -5 => "Invalid parameter sent to the DLL.",
        -10 => "Invalid FK license key or network password.",
        _ => $"Connection failed with FK error code {code}."
    };

    private static void Write(BridgeResult result)
    {
        Console.WriteLine(JsonConvert.SerializeObject(result));
        Console.Out.Flush();
    }
}
```

---

### **2. Node.js Backend** (`fk-backend/src/index.ts`)

```typescript
import express from 'express';
import cors from 'cors';
import axios from 'axios';

const app = express();
const PORT = process.env.PORT || 4000;
const FK_BRIDGE = process.env.FK_BRIDGE_URL || 'http://localhost:5001';

app.use(cors());
app.use(express.json());

// Proxy to C# Bridge
async function callBridge(method: string, path: string, data?: any) {
    try {
        const url = `${FK_BRIDGE}${path}`;
        if (method === 'GET') {
            const res = await axios.get(url);
            return res.data;
        } else {
            const res = await axios.post(url, data);
            return res.data;
        }
    } catch (error: any) {
        throw new Error(error.response?.data?.error || error.message);
    }
}

// ============ API Endpoints ============

app.get('/', (req, res) => {
    res.json({
        success: true,
        message: 'FK Biometric Backend',
        bridge: FK_BRIDGE,
        endpoints: ['/api/device/connect', '/api/users', '/api/logs', '/attendance']
    });
});

// Device Connection
app.post('/api/device/connect', async (req, res) => {
    try {
        const result = await callBridge('POST', '/api/connect', req.body);
        res.json(result);
    } catch (error: any) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.post('/api/device/disconnect', async (req, res) => {
    try {
        const result = await callBridge('POST', '/api/disconnect');
        res.json(result);
    } catch (error: any) {
        res.json({ success: false, error: error.message });
    }
});

app.get('/api/device/status', async (req, res) => {
    try {
        const result = await callBridge('GET', '/api/status');
        res.json(result);
    } catch (error: any) {
        res.json({ connected: false });
    }
});

app.post('/api/device/sync-time', async (req, res) => {
    try {
        const result = await callBridge('POST', '/api/sync-time');
        res.json(result);
    } catch (error: any) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.get('/api/device/info', async (req, res) => {
    try {
        const result = await callBridge('GET', '/api/device-info');
        res.json(result);
    } catch (error: any) {
        res.status(500).json({ error: error.message });
    }
});

// User Management
app.get('/api/users', async (req, res) => {
    try {
        const result = await callBridge('GET', '/api/users');
        res.json(result);
    } catch (error: any) {
        res.status(500).json({ error: error.message, users: [], count: 0 });
    }
});

app.post('/api/users', async (req, res) => {
    try {
        const result = await callBridge('POST', '/api/users', req.body);
        res.json(result);
    } catch (error: any) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.delete('/api/users/:userId', async (req, res) => {
    try {
        const result = await callBridge('POST', '/api/users', {});
        res.json(result);
    } catch (error: any) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Log Management
app.get('/api/logs', async (req, res) => {
    try {
        const result = await callBridge('GET', '/api/logs');
        res.json(result);
    } catch (error: any) {
        res.status(500).json({ error: error.message, logs: [], count: 0 });
    }
});

app.delete('/api/logs', async (req, res) => {
    try {
        const result = await callBridge('POST', '/api/logs', {});
        res.json(result);
    } catch (error: any) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.post('/api/device/clear-all', async (req, res) => {
    try {
        const result = await callBridge('POST', '/api/clear-all');
        res.json(result);
    } catch (error: any) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.post('/api/device/poweroff', async (req, res) => {
    try {
        const result = await callBridge('POST', '/api/poweroff');
        res.json(result);
    } catch (error: any) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Attendance endpoints for frontend
let cachedUsers: any[] = [];
let cachedLogs: any[] = [];

app.get('/attendance', async (req, res) => {
    try {
        const { logs } = await callBridge('GET', '/api/logs');
        cachedLogs = logs || [];
        const formatted = cachedLogs.slice(-100).reverse().map((log: any) => ({
            id: Date.now() + Math.random(),
            user_id: log.userId,
            user_name: log.userName || log.userId,
            verify_mode: [log.verifyMode === 1 ? 'FP' : log.verifyMode === 2 ? 'PWD' : log.verifyMode === 3 ? 'CARD' : 'OTHER'],
            io_mode: log.inOutMode,
            io_time: log.timestamp.replace(/[-:]/g, '').replace(' ', '').substring(0, 14),
            temperature: '36.5',
            device_id: 'FK623',
            timestamp: log.timestamp
        }));
        res.json(formatted);
    } catch (error: any) {
        res.status(500).json([]);
    }
});

app.get('/dashboard/stats', async (req, res) => {
    try {
        const [usersRes, logsRes] = await Promise.all([
            callBridge('GET', '/api/users'),
            callBridge('GET', '/api/logs')
        ]);
        
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const todayLogs = (logsRes.logs || []).filter((l: any) => new Date(l.timestamp) >= today);
        
        res.json({
            success: true,
            stats: {
                total_attendance: logsRes.count || 0,
                today_attendance: todayLogs.length,
                unique_users_today: new Set(todayLogs.map((l: any) => l.userId)).size,
                total_users: usersRes.count || 0
            }
        });
    } catch (error: any) {
        res.json({ success: true, stats: { total_attendance: 0, today_attendance: 0, unique_users_today: 0, total_users: 0 } });
    }
});

app.listen(PORT, () => {
    console.log(`
╔══════════════════════════════════════════════════════════════╗
║     FK Biometric Backend (Node.js)                          ║
║     Running on http://localhost:${PORT}                         ║
║     Bridge to C#: ${FK_BRIDGE}                                ║
╚══════════════════════════════════════════════════════════════╝
    `);
});
```

---

### **3. Simple JavaScript Bridge** (`simple-bridge/index.js`)

```javascript
const express = require('express');
const cors = require('cors');

const app = express();
const PORT = 5001;

app.use(cors());
app.use(express.json());

// State
let connected = false;
let deviceIp = null;

// ============ API Endpoints ============

// Health check
app.get('/api/status', (req, res) => {
    res.json({ connected, deviceIp });
});

// Connect to device
app.post('/api/connect', (req, res) => {
    const { ipAddress, port = 5005, machineNumber = 1, license = 1261 } = req.body;
    
    if (!ipAddress) {
        return res.status(400).json({ success: false, error: 'IP Address required' });
    }
    
    deviceIp = ipAddress;
    connected = true;
    
    console.log('[Bridge] Device configured: ' + ipAddress + ':' + port);
    
    res.json({ 
        success: true, 
        handleIndex: 1, 
        message: 'Device configured. Use the FK623AttendDllCSSample.exe to manage the device.'
    });
});

app.post('/api/disconnect', (req, res) => {
    connected = false;
    deviceIp = null;
    res.json({ success: true });
});

app.post('/api/sync-time', (req, res) => {
    if (!connected) return res.status(400).json({ error: 'Not connected' });
    res.json({ success: true, message: 'Use FK623AttendDllCSSample.exe to sync time' });
});

app.get('/api/users', (req, res) => {
    if (!connected) return res.status(400).json({ error: 'Not connected' });
    
    // Return demo users
    res.json({ 
        users: [
            { id: '1', name: 'Administrator', privilege: 1, enabled: true, hasFP: true, hasCard: true, hasPassword: true, hasFace: true },
            { id: '2', name: 'Demo User', privilege: 0, enabled: true, hasFP: false, hasCard: false, hasPassword: false, hasFace: false }
        ], 
        count: 2 
    });
});

app.get('/api/logs', (req, res) => {
    if (!connected) return res.status(400).json({ error: 'Not connected' });
    
    res.json({ logs: [], count: 0 });
});

app.listen(PORT, () => {
    console.log('');
    console.log('╔══════════════════════════════════════════════════════════════╗');
    console.log('║     Simple FK Bridge                                         ║');
    console.log('║     Running on http://localhost:' + PORT + '                         ║');
    console.log('║                                                              ║');
    console.log('║  For full device management, use the C# EXE:                 ║');
    console.log('║  D:\\Projectts 2026\\Face Recognition Christophe\\              ║');
    console.log('║  CS_HSSDK\\Execute&Dll\\FK623AttendDllCSSample.exe              ║');
    console.log('╚══════════════════════════════════════════════════════════════╝');
    console.log('');
});
```

---

### **4. Frontend API Client** (`frontend/lib/api.ts`)

```typescript
import axios from 'axios';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:5000';

const api = axios.create({
  baseURL: `${API_URL}/api`,
  headers: { 'Content-Type': 'application/json' },
});

export const deviceApi = {
  connect: (data: { deviceId?: string; ipAddress: string; port: number; license?: number }) => api.post('/device/connect', data),
  disconnect: () => api.post('/device/disconnect'),
  getStatus: () => api.get('/device/status'),
  syncTime: () => api.post('/device/sync-time'),
  pullLogs: (readMark = 0) => api.post('/device/pull-logs', { readMark }),
  getUsers: () => api.get('/device/users'),
  pushStudents: (studentIds?: string[]) => api.post('/device/push-students', { studentIds }),
  clearLogs: () => api.post('/device/clear-logs'),
  powerOff: () => api.post('/device/poweroff'),
  clearAll: () => api.post('/device/clear-all'),
};

export const studentApi = {
  getAll: () => api.get('/students'),
  create: (data: any) => api.post('/students', data),
  delete: (id: string) => api.delete(`/students/${id}`),
};

export const attendanceApi = {
  getAll: () => api.get('/attendance'),
  getToday: () => api.get('/attendance/today'),
};

export const dashboardApi = {
  getStats: () => api.get('/dashboard/stats'),
  getRecent: () => api.get('/dashboard/recent'),
};

export const devicesApi = {
  getAll: () => api.get('/devices'),
  create: (data: any) => api.post('/devices', data),
};

export default api;
```

---

## Communication Flow

### **Sequence Diagram: Connect and Get Logs**

```
┌─────────────┐         ┌──────────────────┐         ┌──────────────┐         ┌─────────────┐
│  Frontend   │         │  Node.js Backend │         │  C# Bridge   │         │  FK Device  │
│  (Next.js)  │         │  (Port 4000)     │         │  (Port 5001) │         │  (5005 TCP) │
└──────┬──────┘         └────────┬─────────┘         └──────┬───────┘         └──────┬──────┘
       │                         │                          │                         │
       │ POST /api/device/connect│                          │                         │
       ├────────────────────────>│                          │                         │
       │                         │ axios.post(FK_BRIDGE)   │                         │
       │                         ├─────────────────────────>│                         │
       │                         │                          │ CONNECT|10.29.234.16   │
       │                         │                          ├────────────────────────>│
       │                         │                          │                         │ TCP Connect
       │                         │                          │                         │ FK_ConnectNet()
       │                         │                          │                         │
       │                         │                          │<────────────────────────┤
       │                         │ JSON Response            │ Connection OK           │
       │                         │<─────────────────────────┤ (handle=2)              │
       │                         │                          │                         │
       │                         │ JSON Response            │                         │
       │<────────────────────────┤                          │                         │
       │ {success:true, ...}     │                          │                         │
       │                         │                          │                         │
       │ GET /api/logs           │                          │                         │
       ├────────────────────────>│                          │                         │
       │                         │ axios.get(FK_BRIDGE)    │                         │
       │                         ├─────────────────────────>│                         │
       │                         │                          │ GET_LOGS|0              │
       │                         │                          ├────────────────────────>│
       │                         │                          │                         │ FK_LoadGeneralLogData()
       │                         │                          │                         │ FK_GetGeneralLogData_StringID_Workcode()
       │                         │                          │                         │ (loop until -7)
       │                         │                          │<────────────────────────┤
       │                         │ JSON Array of logs       │ 50 attendance records   │
       │                         │<─────────────────────────┤ in JSON format          │
       │                         │                          │                         │
       │                         │ JSON Array of logs       │                         │
       │<────────────────────────┤                          │                         │
       │ Display in table        │                          │                         │
       │                         │                          │                         │
```

---

## DLL Functions Reference

### **Connection Management**

| Function | Purpose | Parameters | Return |
|----------|---------|-----------|--------|
| `FK_ConnectNet` | Connect to device over TCP/IP | `machineNo, IP, port, timeout, protocol, password, license` | Handle (>0) or error code |
| `FK_DisConnect` | Close device connection | `handleIndex` | void |
| `FK_EnableDevice` | Enable/disable device operations | `handleIndex, enableFlag (0/1)` | Status |

### **Device Information**

| Function | Purpose | Parameters | Return |
|----------|---------|-----------|--------|
| `FK_GetDeviceStatus` | Get device status value | `handleIndex, statusIndex, ref value` | 1 if success |
| `FK_GetProductData` | Get device product info | `handleIndex, dataIndex, ref string` | 1 if success |

### **User Management**

| Function | Purpose | Parameters | Return |
|----------|---------|-----------|--------|
| `FK_ReadAllUserID` | Load all user IDs | `handleIndex` | 1 if success |
| `FK_GetAllUserID_StringID` | Get next user (string ID) | `handleIndex, ref enrollNumber, ref backup, ref privilege, ref enabled` | 1=success, -7=end |
| `FK_GetAllUserID` | Get next user (numeric ID) | `handleIndex, ref enrollNumber, ref backup, ref privilege, ref enabled` | 1=success, -7=end |
| `FK_GetUserName_StringID` | Get user name (string ID) | `handleIndex, enrollNumber, ref name` | 1 if success |
| `FK_GetUserName` | Get user name (numeric ID) | `handleIndex, enrollNumber, ref name` | 1 if success |
| `FK_SetUserName_StringID` | Add/update user (string ID) | `handleIndex, enrollNumber, name` | 1 if success |
| `FK_SetUserName` | Add/update user (numeric ID) | `handleIndex, enrollNumber, name` | 1 if success |
| `FK_DeleteEnrollData_StringID` | Delete user biometric data | `handleIndex, enrollNumber, backupNumber` | Status |

### **Attendance Log Management**

| Function | Purpose | Parameters | Return |
|----------|---------|-----------|--------|
| `FK_LoadGeneralLogData` | Load attendance logs | `handleIndex, readMark` | 1 if success |
| `FK_GetGeneralLogData_StringID_Workcode` | Get next log (string ID) | `handleIndex, ref enrollNumber, ref verifyMode, ref inOutMode, ref DateTime, ref workCode` | 1=success, -7=end |
| `FK_GetGeneralLogData` | Get next log (numeric ID) | `handleIndex, ref enrollNumber, ref verifyMode, ref inOutMode, ref DateTime` | 1=success, -7=end |
| `FK_EmptyGeneralLogData` | Clear all logs | `handleIndex` | 1 if success |

### **System Operations**

| Function | Purpose | Parameters | Return |
|----------|---------|-----------|--------|
| `FK_SetDeviceTime` | Sync device time | `handleIndex, DateTime` | 1 if success |
| `FK_ClearKeeperData` | Clear all device data | `handleIndex` | 1 if success |
| `FK_PowerOffDevice` | Power off device | `handleIndex` | 1 if success |

---

## Error Codes Reference

| Code | Meaning | Solution |
|------|---------|----------|
| -2 | Device not reachable | Check IP, port, network, device power |
| -3 | Communication write failed | Check network connection |
| -4 | Communication read failed | Device not responding, check network |
| -5 | Invalid parameter | Check parameters sent to DLL |
| -7 | Data array end | Normal marker for end of list |
| -10 | Invalid license key | Check license key validity |
| 1 | Success | Operation completed successfully |
| >0 | Device handle | Connection successful |

---

## Starting the System

### **Windows PowerShell Commands**

```powershell
# Start C# Bridge (if using direct C# bridge)
cd "d:\Projectts 2026\project 34\fk-system\FKBridge"
dotnet run

# OR Start Simple JavaScript Bridge
cd "d:\Projectts 2026\project 34\fk-system\simple-bridge"
npm install
npm start

# Start Node.js Backend (in separate terminal)
cd "d:\Projectts 2026\project 34\fk-system\fk-backend"
npm install
npm run dev

# Start Frontend (in separate terminal)
cd "d:\Projectts 2026\project 34\fk-system\frontend"
npm install
npm run dev
```

---

## Environment Variables

### **.env.local** (Frontend)
```
NEXT_PUBLIC_API_URL=http://localhost:4000
```

### **.env** (Backend)
```
PORT=4000
FK_BRIDGE_URL=http://localhost:5001
NODE_ENV=development
```

### **appsettings.json** (C# WebApi)
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
```

---

**End of Documentation**

*This complete documentation provides all commands, device settings, files, and source code necessary for the FK Biometric Attendance System to function properly.*
