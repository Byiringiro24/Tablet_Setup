"use client";
/**
 * Manual Attendance Panel
 * Tick students present/absent by class or dormitory.
 * Submits records to the school server.
 */

import { useEffect, useState, type FormEvent } from "react";
import toast from "react-hot-toast";
import { FiCheckCircle, FiX, FiRefreshCw } from "react-icons/fi";
import { schoolApi } from "@/lib/api";

type SchoolStudent = {
  id: string;
  first_name: string;
  last_name: string;
  student_id_number?: string | null;
};

type AttendanceStatus = "present" | "absent" | "late";

export default function ManualAttendancePanel({
  onClose,
}: {
  onClose: () => void;
}) {
  const [filterType, setFilterType]     = useState<"class" | "dormitory">("class");
  const [classes,    setClasses]         = useState<any[]>([]);
  const [dormitories, setDormitories]   = useState<any[]>([]);
  const [selectedFilter, setSelectedFilter] = useState("");
  const [students,   setStudents]        = useState<SchoolStudent[]>([]);
  const [attendance, setAttendance]      = useState<Record<string, AttendanceStatus>>({});
  const [sessions,   setSessions]        = useState<any[]>([]);
  const [selectedSession, setSelectedSession] = useState("");
  const [loading,    setLoading]         = useState(false);
  const [submitting, setSubmitting]      = useState(false);
  const [notes,      setNotes]           = useState("Manual attendance via gate tablet");

  const load = async () => {
    setLoading(true);
    try {
      const [classRes, dormRes, sessRes] = await Promise.all([
        schoolApi.getClasses(),
        schoolApi.getDormitories(),
        schoolApi.getBoardingSessions({ limit: "30" }),
      ]);
      setClasses((classRes.data as any)?.data ?? classRes.data ?? []);
      setDormitories((dormRes.data as any)?.data ?? dormRes.data ?? []);
      const sessData = (sessRes.data as any)?.data ?? sessRes.data ?? [];
      setSessions(Array.isArray(sessData) ? sessData : []);
    } catch {
      toast.error("Failed to load filters");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { void load(); }, []);

  useEffect(() => {
    if (!selectedFilter) return;
    const run = async () => {
      setLoading(true);
      try {
        const params: Record<string, string> = { limit: "500", status: "active" };
        if (filterType === "class") params.class_id = selectedFilter;
        else params.dormitory_id = selectedFilter;
        const r = await schoolApi.getStudents(params);
        const list: SchoolStudent[] = (r.data as any)?.data ?? r.data ?? [];
        setStudents(Array.isArray(list) ? list : []);
        const init: Record<string, AttendanceStatus> = {};
        (Array.isArray(list) ? list : []).forEach(s => { init[s.id] = "present"; });
        setAttendance(init);
      } catch {
        toast.error("Failed to load students");
      } finally {
        setLoading(false);
      }
    };
    void run();
  }, [selectedFilter, filterType]);

  const toggle = (id: string) => {
    setAttendance(prev => ({ ...prev, [id]: prev[id] === "present" ? "absent" : "present" }));
  };

  const markAll = (status: AttendanceStatus) => {
    const next: Record<string, AttendanceStatus> = {};
    students.forEach(s => { next[s.id] = status; });
    setAttendance(next);
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!selectedSession) { toast.error("Select an attendance session first"); return; }
    if (!students.length)  { toast.error("Load students first"); return; }
    setSubmitting(true);
    try {
      const records = students.map(s => ({
        student_id: s.id,
        status:     attendance[s.id] ?? "present",
        reason:     notes,
      }));
      const r = await schoolApi.submitManualAttendance(selectedSession, records);
      const data = r.data as any;
      const ok = (data?.results ?? []).filter((x: any) => x.ok).length;
      toast.success(`Saved ${ok}/${records.length} attendance records`);
    } catch (e: any) {
      toast.error(e?.response?.data?.error ?? "Failed to submit");
    } finally {
      setSubmitting(false);
    }
  };

  const present = Object.values(attendance).filter(v => v === "present").length;
  const absent  = Object.values(attendance).filter(v => v === "absent").length;

  return (
    <div className="flex flex-col h-full text-white bg-slate-950">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-slate-800 bg-slate-900 px-6 py-4 shrink-0">
        <div className="flex items-center gap-3">
          <div className="rounded-xl bg-emerald-500/15 p-2.5 text-emerald-400">
            <FiCheckCircle className="text-lg" />
          </div>
          <div>
            <h2 className="text-lg font-bold">Manual Attendance</h2>
            <p className="text-xs text-slate-400">Tick present / absent by class or dormitory</p>
          </div>
        </div>
        <button onClick={onClose} className="rounded-lg p-2 text-slate-400 hover:bg-slate-800 hover:text-white">
          <FiX />
        </button>
      </div>

      {/* Controls */}
      <div className="shrink-0 border-b border-slate-800 bg-slate-900/60 px-6 py-4 space-y-3">
        <div className="flex gap-3 flex-wrap">
          {/* Filter type toggle */}
          <div className="flex rounded-xl border border-slate-700 overflow-hidden">
            {(["class", "dormitory"] as const).map(t => (
              <button key={t} onClick={() => { setFilterType(t); setSelectedFilter(""); setStudents([]); }}
                className={`px-4 py-2 text-xs font-semibold capitalize transition ${
                  filterType === t ? "bg-cyan-500/20 text-cyan-300" : "text-slate-400 hover:text-white"
                }`}>
                {t}
              </button>
            ))}
          </div>

          {/* Filter selector */}
          <select value={selectedFilter} onChange={e => setSelectedFilter(e.target.value)}
            className="flex-1 min-w-40 rounded-xl border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none">
            <option value="">-- select {filterType} --</option>
            {(filterType === "class" ? classes : dormitories).map((item: any) => (
              <option key={item.id} value={item.id}>{item.name}</option>
            ))}
          </select>

          {/* Session selector */}
          <select value={selectedSession} onChange={e => setSelectedSession(e.target.value)}
            className="flex-1 min-w-48 rounded-xl border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none">
            <option value="">-- select session --</option>
            {sessions.map((s: any) => (
              <option key={s.id} value={s.id}>
                {s.session_name ?? s.location_type ?? "Session"} — {s.session_date}
              </option>
            ))}
          </select>

          <button onClick={() => void load()} disabled={loading}
            className="rounded-xl border border-slate-700 bg-slate-800 p-2 text-slate-400 hover:text-white disabled:opacity-40">
            <FiRefreshCw className={loading ? "animate-spin" : ""} />
          </button>
        </div>

        {students.length > 0 && (
          <div className="flex items-center gap-4">
            <span className="text-sm text-slate-400">{students.length} students</span>
            <span className="text-sm text-emerald-400 font-semibold">{present} present</span>
            <span className="text-sm text-red-400 font-semibold">{absent} absent</span>
            <div className="flex gap-2 ml-auto">
              <button onClick={() => markAll("present")}
                className="rounded-lg bg-emerald-600/20 border border-emerald-600/40 px-4 py-1.5 text-xs font-semibold text-emerald-300 hover:bg-emerald-600/30">
                All Present
              </button>
              <button onClick={() => markAll("absent")}
                className="rounded-lg bg-red-600/20 border border-red-600/40 px-4 py-1.5 text-xs font-semibold text-red-300 hover:bg-red-600/30">
                All Absent
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Student grid */}
      <div className="flex-1 overflow-y-auto p-4">
        {loading ? (
          <div className="py-20 text-center text-slate-500">Loading students...</div>
        ) : students.length === 0 ? (
          <div className="py-20 text-center text-slate-500">
            Select a {filterType} above to load students
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
            {students.map(s => {
              const status = attendance[s.id] ?? "present";
              return (
                <button key={s.id} onClick={() => toggle(s.id)}
                  className={`flex items-center gap-3 rounded-xl border p-3 text-left transition active:scale-95 ${
                    status === "present"
                      ? "border-emerald-600/40 bg-emerald-600/10"
                      : "border-red-600/40 bg-red-600/10"
                  }`}>
                  <div className={`h-9 w-9 shrink-0 rounded-full flex items-center justify-center text-sm font-black ${
                    status === "present"
                      ? "bg-emerald-600/30 text-emerald-300"
                      : "bg-red-600/30 text-red-300"
                  }`}>
                    {status === "present" ? "P" : "A"}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-semibold truncate">{s.first_name} {s.last_name}</p>
                    <p className="text-[10px] text-slate-400 font-mono">{s.student_id_number}</p>
                  </div>
                </button>
              );
            })}
          </div>
        )}
      </div>

      {/* Submit bar */}
      {students.length > 0 && (
        <form onSubmit={handleSubmit}
          className="shrink-0 border-t border-slate-700 bg-slate-900 px-5 py-4 flex items-center gap-3">
          <input value={notes} onChange={e => setNotes(e.target.value)}
            placeholder="Reason (e.g. Roll call, Device failure)"
            className="flex-1 form-field text-sm" />
          <button type="submit" disabled={submitting || !selectedSession}
            className="shrink-0 rounded-xl bg-cyan-600 px-6 py-3 font-bold text-white hover:bg-cyan-500 disabled:opacity-50 transition whitespace-nowrap">
            {submitting ? "Saving..." : `Submit (${present}P / ${absent}A)`}
          </button>
        </form>
      )}
    </div>
  );
}
