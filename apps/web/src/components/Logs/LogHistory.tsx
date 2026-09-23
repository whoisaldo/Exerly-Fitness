import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, ApiError, getSessionScope } from '../../lib/api';
import { addDays } from '../../lib/dates';
import {
  changed,
  logPath,
  logsChanged,
  normalizeLog,
  readLogs,
  readWrites,
  saveRecord,
} from './logStorage';
import type { LogKind, LogRecord } from './logStorage';

export function LogHistory({
  prefix,
  kind,
  date,
}: {
  prefix: string;
  kind: LogKind;
  date: string;
}) {
  const [days, setDays] = useState(30);
  const [refresh, setRefresh] = useState(0);
  const [records, setRecords] = useState<LogRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const from = addDays(date, -(days - 1));
  const path = logPath(kind);
  useEffect(() => {
    const update = () => {
      try {
        const merged = new Map(readLogs(prefix).map((row) => [row.client_id, row]));
        for (const write of readWrites(prefix, kind)) merged.set(write.entity, write.snapshot);
        setRecords([...merged.values()]);
      } catch {
        setError('Saved history could not be read. It remains stored in this browser.');
      }
    };
    update();
    window.addEventListener('storage', update);
    window.addEventListener(logsChanged, update);
    return () => {
      window.removeEventListener('storage', update);
      window.removeEventListener(logsChanged, update);
    };
  }, [prefix, kind]);
  useEffect(() => {
    const controller = new AbortController();
    const credential = getSessionScope();
    const active = () => !controller.signal.aborted && getSessionScope() === credential;
    setLoading(true);
    setError(null);
    void (async () => {
      const all: LogRecord[] = [];
      for (let page = 1; ; page++) {
        const rows = await api.get<LogRecord[]>(
          `${path}?from=${from}&to=${date}&include_deleted=true&limit=500&page=${page}`,
          { signal: controller.signal }
        );
        if (!active()) return;
        all.push(...rows.map(normalizeLog));
        if (rows.length < 500) break;
      }
      const ids = new Set(all.map((row) => row.id));
      const removed: string[] = [];
      for (const saved of readLogs(prefix).filter(
        (row) => row.entry_date >= from && row.entry_date <= date && !ids.has(row.id)
      )) {
        try {
          all.push(
            normalizeLog(
              await api.get<LogRecord>(
                `${path}/${encodeURIComponent(saved.id)}?include_deleted=true`,
                { signal: controller.signal }
              )
            )
          );
        } catch (err) {
          if (err instanceof ApiError && err.status === 404) removed.push(saved.client_id);
          else throw err;
        }
      }
      if (!active()) return;
      all.forEach((row) => saveRecord(prefix, row));
      removed.forEach((id) => localStorage.removeItem(`${prefix}entry:${id}`));
      changed();
    })()
      .catch(() => {
        if (active()) setError('Could not refresh history. Showing entries saved in this browser.');
      })
      .finally(() => {
        if (active()) setLoading(false);
      });
    return () => controller.abort();
  }, [from, date, path, prefix, refresh]);
  const visible = records.filter(
    (row) => !row.deleted_at && row.entry_date >= from && row.entry_date <= date
  );
  const grouped = new Map<string, LogRecord[]>();
  for (const row of visible)
    grouped.set(row.entry_date, [...(grouped.get(row.entry_date) ?? []), row]);
  const duration = (rows: LogRecord[]) =>
    rows.reduce(
      (sum, row) => sum + (kind === 'activity' ? (row.duration_min ?? 0) : (row.hours ?? 0)),
      0
    );
  const total = duration(visible);
  const format = (value: number) => value.toLocaleString(undefined, { maximumFractionDigits: 2 });
  return (
    <section
      aria-label={`${kind === 'activity' ? 'Activity' : 'Sleep'} history`}
      className="mt-8 rounded-2xl border border-white/10 bg-surface-1 p-5 text-slate-100"
    >
      <div className="flex flex-wrap items-start justify-between gap-4">
        <h2 className="text-balance text-lg font-semibold">
          {kind === 'activity' ? 'Activity' : 'Sleep'} history
        </h2>
        <label className="text-sm text-slate-300">
          History period
          <select
            value={days}
            onChange={(event) => setDays(Number(event.target.value))}
            className="ml-2 min-h-11 rounded-xl border border-white/20 bg-surface-2 px-3 text-base text-slate-100"
          >
            {[7, 30, 90].map((value) => (
              <option key={value} value={value}>
                Last {value} days
              </option>
            ))}
          </select>
        </label>
      </div>
      <p className="mt-3 text-pretty text-sm tabular-nums text-slate-300">
        {from} to {date} · {visible.length} {visible.length === 1 ? 'entry' : 'entries'} on{' '}
        {grouped.size} recorded {grouped.size === 1 ? 'day' : 'days'}.
      </p>
      {visible.length > 0 && (
        <p className="mt-3 text-pretty text-sm tabular-nums text-slate-100">
          {kind === 'activity'
            ? `${format(total)} minutes total · ${format(total / visible.length)} minutes per activity`
            : `${format(total / grouped.size)} hours per recorded day · Days without entries are excluded.`}
        </p>
      )}
      {kind === 'activity' && visible.length > 0 && (
        <p className="mt-2 text-sm tabular-nums text-slate-300">
          {visible.some((row) => row.calories != null)
            ? `${format(visible.reduce((sum, row) => sum + (row.calories ?? 0), 0))} logged kcal · ${visible.filter((row) => row.calories == null).length} entries without calories`
            : 'Calories not recorded'}
        </p>
      )}
      {loading && (
        <p role="status" className="mt-3 text-sm text-slate-300">
          Checking history…
        </p>
      )}
      {error && (
        <p role="alert" className="mt-3 text-pretty text-sm text-error">
          {error}
        </p>
      )}
      <ul className="mt-4 divide-y divide-white/10">
        {[...grouped.entries()]
          .sort(([a], [b]) => b.localeCompare(a))
          .map(([day, rows]) => (
            <li key={day}>
              <Link
                className="flex min-h-11 flex-wrap items-center justify-between gap-2 py-3 text-sm underline"
                to={`/dashboard/${kind === 'activity' ? 'activities' : 'sleep'}?date=${day}`}
              >
                <span className="tabular-nums">{day}</span>
                <span className="tabular-nums">
                  {format(duration(rows))} {kind === 'activity' ? 'min' : 'hours'} · {rows.length}{' '}
                  {rows.length === 1 ? 'entry' : 'entries'}
                </span>
              </Link>
            </li>
          ))}
      </ul>
      {!loading && !visible.length && (
        <p className="mt-3 text-sm text-slate-300">
          No entries saved here in this period. Choose a day above to log one.
        </p>
      )}
      <button
        disabled={loading}
        onClick={() => setRefresh((value) => value + 1)}
        className="mt-4 min-h-11 rounded-xl border border-white/20 px-4 text-sm disabled:opacity-50"
      >
        Refresh history
      </button>
    </section>
  );
}
