const express = require('express');
const cors = require('cors');
const { spawn, execFile } = require('child_process');
const path = require('path');
const readline = require('readline');
const fs = require('fs');
const fsSync = fs;  // alias used in WireGuard routes for clarity
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

// SSE clients â€” set of response objects
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
  if (pollBusy) return;
  pollBusy = true;
  try {
    const result = await sendCommand('GET_LOGS|0', 8000);
    if (!result.success) {
      pollBusy = false;
      // If command failed with a connection-type error, device is offline
      const err = (result.error || '').toLowerCase();
      if (err.includes('not reachable') || err.includes('disconnect') || err.includes('timeout') || err.includes('bridge stopped')) {
        console.log('Log poll: device offline detected â€” triggering reconnect');
        currentDevice = null;
        stopLogPoll();
        sseEmit('deviceStatus', { connected: false });
        if (autoConnectEnabled) scheduleAutoConnect(3000);
      }
      return;
    }
    const rawLogs = Array.isArray(result.data?.logs) ? result.data.logs : [];

    // On first poll after connect, seed ALL existing logs â€” never flash old attendance
    if (seenLogIds.size === 0 && rawLogs.length > 0) {
      const getLogKey = (raw) => raw.id || `${raw.userId}-${raw.timestamp}`;
      rawLogs.forEach((raw) => seenLogIds.add(getLogKey(raw)));
      logsCache = rawLogs;
      // Pull users then emit init with resolved names for sidebar
      await refreshUsersCache().catch(() => null);
      sseEmit('init', rawLogs.map(attendanceFromLog));
      console.log(`Log poll: seeded ${rawLogs.length} existing log(s) â€” no flash`);
      pollBusy = false;
      return;
    }

    // Find fresh raw logs (not yet seen)
    // Use a composite key: userId + timestamp as stable dedup key if log.id is absent
    const getLogKey = (raw) => raw.id || `${raw.userId}-${raw.timestamp}`;
    const freshRaw = rawLogs.filter((raw) => !seenLogIds.has(getLogKey(raw)));
    freshRaw.forEach((raw) => seenLogIds.add(getLogKey(raw)));
    logsCache = rawLogs;

    if (freshRaw.length > 0) {
      console.log(`Log poll: ${freshRaw.length} new attendance record(s)`);
      // If usersCache is empty, pull users now so names resolve before we emit
      if (usersCache.length === 0) {
        await refreshUsersCache().catch(() => null);
      }
      // Map with latest usersCache so studentName is a real name, not a device ID
      const freshMapped = freshRaw.map(attendanceFromLog);
      sseEmit('attendance', freshMapped);
    }
  } catch (err) {
    // silent â€” device may be briefly busy
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

  // Use the in-memory cached config â€” never re-read from file during auto-connect
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
    // Stop log poll before connecting â€” prevents queue contention
    stopLogPoll();
    const { ipAddress, port = 5005, license = 1261, deviceId = '', netPassword = 0, protocolType = -1 } = config;
    const normalizedProtocol = protocolType === null || protocolType === undefined ? -1 : Number(protocolType);
    // Use timeout from saved config â€” longer timeout needed for first connect
    const normalizedTimeout = Number(config.timeoutMs) > 0 ? Number(config.timeoutMs) : 15000;
    const result = await sendCommand(
      `CONNECT|${ipAddress}|${Number(port)}|${Number(license)}|${deviceId}|${Number(netPassword)}|${normalizedProtocol}|${normalizedTimeout}`,
      normalizedTimeout + 10000
    );
    if (result.success) {
      currentDevice = result.data;
      autoConnectAttempt = 0;
      console.log(`Auto-connect: connected successfully to ${ipAddress}`);
      syncTimeAfterConnect();                                    // sync device clock to tablet time
      refreshUsersCache().catch(() => null); // pull users so names resolve immediately
      startLogPoll();
      // Check connection health every 30s (not 15s â€” gives log poll room to breathe)
      scheduleAutoConnect(30000);
    } else {
      console.log(`Auto-connect failed (attempt #${attempt}): ${result.error || 'unknown error'}`);
      // Retry with capped backoff: 3s, 4.5s, 6.7s, â€¦ 30s max
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
  if (!fs.existsSync(bridgePath)) {
    console.warn('FKBridge.exe not found at:', bridgePath);
    console.warn('Bridge features disabled â€” WireGuard VPN setup endpoints are still available.');
    return;
  }
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
    // Bridge died â€” schedule auto-reconnect after a short delay
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

// Command lock â€” only one bridge command runs at a time
let commandLock = false;
const commandQueue = [];

async function sendCommand(command, timeoutMs = 30000) {
  await ensureBridge();
  // Serialize all commands through a queue so they never overlap
  return new Promise((resolve) => {
    commandQueue.push({ command, timeoutMs, resolve });
    drainCommandQueue();
  });
}

async function drainCommandQueue() {
  if (commandLock || commandQueue.length === 0) return;
  commandLock = true;
  // Prioritise CONNECT commands â€” if one is waiting, drop all GET_LOGS in front of it
  const connectIdx = commandQueue.findIndex(({ command }) => command.startsWith('CONNECT'));
  if (connectIdx > 0) {
    // Remove all non-CONNECT commands ahead of it to avoid blocking connect
    commandQueue.splice(0, connectIdx);
  }
  const { command, timeoutMs, resolve } = commandQueue.shift();
  try {
    const result = await sendCommandRaw(command, timeoutMs);
    resolve(result);
  } catch (err) {
    resolve({ success: false, type: 'ERROR', error: err.message });
  }
  commandLock = false;
  if (commandQueue.length > 0) setImmediate(drainCommandQueue);
}

async function sendCommandRaw(command, timeoutMs = 30000) {
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
    photoUrl: input.photoUrl || input.photo_url || '',   // â† stored for display on scan
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
  const stableId = log.id || `${log.userId}-${log.timestamp}`;
  return {
    id: stableId,
    studentId: student?.studentId || `RW-${log.userId}`,
    studentDeviceId: log.userId,
    studentName: student?.name || deviceUser?.name || `User ${log.userId}`,
    className: student?.className || '',
    section: student?.section || '',
    deviceId: currentDevice?.deviceId || currentDevice?.ipAddress || 'FK_DEVICE',
    authenticationMethod: readableMethod(log.method),
    direction: log.direction,
    timestamp: log.timestamp,
    status: resolved.status,
    attendancePeriod: resolved.period,
    photoUrl: student?.photoUrl || '',   // â† included for display on LiveAttendanceScreen
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

// Sync device time to tablet clock immediately after every successful connection.
// Cooldown of 60s prevents repeated syncs during rapid reconnect cycles.
let lastTimeSyncAt = 0;
function syncTimeAfterConnect() {
  const now = Date.now();
  if (now - lastTimeSyncAt < 60000) return; // skip if synced less than 60s ago
  lastTimeSyncAt = now;
  sendCommand('SYNC_TIME', 10000)
    .then((r) => {
      if (r.success) console.log(`[Time Sync] Device clock synced to tablet time: ${new Date().toISOString()}`);
      else           console.warn(`[Time Sync] SYNC_TIME failed: ${r.error || 'unknown error'}`);
    })
    .catch((err) => console.warn(`[Time Sync] SYNC_TIME error: ${err.message}`));
}

async function refreshUsersCache() {
  const result = await sendCommand('GET_USERS', 60000);
  if (result.success) usersCache = aggregateDeviceUsers(result.data.users || []);
  return result.success ? { ...result, data: { users: usersCache, count: usersCache.length } } : result;
}

app.get('/api/health', async (req, res) => {
  const savedConfig = loadDeviceConfig();
  res.json({
    status: 'ok',
    bridgeRunning: bridgeProcess !== null,
    bridgeReady,
    device: currentDevice,
    autoConnect: { enabled: autoConnectEnabled, attempt: autoConnectAttempt },
    savedConfig,
    tabletUuid: TABLET_UUID || null,
    // VPN config â€” tablet wizard reads these to pre-fill the form
    vpn: {
      serverEndpoint: WG_SERVER_ENDPOINT,
      allowedIPs: VPN_ALLOWED_IPS,
      dns: WG_DNS,
    },
  });
});

// Server-Sent Events â€” frontend subscribes here for real-time attendance updates
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

  // Send current log cache immediately on connect â€” seed seenLogIds so they're never treated as fresh
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
      // Silently reject â€” don't log spam from stale browser requests
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
    syncTimeAfterConnect();                  // sync device clock to tablet time
    refreshUsersCache().catch(() => null);
    startLogPoll();
    scheduleAutoConnect(30000);
  }
  apiResult(res, result);
});

// Connect using saved config â€” frontend calls this so it never overwrites the saved IP
app.post('/api/device/connect-saved', async (req, res) => {
  // If already connected, return current device state immediately â€” no need to reconnect
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
    syncTimeAfterConnect();                  // sync device clock to tablet time
    refreshUsersCache().catch(() => null);
    startLogPoll();
    scheduleAutoConnect(30000);
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
  if (result.success) {
    currentDevice = result.data;
  } else {
    // STATUS failed â€” device is offline, clear it so frontend shows disconnected
    currentDevice = null;
    stopLogPoll();
    if (autoConnectEnabled) scheduleAutoConnect(3000);
  }
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

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// WireGuard VPN Setup Endpoints
// These run PowerShell on the Windows tablet so the super admin can set up
// the VPN tunnel from a web browser without touching a terminal.
//
// Flow:
//   1. GET  /api/wireguard/status       â†’ check if WireGuard is installed & tunnel state
//   2. POST /api/wireguard/generate-keys â†’ generate a new private+public key pair
//   3. POST /api/wireguard/install       â†’ write the tunnel config and activate it
//   4. GET  /api/wireguard/status        â†’ verify tunnel is Active
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

// VPN configuration â€” read from .env to match the school server's subnet.
// Must match the server's wg0.conf AllowedIPs (default: 10.0.0.0/16 for 65534 tablets).
const VPN_ALLOWED_IPS = process.env.VPN_ALLOWED_IPS || '10.0.0.0/16';
const WG_SERVER_ENDPOINT = process.env.WG_SERVER_ENDPOINT || '169.58.124.150:51820';
const WG_DNS = process.env.WG_DNS || '1.1.1.1';

// Tablet identity â€” set TABLET_UUID in .env after registering in the portal.
// The school server uses this to identify which tablet is making requests.
const TABLET_UUID = process.env.TABLET_UUID || '';

const WG_EXE = 'C:\\Program Files\\WireGuard\\wg.exe';
const WIREGUARD_TUNNEL_NAME = 'EcareAfrica';
// WireGuard stores tunnel configs here on Windows
const WG_TUNNEL_DIR = `${process.env.PROGRAMDATA || 'C:\\ProgramData'}\\WireGuard`;

function runPS(script, timeoutMs = 15000) {
  return new Promise((resolve, reject) => {
    // Run PowerShell with -NoProfile -NonInteractive so it never hangs waiting for input
    const ps = execFile(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', script],
      { timeout: timeoutMs, windowsHide: true },
      (err, stdout, stderr) => {
        if (err) return reject(new Error(stderr?.trim() || err.message));
        resolve(stdout.trim());
      }
    );
  });
}

function runWg(...args) {
  return new Promise((resolve, reject) => {
    execFile(WG_EXE, args, { timeout: 10000, windowsHide: true }, (err, stdout, stderr) => {
      if (err) return reject(new Error(stderr?.trim() || err.message));
      resolve(stdout.trim());
    });
  });
}

// GET /api/wireguard/status
// Returns: installed, tunnelActive, tunnelName, vpnIp, publicKey (if keys exist)
app.get('/api/wireguard/status', async (req, res) => {
  // Check if running as Administrator — WireGuard tunnel service requires it
  let isAdmin = false;
  try {
    await runPS('([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")', 5000);
    isAdmin = true;
  } catch {
    // If the PS command fails, try a simpler test
    try {
      await runPS('net session', 3000);
      isAdmin = true;
    } catch { isAdmin = false; }
  }
  const wgExeExists  = fsSync.existsSync(WG_EXE);
  const wguiExists   = fsSync.existsSync('C:\\Program Files\\WireGuard\\wireguard.exe');
  const installed    = wgExeExists && wguiExists;

  let tunnelActive  = false;
  let vpnIp         = null;
  let publicKey     = null;
  let lastHandshake = null;
  let tunnelExists  = false;

  if (installed) {
    try {
      // `wg show all` lists all active interfaces â€” safer than `wg show <name>` which errors when absent
      const showAll = await runWg('show', 'all').catch(() => '');
      if (showAll.includes(WIREGUARD_TUNNEL_NAME)) {
        tunnelExists = true;
        // Now get detail for our specific tunnel
        const show = await runWg('show', WIREGUARD_TUNNEL_NAME).catch(() => '');
        if (show.includes('interface:') || show.includes('listening port')) {
          tunnelActive = true;
          // Read VPN IP from the interface address, not the peer's allowed-ips
          // `wg show EcareAfrica` output has: "interface: EcareAfrica" then details
          // The address is not in wg show output — read it from the config file instead
          const hsMatch = show.match(/latest handshake:\s*(.+)/i);
          if (hsMatch) lastHandshake = hsMatch[1].trim();
        }
      }
    } catch { /* no active tunnels */ }

    // Read saved public key from disk
    try {
      const keyFile = path.join(__dirname, 'data', 'wireguard-public.key');
      if (fsSync.existsSync(keyFile)) {
        publicKey = fsSync.readFileSync(keyFile, 'utf8').trim();
        // Validate it looks like a real WireGuard key (44-char base64)
        if (!/^[A-Za-z0-9+/]{43}=$/.test(publicKey)) publicKey = null;
      }
    } catch { /* no saved key */ }
  }

  // Read VPN IP from the saved config file — this is the source of truth
  // wg show does not expose the interface Address, only the peer AllowedIPs
  try {
    const confPath = path.join(WG_TUNNEL_DIR, `${WIREGUARD_TUNNEL_NAME}.conf`);
    if (fsSync.existsSync(confPath)) {
      const conf = fsSync.readFileSync(confPath, 'utf8');
      // Match Address = 10.0.0.3/32 — capture just the IP, not the /32
      const m = conf.match(/^Address\s*=\s*([\d.]+)(?:\/\d+)?/im);
      if (m) vpnIp = m[1];
    }
  } catch { /* ignore */ }

  res.json({
    success: true,
    installed,
    isAdmin,           // frontend uses this to warn user if bridge is not elevated
    wgExeExists,
    tunnelExists,
    tunnelActive,
    tunnelName: WIREGUARD_TUNNEL_NAME,
    vpnIp,
    publicKey,
    lastHandshake,
    wgPath: WG_EXE,
  });
});

// POST /api/wireguard/generate-keys
// Generates a new WireGuard key pair on the tablet.
// Returns: { privateKey, publicKey }
// The super admin copies the publicKey and pastes it into the server web UI.
app.post('/api/wireguard/generate-keys', async (req, res) => {
  if (!fsSync.existsSync(WG_EXE)) {
    return res.status(400).json({
      success: false,
      error: 'WireGuard is not installed. Download from https://www.wireguard.com/install/ and install it first.',
      downloadUrl: 'https://www.wireguard.com/install/',
    });
  }

  try {
    // Step 1: generate private key
    const privateKey = await runWg('genkey');
    if (!privateKey || privateKey.length < 40) {
      throw new Error('wg genkey returned an empty or invalid key');
    }

    // Step 2: derive public key â€” pipe private key to `wg pubkey` via stdin (safe, no shell injection)
    const publicKey = await new Promise((resolve, reject) => {
      const child = execFile(WG_EXE, ['pubkey'], { timeout: 10000, windowsHide: true }, (err, stdout, stderr) => {
        if (err) return reject(new Error(stderr?.trim() || err.message));
        const key = stdout.trim();
        if (!key || key.length < 40) return reject(new Error('wg pubkey returned an empty result'));
        resolve(key);
      });
      // Write private key to wg pubkey's stdin and close it
      child.stdin.write(privateKey + '\n');
      child.stdin.end();
    });

    // Validate both keys look like real WireGuard keys (44-char base64 ending in =)
    const keyRegex = /^[A-Za-z0-9+/]{43}=$/;
    if (!keyRegex.test(privateKey)) throw new Error(`Generated private key has invalid format: "${privateKey}"`);
    if (!keyRegex.test(publicKey))  throw new Error(`Derived public key has invalid format: "${publicKey}"`);

    // Save keys to disk
    const keyDir = path.join(__dirname, 'data');
    if (!fsSync.existsSync(keyDir)) fsSync.mkdirSync(keyDir, { recursive: true });
    fsSync.writeFileSync(path.join(keyDir, 'wireguard-private.key'), privateKey, { mode: 0o600 });
    fsSync.writeFileSync(path.join(keyDir, 'wireguard-public.key'),  publicKey);

    console.log(`[WireGuard] Keys generated. Public: ${publicKey}`);
    res.json({ success: true, privateKey, publicKey });
  } catch (err) {
    console.error('[WireGuard] Key generation failed:', err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

// POST /api/wireguard/install
// Installs and activates the WireGuard tunnel on the tablet.
// Body: { serverPublicKey, serverEndpoint, vpnIp, dns? }
// The super admin pastes the serverPublicKey (from the server web UI) and the assigned VPN IP.
app.post('/api/wireguard/install', async (req, res) => {
  const { serverPublicKey, serverEndpoint, vpnIp, dns = '1.1.1.1' } = req.body || {};

  if (!serverPublicKey) return res.status(400).json({ success: false, error: 'serverPublicKey is required' });
  if (!serverEndpoint)  return res.status(400).json({ success: false, error: 'serverEndpoint is required (e.g. 169.58.124.150:51820)' });
  if (!vpnIp)           return res.status(400).json({ success: false, error: 'vpnIp is required (e.g. 10.0.0.2)' });

  if (!fsSync.existsSync(WG_EXE)) {
    return res.status(400).json({
      success: false,
      error: 'WireGuard is not installed.',
      downloadUrl: 'https://www.wireguard.com/install/',
    });
  }

  // Load saved private key
  const privateKeyFile = path.join(__dirname, 'data', 'wireguard-private.key');
  if (!fsSync.existsSync(privateKeyFile)) {
    return res.status(400).json({
      success: false,
      error: 'No private key found. Generate keys first using the Generate Keys step.',
    });
  }
  const privateKey = fsSync.readFileSync(privateKeyFile, 'utf8').trim();

  // Build the WireGuard config â€” subnet from env (default: /16 to match server)
  const confContent = [
    '[Interface]',
    `PrivateKey = ${privateKey}`,
    `Address = ${vpnIp}/32`,
    `DNS = ${dns || WG_DNS}`,
    '',
    '[Peer]',
    `PublicKey = ${serverPublicKey}`,
    `AllowedIPs = ${VPN_ALLOWED_IPS}`,
    `Endpoint = ${serverEndpoint}`,
    'PersistentKeepalive = 25',
  ].join('\n');  // LF only â€” WireGuard on Windows accepts both LF and CRLF

  // Write config to WireGuard tunnel directory
  // Use Buffer.from with 'utf8' to guarantee NO BOM â€” Node's default utf8 has no BOM
  // but we make it explicit to be safe.
  const confPath = path.join(WG_TUNNEL_DIR, `${WIREGUARD_TUNNEL_NAME}.conf`);
  try {
    if (!fsSync.existsSync(WG_TUNNEL_DIR)) fsSync.mkdirSync(WG_TUNNEL_DIR, { recursive: true });
    // Write as raw buffer â€” absolutely no BOM
    fsSync.writeFileSync(confPath, Buffer.from(confContent, 'utf8'));
  } catch (err) {
    return res.status(500).json({ success: false, error: `Failed to write config: ${err.message}. Run the bridge as Administrator.` });
  }

  // Also write to user's temp directory as fallback for GUI import
  const tempConfPath = path.join(process.env.TEMP || 'C:\\Temp', `${WIREGUARD_TUNNEL_NAME}.conf`);
  try {
    fsSync.writeFileSync(tempConfPath, Buffer.from(confContent, 'utf8'));
  } catch { /* temp write failure is non-fatal */ }

  // Install tunnel via WireGuard CLI (requires admin — bridge must run as Administrator)
  try {
    // Remove existing tunnel if present (ignore error if not installed)
    await runPS(`& '${WG_EXE.replace(/'/g, "''")}' /uninstalltunnelservice ${WIREGUARD_TUNNEL_NAME}`)
      .catch(() => null);

    // Install & start the tunnel service from ProgramData location
    await runPS(`& 'C:\\Program Files\\WireGuard\\wireguard.exe' /installtunnelservice '${confPath.replace(/'/g, "''")}'`);

    // Give it 3s to establish
    await new Promise(r => setTimeout(r, 3000));

    // Verify tunnel is active
    const show = await runWg('show', WIREGUARD_TUNNEL_NAME).catch(() => '');
    const active = show.includes('interface:') || show.includes('listening port');

    res.json({
      success: true,
      tunnelActive: active,
      vpnIp,
      confPath: tempConfPath,
      message: active
        ? `WireGuard tunnel "${WIREGUARD_TUNNEL_NAME}" is active on ${vpnIp}`
        : `Tunnel installed but not yet active. If it stays inactive, open WireGuard app and import: ${tempConfPath}`,
    });
  } catch (err) {
    // Service install failed — config file is ready, guide user to import via GUI
    const show = await runWg('show', WIREGUARD_TUNNEL_NAME).catch(() => '');
    const active = show.includes('interface:') || show.includes('listening port');
    if (active) {
      return res.json({ success: true, tunnelActive: true, vpnIp, confPath: tempConfPath, message: `Tunnel already active on ${vpnIp}` });
    }
    // Return config path so wizard can show the GUI import fallback instruction
    res.json({
      success: false,
      tunnelActive: false,
      vpnIp,
      confPath: tempConfPath,
      requiresGuiImport: true,
      error: `Auto-install failed. Open WireGuard app, click Import tunnel, select: ${tempConfPath}, then Activate.`,
    });
  }
});

// POST /api/services/install
// Installs the bridge and frontend as Windows services using NSSM so they
// start automatically on boot as SYSTEM — no manual "Run as Administrator" needed.
app.post('/api/services/install', async (req, res) => {
  const scriptPath = path.join(__dirname, '..', 'install-services.ps1');
  if (!fsSync.existsSync(scriptPath)) {
    return res.status(404).json({
      success: false,
      error: 'install-services.ps1 not found. Make sure the script is in the Tablet Setup folder.',
    });
  }
  try {
    // Run the install script elevated — the bridge must already be running as admin
    // for this to work (powershell Start-Process -Verb RunAs needs an elevated caller)
    const output = await runPS(
      `& '${scriptPath.replace(/'/g, "''")}' *>&1`,
      120000  // 2 minute timeout — includes possible npm build
    );
    const success = output.includes('SETUP COMPLETE') || output.includes('is RUNNING');
    res.json({ success, output, message: success ? 'Services installed and started' : 'Install may have issues — see output' });
  } catch (err) {
    res.json({
      success: false,
      output: err.message,
      error: 'Install script failed. Make sure the bridge is running as Administrator.',
    });
  }
});

// GET /api/services/status
// Returns status of both Windows services
app.get('/api/services/status', async (req, res) => {
  try {
    const output = await runPS(
      `@("EcaAfrica-Bridge","EcaAfrica-Frontend") | ForEach-Object { $s = Get-Service $_ -EA SilentlyContinue; "$_=$(if($s){$s.Status}else{'NotInstalled'})" }`,
      10000
    );
    const lines = output.split('\n').map(l => l.trim()).filter(Boolean);
    const status = {};
    for (const line of lines) {
      const [name, state] = line.split('=');
      if (name && state) status[name.trim()] = state.trim();
    }
    res.json({
      success: true,
      bridgeService: status['EcaAfrica-Bridge'] || 'NotInstalled',
      frontendService: status['EcaAfrica-Frontend'] || 'NotInstalled',
      bothRunning: status['EcaAfrica-Bridge'] === 'Running' && status['EcaAfrica-Frontend'] === 'Running',
    });
  } catch (err) {
    res.json({ success: false, error: err.message, bridgeService: 'Unknown', frontendService: 'Unknown', bothRunning: false });
  }
});

// POST /api/wireguard/deactivate
// Removes the tunnel service (stops VPN).
app.post('/api/wireguard/deactivate', async (req, res) => {
  try {
    await runPS(`& 'C:\\Program Files\\WireGuard\\wireguard.exe' /uninstalltunnelservice ${WIREGUARD_TUNNEL_NAME}`);
    res.json({ success: true, message: 'WireGuard tunnel stopped' });
  } catch (err) {
    const msg = err.message || '';
    // Treat "not found" / "does not exist" as already-stopped — not a real error
    if (/not found|does not exist|0x80070002|cannot find/i.test(msg)) {
      return res.json({ success: true, message: 'Tunnel was already stopped' });
    }
    res.status(500).json({ success: false, error: msg });
  }
});

// POST /api/wireguard/ping
// Runs a Windows ping from the tablet to a VPN IP and returns the output.
// Body: { target: "10.0.0.1" }
app.post('/api/wireguard/ping', async (req, res) => {
  const target = String(req.body?.target || '').trim();
  // Validate: only allow IP address format to prevent command injection
  if (!/^(\d{1,3}\.){3}\d{1,3}$/.test(target) || target.split('.').some(n => Number(n) > 255)) {
    return res.status(400).json({ success: false, output: 'Invalid target IP address' });
  }
  try {
    // Use ping.exe directly â€” avoids PowerShell alias ambiguity.
    // -n 4 = 4 packets, -w 2000 = 2s timeout per packet, -l 32 = 32-byte payload
    const output = await new Promise((resolve, reject) => {
      execFile(
        'ping.exe',
        ['-n', '4', '-w', '2000', '-l', '32', target],
        { timeout: 20000, windowsHide: true },
        (err, stdout, stderr) => {
          // ping.exe exits with non-zero on failure â€” we want the output regardless
          // so we resolve even on error (stderr) to show the user what happened
          const out = (stdout || stderr || (err ? err.message : 'No output')).trim();
          resolve(out);
        }
      );
    });

    const out = String(output);
    // Windows ping success indicators â€” works on EN, FR, DE, and other locales
    // "TTL=" appears in every locale for successful replies
    const success = out.includes('TTL=') || out.includes('ttl=') || out.includes('bytes=');
    res.json({ success, output: out });
  } catch (err) {
    res.json({ success: false, output: err.message });
  }
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
