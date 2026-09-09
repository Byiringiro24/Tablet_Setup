"use client";

import { FormEvent, useCallback, useEffect, useRef, useState } from "react";
import toast from "react-hot-toast";
import {
  FiActivity, FiCheckCircle, FiDatabase, FiDownloadCloud,
  FiEye, FiEyeOff, FiLock, FiRefreshCw, FiServer,
  FiSettings, FiShield, FiUploadCloud, FiUsers, FiLoader,
  FiX, FiChevronsLeft, FiUserCheck, FiWifi, FiWifiOff,
  FiCopy, FiTerminal, FiAlertTriangle, FiExternalLink,
  FiChevronRight,
} from "react-icons/fi";
import {
  dashboardApi, deviceApi, studentApi,
  wireguardApi, schoolApi,
} from "@/lib/api";
import type {
  NavView, Stats, DeviceStatus,
  AttendanceLog, Student, DeviceUser,
} from "@/components/types";
import {
  NavItem, SideField, SideSelect,
  StatusPill, SummaryTile, InfoRow, AutoConnectBadge,
} from "@/components/ui";
import GateKeeperPanel       from "@/components/GateKeeperPanel";
import ManualAttendancePanel  from "@/components/ManualAttendancePanel";
import UsersPanel             from "@/components/UsersPanel";
import LiveAttendanceScreen   from "@/components/LiveAttendanceScreen";
import WireguardWizard        from "@/components/WireguardWizard";

/* Constants */

const DEV_PASSWORD = "admin1234";
const WG_SERVER_ENDPOINT_DEFAULT = "169.58.124.150:51820";
const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:5000";
const emptyStats: Stats = {
  totalStudents: 0, totalDevices: 0, onlineDevices: 0,
  attendanceToday: 0, lateStudents: 0, totalLogs: 0,
};
const CLASS_LIST = [
  "S1","S2","S3","S4",
  "S5 MPC","S5 MEG","S5 PCB",
  "S6 MPC","S6 MEG","S6 PCB",
];

  /* WireGuard wizard helpers */

type WgStatus = {
  installed: boolean;
  isAdmin: boolean;
  tunnelActive: boolean;
  vpnIp: string | null;
  publicKey: string | null;
  lastHandshake: string | null;
};

/* 
   MAIN COMPONENT
 */

export default function SmartAttendanceDashboard() {

  /* Core state */
  const [stats,      setStats]      = useState<Stats>(emptyStats);
  const [device,     setDevice]     = useState<DeviceStatus | null>(null);
  const [logs,       setLogs]       = useState<AttendanceLog[]>([]);
  const [students,   setStudents]   = useState<Student[]>([]);
  const [deviceUsers,setDeviceUsers]= useState<DeviceUser[]>([]);
  const [busy,       setBusy]       = useState(false);
  const [query,      setQuery]      = useState("");
  const [readMode,   setReadMode]   = useState(0);
  const [activeView, setActiveView] = useState<NavView>("dashboard");
  const [connected,  setConnected]  = useState(false);

  /* Live flash */
  const [liveLog,    setLiveLog]    = useState<AttendanceLog | null>(null);
  const flashQueueRef = useRef<AttendanceLog[]>([]);
  const liveTimerRef  = useRef<ReturnType<typeof setTimeout> | null>(null);
  const knownLogIds   = useRef<Set<string>>(new Set());

  const showNextFromQueue = useRef(() => {
    const next = flashQueueRef.current.shift();
    if (!next) { setLiveLog(null); return; }
    setLiveLog(next);
    liveTimerRef.current = setTimeout(() => showNextFromQueue.current(), 4000);
  });

  /* School auth helpers */
  const [schoolUser,      setSchoolUser]      = useState<any>(null);
  const [schoolLoggedIn,  setSchoolLoggedIn]  = useState(false);
  const [showSchoolLogin, setShowSchoolLogin] = useState(false);
  const [loginPending,    setLoginPending]    = useState<NavView | null>(null);
  const [loginEmail,      setLoginEmail]      = useState("");
  const [loginPassword,   setLoginPassword]   = useState("");
  const [loginError,      setLoginError]      = useState("");
  const [loginBusy,       setLoginBusy]       = useState(false);

  /*  Device config  */
  const [deviceForm, setDeviceForm] = useState({
    deviceId:  "DV-KGL-01",
    ipAddress: "10.23.194.16",
    port:      5005,
    license:   1261,
    location:  "Main Gate",
  });
  const deviceFormRef = useRef(deviceForm);
  useEffect(() => { deviceFormRef.current = deviceForm; }, [deviceForm]);

  /* SSE + auto-connect */
  const sseRef           = useRef<EventSource | null>(null);
  const sseReconnectRef  = useRef<ReturnType<typeof setTimeout> | null>(null);
  const autoConnectRef   = useRef<ReturnType<typeof setTimeout> | null>(null);
  const mountedRef       = useRef(true);
  const [connectStatus,  setConnectStatus]  = useState<"connecting"|"connected"|"retrying">("connecting");
  const [connectAttempt, setConnectAttempt] = useState(0);

  /*  Student form  */
  const [studentForm, setStudentForm] = useState({
    name: "", studentId: "", studentDeviceId: "",
    className: CLASS_LIST[0], section: "",
    assignedDeviceId: "", parentPhone: "",
  });

  /* Dev modal helpers */
  const [devStep,         setDevStep]         = useState<"closed"|"password"|"settings"|"wireguard">("closed");
  const [devPendingAction,setDevPendingAction] = useState<"settings"|"wireguard">("settings");
  const [devPassword,     setDevPassword]     = useState("");
  const [devPasswordError,setDevPasswordError]= useState("");
  const [showDevPassword, setShowDevPassword] = useState(false);
  const [devForm,         setDevForm]         = useState({ ...deviceForm });

  /* WireGuard wizard helpers */
  const [wgStatus,     setWgStatus]     = useState<WgStatus | null>(null);
  const [wgStep,       setWgStep]       = useState<1|2|3|4|5>(1);
  const [wgBusy,       setWgBusy]       = useState(false);
  const [wgError,      setWgError]      = useState("");
  const [wgKeys,       setWgKeys]       = useState<{privateKey:string;publicKey:string}|null>(null);
  const [wgAllowedIPs, setWgAllowedIPs] = useState("10.0.0.0/16");
  const [wgForm,       setWgForm]       = useState({
    serverPublicKey: "", serverEndpoint: WG_SERVER_ENDPOINT_DEFAULT,
    vpnIp: "10.0.0.2", dns: "1.1.1.1",
  });
  const [wgPingTarget, setWgPingTarget]  = useState("10.0.0.1");
  const [wgPingResult, setWgPingResult]  = useState<{success:boolean;output:string}|null>(null);
  const [wgInstalled,  setWgInstalled]   = useState(false);
  const [wgDiagnosis,  setWgDiagnosis]   = useState<any>(null);
  const [wgDiagBusy,   setWgDiagBusy]   = useState(false);
  const [svcStatus,    setSvcStatus]     = useState<{bridgeService:string;frontendService:string;bothRunning:boolean}|null>(null);
  const [svcInstalling,setSvcInstalling] = useState(false);
  const [copiedKey,    setCopiedKey]     = useState(false);

  /* Sidebar visibility */
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
    evts.forEach(e => window.addEventListener(e, resetSidebarTimer, { passive: true }));
    resetSidebarTimer();
    return () => {
      evts.forEach(e => window.removeEventListener(e, resetSidebarTimer));
      if (sidebarTimerRef.current) clearTimeout(sidebarTimerRef.current);
    };
  }, [resetSidebarTimer]);

  const handleSidebarEnter = () => {
    setSidebarLocked(true); setSidebarVisible(true);
    if (sidebarTimerRef.current) clearTimeout(sidebarTimerRef.current);
  };
  const handleSidebarLeave = () => { setSidebarLocked(false); resetSidebarTimer(); };

  /* SSE + auto-connect */
  const onFreshRef = useRef<(logs: AttendanceLog[]) => void>(() => {});
  onFreshRef.current = (fresh: AttendanceLog[]) => {
    const deduped = fresh.filter(l => !knownLogIds.current.has(l.id));
    if (!deduped.length) return;
    deduped.forEach(l => knownLogIds.current.add(l.id));
    setLogs(prev => [...deduped, ...prev].slice(0, 200));
    setStats(prev => ({
      ...prev,
      attendanceToday: prev.attendanceToday + deduped.length,
      totalLogs:       prev.totalLogs + deduped.length,
    }));
    flashQueueRef.current.push(...deduped);
    if (liveTimerRef.current) clearTimeout(liveTimerRef.current);
    showNextFromQueue.current();
  };

  const seedRef = useRef<(logs: AttendanceLog[]) => void>(() => {});
  seedRef.current = (logs: AttendanceLog[]) => {
    logs.forEach(l => knownLogIds.current.add(l.id));
    setLogs(logs);
  };

  function dismissLive() {
    if (liveTimerRef.current) clearTimeout(liveTimerRef.current);
    if (flashQueueRef.current.length > 0) showNextFromQueue.current();
    else setLiveLog(null);
  }

  function connectSSE() {
    if (sseRef.current) { sseRef.current.close(); sseRef.current = null; }
    if (sseReconnectRef.current) { clearTimeout(sseReconnectRef.current); sseReconnectRef.current = null; }
    const es = new EventSource(`${API_BASE}/api/events`);
    es.addEventListener("init", e => {
      try { seedRef.current(JSON.parse((e as MessageEvent).data)); } catch {}
    });
    es.addEventListener("attendance", e => {
      try { onFreshRef.current(JSON.parse((e as MessageEvent).data)); } catch {}
    });
    es.addEventListener("deviceStatus", e => {
      try {
        const s = JSON.parse((e as MessageEvent).data);
        if (s?.connected === false) {
          setDevice(null); setConnected(false); setConnectStatus("retrying");
          toast.error("Device went offline - reconnecting...", { id: "ac" });
          if (autoConnectRef.current) clearTimeout(autoConnectRef.current);
          attemptConnect(0);
        }
      } catch {}
    });
    es.onerror = () => {
      es.close(); sseRef.current = null;
      sseReconnectRef.current = setTimeout(connectSSE, 3000);
    };
    sseRef.current = es;
  }

  useEffect(() => {
    mountedRef.current = true;
    connectSSE();
    attemptConnect(0);
    // Load saved config from backend
    fetch("http://localhost:5000/api/health")
      .then(r => r.json())
      .then(data => {
        const saved = data?.savedConfig;
        if (saved) {
          const cfg = {
            deviceId:  saved.deviceId  || deviceFormRef.current.deviceId,
            ipAddress: saved.ipAddress || deviceFormRef.current.ipAddress,
            port:      saved.port      || deviceFormRef.current.port,
            license:   saved.license   || deviceFormRef.current.license,
            location:  saved.location  || deviceFormRef.current.location,
          };
          setDeviceForm(cfg);
          deviceFormRef.current = cfg;
        }
      }).catch(() => {});
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

  /* Device connect / dashboard */
  async function attemptConnect(attempt: number) {
    if (!mountedRef.current) return;
    setConnectAttempt(attempt);
    setConnectStatus("connecting");
    try {
      // On first attempt use full connect with params; retries use connect-saved (faster)
      const res = attempt === 0
        ? await deviceApi.connect({
            deviceId:  deviceFormRef.current.deviceId,
            ipAddress: deviceFormRef.current.ipAddress,
            port:      deviceFormRef.current.port,
            license:   deviceFormRef.current.license,
            timeoutMs: 6000,   // 6s is enough for LAN; saves 2s vs previous 8s
          })
        : await deviceApi.connectSaved();   // reuses bridge's in-memory config  sub-second
      if (!mountedRef.current) return;
      setDevice(res.data.data);
      setConnected(true);
      setConnectStatus("connected");
      if (attempt > 0) toast.success("Device reconnected", { id: "ac" });
      await refreshDashboard();
      scheduleReconnectCheck();
    } catch (err: any) {
      if (!mountedRef.current) return;
      setDevice(null); setConnected(false);
      setConnectStatus("retrying");
      if (attempt === 0 || attempt % 5 === 0) {
        toast.error(`Device unreachable - retrying...`, { id: "ac" });
      }
      // Capped exponential backoff: 3s, 5s, 8s ... max 20s (not 30s  faster recovery)
      const delay = Math.min(3000 + attempt * 2000, 20000);
      autoConnectRef.current = setTimeout(() => attemptConnect(attempt + 1), delay);
    }
  }

  function scheduleReconnectCheck() {
    if (autoConnectRef.current) clearTimeout(autoConnectRef.current);
    autoConnectRef.current = setTimeout(async () => {
      if (!mountedRef.current) return;
      try {
        await deviceApi.getStatus();
        scheduleReconnectCheck();
      } catch {
        setDevice(null); setConnected(false); setConnectStatus("retrying");
        attemptConnect(0);
      }
    }, 15000);
  }

  async function refreshDashboard() {
    try {
      const [statsRes, logsRes] = await Promise.all([
        dashboardApi.getStats(),
        dashboardApi.getRecent(),
      ]);
      if (statsRes.data) setStats(statsRes.data as Stats);
      if (logsRes.data) {
        const fresh = (logsRes.data as AttendanceLog[]).filter(l => !knownLogIds.current.has(l.id));
        if (fresh.length) { fresh.forEach(l => knownLogIds.current.add(l.id)); setLogs(prev => [...fresh, ...prev].slice(0, 200)); }
      }
    } catch {}
  }

  async function pullLogs() {
    setBusy(true);
    try {
      const res = await deviceApi.pullLogs(readMode);
      if (res.data) {
        const pulled = (res.data as AttendanceLog[]).filter(l => !knownLogIds.current.has(l.id));
        pulled.forEach(l => knownLogIds.current.add(l.id));
        setLogs(prev => [...pulled, ...prev].slice(0, 500));
        toast.success(`Pulled ${pulled.length} new log${pulled.length !== 1 ? "s" : ""}`);
      }
    } catch (e: any) { toast.error(e?.message || "Pull failed"); }
    finally { setBusy(false); }
  }

  async function pullUsers() {
    setBusy(true);
    try {
      const res = await deviceApi.getUsers();
      setDeviceUsers(res.data as DeviceUser[] || []);
    } catch (e: any) { toast.error(e?.message || "Failed"); }
    finally { setBusy(false); }
  }

  async function syncTime() {
    setBusy(true);
    try { await deviceApi.syncTime(); toast.success("Time synced"); }
    catch (e: any) { toast.error(e?.message || "Failed"); }
    finally { setBusy(false); }
  }

  async function pushStudents() {
    setBusy(true);
    try {
      const res = await deviceApi.pushStudents();
      toast.success(`Pushed ${(res.data as any)?.pushed_count ?? "?"} students`);
    } catch (e: any) { toast.error(e?.message || "Failed"); }
    finally { setBusy(false); }
  }

  /* Students view helpers */
  async function loadStudents() {
    setBusy(true);
    try {
      const res = await studentApi.getAll();
      setStudents(res.data as Student[] || []);
    } catch (e: any) { toast.error(e?.message || "Failed"); }
    finally { setBusy(false); }
  }

  const filteredLogs = logs.filter(l => {
    if (!query) return true;
    const q = query.toLowerCase();
    return `${l.studentName} ${l.studentId ?? ""} ${l.className ?? ""}`.toLowerCase().includes(q);
  });

  /* School auth helpers */
  const switchToProtectedView = (view: NavView) => {
    if (schoolLoggedIn) { setActiveView(view); return; }
    setLoginPending(view);
    setLoginEmail(""); setLoginPassword(""); setLoginError("");
    setShowSchoolLogin(true);
  };

  const handleSchoolLogin = async (e: FormEvent) => {
    e.preventDefault();
    setLoginBusy(true); setLoginError("");
    try {
      const r = await schoolApi.login(loginEmail.trim(), loginPassword);
      const d = r.data as any;
      if (d.success && d.user) {
        setSchoolUser(d.user); setSchoolLoggedIn(true);
        setShowSchoolLogin(false);
        if (loginPending) { setActiveView(loginPending); setLoginPending(null); }
        toast.success(`Welcome, ${d.user.name ?? d.user.role}`);
      } else {
        setLoginError(d.error ?? "Login failed");
      }
    } catch (e: any) {
      setLoginError(e?.response?.data?.error ?? "Cannot reach school server");
    } finally { setLoginBusy(false); }
  };

  const handleSchoolLogout = async () => {
    await schoolApi.logout().catch(() => {});
    setSchoolUser(null); setSchoolLoggedIn(false);
    setActiveView("dashboard");
    toast.success("Logged out from school server");
  };

  /* Dev modal helpers */
  const openDevModal = () => {
    setDevPassword(""); setDevPasswordError(""); setShowDevPassword(false);
    setDevPendingAction("settings");
    fetch("http://localhost:5000/api/health")
      .then(r => r.json())
      .then(data => {
        const saved = data?.savedConfig;
        setDevForm({
          deviceId:  saved?.deviceId  || deviceForm.deviceId,
          ipAddress: saved?.ipAddress || deviceForm.ipAddress,
          port:      saved?.port      || deviceForm.port,
          license:   saved?.license   || deviceForm.license,
          location:  saved?.location  || deviceForm.location,
        });
      }).catch(() => setDevForm({ ...deviceForm }));
    setDevStep("password");
  };

  const closeDevModal = () => { setDevStep("closed"); setDevPassword(""); setDevPasswordError(""); };
  const cancelEdit = () => closeDevModal();

  function submitDevPassword(e: FormEvent) {
    e.preventDefault();
    if (devPassword === DEV_PASSWORD) {
      setDevPasswordError(""); setDevPassword("");
      if (devPendingAction === "wireguard") loadAndOpenWgWizard();
      else setDevStep("settings");
    } else {
      setDevPasswordError("Incorrect password. Try again.");
      setDevPassword("");
    }
  }

  function saveDevSettings(e: FormEvent) {
    e.preventDefault();
    const cfg = { ...devForm };
    setDeviceForm(cfg); deviceFormRef.current = cfg;
    closeDevModal();
    // Show success immediately - dont block UI waiting for device TCP handshake
    toast.success("Settings saved - connecting...", { id: "ac" });
    if (autoConnectRef.current) clearTimeout(autoConnectRef.current);
    setConnectAttempt(0);
    deviceApi.connect({ ...cfg, timeoutMs: 6000, saveConfig: true })
      .then(res => {
        if (!mountedRef.current) return;
        setDevice(res.data.data); setConnected(true); setConnectStatus("connected");
        toast.success(`Connected to ${cfg.ipAddress}`, { id: "ac" });
        refreshDashboard(); scheduleReconnectCheck();
      })
      .catch(() => {
        if (!mountedRef.current) return;
        setDevice(null); setConnected(false); setConnectStatus("retrying");
        toast.error(`Saved. Cannot reach ${cfg.ipAddress} - retrying...`, { id: "ac" });
        setTimeout(() => attemptConnect(0), 500);
      });
  }
  /* WireGuard wizard helpers */
  function openWgWizard() {
    setDevPassword(""); setDevPasswordError(""); setShowDevPassword(false);
    setDevPendingAction("wireguard");
    setDevStep("password");
  }

  async function loadAndOpenWgWizard() {
    setWgError(""); setWgPingResult(null); setWgBusy(true);
    try {
      const health = await fetch(`${API_BASE}/api/health`).then(r => r.json()).catch(() => null);
      const vpnCfg = health?.vpn;
      if (vpnCfg?.serverEndpoint) {
        const base = (vpnCfg.allowedIPs || "10.0.0.0/16").split("/")[0];
        const oct  = base.split(".");
        setWgAllowedIPs(vpnCfg.allowedIPs || "10.0.0.0/16");
        setWgForm(prev => ({ ...prev, serverEndpoint: vpnCfg.serverEndpoint, dns: vpnCfg.dns || "1.1.1.1" }));
        setWgPingTarget(`${oct[0]}.${oct[1]}.0.1`);
      }
      const r = await wireguardApi.getStatus();
      const s = r.data as WgStatus & { installed: boolean };
      setWgStatus(s); setWgInstalled(s.installed);
      if (s.publicKey) {
        setWgKeys({ privateKey: "----hidden----", publicKey: s.publicKey });
        setWgStep(s.tunnelActive ? 4 : 3);
      } else if (s.installed) { setWgStep(2); }
      else { setWgStep(1); }
    } catch { setWgStep(1); setWgInstalled(false); }
    setWgBusy(false);
    setDevStep("wireguard");
    void checkServices();
  }

  async function wgRefreshStatus() {
    try {
      const r = await wireguardApi.getStatus();
      const s = r.data as WgStatus & { installed: boolean };
      setWgStatus(s); setWgInstalled(s.installed);
    } catch {}
  }

  async function wgGenerateKeys() {
    setWgBusy(true); setWgError("");
    try {
      const r = await wireguardApi.generateKeys();
      setWgKeys(r.data as any); setWgStep(3);
    } catch (e: any) { setWgError(e?.response?.data?.error || e.message || "Failed to generate keys"); }
    setWgBusy(false);
  }

  async function wgInstall() {
    if (!wgForm.serverPublicKey.trim()) { setWgError("Paste the server public key first."); return; }
    if (!wgForm.serverEndpoint.trim())  { setWgError("Server endpoint is required."); return; }
    if (!wgForm.vpnIp.trim())           { setWgError("VPN IP is required."); return; }
    setWgBusy(true); setWgError("");
    try {
      const r = await wireguardApi.install(wgForm);
      const data = r.data as any;
      await wgRefreshStatus();
      if (data.requiresGuiImport) {
        setWgError(
          `Auto-install failed. Open WireGuard app, click Import tunnel, select:\n${data.confPath || "C:\\Temp\\EcareAfrica.conf"}\nthen Activate. Come back and click Next.`
        );
        setWgStep(4);
      } else {
        setWgStep(4);
        toast.success(data.message || "Tunnel activated");
      }
    } catch (e: any) { setWgError(e?.response?.data?.error || e.message || "Installation failed"); }
    setWgBusy(false);
  }

  async function wgDeactivate() {
    setWgBusy(true); setWgError("");
    try { await wireguardApi.deactivate(); await wgRefreshStatus(); toast.success("Tunnel stopped"); }
    catch (e: any) { setWgError(e?.response?.data?.error || e.message || "Failed"); }
    setWgBusy(false);
  }

  async function wgPing() {
    setWgBusy(true); setWgPingResult(null); setWgError("");
    try {
      const r = await wireguardApi.ping(wgPingTarget);
      const data = r.data as { success: boolean; output: string };
      setWgPingResult(data);
      if (data.success) toast.success("VPN tunnel is live - school server will connect within 30s", { duration: 5000 });
      else toast.error(`Ping ${wgPingTarget} failed`);
    } catch (e: any) { setWgPingResult({ success: false, output: e?.response?.data?.output || e.message || "Failed" }); }
    setWgBusy(false);
  }

  async function wgDiagnose() {
    setWgDiagBusy(true); setWgDiagnosis(null);
    try { const r = await wireguardApi.diagnose(); setWgDiagnosis(r.data as any); }
    catch (e: any) { setWgDiagnosis({ healthy: false, problems: [e?.message || "Diagnosis failed"], fixes: [] }); }
    setWgDiagBusy(false);
  }

  async function wgSyncKey() {
    setWgDiagBusy(true);
    try {
      const r = await wireguardApi.syncKey();
      const d = r.data as any;
      toast.success("Keys synced - " + (d.activeKey?.slice(0, 16) + "..."));
      await wgRefreshStatus(); await wgDiagnose();
    } catch (e: any) { toast.error(e?.response?.data?.error || e.message || "Sync failed"); }
    setWgDiagBusy(false);
  }

  async function checkServices() {
    try { const r = await wireguardApi.getServicesStatus(); setSvcStatus(r.data as any); }
    catch { setSvcStatus(null); }
  }

  async function installServices() {
    setSvcInstalling(true);
    try {
      toast.loading("Installing services (up to 2 min)...", { id: "svc" });
      const r = await wireguardApi.installServices();
      const d = r.data as any;
      toast.dismiss("svc");
      if (d.success) { toast.success("Services installed - auto-start active"); await checkServices(); }
      else toast.error("Install had issues - check output");
    } catch (e: any) { toast.dismiss("svc"); toast.error(e?.response?.data?.error || e.message || "Failed"); }
    setSvcInstalling(false);
  }

  function copyToClipboard(text: string) {
    navigator.clipboard.writeText(text).catch(() => {});
    setCopiedKey(true);
    setTimeout(() => setCopiedKey(false), 2000);
  }

  /* 
     RENDER
   */
  return (
    <div className="fixed inset-0 flex overflow-hidden bg-[#070b14]">

      {/* Collapsed sidebar show button */}
      {!sidebarVisible && (
        <button
          onClick={() => { setSidebarVisible(true); resetSidebarTimer(); }}
          className="fixed left-0 top-1/2 -translate-y-1/2 z-40 flex items-center rounded-r-xl border border-l-0 border-slate-700 bg-slate-900/95 px-2 py-5 text-slate-400 hover:text-cyan-400 shadow-xl transition"
        >
          <FiChevronRight />
        </button>
      )}

      {/* SIDEBAR */}
      <aside
        onMouseEnter={handleSidebarEnter}
        onMouseLeave={handleSidebarLeave}
        className={`relative flex flex-col shrink-0 w-56 border-r border-slate-800/60 bg-slate-900/95 transition-all duration-300 ${sidebarVisible ? "translate-x-0" : "-translate-x-full"} overflow-y-auto`}
      >
        {/* Logo */}
        <div className="flex items-center justify-between border-b border-slate-800 px-4 py-3">
          <span className="text-sm font-bold text-white">EcaAfrica</span>
          <button onClick={() => setSidebarVisible(false)}
            className="rounded-lg p-1.5 text-slate-500 hover:bg-slate-800 hover:text-white transition">
            <FiChevronsLeft />
          </button>
        </div>

        {/* Nav */}
        <nav className="mb-4 p-3 space-y-1 text-sm flex-1">
          <NavItem active={activeView === "dashboard"} onClick={() => setActiveView("dashboard")} icon={<FiActivity />} label="Dashboard" />
          <NavItem active={activeView === "students"}  onClick={() => setActiveView("students")}  icon={<FiUsers />}    label="Students" />
          {/* Gate Keeper - opens directly without extra login (login inside the panel) */}
          <NavItem active={activeView === "gate"}
            onClick={() => setActiveView("gate")}
            icon={<FiShield />} label="Gate Keeper" />
          {/* Attendance and Users require school login */}
          <NavItem active={activeView === "attendance"}
            onClick={() => switchToProtectedView("attendance")}
            icon={<FiCheckCircle />} label="Attendance" />
          <NavItem active={activeView === "users"}
            onClick={() => switchToProtectedView("users")}
            icon={<FiUserCheck />} label="Users" />

          {schoolLoggedIn && (
            <div className="mt-2 rounded-xl bg-emerald-500/10 border border-emerald-500/30 px-3 py-2 text-xs text-emerald-300">
              <p className="font-semibold truncate">{schoolUser?.name ?? schoolUser?.role}</p>
              <button onClick={handleSchoolLogout} className="text-emerald-400 hover:text-white underline text-[10px]">Logout</button>
            </div>
          )}
        </nav>

        {/* Dashboard panel content */}
        {activeView === "dashboard" && (
          <div className="flex flex-1 flex-col min-h-0 px-3 pb-3">
            <div className="mb-2 flex items-center justify-between">
              <span className="flex items-center gap-1.5 text-xs font-semibold uppercase tracking-wide text-slate-400">
                <FiDatabase className="text-cyan-400" /> Logs
              </span>
              <div className="flex items-center gap-1">
                <select value={readMode} onChange={e => setReadMode(Number(e.target.value))}
                  className="rounded-lg border border-slate-700 bg-slate-800 px-1.5 py-0.5 text-xs text-slate-300 outline-none">
                  <option value={0}>All</option>
                  <option value={1}>New</option>
                </select>
                <button onClick={pullLogs} disabled={busy || !connected} title="Pull logs"
                  className="rounded-lg border border-slate-700 bg-slate-800 p-1.5 text-slate-400 hover:text-cyan-400 disabled:opacity-40">
                  <FiDownloadCloud className="text-xs" />
                </button>
              </div>
            </div>
            <input value={query} onChange={e => setQuery(e.target.value)}
              placeholder="Search logs..." autoComplete="off"
              className="mb-2 w-full rounded-lg border border-slate-700 bg-slate-800 px-2.5 py-1.5 text-xs text-slate-100 outline-none placeholder:text-slate-600 focus:border-cyan-400" />
            <div className="flex-1 overflow-y-auto space-y-1 min-h-0">
              {filteredLogs.slice(0, 50).map(l => (
                <div key={l.id} className="rounded-lg border border-slate-800 bg-slate-800/50 p-2 text-xs">
                  <div className="flex items-center justify-between gap-1">
                    <span className="font-semibold truncate">{l.studentName}</span>
                    <StatusPill status={l.status} small />
                  </div>
                  <p className="text-slate-500 text-[10px]">{new Date(l.timestamp).toLocaleTimeString()}</p>
                </div>
              ))}
              {filteredLogs.length === 0 && (
                <p className="py-4 text-center text-xs text-slate-600">No logs yet</p>
              )}
            </div>
          </div>
        )}

        {/* Students panel content */}
        {activeView === "students" && (
          <div className="flex flex-1 flex-col min-h-0 px-3 pb-3 overflow-y-auto space-y-3">
            <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">Register Student</p>
            <SideField label="Full Name *" value={studentForm.name} onChange={v => setStudentForm(f => ({...f, name: v}))} placeholder="Student name" required />
            <SideField label="Student ID" value={studentForm.studentId} onChange={v => setStudentForm(f => ({...f, studentId: v}))} placeholder="STU-001" />
            <SideField label="Device User ID *" value={studentForm.studentDeviceId} onChange={v => setStudentForm(f => ({...f, studentDeviceId: v}))} placeholder="Device user ID" required />
            <SideSelect label="Class" value={studentForm.className} onChange={v => setStudentForm(f => ({...f, className: v}))} options={CLASS_LIST} />
            <SideField label="Section" value={studentForm.section} onChange={v => setStudentForm(f => ({...f, section: v}))} placeholder="A / B / C" />
            <SideField label="Parent Phone" value={studentForm.parentPhone} onChange={v => setStudentForm(f => ({...f, parentPhone: v}))} placeholder="+250..." />
            <button
              onClick={async () => {
                if (!studentForm.name || !studentForm.studentDeviceId) { toast.error("Name and device ID required"); return; }
                setBusy(true);
                try {
                  await studentApi.create({
                    name: studentForm.name, studentId: studentForm.studentId,
                    studentDeviceId: studentForm.studentDeviceId,
                    className: studentForm.className, section: studentForm.section,
                    parentPhone: studentForm.parentPhone,
                  });
                  toast.success(`${studentForm.name} registered`);
                  setStudentForm({ name:"",studentId:"",studentDeviceId:"",className:CLASS_LIST[0],section:"",assignedDeviceId:"",parentPhone:"" });
                  await loadStudents();
                } catch (e: any) { toast.error(e?.message || "Failed"); }
                setBusy(false);
              }}
              disabled={busy}
              className="w-full rounded-xl bg-cyan-600 py-2 text-xs font-semibold text-white hover:bg-cyan-500 disabled:opacity-50"
            >
              Register Student
            </button>
            <div className="border-t border-slate-800 pt-2">
              <p className="text-xs font-semibold uppercase tracking-wide text-slate-400 mb-2">Registered ({students.length})</p>
              <button onClick={loadStudents} disabled={busy} className="mb-2 w-full rounded-lg border border-slate-700 bg-slate-800/50 py-1.5 text-xs text-slate-400 hover:text-white disabled:opacity-40">
                <FiRefreshCw className="inline mr-1" /> Refresh
              </button>
              {students.map(s => (
                <div key={s.studentDeviceId} className="mb-1 rounded-lg border border-slate-800 bg-slate-800/40 p-2 text-xs">
                  <p className="font-semibold">{s.name}</p>
                  <p className="text-slate-500">{s.className}{s.section ? ` - ${s.section}` : ""}</p>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Bottom buttons */}
        <div className="shrink-0 space-y-2 border-t border-slate-800 p-3">
          <button onClick={openDevModal}
            className="group flex w-full items-center gap-2 rounded-xl border border-slate-700/40 bg-slate-800/30 px-3 py-1.5 text-slate-600 transition-all duration-300 hover:border-amber-500/40 hover:bg-amber-500/10 hover:py-3 hover:text-amber-300">
            <FiSettings className="shrink-0 text-sm transition-transform duration-300 group-hover:text-base" />
            <span className="text-[11px] font-medium transition-all duration-300 group-hover:text-xs">Developer</span>
          </button>
          <button onClick={openWgWizard}
            className="group flex w-full items-center gap-2 rounded-xl border border-slate-700/40 bg-slate-800/30 px-3 py-1.5 text-slate-600 transition-all duration-300 hover:border-cyan-500/40 hover:bg-cyan-500/10 hover:py-3 hover:text-cyan-300">
            <FiShield className="shrink-0 text-sm transition-transform duration-300 group-hover:text-base" />
            <span className="text-[11px] font-medium transition-all duration-300 group-hover:text-xs">WireGuard VPN</span>
          </button>
        </div>
      </aside>

      {/* MAIN AREA */}
      <main className="relative flex flex-1 flex-col overflow-hidden">
        {liveLog && <LiveAttendanceScreen log={liveLog} onDismiss={dismissLive} />}

        {!liveLog && (
          <div className="flex h-full flex-col overflow-hidden">
            <div className="flex shrink-0 items-center justify-between border-b border-slate-800 bg-slate-900/80 px-6 py-3 backdrop-blur-sm">
              <div>
                <h2 className="text-xl font-bold text-white">School Attendance</h2>
                <p className="text-xs text-slate-500">FK biometric real-time tracking</p>
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

            <div className="flex flex-1 flex-col overflow-hidden p-5 gap-5">
              {/* Stats */}
              <div className="grid shrink-0 grid-cols-2 gap-4 xl:grid-cols-4">
                <SummaryTile label="Total Students"    value={stats.totalStudents}   color="cyan" />
                <SummaryTile label="Attendance Today"  value={stats.attendanceToday} color="emerald" />
                <SummaryTile label="Devices"           value={`${stats.onlineDevices}/${stats.totalDevices}`} color="indigo" />
                <SummaryTile label="Total Logs"        value={stats.totalLogs}       color="slate" />
              </div>

              {/* Device + push row */}
              <div className="grid shrink-0 gap-4 xl:grid-cols-[0.8fr_1.2fr]">
                <div className="dashboard-panel p-5">
                  <h3 className="mb-3 shrink-0 text-base font-bold">Device Status</h3>
                  <div className="flex-1 space-y-3 text-sm">
                    <InfoRow label="IP Address" value={deviceForm.ipAddress} />
                    <InfoRow label="Location"   value={deviceForm.location} />
                    <InfoRow label="Status" value={connected ? "Online" : connectStatus === "connecting" ? "Connecting..." : "Offline"}
                      valueClass={connected ? "text-green-400" : "text-amber-400"} />
                    {device?.serialNumber && <InfoRow label="Serial" value={device.serialNumber} />}
                    {device?.users != null && <InfoRow label="Users" value={String(device.users)} />}
                  </div>
                  <div className="mt-4 flex shrink-0 gap-2">
                    <button onClick={pullUsers} disabled={busy || !connected} className="secondary-action flex-1 py-2 text-xs">Pull Users</button>
                    <button onClick={syncTime}  disabled={busy || !connected} className="secondary-action flex-1 py-2 text-xs">Sync Time</button>
                  </div>
                </div>

                <div className="dashboard-panel p-5">
                  <div className="mb-3 flex items-center justify-between">
                    <h3 className="text-base font-bold">Push Students</h3>
                    <button onClick={pushStudents} disabled={busy || !connected}
                      className="inline-flex items-center gap-1.5 rounded-xl border border-blue-500/40 bg-blue-500/10 px-3 py-2 text-xs font-semibold text-blue-300 hover:bg-blue-500/20 disabled:opacity-50">
                      <FiUploadCloud /> Push All
                    </button>
                  </div>
                  <p className="text-xs text-slate-500">
                    Enroll students on the FK623 biometric device so they can scan for attendance.
                    Students must be pushed before they can mark attendance.
                  </p>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>

      {/* SCHOOL LOGIN MODAL */}
      {showSchoolLogin && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4 backdrop-blur-sm">
          <div className="w-full max-w-sm rounded-2xl border border-slate-700 bg-slate-900 p-8 shadow-2xl">
            <div className="mb-6 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="rounded-xl bg-cyan-500/15 p-3 text-cyan-400"><FiShield className="text-xl" /></div>
                <div>
                  <h2 className="text-xl font-bold">School Login</h2>
                  <p className="text-sm text-slate-400">Use your school account</p>
                </div>
              </div>
              <button type="button" onClick={() => { setShowSchoolLogin(false); setLoginPending(null); }}
                className="rounded-lg p-2 text-slate-400 hover:bg-slate-800 hover:text-white"><FiX /></button>
            </div>
            <form onSubmit={handleSchoolLogin} className="space-y-4">
              <div>
                <label className="mb-1.5 block text-sm text-slate-400">Email</label>
                <input autoFocus type="email" value={loginEmail} onChange={e => setLoginEmail(e.target.value)}
                  placeholder="user@school.ac" required className="form-field" />
              </div>
              <div>
                <label className="mb-1.5 block text-sm text-slate-400">Password</label>
                <input type="password" value={loginPassword} onChange={e => setLoginPassword(e.target.value)}
                  required className="form-field" />
              </div>
              {loginError && <p className="text-sm text-red-400">{loginError}</p>}
              <button type="submit" disabled={loginBusy} className="primary-action w-full py-3">
                {loginBusy ? "Logging in..." : "Login"}
              </button>
            </form>
          </div>
        </div>
      )}

      {/* GATE KEEPER PANEL - opens directly, no pre-login required */}
      {activeView === "gate" && (
        <div className="fixed inset-0 z-40 bg-slate-950 flex flex-col">
          <GateKeeperPanel onClose={() => setActiveView("dashboard")} />
        </div>
      )}

      {/* ATTENDANCE PANEL */}
      {activeView === "attendance" && schoolLoggedIn && (
        <div className="fixed inset-0 z-40 bg-slate-950 flex flex-col">
          <ManualAttendancePanel onClose={() => setActiveView("dashboard")} />
        </div>
      )}

      {/* USERS PANEL */}
      {activeView === "users" && schoolLoggedIn && (
        <div className="fixed inset-0 z-40 bg-slate-950 flex flex-col">
          <UsersPanel schoolUser={schoolUser} onClose={() => setActiveView("dashboard")} />
        </div>
      )}

      {/* DEVELOPER PASSWORD MODAL */}
      {devStep === "password" && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4 backdrop-blur-sm">
          <div className="w-full max-w-sm rounded-2xl border border-slate-700 bg-slate-900 p-8 shadow-2xl">
            <div className="mb-6 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className={`rounded-xl p-3 ${devPendingAction === "wireguard" ? "bg-cyan-500/15 text-cyan-400" : "bg-cyan-500/15 text-cyan-400"}`}>
                  {devPendingAction === "wireguard" ? <FiShield className="text-xl" /> : <FiLock className="text-xl" />}
                </div>
                <h2 className="text-xl font-bold">
                  {devPendingAction === "wireguard" ? "WireGuard VPN Access" : "Developer Access"}
                </h2>
              </div>
              <button type="button" onClick={closeDevModal} className="rounded-lg p-2 text-slate-400 hover:bg-slate-800 hover:text-white"><FiX /></button>
            </div>
            <form onSubmit={submitDevPassword} className="space-y-4">
              <div>
                <label className="mb-1.5 block text-sm text-slate-400">Password</label>
                <div className="relative">
                  <input autoFocus type={showDevPassword ? "text" : "password"} value={devPassword}
                    onChange={e => { setDevPassword(e.target.value); setDevPasswordError(""); }}
                    placeholder="Enter developer password" className="form-field pr-10" />
                  <button type="button" onClick={() => setShowDevPassword(v => !v)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-white">
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

      {/* DEVELOPER SETTINGS MODAL */}
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
                  <input required type="text" value={devForm.ipAddress} onChange={e => setDevForm({...devForm, ipAddress: e.target.value})} placeholder="192.168.1.118" className="form-field" />
                </div>
                <div>
                  <label className="mb-1.5 block text-sm text-slate-400">Port</label>
                  <input required type="number" value={devForm.port} onChange={e => setDevForm({...devForm, port: Number(e.target.value)})} className="form-field" />
                </div>
                <div>
                  <label className="mb-1.5 block text-sm text-slate-400">License</label>
                  <input required type="number" value={devForm.license} onChange={e => setDevForm({...devForm, license: Number(e.target.value)})} className="form-field" />
                </div>
                <div>
                  <label className="mb-1.5 block text-sm text-slate-400">Device ID</label>
                  <input type="text" value={devForm.deviceId} onChange={e => setDevForm({...devForm, deviceId: e.target.value})} className="form-field" />
                </div>
                <div>
                  <label className="mb-1.5 block text-sm text-slate-400">Location</label>
                  <input type="text" value={devForm.location} onChange={e => setDevForm({...devForm, location: e.target.value})} className="form-field" />
                </div>
              </div>
              {connected && device && (
                <div className="rounded-xl border border-slate-700 bg-slate-800/60 p-4">
                  <p className="mb-3 text-xs font-semibold uppercase tracking-wide text-slate-500">Live Device Info</p>
                  <div className="grid grid-cols-2 gap-3 text-sm">
                    <div><p className="text-slate-500">Serial</p><p className="font-medium text-slate-200">{device.serialNumber || ""}</p></div>
                    <div><p className="text-slate-500">Product</p><p className="font-medium text-slate-200">{device.productName || device.productCode || ""}</p></div>
                    <div><p className="text-slate-500">Users</p><p className="font-medium text-slate-200">{device.users ?? ""}</p></div>
                    <div><p className="text-slate-500">Logs</p><p className="font-medium text-slate-200">{(device as any).logs ?? ""}</p></div>
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

      {/* WIREGUARD VPN WIZARD MODAL - full wizard in WireguardWizard component */}
      {devStep === "wireguard" && (
        <WireguardWizard
          wgStep={wgStep} setWgStep={setWgStep}
          wgBusy={wgBusy} wgError={wgError} setWgError={setWgError}
          wgKeys={wgKeys} wgStatus={wgStatus} wgInstalled={wgInstalled}
          wgForm={wgForm} setWgForm={setWgForm}
          wgAllowedIPs={wgAllowedIPs}
          wgPingTarget={wgPingTarget} setWgPingTarget={setWgPingTarget}
          wgPingResult={wgPingResult} setWgPingResult={setWgPingResult}
          wgDiagnosis={wgDiagnosis} wgDiagBusy={wgDiagBusy}
          svcStatus={svcStatus} svcInstalling={svcInstalling}
          copiedKey={copiedKey}
          onClose={closeDevModal}
          onRefreshStatus={wgRefreshStatus}
          onGenerateKeys={wgGenerateKeys}
          onInstall={wgInstall}
          onDeactivate={wgDeactivate}
          onPing={wgPing}
          onDiagnose={wgDiagnose}
          onSyncKey={wgSyncKey}
          onCheckServices={checkServices}
          onInstallServices={installServices}
          onCopy={copyToClipboard}
        />
      )}
    </div>
  );
}
