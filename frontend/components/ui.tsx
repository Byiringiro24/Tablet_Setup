"use client";
// Small reusable UI components used across the tablet app

import { FiLoader, FiWifi, FiWifiOff } from "react-icons/fi";

export function NavItem({
  icon, label, active = false, onClick,
}: {
  icon: React.ReactNode;
  label: string;
  active?: boolean;
  onClick?: () => void;
}) {
  return (
    <div
      onClick={onClick}
      className={`flex cursor-pointer items-center gap-3 rounded-xl px-3 py-2 text-sm font-medium transition select-none
        ${active
          ? "border border-cyan-500/50 bg-cyan-500/15 text-white"
          : "text-slate-400 hover:bg-slate-800 hover:text-white"
        }`}
    >
      {icon}
      {label}
    </div>
  );
}

export function SideField({
  label, value, onChange, placeholder, required = false,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  required?: boolean;
}) {
  return (
    <label className="block">
      <span className="mb-0.5 block text-[10px] text-slate-500">{label}</span>
      <input
        required={required}
        type="text"
        value={value}
        placeholder={placeholder}
        onChange={(e) => onChange(e.target.value)}
        className="w-full rounded-lg border border-slate-700 bg-slate-800/90 px-2.5 py-1.5 text-xs text-slate-100 outline-none placeholder:text-slate-600 focus:border-cyan-400"
      />
    </label>
  );
}

export function SideSelect({
  label, value, onChange, options,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  options: string[];
}) {
  return (
    <label className="block">
      <span className="mb-0.5 block text-[10px] text-slate-500">{label}</span>
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="w-full rounded-lg border border-slate-700 bg-slate-800/90 px-2.5 py-1.5 text-xs text-slate-100 outline-none focus:border-cyan-400"
      >
        {options.map((o) => <option key={o}>{o}</option>)}
      </select>
    </label>
  );
}

export function StatusPill({ status, small = false }: { status: string; small?: boolean }) {
  const s = status.toLowerCase();
  const color = s.includes("late")
    ? "bg-amber-500/20 text-amber-300"
    : s.includes("absent")
    ? "bg-red-500/20 text-red-300"
    : "bg-green-500/20 text-green-300";
  return (
    <span className={`rounded-full font-medium ${small ? "px-2 py-0.5 text-[10px]" : "px-3 py-1 text-xs"} ${color}`}>
      {status}
    </span>
  );
}

export function SummaryTile({ label, value, color }: { label: string; value: string | number; color: string }) {
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
    <div className={`rounded-xl border p-4 ${map[color] ?? map.slate}`}>
      <p className="text-xs opacity-60">{label}</p>
      <p className="mt-1 text-2xl font-bold">{value}</p>
    </div>
  );
}

export function InfoRow({
  label, value, valueClass = "text-slate-200",
}: {
  label: string;
  value: string;
  valueClass?: string;
}) {
  return (
    <div className="flex items-center justify-between border-b border-slate-800 pb-2 last:border-0 last:pb-0">
      <span className="text-slate-500">{label}</span>
      <span className={`font-medium ${valueClass}`}>{value}</span>
    </div>
  );
}

export function AutoConnectBadge({
  status, attempt,
}: {
  status: "connecting" | "connected" | "retrying";
  attempt: number;
}) {
  if (status === "connected") {
    return (
      <span className="flex items-center gap-1.5 rounded-full bg-green-500/20 px-3 py-1 text-sm text-green-300">
        <FiWifi className="shrink-0" /> Online
      </span>
    );
  }
  if (status === "connecting") {
    return (
      <span className="flex animate-pulse items-center gap-1.5 rounded-full bg-cyan-500/20 px-3 py-1 text-sm text-cyan-300">
        <FiLoader className="shrink-0 animate-spin" /> Connecting...
      </span>
    );
  }
  return (
    <span className="flex animate-pulse items-center gap-1.5 rounded-full bg-amber-500/20 px-3 py-1 text-sm text-amber-300">
      <FiWifiOff className="shrink-0" /> Reconnecting{attempt > 0 ? ` #${attempt + 1}` : ""}...
    </span>
  );
}
