"use client";

import { FormEvent, useCallback, useEffect, useRef, useMemo, useState } from "react";
import toast from "react-hot-toast";
import {
  FiActivity, FiCheckCircle, FiClock, FiCpu, FiCreditCard,
  FiDatabase, FiDownloadCloud, FiEye, FiEyeOff, FiLock,
  FiRefreshCw, FiServer, FiSettings, FiShield, FiUploadCloud,
  FiUsers, FiWifi, FiWifiOff, FiLoader, FiX, FiChevronRight,
  FiChevronsLeft, FiUserCheck, FiArrowLeft,
} from "react-icons/fi";
import { dashboardApi, deviceApi, studentApi } from "@/lib/api";

const DEV_PASSWORD = "admin1234";

/* ─── Types ─── */
type Stats = { totalStudents: number; totalDevices: number; onlineDevices: number; attendanceToday: number; lateStudents: number; totalLogs: number };
type DeviceStatus = { connected?: boolean; deviceId?: string; ipAddress?: string; port?: number; handle?: number; serialNumber?: string; productName?: string; productCode?: string; users?: number; logs?: number; faces?: number; fingerprints?: number; cards?: number };
type AttendanceLog = { id: string; studentId?: string; studentDeviceId?: string; studentName: string; className?: string; section?: string; deviceId: string; authenticationMethod: string; timestamp: string; status: string };
type Student = { studentId: string; studentDeviceId: string; name: string; className: string; section?: string; assignedDeviceId?: string; biometricMethods?: string[]; deviceUser?: DeviceUser };
type DeviceUser = { userId: string; studentDeviceId: string; name: string; privilege: number; enabled: boolean; biometricMethods: string[] };

const emptyStats: Stats = { totalStudents: 0, totalDevices: 0, onlineDevices: 0, attendanceToday: 0, lateStudents: 0, totalLogs: 0 };
const classes = ["S1","S2","S3","S4","S5 MPC","S5 MEG","S5 PCB","S6 MPC","S6 MEG","S6 PCB"];
type NavView = "dashboard" | "students";

/* ══════════════════ Helper components (defined before main to avoid Turbopack SSR hoisting issues) ══════════════════ */

function NavItem({ icon, label, active = false, onClick }: { icon: React.ReactNode; label: string; active?: boolean; onClick?: () => void }) {
  return (
    <div onClick={onClick} className={`flex cursor-pointer items-center gap-3 rounded-xl px-3 py-2 text-sm font-medium transition select-none
      ${active ? "border border-cyan-500/50 bg-cyan-500/15 text-white" : "text-slate-400 hover:bg-slate-800 hover:text-white"}`}>
      {icon}{label}
    </div>
  );
}

function SideField({ label, value, onChange, placeholder, required = false }: { label: string; value: string; onChange: (v: string) => void; placeholder?: string; required?: boolean }) {
  return (
    <label className="block">
      <span className="mb-0.5 block text-[10px] text-slate-500">{label}</span>
      <input required={required} type="text" value={value} placeholder={placeholder}
        onChange={(e) => onChange(e.target.value)}
        className="w-full rounded-lg border border-slate-700 bg-slate-800/90 px-2.5 py-1.5 text-xs text-slate-100 outline-none placeholder:text-slate-600 focus:border-cyan-400" />
    </label>
  );
}

function SideSelect({ label, value, onChange, options }: { label: string; value: string; onChange: (v: string) => void; options: string[] }) {
  return (
    <label className="block">
      <span className="mb-0.5 block text-[10px] text-slate-500">{label}</span>
      <select value={value} onChange={(e) => onChange(e.target.value)}
        className="w-full rounded-lg border border-slate-700 bg-slate-800/90 px-2.5 py-1.5 text-xs text-slate-100 outline-none focus:border-cyan-400">
        {options.map((o) => <option key={o}>{o}</option>)}
      </select>
    </label>
  );
}

function StatusPill({ status, small = false }: { status: string; small?: boolean }) {
  const s = status.toLowerCase();
  const color = s.includes("late") ? "bg-amber-500/20 text-amber-300" : s.includes("absent") ? "bg-red-500/20 text-red-300" : "bg-green-500/20 text-green-300";
  return <span className={`rounded-full font-medium ${small ? "px-2 py-0.5 text-[10px]" : "px-3 py-1 text-xs"} ${color}`}>{status}</span>;
}

function SummaryTile({ label, value, color }: { label: string; value: string | number; color: string }) {
  const map: Record<string, string> = {
    cyan:    "border-cyan-500/30 bg-cyan-500/10 text-cyan-300",
    emerald: "border-emerald-500/30 bg-emerald-500/10 text-emerald-300",
    amber:   "border-amber-500/30 bg-amber-500/10 text-amber-300",
    indigo:  "border-indigo-500/30 bg-indigo-500/10 text-indigo-300",
    green:   "border-green-500/30 bg-green-500/10 text-green-300",
    red:     "border-red-500/30 bg-red-500/10 text-red-300",
    slate:   "border-slate-600/40 bg-slate-800/50 text-slate-300",
  };
  return (
    <div className={`rounded-xl border p-4 ${map[color] || map.slate}`}>
      <p className="text-xs opacity-60">{label}</p>
      <p className="mt-1 text-2xl font-bold">{value}</p>
    </div>
  );
}

function InfoRow({ label, value, valueClass = "text-slate-200" }: { label: string; value: string; valueClass?: string }) {
  return (
    <div className="flex items-center justify-between border-b border-slate-800 pb-2 last:border-0 last:pb-0">
      <span className="text-slate-500">{label}</span>
      <span className={`font-medium ${valueClass}`}>{value}</span>
    </div>
  );
}

function AutoConnectBadge({ status, attempt }: { status: "connecting"|"connected"|"retrying"; attempt: number }) {
  if (status === "connected") return (
    <span className="flex items-center gap-1.5 rounded-full bg-green-500/20 px-3 py-1 text-sm text-green-300">
      <FiWifi className="shrink-0" /> Online
    </span>
  );
  if (status === "connecting") return (
    <span className="flex animate-pulse items-center gap-1.5 rounded-full bg-cyan-500/20 px-3 py-1 text-sm text-cyan-300">
      <FiLoader className="shrink-0 animate-spin" /> Connecting…
    </span>
  );
  return (
    <span className="flex animate-pulse items-center gap-1.5 rounded-full bg-amber-500/20 px-3 py-1 text-sm text-amber-300">
      <FiWifiOff className="shrink-0" /> Reconnecting{attempt > 0 ? ` #${attempt + 1}` : ""}…
    </span>
  );
}

export default function SmartAttendanceDashboard() {
  /* ── data ── */
  const [stats, setStats]           = useState<Stats>(emptyStats);
  const [device, setDevice]         = useState<DeviceStatus | null>(null);
  const [logs, setLogs]             = useState<AttendanceLog[]>([]);
  const [students, setStudents]     = useState<Student[]>([]);
  const [deviceUsers, setDeviceUsers] = useState<DeviceUser[]>([]);                                                                                                                                                       
  const [busy, setBusy]             = useState(false);
  const [query, setQuery]           = useState("");
  const [readMode, setReadMode]     = useState(0);
  const [activeView, setActiveView] = useState<NavView>("dashboard");

  /* ── device form ── */
  const [deviceForm, setDeviceForm] = useState({ deviceId: "DV-KGL-01", ipAddress: "10.23.194.16", port: 5005, license: 1261, location: "Main Gate" });
  const deviceFormRef = useRef(deviceForm);
  useEffect(() => { deviceFormRef.current = deviceForm; }, [deviceForm]);

  /* ── student form ── */
  const [studentForm, setStudentForm] = useState({ name: "", studentId: "RW-", studentDeviceId: "", className: "S1", section: "A", assignedDeviceId: "DV-KGL-01", parentPhone: "" });

  /* ── live attendance flash ── */
  const [liveLog, setLiveLog] = useState<AttendanceLog | null>(null);
  const liveTimerRef   = useRef<ReturnType<typeof setTimeout> | null>(null);
  const knownLogIds    = useRef<Set<string>>(new Set());
  const sseRef         = useRef<EventSource | null>(null);
  const sseReconnectRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const API_BASE       = process.env.NEXT_PUBLIC_API_URL || "http://localhost:5000";

  // Keep latest handler in a ref so SSE callbacks are never stale
  const onFreshRef = useRef<(logs: AttendanceLog[]) => void>(() => {});

  // Always update the ref when component re-renders
  // Queue of logs waiting to be flashed
  const flashQueueRef = useRef<AttendanceLog[]>([]);

  const showNextFromQueue = useRef<() => void>(() => {});
  showNextFromQueue.current = () => {
    if (flashQueueRef.current.length === 0) {
      setLiveLog(null);
      return;
    }
    const next = flashQueueRef.current.shift()!;
    if (liveTimerRef.current) clearTimeout(liveTimerRef.current);
    setLiveLog(next);
    // After 4s show next in queue, or clear
    liveTimerRef.current = setTimeout(() => showNextFromQueue.current(), 4000);
  };

  onFreshRef.current = (fresh: AttendanceLog[]) => {
    if (fresh.length === 0) return;
    fresh.forEach((l) => knownLogIds.current.add(l.id));
    setLogs((prev) => {
      const ids = new Set(prev.map((l) => l.id));
      return [...fresh.filter((l) => !ids.has(l.id)), ...prev];
    });
    setStats((prev) => ({
      ...prev,
      attendanceToday: prev.attendanceToday + fresh.length,
      totalLogs: prev.totalLogs + fresh.length,
    }));
    // Push all fresh logs into the queue
    flashQueueRef.current.push(...fresh);
    // If nothing is currently showing, start immediately
    // If something is already showing, cancel it and move to next (overwrite)
    if (liveTimerRef.current) clearTimeout(liveTimerRef.current);
    showNextFromQueue.current();
  };

  const seedRef = useRef<(logs: AttendanceLog[]) => void>(() => {});
  seedRef.current = (logs: AttendanceLog[]) => {
    logs.forEach((l) => knownLogIds.current.add(l.id));
    setLogs(logs);
  };

  function dismissLive() {
    if (liveTimerRef.current) clearTimeout(liveTimerRef.current);
    // Skip to next queued student, or clear
    if (flashQueueRef.current.length > 0) {
      showNextFromQueue.current();
    } else {
      setLiveLog(null);
    }
  }

  // Connect SSE — all event handlers call through refs so they're never stale
  function connectSSE() {
    if (sseRef.current) { sseRef.current.close(); sseRef.current = null; }
    if (sseReconnectRef.current) { clearTimeout(sseReconnectRef.current); sseReconnectRef.current = null; }

    const es = new EventSource(`${API_BASE}/api/events`);

    es.addEventListener("init", (e) => {
      try {
        const logs: AttendanceLog[] = JSON.parse((e as MessageEvent).data);
        seedRef.current(logs);
      } catch { /* ignore parse errors */ }
    });

    es.addEventListener("attendance", (e) => {
      try {
        const fresh: AttendanceLog[] = JSON.parse((e as MessageEvent).data);
        onFreshRef.current(fresh);
      } catch { /* ignore parse errors */ }
    });

    es.onerror = () => {
      es.close();
      sseRef.current = null;
      // Reconnect after 3s
      sseReconnectRef.current = setTimeout(connectSSE, 3000);
    };

    sseRef.current = es;
  }

  /* ── sidebar auto-hide ── */
  const [sidebarVisible, setSidebarVisible] = useState(true);
  const [sidebarLocked,  setSidebarLocked]  = useState(false);
  const sidebarTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const resetSidebarTimer = useCallback(() => {
    if (sidebarTimerRef.current) clearTimeout(sidebarTimerRef.current);
    setSidebarVisible(true);
    if (!sidebarLocked) {
      sidebarTimerRef.current = setTimeout(() => setSidebarVisible(false), 10000);
    }
  }, [sidebarLocked]);

  useEffect(() => {
    const evts = ["mousemove","mousedown","keydown","touchstart","scroll"];
    evts.forEach((e) => window.addEventListener(e, resetSidebarTimer, { passive: true }));
    resetSidebarTimer();
    return () => {
      evts.forEach((e) => window.removeEventListener(e, resetSidebarTimer));
      if (sidebarTimerRef.current) clearTimeout(sidebarTimerRef.current);
    };
  }, [resetSidebarTimer]);

  const handleSidebarEnter = () => { setSidebarLocked(true); setSidebarVisible(true); if (sidebarTimerRef.current) clearTimeout(sidebarTimerRef.current); };
  const handleSidebarLeave = () => { setSidebarLocked(false); resetSidebarTimer(); };

  /* ── auto-connect ── */
  const [connectStatus,  setConnectStatus]  = useState<"connecting"|"connected"|"retrying">("connecting");
  const [connectAttempt, setConnectAttempt] = useState(0);
  const autoConnectRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const mountedRef     = useRef(true);

  useEffect(() => {
    mountedRef.current = true;
    connectSSE();
    attemptConnect(0);
    return () => {
      mountedRef.current = false;
      if (autoConnectRef.current) clearTimeout(autoConnectRef.current);
      if (liveTimerRef.current) clearTimeout(liveTimerRef.current);
      if (sseReconnectRef.current) clearTimeout(sseReconnectRef.current);
      if (sseRef.current) { sseRef.current.close(); sseRef.current = null; }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (connectStatus !== "connected") return;
    const iv = setInterval(refreshDashboard, 30000);
    return () => clearInterval(iv);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [connectStatus]);

  async function attemptConnect(attempt: number) {
    if (!mountedRef.current) return;
    setConnectAttempt(attempt);
    setConnectStatus(attempt === 0 ? "connecting" : "retrying");
    if (attempt === 0) toast.loading("Connecting to device...", { id: "ac" });
    try {
      const res = await deviceApi.connect({ ...deviceFormRef.current, timeoutMs: 3000 });
      if (!mountedRef.current) return;
      setDevice(res.data.data);
      setConnectStatus("connected");
      toast.success("Device connected", { id: "ac" });
      await refreshDashboard();
      scheduleReconnectCheck();
    } catch {
      if (!mountedRef.current) return;
      setDevice(null); setConnectStatus("retrying");
      if (attempt === 0 || attempt % 5 === 0) toast.error(`Device unreachable — retrying (attempt ${attempt + 1})...`, { id: "ac" });
      const delay = Math.min(3000 * Math.pow(1.5, Math.min(attempt, 8)), 30000);
      autoConnectRef.current = setTimeout(() => attemptConnect(attempt + 1), delay);
    }
  }

  function scheduleReconnectCheck() {
    autoConnectRef.current = setTimeout(async () => {
      if (!mountedRef.current) return;
      try {
        const res = await deviceApi.getStatus();
        const d: DeviceStatus = res.data.data;
        if (d?.connected) { setDevice(d); setConnectStatus("connected"); scheduleReconnectCheck(); }
        else throw new Error("disconnected");
      } catch {
        if (!mountedRef.current) return;
        setDevice(null); setConnectStatus("retrying");
        toast.error("Device connection lost — reconnecting...", { id: "ac" });
        attemptConnect(0);
      }
    }, 15000);
  }

  const connected = Boolean(device?.connected);

  /* ── developer modal ── */
  const [devStep,          setDevStep]         = useState<"closed"|"password"|"settings">("closed");
  const [devPassword,      setDevPassword]      = useState("");
  const [devPasswordError, setDevPasswordError] = useState("");
  const [showDevPassword,  setShowDevPassword]  = useState(false);
  const [devForm,          setDevForm]          = useState({ ...deviceForm });

  const openDevModal  = () => { setDevPassword(""); setDevPasswordError(""); setShowDevPassword(false); setDevForm({ ...deviceForm }); setDevStep("password"); };
  const closeDevModal = () => { setDevStep("closed"); setDevPassword(""); setDevPasswordError(""); };

  function submitDevPassword(e: FormEvent) {
    e.preventDefault();
    if (devPassword === DEV_PASSWORD) { setDevPasswordError(""); setDevStep("settings"); }
    else { setDevPasswordError("Incorrect password. Try again."); setDevPassword(""); }
  }

  function saveDevSettings(e: FormEvent) {
    e.preventDefault();
    setDeviceForm({ ...devForm });
    closeDevModal();
    toast.success("Settings saved — reconnecting…");
    if (autoConnectRef.current) clearTimeout(autoConnectRef.current);
    setTimeout(() => attemptConnect(0), 100);
  }

  /* ── data actions ── */
  async function refreshDashboard() {
    setBusy(true);
    try {
      const [sR, stR] = await Promise.allSettled([dashboardApi.getStats(), studentApi.getAll()]);
      if (sR.status  === "fulfilled") setStats(sR.value.data.stats || emptyStats);
      if (stR.status === "fulfilled") setStudents(stR.value.data.students || []);
    } finally { setBusy(false); }
  }

  async function pullLogs() {
    setBusy(true); toast.loading("Pulling logs…", { id: "logs" });
    try { const r = await deviceApi.pullLogs(readMode); toast.success(`Cached: ${r.data.data?.count || 0} logs`, { id: "logs" }); await refreshDashboard(); }
    catch (e: any) { toast.error(e?.response?.data?.error || "Pull logs failed", { id: "logs" }); }
    finally { setBusy(false); }
  }

  async function pullUsers() {
    setBusy(true); toast.loading("Pulling users…", { id: "users" });
    try { await deviceApi.pullUsers(); const r = await deviceApi.getUsers(); setDeviceUsers(r.data.data?.users || []); toast.success(`Cached: ${r.data.data?.count || 0} users`, { id: "users" }); }
    catch (e: any) { toast.error(e?.response?.data?.error || "Pull users failed", { id: "users" }); }
    finally { setBusy(false); }
  }

  async function syncTime() {
    setBusy(true);
    try { await deviceApi.syncTime(); toast.success("Time synced"); }
    catch (e: any) { toast.error(e?.response?.data?.error || "Sync failed"); }
    finally { setBusy(false); }
  }

  async function registerStudent(event: FormEvent) {
    event.preventDefault(); setBusy(true); toast.loading("Registering…", { id: "stu" });
    try {
      const r = await studentApi.create({ ...studentForm, pushToDevice: true });
      if (!r.data.success) throw new Error(r.data.error || "Push failed");
      toast.success("Registered & pushed to device", { id: "stu" });
      setStudentForm({ ...studentForm, name: "", studentId: "RW-", studentDeviceId: "", parentPhone: "" });
      await pullUsers(); await refreshDashboard();
    } catch (e: any) { toast.error(e?.response?.data?.error || e?.message || "Registration failed", { id: "stu" }); }
    finally { setBusy(false); }
  }

  async function pushAllStudents() {
    setBusy(true); toast.loading("Pushing all students…", { id: "push" });
    try { const r = await deviceApi.pushStudents(); toast.success(`Pushed ${r.data.data?.pushed || 0} students`, { id: "push" }); await pullUsers(); }
    catch (e: any) { toast.error(e?.response?.data?.error || "Push failed", { id: "push" }); }
    finally { setBusy(false); }
  }

  const filteredLogs = useMemo(() => {
    if (!query) return logs;
    const q = query.toLowerCase();
    return logs.filter((l) => `${l.studentName} ${l.studentId} ${l.className}`.toLowerCase().includes(q));
  }, [logs, query]);

  /* ─── RENDER ─── */
  return (
    <div className="fixed inset-0 flex overflow-hidden bg-[#070b14]">

      {/* ══════════════ SIDEBAR ══════════════ */}
      {!sidebarVisible && (
        <button
          onClick={() => { setSidebarVisible(true); resetSidebarTimer(); }}
          className="fixed left-0 top-1/2 -translate-y-1/2 z-40 flex items-center rounded-r-xl border border-l-0 border-slate-700 bg-slate-900/95 px-2 py-5 text-slate-400 hover:text-cyan-400 shadow-xl transition"
        >
          <FiChevronRight />
        </button>
      )}

      <aside
        onMouseEnter={handleSidebarEnter}
        onMouseLeave={handleSidebarLeave}
        className={`flex flex-col shrink-0 border-r border-slate-800 bg-slate-900/95 backdrop-blur-sm
          transition-all duration-500 ease-in-out overflow-hidden
          ${sidebarVisible ? "w-72 opacity-100" : "w-0 opacity-0 pointer-events-none"}`}
      >
        <div className="flex h-full w-72 flex-col p-4">

          {/* Brand + collapse */}
          <div className="mb-5 flex items-center justify-between">
            <h1 className="text-lg font-bold text-cyan-400">SmartAttend FK</h1>
            <button onClick={() => { setSidebarVisible(false); if (sidebarTimerRef.current) clearTimeout(sidebarTimerRef.current); }}
              className="rounded-lg p-1.5 text-slate-500 hover:bg-slate-800 hover:text-white transition">
              <FiChevronsLeft />
            </button>
          </div>

          {/* Nav tabs */}
          <nav className="mb-4 space-y-1 text-sm">
            <NavItem active={activeView === "dashboard"} onClick={() => setActiveView("dashboard")} icon={<FiActivity />} label="Dashboard" />
            <NavItem active={activeView === "students"}  onClick={() => setActiveView("students")}  icon={<FiUsers />}    label="Students" />
            <NavItem icon={<FiServer />}   label="Devices" />
            <NavItem icon={<FiCpu />}      label="Biometrics" />
            <NavItem icon={<FiRefreshCw />} label="Device Sync" />
            <NavItem icon={<FiShield />}   label="Users & Roles" />
          </nav>

          {/* ── Sidebar panel content switches per view ── */}
          {activeView === "dashboard" && (
            <div className="flex flex-1 flex-col min-h-0">
              {/* Attendance logs header */}
              <div className="mb-2 flex items-center justify-between">
                <span className="flex items-center gap-1.5 text-xs font-semibold uppercase tracking-wide text-slate-400">
                  <FiDatabase className="text-cyan-400" /> Logs
                </span>
                <div className="flex items-center gap-1.5">
                  <select value={readMode} onChange={(e) => setReadMode(Number(e.target.value))}
                    className="rounded-lg border border-slate-700 bg-slate-800 px-2 py-1 text-xs text-slate-300 outline-none">
                    <option value={0}>All</option>
                    <option value={1}>New</option>
                  </select>
                  <button onClick={pullLogs} disabled={busy || !connected} title="Pull logs"
                    className="rounded-lg border border-slate-700 bg-slate-800 p-1.5 text-slate-400 hover:border-cyan-500 hover:text-cyan-400 disabled:opacity-40 transition">
                    <FiDownloadCloud className="text-sm" />
                  </button>
                </div>
              </div>
              <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search…"
                className="mb-2 w-full rounded-xl border border-slate-700 bg-slate-800/90 px-3 py-2 text-xs text-slate-100 outline-none placeholder:text-slate-500 focus:border-cyan-400" />
              <div className="flex-1 overflow-y-auto space-y-2 pr-0.5">
                {filteredLogs.length === 0
                  ? <p className="pt-8 text-center text-xs text-slate-600">No logs yet — pull from device</p>
                  : filteredLogs.map((log) => (
                    <div key={log.id} className="rounded-xl border border-slate-800 bg-slate-800/60 p-3 text-xs">
                      <div className="flex items-center justify-between gap-1">
                        <span className="font-semibold text-slate-100 truncate">{log.studentName}</span>
                        <StatusPill status={log.status} small />
                      </div>
                      <div className="mt-0.5 text-slate-400">{log.studentId || log.studentDeviceId}{log.className ? ` · ${log.className}` : ""}</div>
                      <div className="mt-0.5 flex justify-between text-slate-500">
                        <span>{log.authenticationMethod}</span>
                        <span>{new Date(log.timestamp).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}</span>
                      </div>
                    </div>
                  ))
                }
              </div>
            </div>
          )}

          {activeView === "students" && (
            <div className="flex flex-1 flex-col min-h-0 overflow-y-auto space-y-4 pr-0.5">
              {/* Registration form */}
              <div>
                <div className="mb-2 flex items-center justify-between">
                  <span className="text-xs font-semibold uppercase tracking-wide text-slate-400">Register Student</span>
                  <button onClick={pushAllStudents} disabled={busy || !connected}
                    className="flex items-center gap-1 rounded-lg bg-emerald-600/80 px-2 py-1 text-xs font-medium text-white hover:bg-emerald-500 disabled:opacity-40 transition">
                    <FiUploadCloud className="text-xs" /> Sync All
                  </button>
                </div>
                <form onSubmit={registerStudent} className="space-y-2">
                  <SideField label="Full Name"   value={studentForm.name}           onChange={(v) => setStudentForm({ ...studentForm, name: v })} required />
                  <SideField label="Student ID"  value={studentForm.studentId}      onChange={(v) => setStudentForm({ ...studentForm, studentId: v.toUpperCase() })} placeholder="RW-0001" required />
                  <SideField label="Device ID"   value={studentForm.studentDeviceId} onChange={(v) => setStudentForm({ ...studentForm, studentDeviceId: v })} placeholder="1001" required />
                  <SideField label="Parent Phone" value={studentForm.parentPhone}   onChange={(v) => setStudentForm({ ...studentForm, parentPhone: v })} />
                  <SideSelect label="Class" value={studentForm.className} onChange={(v) => setStudentForm({ ...studentForm, className: v })} options={classes} />
                  <SideField label="Section" value={studentForm.section} onChange={(v) => setStudentForm({ ...studentForm, section: v })} />
                  <button disabled={busy || !connected} className="mt-1 w-full rounded-xl bg-cyan-500 py-2 text-xs font-bold text-slate-950 hover:bg-cyan-300 disabled:opacity-40 transition">
                    Register &amp; Push
                  </button>
                </form>
              </div>
              {/* Device users */}
              <div>
                <div className="mb-2 flex items-center justify-between">
                  <span className="text-xs font-semibold uppercase tracking-wide text-slate-400">Device Users</span>
                  <button onClick={pullUsers} disabled={busy || !connected}
                    className="rounded-lg border border-slate-700 bg-slate-800 p-1.5 text-slate-400 hover:border-cyan-500 hover:text-cyan-400 disabled:opacity-40 transition">
                    <FiDownloadCloud className="text-sm" />
                  </button>
                </div>
                {deviceUsers.length === 0
                  ? <p className="text-center text-xs text-slate-600 py-4">Pull users to see biometric data</p>
                  : deviceUsers.map((u) => (
                    <div key={u.userId} className="mb-2 rounded-xl border border-slate-800 bg-slate-800/60 p-3 text-xs">
                      <div className="flex items-center justify-between">
                        <span className="font-semibold text-slate-100 truncate">{u.name || `User ${u.userId}`}</span>
                        <span className={`rounded-full px-2 py-0.5 text-[10px] ${u.enabled ? "bg-green-500/20 text-green-300" : "bg-red-500/20 text-red-300"}`}>{u.enabled ? "Active" : "Off"}</span>
                      </div>
                      <div className="mt-0.5 text-slate-500">ID: {u.userId}</div>
                      <div className="mt-1 flex flex-wrap gap-1">
                        {u.biometricMethods.map((m) => <span key={m} className="rounded-full bg-slate-900 px-2 py-0.5 text-[10px] text-slate-400">{m}</span>)}
                      </div>
                    </div>
                  ))
                }
              </div>
            </div>
          )}

          {/* Developer button */}
          <div className="mt-3 border-t border-slate-800 pt-3">
            <button type="button" onClick={openDevModal}
              className="group flex w-full items-center gap-2 rounded-xl border border-slate-700/40 bg-slate-800/30 px-3 py-1.5 text-slate-600 transition-all duration-300 hover:border-amber-500/40 hover:bg-amber-500/10 hover:py-3 hover:text-amber-300">
              <FiSettings className="shrink-0 text-sm transition-transform duration-300 group-hover:rotate-45 group-hover:text-base" />
              <span className="text-[11px] font-medium transition-all duration-300 group-hover:text-xs">Developer</span>
            </button>
          </div>
        </div>
      </aside>

      {/* ══════════════ MAIN AREA ══════════════ */}
      <main className="relative flex flex-1 flex-col overflow-hidden">

        {/* ── LIVE ATTENDANCE FLASH (takes over whole main area) ── */}
        {liveLog && (
          <LiveAttendanceScreen log={liveLog} onDismiss={dismissLive} />
        )}

        {/* ── NORMAL DASHBOARD (hidden while flash is showing) ── */}
        {!liveLog && (
          <div className="flex h-full flex-col overflow-hidden">

            {/* Top bar */}
            <div className="flex shrink-0 items-center justify-between border-b border-slate-800 bg-slate-900/80 px-6 py-3 backdrop-blur-sm">
              <div>
                <h2 className="text-xl font-bold text-white">School Attendance Monitoring</h2>
                <p className="text-xs text-slate-500">FK biometric · real-time tracking</p>
              </div>
              <div className="flex items-center gap-3">
                <AutoConnectBadge status={connectStatus} attempt={connectAttempt} />
                <button onClick={() => { if (autoConnectRef.current) clearTimeout(autoConnectRef.current); attemptConnect(0); }}
                  disabled={connectStatus === "connecting"}
                  className="flex items-center gap-1.5 rounded-lg border border-slate-700 bg-slate-800 px-3 py-1.5 text-xs text-slate-300 hover:bg-slate-700 disabled:opacity-50 transition">
                  <FiRefreshCw className={connectStatus === "connecting" ? "animate-spin" : ""} /> Reconnect
                </button>
              </div>
            </div>

            {/* Content — fills remaining height, no scroll */}
            <div className="flex flex-1 flex-col overflow-hidden p-5 gap-5">

              {/* Stat cards row */}
              <div className="grid shrink-0 grid-cols-2 gap-4 xl:grid-cols-4">
                {[
                  { title: "Total Students",    value: stats.totalStudents,  icon: FiUsers,     tone: "text-cyan-300 bg-cyan-500/15" },
                  { title: "Attendance Today",  value: stats.attendanceToday, icon: FiUserCheck, tone: "text-emerald-300 bg-emerald-500/15" },
                  { title: "Devices",           value: `${stats.onlineDevices}/${stats.totalDevices}`,
                    icon: connectStatus === "connected" ? FiWifi : connectStatus === "connecting" ? FiLoader : FiWifiOff,
                    tone: connectStatus === "connected" ? "text-green-300 bg-green-500/15" : connectStatus === "connecting" ? "text-cyan-300 bg-cyan-500/15" : "text-red-300 bg-red-500/15" },
                  { title: "Late Students",     value: stats.lateStudents,   icon: FiClock,     tone: "text-amber-300 bg-amber-500/15" },
                ].map((c) => (
                  <div key={c.title} className="metric-card">
                    <div className="flex items-center justify-between">
                      <div><p className="text-sm text-slate-400">{c.title}</p><p className="mt-1 text-3xl font-bold">{c.value}</p></div>
                      <div className={`rounded-xl p-3 text-2xl ${c.tone}`}><c.icon /></div>
                    </div>
                  </div>
                ))}
              </div>

              {/* Bottom row — summary + device status, fills remaining space */}
              <div className="flex flex-1 min-h-0 gap-5">

                {/* Today summary */}
                <div className="dashboard-panel flex-1 min-w-0 p-5 flex flex-col">
                  <h3 className="mb-4 shrink-0 text-base font-bold">Today's Summary</h3>
                  <div className="grid flex-1 grid-cols-2 gap-3 sm:grid-cols-3 content-start">
                    <SummaryTile label="Total registered"  value={stats.totalStudents}  color="cyan" />
                    <SummaryTile label="Checked in today"  value={stats.attendanceToday} color="emerald" />
                    <SummaryTile label="Late arrivals"     value={stats.lateStudents}    color="amber" />
                    <SummaryTile label="Total log entries" value={stats.totalLogs}       color="indigo" />
                    <SummaryTile label="Device online"     value={stats.onlineDevices > 0 ? "Yes" : "No"} color={stats.onlineDevices > 0 ? "green" : "red"} />
                    <SummaryTile label="Not checked in"    value={Math.max(0, stats.totalStudents - stats.attendanceToday)} color="slate" />
                  </div>
                </div>

                {/* Device status */}
                <div className="dashboard-panel w-72 shrink-0 p-5 flex flex-col">
                  <h3 className="mb-3 shrink-0 text-base font-bold">Device Status</h3>
                  <div className="flex-1 space-y-3 text-sm">
                    <InfoRow label="IP Address" value={deviceForm.ipAddress} />
                    <InfoRow label="Location"   value={deviceForm.location} />
                    <InfoRow label="Status" value={connected ? "Online" : connectStatus === "connecting" ? "Connecting…" : "Offline"} valueClass={connected ? "text-green-400" : "text-amber-400"} />
                    {device?.serialNumber && <InfoRow label="Serial"   value={device.serialNumber} />}
                    {(device?.productName || device?.productCode) && <InfoRow label="Product" value={device.productName || device.productCode || ""} />}
                    {device?.users != null && <InfoRow label="Users"   value={String(device.users)} />}
                  </div>
                  <div className="mt-4 flex shrink-0 gap-2">
                    <button onClick={pullUsers} disabled={busy || !connected} className="secondary-action flex-1 py-2 text-xs">Pull Users</button>
                    <button onClick={syncTime}  disabled={busy || !connected} className="secondary-action flex-1 py-2 text-xs">Sync Time</button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>

      {/* ══════════ DEVELOPER PASSWORD MODAL ══════════ */}
      {devStep === "password" && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4 backdrop-blur-sm">
          <div className="w-full max-w-sm rounded-2xl border border-slate-700 bg-slate-900 p-8 shadow-2xl">
            <div className="mb-6 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="rounded-xl bg-cyan-500/15 p-3 text-cyan-400"><FiLock className="text-xl" /></div>
                <h2 className="text-xl font-bold">Developer Access</h2>
              </div>
              <button type="button" onClick={closeDevModal} className="rounded-lg p-2 text-slate-400 hover:bg-slate-800 hover:text-white"><FiX /></button>
            </div>
            <form onSubmit={submitDevPassword} className="space-y-4">
              <div>
                <label className="mb-1.5 block text-sm text-slate-400">Password</label>
                <div className="relative">
                  <input autoFocus type={showDevPassword ? "text" : "password"} value={devPassword}
                    onChange={(e) => { setDevPassword(e.target.value); setDevPasswordError(""); }}
                    placeholder="Enter developer password" className="form-field pr-10" />
                  <button type="button" onClick={() => setShowDevPassword(v => !v)} className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-white">
                    {showDevPassword ? <FiEyeOff /> : <FiEye />}
                  </button>
                </div>
                {devPasswordError && <p className="mt-1.5 text-sm text-red-400">{devPasswordError}</p>}
              </div>
              <button type="submit" className="primary-action w-full py-3">Unlock</button>
            </form>
          </div>
        </div>
      )}

      {/* ══════════ DEVELOPER SETTINGS MODAL ══════════ */}
      {devStep === "settings" && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4 backdrop-blur-sm">
          <div className="w-full max-w-lg rounded-2xl border border-slate-700 bg-slate-900 p-8 shadow-2xl">
            <div className="mb-6 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="rounded-xl bg-amber-500/15 p-3 text-amber-400"><FiSettings className="text-xl" /></div>
                <div>
                  <h2 className="text-xl font-bold">Device Configuration</h2>
                  <p className="text-sm text-slate-400">Changes take effect immediately on save</p>
                </div>
              </div>
              <button type="button" onClick={closeDevModal} className="rounded-lg p-2 text-slate-400 hover:bg-slate-800 hover:text-white"><FiX /></button>
            </div>
            <form onSubmit={saveDevSettings} className="space-y-5">
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div className="sm:col-span-2">
                  <label className="mb-1.5 block text-sm text-slate-400">IP Address</label>
                  <input required type="text" value={devForm.ipAddress} onChange={(e) => setDevForm({ ...devForm, ipAddress: e.target.value })} placeholder="192.168.1.118" className="form-field" />
                </div>
                <div><label className="mb-1.5 block text-sm text-slate-400">Port</label><input required type="number" value={devForm.port} onChange={(e) => setDevForm({ ...devForm, port: Number(e.target.value) })} className="form-field" /></div>
                <div><label className="mb-1.5 block text-sm text-slate-400">License</label><input required type="number" value={devForm.license} onChange={(e) => setDevForm({ ...devForm, license: Number(e.target.value) })} className="form-field" /></div>
                <div><label className="mb-1.5 block text-sm text-slate-400">Device ID</label><input type="text" value={devForm.deviceId} onChange={(e) => setDevForm({ ...devForm, deviceId: e.target.value })} className="form-field" /></div>
                <div><label className="mb-1.5 block text-sm text-slate-400">Location</label><input type="text" value={devForm.location} onChange={(e) => setDevForm({ ...devForm, location: e.target.value })} className="form-field" /></div>
              </div>
              {connected && device && (
                <div className="rounded-xl border border-slate-700 bg-slate-800/60 p-4">
                  <p className="mb-3 text-xs font-semibold uppercase tracking-wide text-slate-500">Live Device Info</p>
                  <div className="grid grid-cols-2 gap-3 text-sm">
                    <div><p className="text-slate-500">Serial</p><p className="font-medium text-slate-200">{device.serialNumber || "—"}</p></div>
                    <div><p className="text-slate-500">Product</p><p className="font-medium text-slate-200">{device.productName || device.productCode || "—"}</p></div>
                    <div><p className="text-slate-500">Users</p><p className="font-medium text-slate-200">{device.users ?? "—"}</p></div>
                    <div><p className="text-slate-500">Logs</p><p className="font-medium text-slate-200">{device.logs ?? "—"}</p></div>
                  </div>
                </div>
              )}
              <div className="flex gap-3">
                <button type="submit" className="primary-action flex-1 py-3">Save &amp; Reconnect</button>
                <button type="button" onClick={closeDevModal} className="secondary-action flex-1 py-3">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

/* ══════════════════════════════════════════════
   LIVE ATTENDANCE FULL-SCREEN FLASH
══════════════════════════════════════════════ */
function LiveAttendanceScreen({ log, onDismiss }: { log: AttendanceLog; onDismiss: () => void }) {
  const [visible, setVisible] = useState(false);
  const [progress, setProgress] = useState(100);

  useEffect(() => {
    const t = setTimeout(() => setVisible(true), 40);
    // Animate the countdown bar over 10s
    const start = Date.now();
    const tick = setInterval(() => {
      const elapsed = Date.now() - start;
      setProgress(Math.max(0, 100 - (elapsed / 4000) * 100));
    }, 50);
    return () => { clearTimeout(t); clearInterval(tick); };
  }, []);

  const method = log.authenticationMethod || "Unknown";
  const s = (log.status || "").toLowerCase();
  const isLate   = s.includes("late");
  const isAbsent = s.includes("absent");

  const methodIcon =
    method.toLowerCase().includes("face")   ? "🪪" :
    method.toLowerCase().includes("finger") ? "👆" :
    method.toLowerCase().includes("card")   ? "💳" :
    method.toLowerCase().includes("pin") || method.toLowerCase().includes("pass") ? "🔑" : "✅";

  const accentColor = isLate ? "from-amber-500/20 via-slate-900 to-slate-900 border-amber-500/40" :
                      isAbsent ? "from-red-500/20 via-slate-900 to-slate-900 border-red-500/40" :
                      "from-emerald-500/20 via-slate-900 to-slate-900 border-emerald-500/40";

  const barColor = isLate ? "bg-amber-500" : isAbsent ? "bg-red-500" : "bg-emerald-500";
  const glowColor = isLate ? "shadow-amber-500/20" : isAbsent ? "shadow-red-500/20" : "shadow-emerald-500/20";

  return (
    <div className={`absolute inset-0 z-30 flex flex-col items-center justify-center bg-gradient-to-br ${accentColor}
      transition-all duration-700 ease-out ${visible ? "opacity-100 scale-100" : "opacity-0 scale-95"}`}>

      {/* Dismiss button */}
      <button onClick={onDismiss} className="absolute right-6 top-6 rounded-xl border border-slate-700 bg-slate-800/80 p-2.5 text-slate-400 hover:text-white transition">
        <FiX className="text-lg" />
      </button>

      {/* Back button */}
      <button onClick={onDismiss} className="absolute left-6 top-6 flex items-center gap-2 rounded-xl border border-slate-700 bg-slate-800/80 px-4 py-2.5 text-sm text-slate-400 hover:text-white transition">
        <FiArrowLeft /> Back to dashboard
      </button>

      {/* Central card */}
      <div className={`relative w-full max-w-lg rounded-3xl border bg-slate-900/95 p-10 shadow-2xl ${glowColor} shadow-2xl ${accentColor.split(" ")[2]}`}
        style={{ borderColor: isLate ? "rgba(245,158,11,0.4)" : isAbsent ? "rgba(239,68,68,0.4)" : "rgba(16,185,129,0.4)" }}>

        {/* Method icon */}
        <div className="mb-6 flex justify-center">
          <div className={`flex h-24 w-24 items-center justify-center rounded-full border-4 text-5xl shadow-xl
            ${isLate ? "border-amber-500/50 bg-amber-500/10" : isAbsent ? "border-red-500/50 bg-red-500/10" : "border-emerald-500/50 bg-emerald-500/10"}`}>
            {methodIcon}
          </div>
        </div>

        {/* Student info */}
        <div className="text-center">
          <p className="text-4xl font-extrabold tracking-tight text-white">{log.studentName}</p>
          <p className="mt-2 text-lg text-slate-400">{log.studentId || log.studentDeviceId}</p>
          {log.className && (
            <p className="mt-1 text-slate-500">{log.className}{log.section ? ` · Section ${log.section}` : ""}</p>
          )}
        </div>

        {/* Status badge */}
        <div className="mt-6 flex justify-center">
          <span className={`rounded-full px-6 py-2 text-lg font-bold
            ${isLate ? "bg-amber-500/20 text-amber-300" : isAbsent ? "bg-red-500/20 text-red-300" : "bg-emerald-500/20 text-emerald-300"}`}>
            {log.status}
          </span>
        </div>

        {/* Details grid */}
        <div className="mt-8 grid grid-cols-2 gap-4 text-sm">
          <div className="rounded-xl border border-slate-800 bg-slate-800/60 p-4 text-center">
            <p className="text-xs text-slate-500 uppercase tracking-wide mb-1">Method</p>
            <p className="font-semibold text-slate-200">{method}</p>
          </div>
          <div className="rounded-xl border border-slate-800 bg-slate-800/60 p-4 text-center">
            <p className="text-xs text-slate-500 uppercase tracking-wide mb-1">Time</p>
            <p className="font-semibold text-slate-200">
              {new Date(log.timestamp).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" })}
            </p>
          </div>
          <div className="rounded-xl border border-slate-800 bg-slate-800/60 p-4 text-center">
            <p className="text-xs text-slate-500 uppercase tracking-wide mb-1">Date</p>
            <p className="font-semibold text-slate-200">
              {new Date(log.timestamp).toLocaleDateString([], { weekday: "short", month: "short", day: "numeric" })}
            </p>
          </div>
          <div className="rounded-xl border border-slate-800 bg-slate-800/60 p-4 text-center">
            <p className="text-xs text-slate-500 uppercase tracking-wide mb-1">Device</p>
            <p className="font-semibold text-slate-200 truncate">{log.deviceId || "—"}</p>
          </div>
        </div>

        {/* Approval line */}
        <div className="mt-6 flex items-center justify-center gap-2 text-sm">
          <FiCheckCircle className={`text-lg ${isLate ? "text-amber-400" : isAbsent ? "text-red-400" : "text-emerald-400"}`} />
          <span className="text-slate-300">Attendance recorded &amp; approved</span>
        </div>

        {/* Countdown bar */}
        <div className="mt-6 h-1.5 w-full overflow-hidden rounded-full bg-slate-700">
          <div
            className={`h-full rounded-full transition-none ${barColor}`}
            style={{ width: `${progress}%` }}
          />
        </div>
        <p className="mt-1.5 text-center text-xs text-slate-600">Auto-returns to dashboard in a moment</p>
      </div>
    </div>
  );
}
