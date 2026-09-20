# 📡 WireGuard VPN Setup Guide – Web-Based Management

## ✅ Zero Command Line – Fully Managed via Web Dashboard

This guide walks you through setting up a secure WireGuard VPN between your cloud server and any number of school tablets using our **Web Management Interface**. No command-line expertise required – everything is done through a simple dashboard.

---

## 📌 Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Part 1 – Server VPN Setup (One-Time)](#part-1--server-vpn-setup-one-time)
4. [Part 2 – Adding a New Tablet (Unlimited)](#part-2--adding-a-new-tablet-unlimited)
5. [Part 3 – Tablet Installation & Connection](#part-3--tablet-installation--connection)
6. [Part 4 – Monitoring & Managing Devices](#part-4--monitoring--managing-devices)
7. [FAQ & Troubleshooting](#faq--troubleshooting)

---

## Overview

Our Web-Based VPN Management System allows you to:

- **Set up the VPN server** in minutes using a web interface.
- **Add as many tablets** as you need with one click – each gets a unique IP address automatically.
- **Download ready-to-use config files** for each tablet.
- **Monitor connection status** in real-time.
- **Remove or update tablets** without server restarts.

No SSH, no terminal, no manual key generation – all done through a friendly dashboard.

---

## Prerequisites

### Server Side
- A Linux server (Ubuntu 22.04 or 24.04) with root/sudo access.
- A public IP address (or a DDNS domain).
- The backend application already installed (EcareAfrica or similar).
- Web dashboard accessible via browser.

### Tablet Side
- Any Windows PC/tablet with administrator rights.
- Internet connection (to reach the server).
- WireGuard for Windows installed (we’ll guide you).

---

## Part 1 – Server VPN Setup (One-Time)

> ⚙️ This step is performed **once** by the system administrator.

### Step 1.1 – Access the VPN Management Dashboard

1. Open your browser and go to:  
   `https://your-server-domain.com/vpn`  
   (or `http://server-ip:5500/vpn` if running locally)

2. Log in with your admin credentials.

3. You will see the **VPN Management** page with three tabs:  
   **Server** | **Tablets** | **Monitor**

---

### Step 1.2 – Configure the Server

1. Click on the **Server** tab.

2. You’ll see the current status (stopped).  
   Click the **"Start VPN"** button – the system will automatically:
   - Generate a new private/public key pair for the server.
   - Create the WireGuard configuration.
   - Enable IP forwarding.
   - Start the service.

3. After a few seconds, the status changes to **Running**.

4. The **Server Public Key** is displayed – this will be used by tablets, but you don’t need to copy it manually; the system embeds it automatically in the tablet configs.

5. (Optional) You can adjust the **Listen Port** (default `51820`) and the **VPN IP Range** (default `10.0.0.0/24`).

> ✅ The server is now ready to accept tablet connections.

---

### Step 1.3 – Verify Server Status

The dashboard shows:
- **Service Status** (Running / Stopped)
- **VPN IP** (e.g., `10.0.0.1`)
- **Listening Port**
- **Connected Peers** count
- **List of currently connected tablets** (will populate after tablets connect)

You can also view live logs by switching to the **Monitor** tab.

---

## Part 2 – Adding a New Tablet (Unlimited)

> 📱 This is where you add a new school tablet to the VPN network. The process is identical for the first tablet, the hundredth tablet, etc.

### Step 2.1 – Open the Tablets Tab

1. In the VPN Management dashboard, click **Tablets**.

2. You’ll see a list of all registered tablets (if any) and a big **"Add Tablet"** button.

### Step 2.2 – Fill in Tablet Details

Click **"Add Tablet"**, and a modal form appears:

| Field | Description | Example |
|-------|-------------|---------|
| **Tablet Name** | A friendly name (e.g., school name + location) | "Kigali Main Gate" |
| **School ID** | The school’s database ID (if applicable) | 42 |
| **Tablet Type** | Usually "Windows" | Windows |
| **Location** | Optional location description | Main Entrance |

Click **Add**.

### Step 2.3 – Automatic Configuration

The system automatically:

1. **Finds the next available IP** in the `10.0.0.x` range (starting from `10.0.0.2`).
2. **Generates a unique key pair** for that tablet.
3. **Adds the tablet as a peer** to the server’s WireGuard configuration – without restarting the service.
4. **Saves the tablet details** in the database.
5. **Generates a complete configuration file** (`.conf`) ready for download.

### Step 2.4 – Download the Tablet Package

After successful creation, you are presented with:

- **Config File** (`.conf`) – click to download immediately.
- **PowerShell Setup Script** (`.ps1`) – this is a one‑click script that automates the setup on the tablet (recommended).

> 💡 *You can download these later from the Tablets list using the download icons.*

---

## Part 3 – Tablet Installation & Connection

> 👨‍💻 This part is performed on the actual Windows tablet/PC.

### Step 3.1 – Install WireGuard (first time only)

1. On the tablet, open a browser and go to:  
   https://www.wireguard.com/install/  
2. Download the **Windows Installer** and run it.  
3. Accept the defaults (requires administrator rights).

### Step 3.2 – Run the Auto Setup Script (Recommended)

1. Transfer the downloaded **PowerShell setup script** (`setup-<tablet-name>.ps1`) to the tablet (e.g., via USB, email, or download from the dashboard if accessible).
2. Right-click the script and select **"Run with PowerShell"**.
3. The script will:
   - Create the WireGuard configuration file on the desktop.
   - Open the WireGuard app (if installed).
   - Guide you through the final activation steps.

4. Once the WireGuard app opens:
   - Click **"Add Tunnel"** → **"Import from file"**.
   - Select the config file from the desktop (`wireguard-<tablet-name>.conf`).
   - Click **"Activate"**.

### Step 3.3 – Verify the Connection

- In the WireGuard app, the tunnel should show **"Active"**.
- Open a command prompt and type:  
  `ping 10.0.0.1`  
  You should receive replies from the server VPN IP.

- The server dashboard will now show this tablet as **Online** under the Tablets tab.

> ✅ The tablet is now part of the secure VPN network and the backend can communicate with it.

---

## Part 4 – Monitoring & Managing Devices

### 4.1 – Live Status Dashboard

- The **Server** tab shows total connected peers and a list with handshake times and transfer statistics.
- The **Tablets** tab lists all registered tablets with:
  - **Name**
  - **VPN IP**
  - **Status** (Active/Offline/Deleted)
  - **Connection** (Online/Offline)
  - **Last Handshake**

### 4.2 – Adding More Tablets

Repeat **Part 2** for each additional tablet – the process is exactly the same. Each gets a unique IP automatically. There is no limit (up to 253 per /24 subnet, or more with a larger subnet).

### 4.3 – Removing a Tablet

1. In the Tablets tab, find the tablet you want to remove.
2. Click the **trash can icon**.
3. Confirm – the system will:
   - Remove the peer from the server (immediate disconnection).
   - Delete the entry from the database.
   - Free up the IP address for future use.

### 4.4 – Monitoring Logs

Switch to the **Monitor** tab to view real‑time WireGuard service logs. This helps troubleshoot connectivity issues.

---

## FAQ & Troubleshooting

### Q1: The tablet cannot ping `10.0.0.1`.
- Ensure the tunnel is **Active** in the WireGuard app.
- Check that the server’s WireGuard service is running (server tab shows “Running”).
- Verify that the server firewall allows UDP port `51820`.

### Q2: The tablet shows “Offline” in the dashboard.
- Wait a few seconds for the handshake to complete.
- Check the tablet’s internet connection – it must reach the server’s public IP.
- Confirm that the **Public Key** on the tablet matches the one stored in the server’s database (auto-generated, so usually fine).

### Q3: Can I change a tablet’s IP?
- Yes, but it’s easier to remove and re‑add the tablet. The system will assign a new IP.

### Q4: What if I exceed the 253 IP limit?
- We can extend the subnet to `/16` (supporting 65,535 devices) – contact the admin to adjust the server configuration via the dashboard settings (advanced).

### Q5: Is the setup script safe?
- Yes, it only creates the config file and opens the WireGuard app. No passwords or sensitive data are sent elsewhere.

---

## 📝 Summary

With our **Web-Based VPN Management System**, you can:

- Set up the VPN server **once** via the web.
- Add **unlimited tablets** with a few clicks.
- Download ready‑to‑use config files or auto‑setup scripts.
- Monitor all connections in real time.
- Remove or update devices without touching the server.

**No command line, no SSH – just a modern web dashboard!**

---

**Need help?** Contact your system administrator or open a support ticket through the dashboard.

---

*Document version 1.0 – August 2026*