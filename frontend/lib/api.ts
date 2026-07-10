import axios from 'axios';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:5000';

const api = axios.create({
  baseURL: `${API_URL}/api`,
  headers: { 'Content-Type': 'application/json' },
});

export const deviceApi = {
  connect: (data: { deviceId?: string; ipAddress: string; port: number; license?: number }) => api.post('/device/connect', data),
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

export default api;