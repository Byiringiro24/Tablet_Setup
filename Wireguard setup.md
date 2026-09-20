# WireGuard VPN Setup Guide for FK Biometric System

**Version:** 1.0  
**Date:** August 2026  
**Author:** System Administrator  

---

## Overview

This document describes the step-by-step process to set up a **WireGuard VPN** tunnel between a remote Windows tablet (running the FK623 bridge application) and a Linux server (hosting the EcareAfrica backend). The VPN enables the backend to securely communicate with the tablet over the internet, allowing automatic attendance log pulls from the FK623 biometric device.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     SCHOOL NETWORK                              │
│  ┌──────────────┐          ┌──────────────┐                   │
│  │ FK623 Device │          │   Windows    │                   │
│  │ 192.168.1.118│◄─────────│   Tablet     │                   │
│  │   Port 4370  │   LAN    │ (Bridge App) │                   │
│  └──────────────┘          │ 10.0.0.2/24  │                   │
│                            └──────┬───────┘                   │
└───────────────────────────────────┼────────────────────────────┘
                                    │ WireGuard VPN (UDP 51820)
                                    │ Public IP: 169.58.124.150
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                       CLOUD SERVER                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │   WireGuard Server (10.0.0.1/24)                        │  │
│  │   Backend (Node.js) on port 5500                        │  │
│  │   PostgreSQL database                                    │  │
│  │   PM2 process manager                                    │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

- **WireGuard Server:** Ubuntu 22.04/24.04 (or Debian) at `169.58.124.150`
- **WireGuard Client:** Windows tablet with the bridge application on port `5000`
- **VPN Network:** `10.0.0.0/24` – Server gets `10.0.0.1`, each tablet gets a unique IP (e.g., `10.0.0.2`, `10.0.0.3`, ...)

---

## Prerequisites

### Server Side
- Linux server with root or sudo access
- Public IP (static or DDNS)
- UDP port 51820 open in firewall
- WireGuard installed

### Tablet Side
- Windows PC/tablet with administrative privileges
- WireGuard for Windows installed
- FK623 bridge application running and listening on port 5000

---

## Part 1: Server Setup (Linux)

### 1.1 Install WireGuard

```bash
sudo apt update
sudo apt install wireguard -y
```

### 1.2 Generate Server Keys

```bash
cd /etc/wireguard
umask 077
wg genkey | tee privatekey | wg pubkey > publickey
```

- `privatekey`: Keep secret – this is the server's private key.
- `publickey`: This will be shared with tablets.

### 1.3 Create WireGuard Configuration

Create `/etc/wireguard/wg0.conf`:

```bash
nano /etc/wireguard/wg0.conf
```

Paste the following template (replace `<SERVER_PRIVATE_KEY>` with actual content of `privatekey`):

```ini
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = <SERVER_PRIVATE_KEY>

# Enable IP forwarding and NAT (optional, for internet access from tablet)
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
```

**Note:** `eth0` is your primary network interface; if different (e.g., `ens3`), adjust accordingly.

### 1.4 Add a Peer for Each Tablet

For each tablet, you'll need its **public key**. Once you have it, add a `[Peer]` section:

```ini
[Peer]
PublicKey = <TABLET_PUBLIC_KEY>
AllowedIPs = 10.0.0.2/32
```

Repeat for additional tablets with different IPs (`10.0.0.3/32`, etc.).

### 1.5 Enable IP Forwarding

```bash
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
```

### 1.6 Start and Enable WireGuard

```bash
# Start the interface
wg-quick up wg0

# Enable service to start on boot
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
```

**Troubleshooting:** If `wg-quick up wg0` fails, check the configuration syntax. Use `journalctl -xe -u wg-quick@wg0` for details.

### 1.7 Verify Server Status

```bash
wg show
```

Expected output:
```
interface: wg0
  public key: 6b8yTx1nz243Z044DZTt/OP5+gdLj9lVmUr5DteDzko=
  private key: (hidden)
  listening port: 51820

peer: dlSJrCfnubyRBzDrKyZ9MauqaXHUsTV8ObVyaKia61o=
  allowed ips: 10.0.0.2/32
```

### 1.8 Firewall Configuration

Ensure UDP port 51820 is open:

```bash
# If using UFW
ufw allow 51820/udp

# If using iptables directly
iptables -A INPUT -p udp --dport 51820 -j ACCEPT
```

---

## Part 2: Windows Tablet Setup

### 2.1 Install WireGuard for Windows

1. Download from [https://www.wireguard.com/install/](https://www.wireguard.com/install/)
2. Run the installer (admin privileges required).
3. After installation, you'll have the WireGuard GUI and `wg.exe` command-line tool.

### 2.2 Generate Tablet Keys

Open **PowerShell as Administrator** and run:

```powershell
# Navigate to the WireGuard directory (or any folder)
cd "C:\Program Files\WireGuard"

# Generate a new private key
wg.exe genkey > tablet_private.key

# Generate the corresponding public key
wg.exe pubkey < tablet_private.key > tablet_public.key

# Display both keys
type tablet_private.key
type tablet_public.key
```

Copy the **private key** and **public key** to a safe place.

### 2.3 Create a WireGuard Tunnel Configuration

Open the WireGuard GUI → **Add Tunnel** → **Add empty tunnel**.

Paste the following configuration (replace `<TABLET_PRIVATE_KEY>` and `<SERVER_PUBLIC_KEY>`):

```ini
[Interface]
PrivateKey = <TABLET_PRIVATE_KEY>
Address = 10.0.0.2/24
DNS = 1.1.1.1

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
AllowedIPs = 10.0.0.0/24
Endpoint = <SERVER_PUBLIC_IP>:51820
PersistentKeepalive = 25
```

- `AllowedIPs = 10.0.0.0/24` – Only routes VPN subnet through the tunnel. If you want all internet traffic through VPN, use `0.0.0.0/0` (not recommended unless required).
- `PersistentKeepalive = 25` – Sends keepalive packets every 25 seconds to maintain the connection (especially important behind NAT).

**Get Server Public Key:** On server, run `cat /etc/wireguard/publickey`.

### 2.4 Activate the Tunnel

In the WireGuard GUI:
1. Select the tunnel you just created.
2. Click **Activate**.

You should see the interface status as **Active**.

### 2.5 Verify Connectivity

Open a command prompt on the tablet and:

```cmd
ping 10.0.0.1
```

If replies are received, the VPN tunnel is established.

---

## Part 3: Connecting the Bridge Application

The Windows tablet runs the FK623 bridge application, typically on port `5000`.

### 3.1 Verify Bridge is Running

```cmd
netstat -ano | findstr :5000
```

You should see a listening process (e.g., `FKBridge.exe`).

### 3.2 Test Bridge Reachability from Server

From the server:

```bash
curl http://10.0.0.2:5000/api/health
```

Expected response:
```json
{"status":"ok","bridgeRunning":true,"bridgeReady":true,...}
```

If successful, the backend can now communicate with the bridge.

### 3.3 Connect Bridge to FK623 Device

The bridge must be able to reach the FK623 device on the school's local network. Confirm:

```cmd
ping 192.168.1.118
```

If not reachable, the device might be on a different subnet. Check with school IT.

**Update Bridge Saved Config:** You can send a POST request to the bridge:

```bash
curl -X POST http://10.0.0.2:5000/api/connect \
  -H "Content-Type: application/json" \
  -d '{"ipAddress":"192.168.1.118","port":4370,"license":1261}'
```

---

## Part 4: Backend Integration

### 4.1 Database Configuration

The backend's auto-pull job looks for tablets with a valid IP (`10.0.0.x`) and status `online`.

#### 4.1.1 Add Tablet to Database

```bash
sudo -u postgres psql ecareafrica -c "
INSERT INTO tablets (name, ip, port, status, school_id, is_active)
VALUES ('Main Gate Tablet (VPN)', '10.0.0.2', 5000, 'online', <school_id>, true);
"
```

Replace `<school_id>` with the actual school ID.

#### 4.1.2 Update Linked Devices (if any)

```bash
sudo -u postgres psql ecareafrica -c "
UPDATE devices SET tablet_ip = '10.0.0.2', tablet_port = 5000
WHERE tablet_id = <tablet_id>;
"
```

### 4.2 Environment Variables

Ensure the backend `.env` file has the correct settings (if needed):

```
DATABASE_URL="postgresql://postgres:2211@localhost:5432/ecareafrica?schema=public"
PORT=5500
# No specific WireGuard variables needed; auto-pull uses tablet IP from DB.
```

### 4.3 Restart Backend

```bash
pm2 restart ecare-backend
```

### 4.4 Monitor Auto-Pull Logs

```bash
pm2 logs ecare-backend --lines 50
```

You should see logs like:
```
[pull-logs] Tablet found: 10.0.0.2
[pull-logs] Pull complete { saved: 3, duplicates: 0, errors: 0 }
```

---

## Part 5: Adding More Tablets

To add another school's tablet:

1. **Server Side:** Add a new `[Peer]` section in `/etc/wireguard/wg0.conf` with a unique IP (e.g., `10.0.0.3/32`).
2. **Reload WireGuard:** `wg-quick down wg0; wg-quick up wg0` (or `wg set wg0 peer ... allowed-ips 10.0.0.3/32` without downtime).
3. **Tablet Side:** Generate keys, create a tunnel with `Address = 10.0.0.3/24`, same server public key and endpoint.
4. **Database:** Insert a new tablet record with `ip = '10.0.0.3'`.

---

## Troubleshooting Guide

| Problem | Solution |
|---------|----------|
| `wg-quick up wg0` fails with "Key is not the correct length" | Check for trailing spaces or invalid characters in `PrivateKey`. Use freshly generated keys. |
| Tablet not getting handshake (handshake = (none)) | Verify endpoint IP/port, firewall on server, and that server is reachable from tablet. |
| Ping to 10.0.0.2 fails | Check tablet's WireGuard is active. Verify `AllowedIPs` includes the VPN subnet. |
| curl to bridge returns "Connection refused" | Bridge not running on port 5000; start `FKBridge.exe`. |
| Bridge can't connect to FK623 | Device IP may have changed; confirm with school IT and update bridge config. |
| Auto-pull not saving logs | Check tablet entry in database, and that `status` is `online`. |

---

## Security Considerations

- **Private Keys:** Never share or expose them. Store securely.
- **AllowedIPs:** Limit to only necessary subnets (e.g., `10.0.0.0/24`) to reduce attack surface.
- **Firewall:** Only expose UDP port 51820; block other ports.
- **Update:** Keep WireGuard and system packages updated.

---

## Appendix: Example Configuration Files

### Server (`/etc/wireguard/wg0.conf`)

```ini
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = SF7lYJlP+wLAmTSfIsBlfjXXDM6531dqBysk9x97dFc=

PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = dlSJrCfnubyRBzDrKyZ9MauqaXHUsTV8ObVyaKia61o=
AllowedIPs = 10.0.0.2/32
```

### Tablet (`Wireguard_Tunnel` config)

```ini
[Interface]
PrivateKey = CIRzKz5VqlaagtMbBQogLI08rTxzXnUSpZREWn5LsE8=
Address = 10.0.0.2/24
DNS = 1.1.1.1

[Peer]
PublicKey = 6b8yTx1nz243Z044DZTt/OP5+gdLj9lVmUr5DteDzko=
AllowedIPs = 10.0.0.0/24
Endpoint = 169.58.124.150:51820
PersistentKeepalive = 25
```

---

## Final Verification Checklist

- [ ] Server WireGuard interface is up (`wg show`).
- [ ] Tablet WireGuard is active (handshake appears).
- [ ] `ping 10.0.0.2` succeeds from server.
- [ ] `curl http://10.0.0.2:5000/api/health` returns JSON.
- [ ] Tablet exists in `tablets` table with IP `10.0.0.2` and port `5000`.
- [ ] FK623 bridge can connect to the device (`api/connect` success).
- [ ] Auto-pull job runs without errors.
- [ ] Attendance logs appear in the frontend dashboard.

---

**Document End**