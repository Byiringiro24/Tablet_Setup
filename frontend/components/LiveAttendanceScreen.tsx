"use client";
import { useEffect, useState } from "react";
import { FiX, FiArrowLeft } from "react-icons/fi";
import type { AttendanceLog } from "./types";

export default function LiveAttendanceScreen({
  log,
  onDismiss,
}: {
  log: AttendanceLog;
  onDismiss: () => void;
}) {
  const [visible,  setVisible]  = useState(false);
  const [progress, setProgress] = useState(100);

  useEffect(() => {
    const t = setTimeout(() => setVisible(true), 40);
    const start = Date.now();
    const tick = setInterval(() => {
      setProgress(Math.max(0, 100 - ((Date.now() - start) / 4000) * 100));
    }, 50);
    return () => { clearTimeout(t); clearInterval(tick); };
  }, []);

  const method = log.authenticationMethod || "Unknown";
  const s      = (log.status || "").toLowerCase();
  const isLate   = s.includes("late");
  const isAbsent = s.includes("absent");

  const methodIcon =
    method.toLowerCase().includes("face")    ? "ID" :
    method.toLowerCase().includes("finger")  ? "FP" :
    method.toLowerCase().includes("card")    ? "NFC" :
    method.toLowerCase().includes("pin") || method.toLowerCase().includes("pass") ? "PIN" : "OK";

  const accent = isLate
    ? "from-amber-500/20  border-amber-500/40"
    : isAbsent
    ? "from-red-500/20    border-red-500/40"
    : "from-emerald-500/20 border-emerald-500/40";

  const bar  = isLate ? "bg-amber-500"   : isAbsent ? "bg-red-500"   : "bg-emerald-500";
  const glow = isLate ? "shadow-amber-500/20" : isAbsent ? "shadow-red-500/20" : "shadow-emerald-500/20";

  return (
    <div className={`absolute inset-0 z-30 flex flex-col items-center justify-center bg-gradient-to-br via-slate-900 to-slate-900 ${accent}
      transition-all duration-700 ease-out ${visible ? "opacity-100 scale-100" : "opacity-0 scale-95"}`}>

      <button onClick={onDismiss}
        className="absolute right-6 top-6 rounded-xl border border-slate-700 bg-slate-800/80 p-2.5 text-slate-400 hover:text-white transition">
        <FiX className="text-lg" />
      </button>
      <button onClick={onDismiss}
        className="absolute left-6 top-6 flex items-center gap-2 rounded-xl border border-slate-700 bg-slate-800/80 px-4 py-2.5 text-sm text-slate-400 hover:text-white transition">
        <FiArrowLeft /> Back
      </button>

      <div className={`relative w-full max-w-lg rounded-3xl border bg-slate-900/95 p-10 shadow-2xl ${glow} shadow-2xl ${accent.split(" ")[1]}`}>

        {/* Photo or icon */}
        <div className="mb-6 flex justify-center">
          {log.photoUrl ? (
            <div className={`relative h-32 w-32 rounded-full border-4 overflow-hidden shadow-xl ${isLate ? "border-amber-500/70" : isAbsent ? "border-red-500/70" : "border-emerald-500/70"}`}>
              <img src={log.photoUrl} alt={log.studentName} className="h-full w-full object-cover"
                onError={e => { (e.currentTarget as HTMLImageElement).style.display = "none"; }} />
            </div>
          ) : (
            <div className={`flex h-32 w-32 items-center justify-center rounded-full border-4 text-3xl font-black shadow-xl
              ${isLate ? "border-amber-500/50 bg-amber-500/10 text-amber-300" : isAbsent ? "border-red-500/50 bg-red-500/10 text-red-300" : "border-emerald-500/50 bg-emerald-500/10 text-emerald-300"}`}>
              {methodIcon}
            </div>
          )}
        </div>

        {/* Student info */}
        <div className="text-center">
          <p className="text-5xl font-black tracking-tight text-white leading-tight">{log.studentName}</p>
          <p className="mt-3 text-2xl font-bold text-cyan-400">{log.studentId || log.studentDeviceId}</p>
          {log.className && (
            <p className="mt-1.5 text-base text-slate-400">
              {log.className}{log.section ? ` - Section ${log.section}` : ""}
            </p>
          )}
        </div>

        {/* Status badge */}
        <div className="mt-6 flex justify-center">
          <span className={`rounded-full px-6 py-2 text-lg font-bold ${isLate ? "bg-amber-500/20 text-amber-300" : isAbsent ? "bg-red-500/20 text-red-300" : "bg-emerald-500/20 text-emerald-300"}`}>
            {log.status}
          </span>
        </div>

        {/* Details */}
        <div className="mt-8 grid grid-cols-2 gap-4 text-sm">
          {[
            { label: "Method", value: method },
            { label: "Time",   value: new Date(log.timestamp).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" }) },
            { label: "Date",   value: new Date(log.timestamp).toLocaleDateString([], { weekday: "short", month: "short", day: "numeric" }) },
            { label: "Device", value: log.deviceId || "—" },
          ].map(item => (
            <div key={item.label} className="rounded-xl border border-slate-800 bg-slate-800/60 p-4 text-center">
              <p className="text-xs text-slate-500 uppercase tracking-wide mb-1">{item.label}</p>
              <p className="font-semibold text-slate-200 truncate">{item.value}</p>
            </div>
          ))}
        </div>

        <div className="mt-6 flex items-center justify-center gap-2 text-sm">
          <span className={`text-lg ${isLate ? "text-amber-400" : isAbsent ? "text-red-400" : "text-emerald-400"}`}>&#x2714;</span>
          <span className="text-slate-300">Attendance recorded</span>
        </div>

        {/* Countdown bar */}
        <div className="mt-6 h-1.5 w-full overflow-hidden rounded-full bg-slate-700">
          <div className={`h-full rounded-full transition-none ${bar}`} style={{ width: `${progress}%` }} />
        </div>
        <p className="mt-1.5 text-center text-xs text-slate-600">Auto-returns to dashboard</p>
      </div>
    </div>
  );
}
