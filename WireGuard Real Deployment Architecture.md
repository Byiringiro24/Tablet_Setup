# WireGuard real deployment architecture for EcaAfrica

This project is not a browser-only WireGuard implementation.

Reason:
- The browser cannot safely execute system-level commands such as `wg`, `wg-quick`, `ping`, or `ssh` on the host machine.
- To make the VPN setup real, the frontend must call server-side APIs, and the backend must run the privileged commands on the Linux server.
- The frontend should never store or type a server SSH password in the browser. That would expose the server credentials to the browser and create a security risk.

## Real architecture

1. Super Admin in browser opens the UI.
2. Frontend calls backend endpoints such as:
   - `/platform/hardware/vpn/status`
   - `/platform/hardware/vpn/peers`
   - `/platform/hardware/vpn/fix-peer`
   - `/platform/hardware/vpn/ping`
3. Backend runs the privileged code on the Linux server.
4. The backend updates the real WireGuard config, adds/removes peers, and checks connectivity.

This is the actual implementation in the repo:
- Frontend API calls: [Ecareafrica_frontend/src/routes/super-admin.hardware.tsx](Ecareafrica_frontend/src/routes/super-admin.hardware.tsx)
- Backend WireGuard commands: [Ecareafrica_backend/src/services/wireguard.service.ts](Ecareafrica_backend/src/services/wireguard.service.ts)
- Backend endpoints: [Ecareafrica_backend/src/controllers/platform/wireguard.controller.ts](Ecareafrica_backend/src/controllers/platform/wireguard.controller.ts)

## Required server-side setup

Run the following commands on the Linux server that hosts the backend and WireGuard:

```bash
sudo apt update
sudo apt install -y wireguard qrencode iproute2
sudo mkdir -p /etc/wireguard
sudo chmod 700 /etc/wireguard
```

Generate server keys:

```bash
sudo bash -c 'wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key'
sudo chmod 600 /etc/wireguard/server_private.key
sudo chmod 644 /etc/wireguard/server_public.key
```

Create the server config:

```bash
sudo cat > /etc/wireguard/wg0.conf <<'EOF'
[Interface]
Address = 10.0.0.1/16
PrivateKey = $(sudo cat /etc/wireguard/server_private.key)
ListenPort = 51820
SaveConfig = true

# peers added dynamically later
EOF
```

Start the interface:

```bash
sudo wg-quick up /etc/wireguard/wg0.conf
sudo wg show wg0
```

Allow firewall traffic:

```bash
sudo ufw allow 51820/udp
sudo ufw status
```

Set the backend environment for the app:

```bash
export WG_CONF_PATH=/etc/wireguard/wg0.conf
export WG_PUBKEY_PATH=/etc/wireguard/server_public.key
export WG_INTERFACE=wg0
export WG_PORT=51820
export SERVER_PUBLIC_IP=169.58.124.150
export SERVER_VPN_IP=10.0.0.1
export VPN_SUBNET=10.0
export VPN_CIDR=16
```

Start the backend service:

```bash
cd /path/to/Ecareafrica_backend
npm install
npm run build
npm run start
```

## Frontend flow (real solution)

The frontend should only do this:
- collect the tablet public key
- choose an assigned VPN IP
- call backend endpoint to add the peer
- display the server public key and endpoint values
- call ping endpoint to confirm reachability

This is already implemented in the Super Admin UI at [Ecareafrica_frontend/src/routes/super-admin.hardware.tsx](Ecareafrica_frontend/src/routes/super-admin.hardware.tsx).

## What is not allowed

The browser must not do any of the following directly:
- `ssh user@server`
- `sudo wg set ...`
- `sudo wg-quick up ...`
- `sudo ufw allow ...`
- storing the server SSH password in frontend code or localStorage

That would be unsafe and would not work reliably in a browser sandbox.

## Recommended production pattern

Use a backend service running on the same Linux server with a platform-admin JWT. The browser sends authenticated requests. The backend owns the WireGuard state. This is the secure and real solution.

If you require a 100% browser-based demo for presentation purposes only, you can create a mock mode, but it must be clearly labeled as a simulation and must not be used in production or to configure real WireGuard peers.
