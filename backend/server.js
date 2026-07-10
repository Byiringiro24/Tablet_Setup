const express = require('express');
const cors = require('cors');
const { spawn } = require('child_process');
const path = require('path');
const readline = require('readline');
const fs = require('fs');
const app = express();

app.use(cors());
app.use(express.json());

const bridgeDir = path.join(__dirname, '..', 'FKBridge', 'bin', 'Release', 'net8.0');
const bridgePath = path.join(bridgeDir, 'FKBridge.exe');
const dataDir = path.join(__dirname, 'data');
const studentsFile = path.join(dataDir, 'students.json');
const attendanceSettingsFile = path.join(dataDir, 'attendance-settings.json');

let bridgeProcess = null;
let bridgeReady = false;
let pending = [];
let currentDevice = null;
let usersCache = [];
let logsCache = [];
let students = loadStudents();
let attendanceSettings = loadAttendanceSettings();

// Auto-connect state
const deviceConfigFile = path.join(dataDir, 'device-config.json');
let autoConnectTimer = null;
let autoConnectEnabled = true;
let autoConnectAttempt = 0;

// activeDeviceConfig is the single source of truth for what IP to connect to.
// Loaded from file at startup, only updated when Developer modal saves new settings.
// Never re-read from disk during auto-connect to avoid stale browser overwrites.
let activeDeviceConfig = loadDeviceConfig();

// SSE clients — set of response objects
const sseClients = new Set();

function sseEmit(event, data) {
  const payload = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
  for (const client of sseClients) {
    try { client.write(payload); } catch { sseClients.delete(client); }
  }
}

// Auto-log-poll state
let logPollTimer = null;
const seenLogIds = new Set();
let pollBusy = false;   // prevent overlapping polls if device is slow

function startLogPoll() {
  if (logPollTimer) return;
  seenLogIds.clear();   // always reset on new connection so first poll seeds correctly
  pollBusy = false;
  logPollTimer = setInterval(runLogPoll, 2000);
  console.log('Log auto-poll started (every 2s)');
}

function stopLogPoll() {
  if (logPollTimer) { clearInterval(logPollTimer); logPollTimer = null; }
  seenLogIds.clear();
  pollBusy = false;
}

async function runLogPoll() {
  if (!currentDevice || !currentDevice.connected) return;
  if (pollBusy) return;   // skip this tick if previous poll is still running
  pollBusy = true;
  try {
    const result = await sendCommand('GET_LOGS|0', 8000);
    if (!result.success) { pollBusy = false; return; }
    const rawLogs = Array.isArray(result.data?.logs) ? result.data.logs : [];
    const mapped = rawLogs.map(attendanceFromLog);

    // On first poll after connect, seed ALL existing logs — never flash old attendance
    if (seenLogIds.size === 0 && mapped.length > 0) {
      mapped.forEach((l) => seenLogIds.add(l.id));
      logsCache = rawLogs;
      sseEmit('init', mapped);
      console.log(`Log poll: seeded ${mapped.length} existing log(s) — no flash`);
      pollBusy = false;
      return;
    }

    const fresh = mapped.filter((l) => !seenLogIds.has(l.id));
    fresh.forEach((l) => seenLogIds.add(l.id));
    logsCache = rawLogs;
    if (fresh.length > 0) {
      console.log(`Log poll: ${fresh.length} new attendance record(s)`);
      sseEmit('attendance', fresh);
    }
  } catch (err) {
    // silent — device may be briefly busy
  }
  pollBusy = false;
}

function loadStudents() {  
  try {
    if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });
    if (!fs.existsSync(studentsFile)) fs.writeFileSync(studentsFile, '[]');
    return JSON.parse(fs.readFileSync(studentsFile, 'utf8'));
  } catch {
    return [];
  }
}

function defaultAttendanceSettings() {
  return {
    morning: {
      name: 'Morning Attendance',
      rules: [
        { label: 'Present', start: '07:00', end: '07:59' },
        { label: 'Late', start: '08:00', end: '16:29' },
        { label: 'Absent', start: '16:30', end: '04:59' },
      ],
    },
    evening: {
      name: 'Evening Attendance',
      rules: [
        { label: 'Leave on time', start: '17:00', end: '17:59' },
        { label: 'Leave late', start: '18:00', end: '18:59' },
        { label: 'Still at school', start: '19:00', end: '04:29' },
      ],
    },
    updatedAt: new Date().toISOString(),
  };
}

function normalizeTime(value) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  const match = trimmed.match(/^(\d{1,2}):(\d{2})$/);
  if (!match) return null;
  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  if (Number.isNaN(hours) || Number.isNaN(minutes)) return null;
  if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) return null;
  return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`;
}

function normalizeRules(rules, fallbackRules) {
  const source = Array.isArray(rules) && rules.length ? rules : fallbackRules;
  return source.map((rule) => {
    const label = String(rule?.label || '').trim();
    const start = normalizeTime(rule?.start);
    const end = normalizeTime(rule?.end);
    if (!label || !start || !end) throw new Error('Invalid attendance rule format');
    return { label, start, end };
  });
}

function normalizeAttendanceSettings(input) {
  const defaults = defaultAttendanceSettings();
  const morningRules = normalizeRules(input?.morning?.rules, defaults.morning.rules);
  const eveningRules = normalizeRules(input?.evening?.rules, defaults.evening.rules);
  const morningName = String(input?.morning?.name || defaults.morning.name).trim() || defaults.morning.name;
  const eveningName = String(input?.evening?.name || defaults.evening.name).trim() || defaults.evening.name;
  return {
    morning: { name: morningName, rules: morningRules },
    evening: { name: eveningName, rules: eveningRules },
    updatedAt: new Date().toISOString(),
  };
}

function loadDeviceConfig() {
  try {
    if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });
    if (!fs.existsSync(deviceConfigFile)) return null;
    const raw = JSON.parse(fs.readFileSync(deviceConfigFile, 'utf8'));
    if (!raw || !raw.ipAddress) return null;
    return raw;
  } catch {
    return null;
  }
}

function saveDeviceConfig(config) {
  try {
    if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });
    fs.writeFileSync(deviceConfigFile, JSON.stringify(config, null, 2));
  } catch (err) {
    console.error('Failed to save device config:', err);
  }
}

function scheduleAutoConnect(delayMs = 5000) {
  if (autoConnectTimer) {
    clearTimeout(autoConnectTimer);
    autoConnectTimer = null;
  }
  if (!autoConnectEnabled) return;
  autoConnectTimer = setTimeout(() => {
    autoConnectTimer = null;
    runAutoConnect();
  }, delayMs);
}

async function runAutoConnect() {
  if (!autoConnectEnabled) return;
  if (currentDevice && currentDevice.connected) return;

  // Use the in-memory cached config — never re-read from file during auto-connect
  // (file can be overwritten by stale browser requests; memory is authoritative)
  if (!activeDeviceConfig || !activeDeviceConfig.ipAddress) {
    console.log('Auto-connect: no device config in memory, retrying in 10s...');
    scheduleAutoConnect(10000);
    return;
  }

  const config = activeDeviceConfig;

  autoConnectAttempt += 1;
  const attempt = autoConnectAttempt;
  console.log(`Auto-connect attempt #${attempt}: ${config.ipAddress}:${config.port || 5005}`);

  try {
    await ensureBridge();
    const { ipAddress, port = 5005, license = 1261, deviceId = '', netPassword = 0, protocolType = -1 } = config;
    const normalizedProtocol = protocolType === null || protocolType === undefined ? -1 : Number(protocolType);
    // Use timeout from saved config — longer timeout needed for first connect
    const normalizedTimeout = Number(config.timeoutMs) > 0 ? Number(config.timeoutMs) : 10000;
    const result = await sendCommand(
      `CONNECT|${ipAddress}|${Number(port)}|${Number(license)}|${deviceId}|${Number(netPassword)}|${normalizedProtocol}|${normalizedTimeout}`,
      normalizedTimeout + 5000
    );
    if (result.success) {
      currentDevice = result.data;
      autoConnectAttempt = 0;
      console.log(`Auto-connect: connected successfully to ${ipAddress}`);
      startLogPoll();
      // Keep polling to detect disconnection
      scheduleAutoConnect(15000);
    } else {
      console.log(`Auto-connect failed (attempt #${attempt}): ${result.error || 'unknown error'}`);
      // Retry with capped backoff: 3s, 4.5s, 6.7s, … 30s max
      const delay = Math.min(3000 * Math.pow(1.5, Math.min(attempt - 1, 6)), 30000);
      scheduleAutoConnect(delay);
    }
  } catch (err) {
    console.log(`Auto-connect error (attempt #${attempt}): ${err.message}`);
    const delay = Math.min(3000 * Math.pow(1.5, Math.min(attempt - 1, 6)), 30000);
    scheduleAutoConnect(delay);
  }
}

function loadAttendanceSettings() {
  try {
    if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });
    if (!fs.existsSync(attendanceSettingsFile)) {
      const defaults = defaultAttendanceSettings();
      fs.writeFileSync(attendanceSettingsFile, JSON.stringify(defaults, null, 2));
      return defaults;
    }
    const raw = JSON.parse(fs.readFileSync(attendanceSettingsFile, 'utf8'));
    const normalized = normalizeAttendanceSettings(raw);
    fs.writeFileSync(attendanceSettingsFile, JSON.stringify(normalized, null, 2));
    return normalized;
  } catch {
    const defaults = defaultAttendanceSettings();
    fs.writeFileSync(attendanceSettingsFile, JSON.stringify(defaults, null, 2));
    return defaults;
  }
}

function saveAttendanceSettings() {
  if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });
  fs.writeFileSync(attendanceSettingsFile, JSON.stringify(attendanceSettings, null, 2));
}

function saveStudents() {
  if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });
  fs.writeFileSync(studentsFile, JSON.stringify(students, null, 2));
}

function startBridge() {
  if (bridgeProcess) return;
  console.log('Starting FK bridge:', bridgePath);
  bridgeReady = false;
  bridgeProcess = spawn(bridgePath, [], { cwd: bridgeDir, windowsHide: true });

  const rl = readline.createInterface({ input: bridgeProcess.stdout });
  rl.on('line', (line) => {
    if (!line.trim()) return;
    let message;
    try {
      message = JSON.parse(line);
    } catch {
      console.log('Bridge:', line);
      return;
    }

    if (message.type === 'READY') {
      bridgeReady = true;
      console.log('FK bridge ready');
      return;
    }

    const next = pending.shift();
    if (next) next.resolve(message);
  });

  bridgeProcess.stderr.on('data', (data) => console.error('Bridge stderr:', data.toString()));
  bridgeProcess.on('close', (code) => {
    console.log('FK bridge exited:', code);
    for (const item of pending.splice(0)) item.resolve({ success: false, type: 'ERROR', error: 'Bridge stopped' });
    bridgeProcess = null;
    bridgeReady = false;
    currentDevice = null;
    stopLogPoll();
    // Bridge died — schedule auto-reconnect after a short delay
    if (autoConnectEnabled) scheduleAutoConnect(5000);
  });
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function ensureBridge() {
  startBridge();
  const started = Date.now();
  while (!bridgeReady && Date.now() - started < 10000) await wait(100);
  if (!bridgeReady) throw new Error('FK bridge did not start. Build FKBridge first and confirm FKBridge.exe exists.');
}

async function sendCommand(command, timeoutMs = 30000) {
  await ensureBridge();
  return new Promise((resolve) => {
    let done = false;
    const wrappedResolve = (message) => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      resolve(message);
    };
    const timer = setTimeout(() => {
      const index = pending.findIndex((item) => item.resolve === wrappedResolve);
      if (index >= 0) pending.splice(index, 1);
      wrappedResolve({ success: false, type: 'TIMEOUT', error: 'Bridge command timed out' });
    }, timeoutMs);

    pending.push({ resolve: wrappedResolve });
    bridgeProcess.stdin.write(command + '\n');
  });
}

function apiResult(res, result, successStatus = 200) {
  if (!result.success) return res.status(500).json(result);
  return res.status(successStatus).json(result);
}

function backupToMethod(backupNumber) {
  if (backupNumber >= 0 && backupNumber <= 9) return 'Fingerprint';
  if (backupNumber === 10) return 'Password/PIN';
  if (backupNumber === 11) return 'RFID Card';
  if (backupNumber === 12) return 'Face Recognition';
  if (backupNumber >= 13 && backupNumber <= 20) return 'Vein/Palm';
  return `Backup ${backupNumber}`;
}

function aggregateDeviceUsers(rawUsers = []) {
  const byId = new Map();
  for (const raw of rawUsers) {
    const userId = String(raw.userId || '').trim();
    if (!userId) continue;
    const existing = byId.get(userId) || {
      userId,
      studentDeviceId: userId,
      name: raw.name || '',
      privilege: raw.privilege || 0,
      enabled: Boolean(raw.enabled),
      biometricMethods: [],
      backupNumbers: [],
      fingerprintRegistered: false,
      faceRegistered: false,
      cardRegistered: false,
      pinRegistered: false,
    };
    const method = backupToMethod(Number(raw.backupNumber));
    if (!existing.biometricMethods.includes(method)) existing.biometricMethods.push(method);
    if (!existing.backupNumbers.includes(raw.backupNumber)) existing.backupNumbers.push(raw.backupNumber);
    existing.fingerprintRegistered ||= method === 'Fingerprint';
    existing.faceRegistered ||= method === 'Face Recognition';
    existing.cardRegistered ||= method === 'RFID Card';
    existing.pinRegistered ||= method === 'Password/PIN';
    if (!existing.name && raw.name) existing.name = raw.name;
    existing.enabled ||= Boolean(raw.enabled);
    byId.set(userId, existing);
  }
  return Array.from(byId.values()).sort((a, b) => a.userId.localeCompare(b.userId, undefined, { numeric: true }));
}

function getStudentForDeviceUser(userId) {
  return students.find((student) => String(student.studentDeviceId) === String(userId) || String(student.deviceUserId) === String(userId));
}

function normalizeStudent(input) {
  const studentDeviceId = String(input.studentDeviceId || input.deviceUserId || input.enrollmentId || input.id || '').trim();
  const generatedSuffix = studentDeviceId || Date.now().toString().slice(-6);
  const studentId = String(input.studentId || `RW-${generatedSuffix}`).trim().toUpperCase();
  return {
    id: studentId,
    studentId,
    name: String(input.name || '').trim(),
    className: String(input.className || '').trim(),
    section: String(input.section || '').trim(),
    studentDeviceId,
    deviceUserId: studentDeviceId,
    assignedDeviceId: input.assignedDeviceId || currentDevice?.deviceId || '',
    parentName: input.parentName || '',
    parentPhone: input.parentPhone || '',
    phone: input.phone || '',
    email: input.email || '',
    createdAt: input.createdAt || new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
}

function timeStringToMinutes(value) {
  const [hours, minutes] = value.split(':').map(Number);
  return hours * 60 + minutes;
}

function isMinutesInRange(minutes, start, end) {
  if (start <= end) return minutes >= start && minutes <= end;
  return minutes >= start || minutes <= end;
}

function resolveAttendanceStatus(log) {
  const timestamp = new Date(log.timestamp);
  const minutes = timestamp.getHours() * 60 + timestamp.getMinutes();
  const eveningMatch = attendanceSettings.evening.rules.find((rule) =>
    isMinutesInRange(minutes, timeStringToMinutes(rule.start), timeStringToMinutes(rule.end))
  );
  if (eveningMatch) {
    const fallback = attendanceSettings.evening.rules[attendanceSettings.evening.rules.length - 1]?.label;
    return { status: eveningMatch.label || fallback || 'Unknown', period: attendanceSettings.evening.name };
  }

  const morningMatch = attendanceSettings.morning.rules.find((rule) =>
    isMinutesInRange(minutes, timeStringToMinutes(rule.start), timeStringToMinutes(rule.end))
  );
  const fallback = attendanceSettings.morning.rules[attendanceSettings.morning.rules.length - 1]?.label;
  return { status: morningMatch?.label || fallback || 'Unknown', period: attendanceSettings.morning.name };
}

function attendanceFromLog(log) {
  const student = getStudentForDeviceUser(log.userId);
  const deviceUser = usersCache.find((item) => item.userId === log.userId);
  const resolved = resolveAttendanceStatus(log);
  return {
    id: log.id,
    studentId: student?.studentId || `RW-${log.userId}`,
    studentDeviceId: log.userId,
    studentName: student?.name || deviceUser?.name || log.userId,
    className: student?.className || '',
    section: student?.section || '',
    deviceId: currentDevice?.deviceId || currentDevice?.ipAddress || 'FK_DEVICE',
    authenticationMethod: readableMethod(log.method),
    direction: log.direction,
    timestamp: log.timestamp,
    status: resolved.status,
    attendancePeriod: resolved.period,
    verified: true,
    rawData: log,
  };
}

function readableMethod(method) {
  const value = String(method || '').toUpperCase();
  if (value.includes('FACE')) return 'Face Recognition';
  if (value.includes('FINGER') || value.includes('FP')) return 'Fingerprint';
  if (value.includes('CARD')) return 'RFID Card';
  if (value.includes('PASS') || value.includes('PIN')) return 'Password/PIN';
  return value.startsWith('MODE_') ? 'Device Verified' : method;
}

async function refreshUsersCache() {
  const result = await sendCommand('GET_USERS', 60000);
  if (result.success) usersCache = aggregateDeviceUsers(result.data.users || []);
  return result.success ? { ...result, data: { users: usersCache, count: usersCache.length } } : result;
}

app.get('/api/health', async (req, res) => {
  const savedConfig = loadDeviceConfig();
  res.json({ status: 'ok', bridgeRunning: bridgeProcess !== null, bridgeReady, device: currentDevice, autoConnect: { enabled: autoConnectEnabled, attempt: autoConnectAttempt }, savedConfig });
});

// Server-Sent Events — frontend subscribes here for real-time attendance updates
app.get('/api/events', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.flushHeaders();

  // Send a heartbeat every 20s so proxies don't close the connection
  const heartbeat = setInterval(() => {
    try { res.write(': heartbeat\n\n'); } catch { /* client gone */ }
  }, 20000);

  // Send current log cache immediately on connect — seed seenLogIds so they're never treated as fresh
  const current = logsCache.map(attendanceFromLog);
  current.forEach((l) => seenLogIds.add(l.id));
  // Send to frontend as init (sidebar logs only, no flash)
  res.write(`event: init\ndata: ${JSON.stringify(current)}\n\n`);

  sseClients.add(res);
  req.on('close', () => {
    clearInterval(heartbeat);
    sseClients.delete(res);
  });
});

app.post('/api/device/connect', async (req, res) => {
  const {
    ipAddress,
    address,
    port = 5005,
    license = 1261,
    deviceId = '',
    netPassword = 0,
    protocolType = -1,
    timeoutMs = 3000,
    saveConfig = false,   // only save when explicitly requested (Developer modal)
  } = req.body;
  const targetAddress = ipAddress || address;
  const normalizedProtocol = protocolType === null || protocolType === undefined ? -1 : Number(protocolType);
  const normalizedTimeout = Number(timeoutMs) > 0 ? Number(timeoutMs) : 3000;

  // Only persist the config when saveConfig=true (sent only by the Developer modal)
  if (saveConfig === true) {
    const cfg = { ipAddress: targetAddress, port: Number(port), license: Number(license), deviceId, netPassword: Number(netPassword), protocolType: normalizedProtocol, timeoutMs: normalizedTimeout };
    saveDeviceConfig(cfg);
    activeDeviceConfig = cfg;  // update in-memory so auto-connect uses new IP immediately
  } else {
    // If there is already a saved config with a different IP, ignore the caller's IP and use the saved one
    const existing = loadDeviceConfig();
    if (existing && existing.ipAddress && existing.ipAddress !== targetAddress) {
      // Silently reject — don't log spam from stale browser requests
      return res.status(400).json({ success: false, error: `Device IP mismatch. Saved IP is ${existing.ipAddress}. Open Developer settings to update it.` });
    }
  }

  const result = await sendCommand(
    `CONNECT|${targetAddress}|${Number(port)}|${Number(license)}|${deviceId}|${Number(netPassword)}|${normalizedProtocol}|${normalizedTimeout}`,
    8000
  );
  if (result.success) {
    currentDevice = result.data;
    autoConnectAttempt = 0;
    startLogPoll();
    scheduleAutoConnect(15000);
  }
  apiResult(res, result);
});

// Connect using saved config — frontend calls this so it never overwrites the saved IP
app.post('/api/device/connect-saved', async (req, res) => {
  // If already connected, return current device state immediately — no need to reconnect
  if (currentDevice && currentDevice.connected) {
    return res.json({ success: true, data: currentDevice });
  }
  const config = activeDeviceConfig || loadDeviceConfig();
  if (!config || !config.ipAddress) {
    return res.status(400).json({ success: false, error: 'No saved device config. Use Developer settings to set the IP first.' });
  }
  const { ipAddress, port = 5005, license = 1261, deviceId = '', netPassword = 0, protocolType = -1, timeoutMs = 10000 } = config;
  const normalizedProtocol = protocolType === null || protocolType === undefined ? -1 : Number(protocolType);
  const normalizedTimeout = Number(timeoutMs) > 0 ? Number(timeoutMs) : 10000;
  const result = await sendCommand(
    `CONNECT|${ipAddress}|${Number(port)}|${Number(license)}|${deviceId}|${Number(netPassword)}|${normalizedProtocol}|${normalizedTimeout}`,
    normalizedTimeout + 5000
  );
  if (result.success) {
    currentDevice = result.data;
    autoConnectAttempt = 0;
    startLogPoll();
    scheduleAutoConnect(15000);
  }
  apiResult(res, result);
});

app.post('/api/device/disconnect', async (req, res) => {
  const result = await sendCommand('DISCONNECT');
  currentDevice = null;
  stopLogPoll();
  autoConnectEnabled = false;
  if (autoConnectTimer) { clearTimeout(autoConnectTimer); autoConnectTimer = null; }
  apiResult(res, result);
});

app.post('/api/device/reconnect', (req, res) => {
  // Re-enable auto-connect and trigger immediately
  autoConnectEnabled = true;
  autoConnectAttempt = 0;
  scheduleAutoConnect(0);
  res.json({ success: true, message: 'Auto-connect re-enabled' });
});

app.get('/api/device/status', async (req, res) => {
  const result = await sendCommand('STATUS', 5000);
  if (result.success) currentDevice = result.data;
  apiResult(res, result);
});

app.post('/api/device/sync-time', async (req, res) => apiResult(res, await sendCommand('SYNC_TIME')));

app.post('/api/device/set-time', async (req, res) => {
  const timestamp = req.body?.timestamp;
  if (!timestamp) return res.status(400).json({ success: false, error: 'Timestamp is required' });
  apiResult(res, await sendCommand(`SET_TIME|${timestamp}`));
});

app.get('/api/device/users', async (req, res) => apiResult(res, await refreshUsersCache()));

app.post('/api/device/users', async (req, res) => {
  const userId = String(req.body?.userId || req.body?.studentDeviceId || req.body?.studentId || '').trim();
  const name = String(req.body?.name || req.body?.studentName || userId).replace(/\|/g, ' ').trim();
  if (!userId) return res.status(400).json({ success: false, error: 'User ID is required' });
  const result = await sendCommand(`ADD_USER|${userId}|${name}`, 30000);
  if (result.success) await refreshUsersCache().catch(() => null);
  apiResult(res, result, 201);
});

app.delete('/api/device/users/:id', async (req, res) => {
  const userId = String(req.params.id || '').trim();
  if (!userId) return res.status(400).json({ success: false, error: 'User ID is required' });
  const result = await sendCommand(`DELETE_USER|${userId}`, 30000);
  if (result.success) usersCache = usersCache.filter((user) => user.userId !== userId);
  apiResult(res, result);
});

app.post('/api/device/pull-logs', async (req, res) => {
  const readMark = req.body?.readMark === 1 || req.query.readMark === '1' ? 1 : 0;
  let result = await sendCommand(`GET_LOGS|${readMark}`, 90000);
  if (result.success && (result.data?.logs || []).length === 0 && readMark === 1) {
    result = await sendCommand('GET_LOGS|0', 90000);
  }
  if (result.success) {
    const newLogs = Array.isArray(result.data?.logs) ? result.data.logs : [];
    logsCache = newLogs;
    // Seed seen IDs so auto-poll doesn't re-fire these as new
    newLogs.map(attendanceFromLog).forEach((l) => seenLogIds.add(l.id));
  }
  apiResult(res, result);
});

app.post('/api/device/push-students', async (req, res) => {
  const ids = Array.isArray(req.body?.studentIds) ? req.body.studentIds : [];
  const selected = ids.length ? students.filter((student) => ids.includes(student.studentId)) : students;
  const pushed = [];
  const failed = [];
  for (const student of selected) {
    const result = await sendCommand(`ADD_USER|${student.studentDeviceId}|${String(student.name).replace(/\|/g, ' ')}`, 30000);
    if (result.success) pushed.push(student); else failed.push({ student, error: result.error, code: result.code });
  }
  if (pushed.length) await refreshUsersCache().catch(() => null);
  res.json({ success: failed.length === 0, data: { pushed: pushed.length, failed: failed.length, failures: failed }, error: failed[0]?.error || null });
});

app.post('/api/device/clear-logs', async (req, res) => apiResult(res, await sendCommand('CLEAR_LOGS')));
app.post('/api/device/clear-all', async (req, res) => apiResult(res, await sendCommand('CLEAR_ALL')));
app.post('/api/device/poweroff', async (req, res) => apiResult(res, await sendCommand('POWEROFF')));

app.get('/api/dashboard/stats', async (req, res) => {
  if (!currentDevice) {
    const status = await sendCommand('STATUS', 10000).catch(() => null);
    if (status?.success) currentDevice = status.data;
  }
  const today = new Date().toDateString();
  const todayLogs = logsCache.filter((log) => new Date(log.timestamp).toDateString() === today);
  const lateCount = todayLogs
    .map(attendanceFromLog)
    .filter((log) => String(log.status).toLowerCase().includes('late')).length;
  res.json({
    success: true,
    stats: {
      totalStudents: students.length || usersCache.length,
      totalDevices: currentDevice ? 1 : 0,
      onlineDevices: currentDevice?.connected ? 1 : 0,
      attendanceToday: new Set(todayLogs.map((log) => log.userId)).size,
      lateStudents: lateCount,
      totalLogs: logsCache.length,
    },
  });
});

app.get('/api/dashboard/recent', (req, res) => {
  res.json({ success: true, recent: logsCache.slice(0, 20).map(attendanceFromLog) });
});

app.get('/api/students', async (req, res) => {
  const merged = students.map((student) => {
    const deviceUser = usersCache.find((user) => user.userId === student.studentDeviceId);
    return { ...student, deviceUser, biometricMethods: deviceUser?.biometricMethods || [] };
  });
  res.json({ success: true, students: merged, count: merged.length });
});

app.post('/api/students', async (req, res) => {
  const student = normalizeStudent(req.body);
  if (!student.name) return res.status(400).json({ success: false, error: 'Student full name is required' });
  if (!student.studentDeviceId) return res.status(400).json({ success: false, error: 'Student device ID is required' });
  if (!student.studentId.startsWith('RW-')) return res.status(400).json({ success: false, error: 'Student ID must start with Rwanda suffix RW-, for example RW-0001' });

  const existingIndex = students.findIndex((item) => item.studentId === student.studentId || item.studentDeviceId === student.studentDeviceId);
  if (existingIndex >= 0) students[existingIndex] = { ...students[existingIndex], ...student, updatedAt: new Date().toISOString() };
  else students.push(student);
  saveStudents();

  let pushResult = null;
  if (req.body.pushToDevice !== false) {
    pushResult = await sendCommand(`ADD_USER|${student.studentDeviceId}|${String(student.name).replace(/\|/g, ' ')}`, 30000);
    await refreshUsersCache().catch(() => null);
  }

  res.json({ success: !pushResult || pushResult.success, student, pushResult, error: pushResult?.success === false ? pushResult.error : null });
});

app.delete('/api/students/:id', async (req, res) => {
  const student = students.find((item) => item.studentId === req.params.id || item.studentDeviceId === req.params.id);
  const deviceId = student?.studentDeviceId || req.params.id;
  const result = await sendCommand(`DELETE_USER|${deviceId}`);
  students = students.filter((item) => item.studentId !== req.params.id && item.studentDeviceId !== req.params.id);
  saveStudents();
  if (result.success) usersCache = usersCache.filter((user) => user.userId !== deviceId);
  apiResult(res, result);
});

app.get('/api/devices', (req, res) => {
  res.json({ success: true, devices: currentDevice ? [currentDevice] : [] });
});

app.post('/api/devices', (req, res) => {
  currentDevice = { ...req.body, connected: false };
  res.json({ success: true, data: currentDevice, device: currentDevice });
});

app.get('/api/attendance', (req, res) => {
  res.json({ success: true, attendance: logsCache.map(attendanceFromLog), count: logsCache.length });
});

app.get('/api/attendance/settings', (req, res) => {
  res.json({ success: true, settings: attendanceSettings });
});

app.put('/api/attendance/settings', (req, res) => {
  try {
    attendanceSettings = normalizeAttendanceSettings(req.body || {});
    saveAttendanceSettings();
    res.json({ success: true, settings: attendanceSettings });
  } catch (error) {
    res.status(400).json({ success: false, error: error?.message || 'Invalid attendance settings' });
  }
});

app.get('/api/attendance/today', (req, res) => {
  const today = new Date().toDateString();
  const todayLogs = logsCache.filter((log) => new Date(log.timestamp).toDateString() === today).map(attendanceFromLog);
  res.json({ success: true, summary: { total: todayLogs.length, checkIns: todayLogs.length, uniqueStudents: new Set(todayLogs.map((log) => log.studentDeviceId)).size } });
});

const PORT = Number(process.env.PORT || 5000);
app.listen(PORT, '0.0.0.0', () => {
  console.log(`FK Attendance Backend running on http://localhost:${PORT}`);
  startBridge();
  // Kick off auto-connect shortly after bridge starts
  scheduleAutoConnect(3000);
});

process.on('SIGINT', () => {
  if (bridgeProcess) bridgeProcess.kill();
  process.exit(0);
});