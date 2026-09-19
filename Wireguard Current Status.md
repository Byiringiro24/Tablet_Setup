# WireGuard VPN — Current Configuration Status

**Date:** August 7, 2026  
**System:** FK Biometric Attendance System (EcareAfrica)  
**Status:** ✅ VPN tunnel established and verified  

---

## 📌 Overview

A WireGuard VPN tunnel has been set up between the **EcareAfrica cloud server** and a **remote Windows tablet** running the FK623 bridge application. The tunnel allows the backend to securely pull attendance logs from the biometric device without exposing the school network.

---

## 🖥️ Server Configuration

### Server Details
- **Public IP:** `169.58.124.150`
- **VPN IP:** `10.0.0.1/24`
- **WireGuard Port:** `51820/udp`
- **Server Public Key:**  
  `6b8yTx1nz243Z044DZTt/OP5+gdLj9lVmUr5DteDzko=`
- **Server Private Key:**  
  (stored securely in `/etc/wireguard/privatekey`)

### Configuration File (`/etc/wireguard/wg0.conf`)
```ini
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = SF7lYJlP+wLAmTSfIsBlfjXXDM6531dqBysk9x97dFc=

[Peer]
PublicKey = dlSJrCfnubyRBzDrKyZ9MauqaXHUsTV8ObVyaKia61o=
AllowedIPs = 10.0.0.2/32
```
*(PostUp/PostDown rules for NAT are currently disabled; they can be added later if needed.)*

### Service Status
```bash
root@vmi3486264:/etc/wireguard# wg show
interface: wg0
  public key: 6b8yTx1nz243Z044DZTt/OP5+gdLj9lVmUr5DteDzko=
  private key: (hidden)
  listening port: 51820

peer: dlSJrCfnubyRBzDrKyZ9MauqaXHUsTV8ObVyaKia61o=
  endpoint: 41.186.132.1:44887
  allowed ips: 10.0.0.2/32
  latest handshake: 21 seconds ago
  transfer: 1.68 KiB received, 124 B sent
```
- **Handshake confirmed** – the peer is connected.
- **Service enabled** – `wg-quick@wg0` is configured to start on boot.

---

## 💻 Tablet Configuration (Windows)

### Tablet Details
- **VPN IP:** `10.0.0.2/24`
- **Bridge API Port:** `5000`
- **Tablet Public Key:**  
  `dlSJrCfnubyRBzDrKyZ9MauqaXHUsTV8ObVyaKia61o=`
- **Tablet Private Key:**  
  `CIRzKz5VqlaagtMbBQogLI08rTxzXnUSpZREWn5LsE8=`

### WireGuard Tunnel Configuration
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

### Bridge Application Status
- The FK623 bridge (`FKBridge.exe`) is running and listening on port `5000`.
- It is configured to connect to the FK623 device at `192.168.1.118:5005` (as retrieved from the `/api/health` response).

---

## ✅ Connectivity Verification

| Test | Command | Result |
|------|---------|--------|
| Ping tablet VPN IP | `ping 10.0.0.2` | ✅ 0% packet loss, avg ~218 ms |
| Bridge health check | `curl http://10.0.0.2:5000/api/health` | ✅ JSON response received |
| Handshake status | `wg show` on server | ✅ latest handshake: 21 seconds ago |

### Example `curl` Output
```json
{
  "status":"ok",
  "bridgeRunning":true,
  "bridgeReady":true,
  "device":null,
  "autoConnect":{
    "enabled":true,
    "attempt":296
  },
  "savedConfig":{
    "ipAddress":"192.168.1.118",
    "port":5005,
    "license":1261,
    "deviceId":"DV-KGL-01",
    "netPassword":0,
    "protocolType":-1,
    "timeoutMs":10000
  }
}
```

---

## 🔄 Next Steps

1. **Add tablet entry to PostgreSQL database** (if not already present):
   ```sql
   INSERT INTO tablets (name, ip, port, status, school_id, is_active)
   VALUES ('Main Gate Tablet (VPN)', '10.0.0.2', 5000, 'online', <school_id>, true);
   ```

2. **Update any linked devices** to use the new tablet IP:
   ```sql
   UPDATE devices SET tablet_ip = '10.0.0.2', tablet_port = 5000 WHERE tablet_id = <tablet_id>;
   ```

3. **Restart the backend** to enable auto-pull:
   ```bash
   pm2 restart ecare-backend
   ```

4. **Monitor auto-pull logs**:
   ```bash
   pm2 logs ecare-backend --lines 50
   ```

5. **If the bridge cannot connect to the FK623 device**, verify the device IP (`192.168.1.118`) is reachable from the tablet and adjust the bridge configuration via API:
   ```bash
   curl -X POST http://10.0.0.2:5000/api/connect \
     -H "Content-Type: application/json" \
     -d '{"ipAddress":"<correct_device_ip>","port":4370,"license":1261}'
   ```

---

## 📝 Notes

- The VPN is **operational** and the bridge is reachable.
- The backend’s auto-pull mechanism should now automatically fetch logs every 10 seconds, provided the tablet entry in the database is correct and the bridge can talk to the FK623 device.
- No additional firewall rules are required beyond UDP port `51820` already open on the server.

---

**Document prepared by:** System Administrator  
**Last updated:** August 7, 2026