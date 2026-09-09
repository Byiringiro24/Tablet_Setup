"use client";
/**
 * Gate Keeper Panel (tablet interface)
 *
 * Shows DOD-approved boarding exits with student photo, name, ID, exit time
 * and return time. Gate keeper confirms exit and confirms return.
 *
 * NO LOGIN REQUIRED — opens directly from the sidebar.
 * The tablet is physically at the gate; anyone using it is the gate keeper.
 * It fetches data from the school server using the stored session token if
 * the device is already authenticated, or shows the school login form otherwise.
 */

import { useEffect, useState, type FormEvent } from "react";
import toast from "react-hot-toast";
import {
  FiShield, FiRefreshCw, FiX, FiSearch, FiUser,
} from "react-icons/fi";
import { schoolApi } from "@/lib/api";
import type { ApprovedExit, SchoolUser } from "./types";

const STATE_BADGE: Record<string, string> = {
  awaiting_physical_exit: "bg-amber-500/20 text-amber-300 border border-amber-500/30",
  outside_school:         "bg-orange-500/20 text-orange-300 border border-orange-500/30",
  returned:               "bg-emerald-500/20 text-emerald-300 border border-emerald-500/30",
  closed:                 "bg-slate-700 text-slate-400 border border-slate-600",
};

export default function GateKeeperPanel({ onClose }: { onClose: () => void }) {
  const [loggedIn,  setLoggedIn]  = useState(false);
  const [schoolUser, setSchoolUser] = useState<SchoolUser | null>(null);
  const [loginEmail,    setLoginEmail]    = useState("");
  const [loginPassword, setLoginPassword] = useState("");
  const [loginError,    setLoginError]    = useState("");
  const [loginBusy,     setLoginBusy]     = useState(false);

  const [exits,    setExits]    = useState<ApprovedExit[]>([]);
  const [loading,  setLoading]  = useState(false);
  const [view,     setView]     = useState<"pending" | "outside" | "all">("pending");
  const [query,    setQuery]    = useState("");
  const [selected, setSelected] = useState<ApprovedExit | null>(null);
  const [notes,    setNotes]    = useState("");
  const [acting,   setActing]   = useState(false);

  // Check if already logged in on mount
  useEffect(() => {
    schoolApi.me().then(r => {
      const d = r.data as any;
      if (d.loggedIn && d.user) {
        setSchoolUser(d.user);
        setLoggedIn(true);
      }
    }).catch(() => {});
  }, []);

  useEffect(() => {
    if (loggedIn) void loadExits();
  }, [loggedIn]);

  const handleLogin = async (e: FormEvent) => {
    e.preventDefault();
    setLoginBusy(true); setLoginError("");
    try {
      const r = await schoolApi.login(loginEmail.trim(), loginPassword);
      const d = r.data as any;
      if (d.success && d.user) {
        setSchoolUser(d.user);
        setLoggedIn(true);
        toast.success(`Welcome, ${d.user.name ?? d.user.role}`);
      } else {
        setLoginError(d.error ?? "Login failed");
      }
    } catch (e: any) {
      setLoginError(e?.response?.data?.error ?? "Cannot reach school server");
    } finally { setLoginBusy(false); }
  };

  const loadExits = async () => {
    setLoading(true);
    try {
      const today = new Date().toISOString().slice(0, 10);
      const r = await schoolApi.getApprovedExits(today);
      const data = (r.data as any)?.data ?? r.data ?? [];
      setExits(Array.isArray(data) ? data : []);
    } catch (e: any) {
      toast.error(e?.response?.data?.error ?? "Failed to load exits");
    } finally { setLoading(false); }
  };

  const filtered = exits.filter(e => {
    if (view === "pending")  return e.leave_state === "awaiting_physical_exit";
    if (view === "outside")  return ["outside_school", "returned"].includes(e.leave_state);
    return true;
  }).filter(e => {
    const q = query.toLowerCase();
    if (!q) return true;
    const name = `${e.student?.first_name ?? ""} ${e.student?.last_name ?? ""}`.toLowerCase();
    return name.includes(q) || (e.student?.student_id_number ?? "").toLowerCase().includes(q);
  });

  const confirmExit = async () => {
    if (!selected) return;
    setActing(true);
    try {
      await schoolApi.confirmExit(selected.id, notes);
      toast.success("Gate exit confirmed");
      setSelected(null); setNotes("");
      await loadExits();
    } catch (e: any) {
      toast.error(e?.response?.data?.error ?? "Failed to confirm exit");
    } finally { setActing(false); }
  };

  const confirmReturn = async () => {
    if (!selected) return;
    setActing(true);
    try {
      await schoolApi.confirmReturn(selected.id);
      toast.success("Return confirmed — leave closed");
      setSelected(null);
      await loadExits();
    } catch (e: any) {
      toast.error(e?.response?.data?.error ?? "Failed to confirm return");
    } finally { setActing(false); }
  };

  // -- Login screen --
  if (!loggedIn) {
    return (
      <div className="flex flex-col h-full text-white bg-slate-950">
        <div className="flex items-center justify-between border-b border-slate-800 bg-slate-900 px-6 py-4 shrink-0">
          <div className="flex items-center gap-3">
            <div className="rounded-xl bg-cyan-500/15 p-2.5 text-cyan-400"><FiShield className="text-lg" /></div>
            <div>
              <h2 className="text-lg font-bold">Gate Keeper</h2>
              <p className="text-xs text-slate-400">Login to view approved exits</p>
            </div>
          </div>
          <button onClick={onClose} className="rounded-lg p-2 text-slate-400 hover:bg-slate-800 hover:text-white"><FiX /></button>
        </div>
        <div className="flex flex-1 items-center justify-center p-6">
          <div className="w-full max-w-sm space-y-6">
            <div className="text-center">
              <div className="mx-auto mb-4 grid h-16 w-16 place-items-center rounded-2xl bg-cyan-500/15 text-cyan-400">
                <FiShield className="text-3xl" />
              </div>
              <h3 className="text-xl font-bold">School Server Login</h3>
              <p className="mt-1 text-sm text-slate-400">Use your school account credentials</p>
            </div>
            <form onSubmit={handleLogin} className="space-y-4">
              <div>
                <label className="mb-1.5 block text-sm text-slate-400">Email</label>
                <input autoFocus type="email" value={loginEmail} onChange={e => setLoginEmail(e.target.value)}
                  required placeholder="user@school.ac" className="form-field" />
              </div>
              <div>
                <label className="mb-1.5 block text-sm text-slate-400">Password</label>
                <input type="password" value={loginPassword} onChange={e => setLoginPassword(e.target.value)}
                  required className="form-field" />
              </div>
              {loginError && (
                <p className="rounded-lg bg-red-500/15 border border-red-500/30 px-3 py-2 text-sm text-red-300">{loginError}</p>
              )}
              <button type="submit" disabled={loginBusy} className="primary-action w-full py-3">
                {loginBusy ? "Logging in..." : "Login"}
              </button>
            </form>
          </div>
        </div>
      </div>
    );
  }

  // -- Main gate keeper UI --
  return (
    <div className="flex flex-col h-full text-white bg-slate-950">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-slate-800 bg-slate-900 px-6 py-4 shrink-0">
        <div className="flex items-center gap-3">
          <div className="rounded-xl bg-cyan-500/15 p-2.5 text-cyan-400"><FiShield className="text-lg" /></div>
          <div>
            <h2 className="text-lg font-bold">Gate Keeper</h2>
            <p className="text-xs text-slate-400">
              Approved exits {schoolUser ? `- ${schoolUser.name}` : ""}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <button onClick={() => void loadExits()} disabled={loading}
            className="rounded-lg border border-slate-700 bg-slate-800 p-2 text-slate-400 hover:text-white disabled:opacity-40">
            <FiRefreshCw className={loading ? "animate-spin" : ""} />
          </button>
          <button onClick={onClose} className="rounded-lg p-2 text-slate-400 hover:bg-slate-800 hover:text-white">
            <FiX />
          </button>
        </div>
      </div>

      {/* Filters */}
      <div className="flex items-center gap-3 border-b border-slate-800 bg-slate-900/60 px-6 py-3 shrink-0 flex-wrap">
        <div className="relative flex-1 min-w-48">
          <FiSearch className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500 text-sm" />
          <input value={query} onChange={e => setQuery(e.target.value)} placeholder="Search student name or ID..."
            className="w-full rounded-xl border border-slate-700 bg-slate-800 pl-9 pr-4 py-2 text-sm text-white placeholder-slate-500 outline-none" />
        </div>
        {(["pending", "outside", "all"] as const).map(v => (
          <button key={v} onClick={() => setView(v)}
            className={`rounded-xl px-4 py-2 text-xs font-semibold transition ${
              view === v ? "bg-cyan-500/20 text-cyan-300 border border-cyan-500/40" : "border border-slate-700 text-slate-400 hover:text-white"
            }`}>
            {v === "pending" ? `Awaiting Exit (${exits.filter(e => e.leave_state === "awaiting_physical_exit").length})` :
             v === "outside" ? `Outside / Returned (${exits.filter(e => ["outside_school","returned"].includes(e.leave_state)).length})` :
             `All (${exits.length})`}
          </button>
        ))}
      </div>

      {/* List */}
      <div className="flex-1 overflow-y-auto p-4 space-y-3">
        {loading ? (
          <div className="py-20 text-center text-slate-500">Loading...</div>
        ) : filtered.length === 0 ? (
          <div className="py-20 text-center">
            <FiUser className="mx-auto mb-3 text-4xl text-slate-700" />
            <p className="text-slate-500">No {view === "pending" ? "awaiting exits" : "records"} found</p>
          </div>
        ) : filtered.map(ex => {
          const s = ex.student;
          const name = s ? `${s.first_name} ${s.last_name}` : "Unknown";
          const photoSrc = s?.photo_url ? schoolApi.photoUrl(s.photo_url) : null;
          const isLate = ex.late_return_flagged && ex.leave_state === "outside_school";
          const isSelected = selected?.id === ex.id;
          return (
            <div key={ex.id}
              onClick={() => { setSelected(isSelected ? null : ex); setNotes(""); }}
              className={`flex items-center gap-4 rounded-2xl border p-4 cursor-pointer transition
                ${isSelected ? "border-cyan-500/50 bg-cyan-500/10" : "border-slate-700 bg-slate-900/60 hover:border-slate-600"}
                ${isLate ? "border-red-500/40" : ""}`}>
              {/* Photo */}
              <div className="h-16 w-14 shrink-0 rounded-xl overflow-hidden border-2 border-slate-700">
                {photoSrc ? (
                  <img src={photoSrc} alt={name} className="h-full w-full object-cover"
                    onError={e => { (e.currentTarget as any).style.display = "none"; }} />
                ) : (
                  <div className="h-full w-full flex items-center justify-center bg-slate-800 text-lg font-bold text-slate-400">
                    {name.split(" ").map(w => w[0]).join("").slice(0, 2).toUpperCase()}
                  </div>
                )}
              </div>
              {/* Info */}
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 flex-wrap mb-0.5">
                  <span className="font-bold">{name}</span>
                  {isLate && (
                    <span className="rounded-full bg-red-500/20 border border-red-500/30 px-2 py-0.5 text-[10px] font-bold text-red-300">
                      LATE RETURN
                    </span>
                  )}
                </div>
                <p className="text-xs font-mono text-slate-400">{s?.student_id_number ?? "—"}</p>
                <div className="mt-1 flex gap-3 text-xs text-slate-500">
                  <span>Exit: <strong className="text-slate-300">{ex.exited_at ? new Date(ex.exited_at).toLocaleTimeString() : ex.start_time ?? ex.start_date}</strong></span>
                  <span>Return by: <strong className="text-slate-300">{ex.expected_return_time ?? ex.end_date}</strong></span>
                </div>
                <p className="mt-0.5 text-xs text-slate-500 capitalize">
                  {ex.leave_type?.replace(/_/g, " ")} {ex.destination ? `- ${ex.destination}` : ""}
                </p>
              </div>
              <span className={`rounded-full px-3 py-1 text-xs font-bold shrink-0 ${STATE_BADGE[ex.leave_state] ?? "bg-slate-700 text-slate-400"}`}>
                {ex.leave_state.replace(/_/g, " ")}
              </span>
            </div>
          );
        })}
      </div>

      {/* Selected student action panel */}
      {selected && (
        <div className="shrink-0 border-t-2 border-cyan-500/30 bg-slate-900 p-5 space-y-4">
          {/* Identity verification row */}
          <div className="flex items-center gap-5">
            <div className="h-24 w-20 shrink-0 rounded-2xl overflow-hidden border-2 border-cyan-500/40 shadow-xl shadow-cyan-900/20">
              {selected.student?.photo_url ? (
                <img src={schoolApi.photoUrl(selected.student.photo_url)} alt=""
                  className="h-full w-full object-cover" />
              ) : (
                <div className="h-full w-full flex items-center justify-center bg-slate-800 text-3xl font-black text-slate-400">
                  {`${selected.student?.first_name?.[0] ?? ""}${selected.student?.last_name?.[0] ?? ""}`}
                </div>
              )}
            </div>
            <div className="flex-1">
              <p className="text-2xl font-black leading-tight">
                {selected.student ? `${selected.student.first_name} ${selected.student.last_name}` : "—"}
              </p>
              <p className="font-mono text-sm text-cyan-300 mt-0.5">{selected.student?.student_id_number}</p>
              <div className="mt-2 grid grid-cols-2 gap-x-4 text-xs text-slate-400">
                <span>Leave: <strong className="text-white capitalize">{selected.leave_type?.replace(/_/g, " ")}</strong></span>
                <span>Destination: <strong className="text-white">{selected.destination ?? "—"}</strong></span>
                <span>From: <strong className="text-white">{selected.start_date} {selected.start_time ?? ""}</strong></span>
                <span>Return by: <strong className="text-white">{selected.expected_return_time ?? selected.end_date}</strong></span>
              </div>
              {selected.reason && <p className="mt-1 text-xs text-slate-500 italic">{selected.reason}</p>}
            </div>
          </div>

          {/* Notes input for exit */}
          {selected.leave_state === "awaiting_physical_exit" && (
            <input value={notes} onChange={e => setNotes(e.target.value)}
              placeholder="Optional notes (e.g. verified ID, parent present)"
              className="form-field text-sm w-full" />
          )}

          {/* Action buttons */}
          <div className="flex gap-3">
            {selected.leave_state === "awaiting_physical_exit" && (
              <button onClick={confirmExit} disabled={acting}
                className="flex-1 rounded-2xl bg-emerald-600 py-5 text-xl font-black text-white hover:bg-emerald-500 disabled:opacity-50 transition shadow-lg shadow-emerald-900/40 active:scale-95">
                {acting ? "Processing..." : "CONFIRM GATE EXIT"}
              </button>
            )}
            {(selected.leave_state === "outside_school" || selected.leave_state === "returned") && (
              <button onClick={confirmReturn} disabled={acting}
                className="flex-1 rounded-2xl bg-blue-600 py-5 text-xl font-black text-white hover:bg-blue-500 disabled:opacity-50 transition shadow-lg shadow-blue-900/40 active:scale-95">
                {acting ? "Processing..." : "CONFIRM RETURN"}
              </button>
            )}
            <button onClick={() => setSelected(null)}
              className="rounded-2xl border border-slate-700 px-8 py-5 font-bold text-slate-300 hover:bg-slate-800 transition">
              Cancel
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
