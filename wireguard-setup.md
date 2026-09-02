# WireGuard VPN Setup Documentation

**Project**: FK Biometric Attendance System  
**Date**: August 7, 2026  
**Prepared by**: System Administrator  
**Witnessed and Verified by**: ___________________________

---

## Overview

This document describes the WireGuard VPN tunnel configuration connecting the local Windows client machine to the new remote server at `169.58.124.150`. The tunnel securely routes traffic between the attendance system backend and the remote server over an encrypted peer-to-peer connection.

---

## Current Tunnel Configuration (Client Side — Windows)

Captured from WireGuard Windows client on August 7, 2026:

| Field | Value |
|-------|-------|
| Tunnel Name | `Wireguard_Tunnel` |
| Status | **Active** |
| Client Public Key | `ZUSo5dk87kr6PSSk9hBd3ZvQ5+PpHHMy7xaexwrKJko=` |
| Listen Port | `49667` |
| VPN Address | `10.0.0.2/24` |
| DNS Server | `1.1.1.1` |
| Peer Public Key | `5IpzSFa0lCjJjWZW+gAXEJfxxcwlkrJOpAoeafs9EWQ=` |
| Allowed IPs | `10.0.0.0/24` |
| Current Endpoint | `13.140.133.61:51820` *(old server — to be replaced)* |
| Persistent Keepalive | `25` seconds |

---

## Network Architecture After Migration

```
┌──────────────────────────────────────────────┐
│        Windows Client Machine (Local)        │
│   WireGuard Interface: Wireguard_Tunnel      │
│   VPN IP:  10.0.0.1/24                       │
│   Public Key: ZUSo5dk87...KJko=              │
│   Listen Port: 49667                         │
└──────────────────┬───────────────────────────┘
                   │ Encrypted WireGuard Tunnel
                   │ UDP / Port 51820
┌──────────────────▼───────────────────────────┐
│        New Remote Server                     │
│   Public IP:  169.58.124.150                 │
│   VPN IP:     10.0.0.1/24                    │
│   WireGuard Port: 51820                      │
│   OS: Linux (root access)                   │
└──────────────────────────────────────────────┘
```

---

## Step 1 — Set Up WireGuard on the New Server (169.58.124.150)

SSH into the new server and run the following commands as root:

```bash
ssh root@169.58.124.150
```

### 1.1 Install WireGuard

```bash
apt update && apt install -y wireguard
```

### 1.2 Generate Server Key Pair

```bash
cd /etc/wireguard
wg genkey | tee server_private.key | wg pubkey > server_public.key
chmod 600 server_private.key
cat server_private.key    # Save this — used in config below
cat server_public.key     # Share this with the Windows client
```

### 1.3 Create Server WireGuard Config

```bash
nano /etc/wireguard/wg0.conf
```

Paste the following (replace `<SERVER_PRIVATE_KEY>` with the key from step 1.2):

```ini
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = <SERVER_PRIVATE_KEY>

# Allow IP forwarding (optional, for routing internet traffic)
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Windows Client Peer
[Peer]
PublicKey = ZUSo5dk87kr6PSSk9hBd3ZvQ5+PpHHMy7xaexwrKJko=
AllowedIPs = 10.0.0.2/32
PersistentKeepalive = 25
```

> **Note**: Replace `eth0` with the actual network interface name. Run `ip route` to find it (look for the interface on the default route line).

### 1.4 Enable IP Forwarding

```bash
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p
```

### 1.5 Enable and Start WireGuard

```bash
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
systemctl status wg-quick@wg0
```

### 1.6 Open Firewall Port

```bash
ufw allow 51820/udp
ufw reload
```

---

## Step 2 — Update Windows Client Configuration

Open **WireGuard** on Windows → select `Wireguard_Tunnel` → click **Edit**.

Update the config to point to the new server. Replace the existing `[Peer]` block:

```ini
[Interface]
PrivateKey = <YOUR_EXISTING_PRIVATE_KEY>
Address = 10.0.0.2/24
DNS = 1.1.1.1
ListenPort = 49667

[Peer]
PublicKey = <SERVER_PUBLIC_KEY_FROM_STEP_1.2>
AllowedIPs = 10.0.0.0/24
Endpoint = 169.58.124.150:51820
PersistentKeepalive = 25
```

> **Important**: Your existing private key is stored in the WireGuard client — do not regenerate it unless necessary. Only update the `[Peer]` section with the new server's public key and endpoint.

Click **Save**, then click **Activate**.

---

## Step 3 — Verify the Tunnel

### On Windows Client

Open WireGuard and confirm:
- Status shows **Active**
- Endpoint shows `169.58.124.150:51820`
- **Latest handshake** appears within a few seconds
- **Transfer** shows bytes sent/received

Then test connectivity:

```cmd
ping 10.0.0.1
```

Expected: replies from `10.0.0.1` (the server's VPN IP).

### On the Server

```bash
wg show
```

Expected output:

```
interface: wg0
  public key: <server public key>
  private key: (hidden)
  listening port: 51820

peer: ZUSo5dk87kr6PSSk9hBd3ZvQ5+PpHHMy7xaexwrKJko=
  endpoint: <your_public_ip>:49667
  allowed ips: 10.0.0.2/32
  latest handshake: X seconds ago
  transfer: X KiB received, X KiB sent
```

---

## Step 4 — Update Backend Device Configuration (If Required)

If the backend server now runs on the new VPN server, update the device config to use the VPN IP:

**File**: `backend/data/device-config.json`

```json
{
  "ipAddress": "10.0.0.1",
  "port": 5005,
  "license": 1261,
  "deviceId": "DV-KGL-01",
  "netPassword": 0,
  "protocolType": -1,
  "timeoutMs": 10000
}
```

> Only change `ipAddress` if the FK623 biometric device is accessed through the VPN tunnel. If the device is on the local LAN, keep `192.168.1.118`.

---

## Troubleshooting

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| No handshake after activation | Wrong server public key or endpoint | Double-check public key and IP `169.58.124.150:51820` |
| Tunnel active but no ping | Firewall blocking UDP 51820 | Run `ufw allow 51820/udp` on server |
| `wg show` shows no peer | Server config not saved correctly | Re-check `/etc/wireguard/wg0.conf` and restart `wg-quick@wg0` |
| DNS not resolving through VPN | DNS setting not applied | Verify `DNS = 1.1.1.1` is in the `[Interface]` block on Windows |
| Server restarts and tunnel drops | wg-quick not enabled as service | Run `systemctl enable wg-quick@wg0` |

---

## Key Reference Table

| Role | Public Key | VPN IP | Endpoint |
|------|-----------|--------|----------|
| Windows Client | `ZUSo5dk87kr6PSSk9hBd3ZvQ5+PpHHMy7xaexwrKJko=` | `10.0.0.2` | Dynamic (behind NAT) |
| New Server | *(generated in Step 1.2)* | `10.0.0.1` | `169.58.124.150:51820` |

---

## Witness & Sign-Off

This document was prepared and the configuration was applied on the date stated above.

| Role | Name | Signature | Date |
|------|------|-----------|------|
| System Administrator | | | |
| Technical Witness | | | |
| Authorized Approver | | | |

---

## Revision History

| Version | Date | Author | Notes |
|---------|------|--------|-------|
| 1.0 | August 7, 2026 | System Administrator | Initial setup — migrating from `13.140.133.61` to `169.58.124.150` |

---

*End of WireGuard Setup Documentation*
