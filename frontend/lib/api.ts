import axios from 'axios';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:5000';

const api = axios.create({
  baseURL: `${API_URL}/api`,
  headers: { 'Content-Type': 'application/json' },
});

export const deviceApi = {
  connect: (data: { deviceId?: string; ipAddress: string; port: number; license?: number; [key: string]: any }) => api.post('/device/connect', data),
  connectSaved: () => api.post('/device/connect-saved'),
  disconnect: () => api.post('/device/disconnect'),
  reconnect: () => api.post('/device/reconnect'),
  getStatus: () => api.get('/device/status'),
  syncTime: () => api.post('/device/sync-time'),
  setTime: (timestamp: string) => api.post('/device/set-time', { timestamp }),
  pullLogs: (readMark = 0) => api.post('/device/pull-logs', { readMark }),
  pullUsers: () => api.get('/device/users'),
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
  getSettings: () => api.get('/attendance/settings'),
  updateSettings: (settings: any) => api.put('/attendance/settings', settings),
};

export const dashboardApi = {
  getStats: () => api.get('/dashboard/stats'),
  getRecent: () => api.get('/dashboard/recent'),
};

export const devicesApi = {
  getAll: () => api.get('/devices'),
  create: (data: any) => api.post('/devices', data),
};

export const wireguardApi = {
  /** Check if WireGuard is installed and whether the tunnel is active */
  getStatus: () => api.get('/wireguard/status'),
  /** Generate a new key pair on the tablet — returns { privateKey, publicKey } */
  generateKeys: () => api.post('/wireguard/generate-keys'),
  /** Write config + activate tunnel — requires server info pasted by admin */
  install: (data: {
    serverPublicKey: string;
    serverEndpoint: string;   // e.g. "169.58.124.150:51820"
    vpnIp: string;            // e.g. "10.0.0.2"
    dns?: string;
  }) => api.post('/wireguard/install', data),
  /** Stop and remove the tunnel service */
  deactivate: () => api.post('/wireguard/deactivate'),
  /** Install bridge + frontend as Windows auto-start services (run as SYSTEM) */
  installServices: () => api.post('/services/install'),
  /** Check if services are installed and running */
  getServicesStatus: () => api.get('/services/status'),
  /** Diagnose VPN connection — detects key mismatch, handshake issues */
  diagnose: () => api.post('/wireguard/diagnose'),
  /** Sync saved key files to match the running tunnel (fixes key mismatch) */
  syncKey: () => api.post('/wireguard/sync-key'),
  /** Ping a VPN IP from the tablet using Windows ping.exe */
  ping: (target: string) => api.post('/wireguard/ping', { target }),
};

export default api;