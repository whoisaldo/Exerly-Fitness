import { useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import API_CONFIG from '../../config';
import { api, ApiError, getSessionScope } from '../../lib/api';
import { addDays, isCalendarDay } from '../../lib/dates';
import { useAccountCalendar, useSelectedDay } from '../../hooks/useAccountCalendar';
import { operationID } from '../../lib/ids';
import { cn } from '../../lib/cn';
import { useSession } from '../../hooks/useSession';
import { AppShell } from '../ui/AppShell';
import { DateNav } from '../ui/DateNav';
import { ConfirmAction } from '../ui/ConfirmAction';
import { LogHistory } from './LogHistory';
import {
  changed,
  describeLog,
  editDraft,
  logPath,
  logsChanged,
  newDraft,
  normalizeLog,
  persistWrite,
  readDraft,
  readLogs,
  readWrites,
  removeWrite,
  saveRecord,
  transmit,
} from './logStorage';
import type { LogDraft, LogKind, LogRecord, LogWrite } from './logStorage';

const button =
  'min-h-11 rounded-xl border border-white/20 px-4 py-2 text-sm font-semibold text-slate-100 hover:bg-white/5 focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary disabled:opacity-50';
const input =
  'mt-1 min-h-11 w-full rounded-xl border border-white/20 bg-surface-2 px-3 py-2 text-base text-slate-100 focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary';
const message = (error: unknown) =>
  error instanceof Error
    ? error.message
    : 'This change could not be synchronized. Your saved copy is still in this browser.';

export default function ManualLogs({ kind }: { kind: LogKind }) {
  const { date, setDate } = useSelectedDay();
  const { user, loading } = useSession();
  const prefix = user?._id ? `manual-logs.v1:${API_CONFIG.BASE_URL}:${user._id}:${kind}:` : null;
  return (
    <AppShell>
      <div className="flex flex-wrap items-center justify-between gap-4">
        <h1 className="text-balance text-display-sm text-slate-50">
          {kind === 'activity' ? 'Activity' : 'Sleep'}
        </h1>
        <DateNav date={date} onChange={setDate} />
      </div>
      <nav aria-label="Daily logs" className="mt-4 flex gap-5 text-sm text-slate-300">
        <Link className="py-2 underline" to={`/dashboard/diary?date=${date}`}>
          Food diary
        </Link>
        <Link
          className="py-2 underline"
          to={`/dashboard/${kind === 'activity' ? 'sleep' : 'activities'}?date=${date}`}
        >
          {kind === 'activity' ? 'Sleep' : 'Activity'}
        </Link>
      </nav>
      {loading && (
        <p role="status" className="mt-6 text-slate-300">
          Loading your account…
        </p>
      )}
      {prefix && <OwnedLogs key={prefix + date} prefix={prefix} date={date} kind={kind} />}
      {prefix && <LogHistory key={prefix} prefix={prefix} date={date} kind={kind} />}
    </AppShell>
  );
}

function OwnedLogs({ prefix, date, kind }: { prefix: string; date: string; kind: LogKind }) {
  const { today } = useAccountCalendar();
  const path = logPath(kind);
  const label = kind === 'activity' ? 'activity' : 'sleep entry';
  const draftKey = `${prefix}draft:${date}`;
  const [records, setRecords] = useState<LogRecord[]>([]);
  const [writes, setWrites] = useState<LogWrite[]>([]);
  const [draft, setDraft] = useState<LogDraft | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [storageReady, setStorageReady] = useState(false);
  const [sending, setSending] = useState(false);
  const [refresh, setRefresh] = useState(0);
  const [conflicts, setConflicts] = useState<Record<string, LogRecord>>({});
  const [writeErrors, setWriteErrors] = useState<Record<string, string>>({});
  const mounted = useRef(true);
  const busy = useRef(false);

  useEffect(() => {
    mounted.current = true;
    const update = () => {
      try {
        setRecords(readLogs(prefix));
        setWrites(readWrites(prefix, kind));
        setDraft(readDraft(draftKey));
        setStorageReady(true);
      } catch (err) {
        setError(message(err));
        setStorageReady(false);
      }
    };
    update();
    window.addEventListener('storage', update);
    window.addEventListener(logsChanged, update);
    return () => {
      mounted.current = false;
      window.removeEventListener('storage', update);
      window.removeEventListener(logsChanged, update);
    };
  }, [prefix, draftKey, kind]);

  useEffect(() => {
    const controller = new AbortController();
    const credential = getSessionScope();
    const active = () => !controller.signal.aborted && getSessionScope() === credential;
    setLoading(true);
    setLoadError(null);
    void (async () => {
      const all: LogRecord[] = [];
      for (let page = 1; ; page++) {
        const rows = await api.get<LogRecord[]>(
          `${path}?date=${date}&include_deleted=true&limit=500&page=${page}`,
          { signal: controller.signal }
        );
        if (!active()) return;
        all.push(...rows.map(normalizeLog));
        if (rows.length < 500) break;
      }
      // Resolve missing cached IDs: entries may have moved to another day.
      const ids = new Set(all.map((row) => row.id));
      for (const saved of readLogs(prefix).filter(
        (row) => row.entry_date === date && !ids.has(row.id)
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
          if (!active()) return;
          if (err instanceof ApiError && err.status === 404)
            localStorage.removeItem(`${prefix}entry:${saved.client_id}`);
          else throw err;
        }
      }
      if (!active()) return;
      all.forEach((row) => saveRecord(prefix, row));
      changed();
    })()
      .catch((err) => {
        if (active()) setLoadError(message(err));
      })
      .finally(() => {
        if (active()) setLoading(false);
      });
    return () => controller.abort();
  }, [date, prefix, path, refresh]);

  function storeDraft(next: LogDraft | null) {
    try {
      if (next) localStorage.setItem(draftKey, JSON.stringify(next));
      else localStorage.removeItem(draftKey);
      changed();
      setError(null);
    } catch {
      setError('This browser could not save the draft. Free storage space before continuing.');
    }
  }
  function field(name: string, value: string) {
    if (draft) storeDraft({ ...draft, fields: { ...draft.fields, [name]: value } });
  }
  async function send(write: LogWrite) {
    if (busy.current) return;
    busy.current = true;
    setSending(true);
    const credential = getSessionScope();
    let stored = false;
    try {
      persistWrite(prefix, write);
      stored = true;
      setError(null);
      setWriteErrors((values) => ({ ...values, [write.id]: '' }));
      const result = await transmit(write, kind);
      // Acknowledgements stay with the original account after navigation.
      saveRecord(prefix, result);
      removeWrite(prefix, write.id);
      if (mounted.current && getSessionScope() === credential) setRefresh((value) => value + 1);
    } catch (err) {
      if (!mounted.current || getSessionScope() !== credential) return;
      if (!stored) {
        setError('This browser could not save the change. Free storage space before continuing.');
        return;
      }
      if (err instanceof ApiError && err.status === 409) {
        const current = (err.details as { current?: LogRecord } | undefined)?.current;
        if (current)
          setConflicts((previous) => ({ ...previous, [write.id]: normalizeLog(current) }));
      }
      setWriteErrors((values) => ({ ...values, [write.id]: message(err) }));
    } finally {
      busy.current = false;
      if (mounted.current) setSending(false);
    }
  }
  function save() {
    if (!draft || busy.current) return;
    const fields = draft.fields;
    const value = Number(kind === 'activity' ? fields.duration_min : fields.hours);
    const energy = fields.calories?.trim() ? Number(fields.calories) : null;
    if (
      !isCalendarDay(fields.entry_date) ||
      fields.entry_date > today ||
      fields.entry_date < addDays(today, -3650)
    ) {
      setError('Choose today or a date within the past ten years.');
      return;
    }
    if (
      !Number.isFinite(value) ||
      (kind === 'activity' ? value < 0.1 || value > 1440 : !fields.hours || value < 0 || value > 24)
    ) {
      setError(
        kind === 'activity'
          ? 'Enter a duration from 0.1 to 1,440 minutes.'
          : 'Enter hours slept from 0 to 24.'
      );
      return;
    }
    if (
      kind === 'activity' &&
      (!fields.activity?.trim() ||
        (energy !== null && (!Number.isFinite(energy) || energy < 0 || energy > 20000)))
    ) {
      setError('Enter an activity name and a calorie amount from 0 to 20,000 if known.');
      return;
    }
    const body =
      kind === 'activity'
        ? {
            activity: fields.activity.trim(),
            duration_min: value,
            calories: energy,
            intensity: fields.intensity || null,
            type: fields.type || null,
            entry_date: fields.entry_date,
          }
        : {
            hours: value,
            quality: fields.quality || null,
            bedtime: fields.bedtime || null,
            wake_time: fields.wake_time || null,
            entry_date: fields.entry_date,
          };
    const write: LogWrite = {
      id: operationID(),
      entity: draft.entity,
      intent: 'save',
      method: draft.original ? 'PUT' : 'POST',
      path: draft.original ? `${path}/${encodeURIComponent(draft.original.id)}` : path,
      body: {
        ...body,
        client_id: draft.entity,
        ...(draft.original ? { base_revision: draft.original.revision } : {}),
      },
      snapshot: {
        ...draft.original,
        ...body,
        id: draft.original?.id ?? draft.entity,
        client_id: draft.entity,
        revision: draft.original?.revision ?? 0,
      },
    };
    try {
      persistWrite(prefix, write);
      localStorage.removeItem(draftKey);
      changed();
      void send(write);
    } catch {
      setError('This browser could not save the entry. Your draft is still open.');
    }
  }
  function remove(row: LogRecord) {
    void send({
      id: operationID(),
      entity: row.client_id,
      intent: 'delete',
      method: 'DELETE',
      path: `${path}/${encodeURIComponent(row.id)}`,
      body: { base_revision: row.revision },
      snapshot: { ...row, deleted_at: new Date().toISOString() },
    });
  }
  function restore(row: LogRecord) {
    void send({
      id: operationID(),
      entity: row.client_id,
      intent: 'restore',
      method: 'POST',
      path: `${path}/${encodeURIComponent(row.id)}/restore`,
      body: { base_revision: row.revision },
      snapshot: { ...row, deleted_at: null },
    });
  }
  function acceptSaved(write: LogWrite, server: LogRecord) {
    try {
      saveRecord(prefix, server);
      removeWrite(prefix, write.id);
      setRefresh((value) => value + 1);
    } catch (err) {
      setError(message(err));
    }
  }
  function applyReviewed(write: LogWrite, server: LogRecord) {
    if (server.deleted_at && write.intent !== 'restore') return;
    void send({
      ...write,
      id: operationID(),
      replaces: write.id,
      method: write.intent === 'save' ? 'PUT' : write.method,
      path: `${path}/${encodeURIComponent(server.id)}${write.intent === 'restore' ? '/restore' : ''}`,
      body: { ...write.body, base_revision: server.revision },
      snapshot: { ...write.snapshot, id: server.id, revision: server.revision },
    });
  }
  const merged = new Map(records.map((row) => [row.client_id, row]));
  for (const write of writes) merged.set(write.entity, write.snapshot);
  const entries = [...merged.values()]
    .filter((row) => row.entry_date === date)
    .sort((a, b) => (b.created_at ?? '').localeCompare(a.created_at ?? ''));
  const active = entries.filter((row) => !row.deleted_at);
  const pendingEntities = new Set(writes.map((write) => write.entity));
  const duration = active.reduce(
    (sum, row) => sum + (kind === 'activity' ? (row.duration_min ?? 0) : (row.hours ?? 0)),
    0
  );
  const calories = active.filter((row) => row.calories != null);
  const draftPending = draft && pendingEntities.has(draft.entity);

  return (
    <div className="mt-6 space-y-6 text-slate-100">
      <section
        aria-label={`${kind === 'activity' ? 'Activity' : 'Sleep'} for ${date}`}
        className="rounded-2xl border border-white/10 bg-surface-1 p-5"
      >
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p className="text-sm text-slate-300">
              {kind === 'activity' ? 'Logged movement' : 'Manual sleep'} ·{' '}
              <span className="tabular-nums">{date}</span>
            </p>
            <p className="mt-2 text-3xl font-semibold tabular-nums">
              {active.length
                ? duration.toLocaleString(undefined, { maximumFractionDigits: 4 })
                : '—'}{' '}
              <span className="text-base font-normal text-slate-300">
                {kind === 'activity' ? 'minutes' : 'hours'}
              </span>
            </p>
            {kind === 'activity' && (
              <p className="mt-2 text-sm tabular-nums text-slate-300">
                {calories.length
                  ? `${calories.reduce((sum, row) => sum + (row.calories ?? 0), 0).toLocaleString()} logged kcal${calories.length < active.length ? ' · Some calories not recorded' : ''}`
                  : 'Calories not recorded'}
              </p>
            )}
          </div>
          <button
            className={button}
            disabled={loading || sending}
            onClick={() => setRefresh((value) => value + 1)}
          >
            Refresh entries
          </button>
        </div>
        {kind === 'sleep' && (
          <p className="mt-4 text-pretty text-sm text-slate-300">
            Log overnight sleep on the day you woke up. Naps are separate entries. Hours are entered
            separately from optional times.
          </p>
        )}
        {loading && (
          <p role="status" className="mt-3 text-sm text-slate-300">
            Checking saved entries…
          </p>
        )}
        {loadError && (
          <p role="alert" className="mt-3 text-sm text-slate-300">
            Could not refresh. Showing entries saved in this browser. {loadError}
          </p>
        )}
        {!draft && (
          <button
            className={cn(button, 'mt-5 border-primary bg-primary text-white')}
            disabled={!storageReady || sending}
            onClick={() => storeDraft(newDraft(date))}
          >
            Log {kind}
          </button>
        )}
      </section>
      {error && (
        <p id="log-error" role="alert" className="text-pretty text-sm text-error">
          {error}
        </p>
      )}
      {draft && (
        <form
          aria-label={`${draft.original ? 'Edit' : 'Log'} ${kind}`}
          onSubmit={(event) => {
            event.preventDefault();
            save();
          }}
          className="rounded-2xl border border-white/15 bg-surface-1 p-5"
        >
          <h2 className="text-balance text-lg font-semibold">
            {draft.original ? 'Edit' : 'Log'} {kind}
          </h2>
          <p className="mt-1 text-sm text-slate-300">
            Draft saved in this browser. Save the entry to sync it.
          </p>
          <fieldset
            disabled={sending || !!draftPending || !storageReady}
            className="mt-5 grid gap-4 sm:grid-cols-2"
          >
            {kind === 'activity' ? (
              <>
                <label className="text-sm sm:col-span-2">
                  Activity name
                  <input
                    className={input}
                    value={draft.fields.activity}
                    onChange={(e) => field('activity', e.target.value)}
                    maxLength={120}
                    required
                  />
                </label>
                <label className="text-sm">
                  Duration (minutes)
                  <input
                    className={input}
                    type="number"
                    inputMode="decimal"
                    step="any"
                    min="0.1"
                    max="1440"
                    value={draft.fields.duration_min}
                    onChange={(e) => field('duration_min', e.target.value)}
                    required
                  />
                </label>
                <label className="text-sm">
                  Calories, optional
                  <input
                    className={input}
                    type="number"
                    inputMode="decimal"
                    step="any"
                    min="0"
                    max="20000"
                    value={draft.fields.calories}
                    onChange={(e) => field('calories', e.target.value)}
                  />
                </label>
                <label className="text-sm">
                  Intensity
                  <select
                    className={input}
                    value={draft.fields.intensity}
                    onChange={(e) => field('intensity', e.target.value)}
                  >
                    <option value="">Not recorded</option>
                    {['light', 'moderate', 'intense'].map((value) => (
                      <option key={value} value={value}>
                        {value}
                      </option>
                    ))}
                    {draft.fields.intensity &&
                      !['light', 'moderate', 'intense'].includes(draft.fields.intensity) && (
                        <option value={draft.fields.intensity}>{draft.fields.intensity}</option>
                      )}
                  </select>
                </label>
                <label className="text-sm">
                  Type, optional
                  <input
                    className={input}
                    maxLength={48}
                    value={draft.fields.type}
                    onChange={(e) => field('type', e.target.value)}
                  />
                </label>
              </>
            ) : (
              <>
                <label className="text-sm">
                  Hours slept
                  <input
                    className={input}
                    type="number"
                    inputMode="decimal"
                    step="any"
                    min="0"
                    max="24"
                    value={draft.fields.hours}
                    onChange={(e) => field('hours', e.target.value)}
                    required
                  />
                </label>
                <label className="text-sm">
                  Quality
                  <select
                    className={input}
                    value={draft.fields.quality}
                    onChange={(e) => field('quality', e.target.value)}
                  >
                    <option value="">Not recorded</option>
                    {['poor', 'fair', 'good', 'great', 'excellent'].map((value) => (
                      <option key={value} value={value}>
                        {value}
                      </option>
                    ))}
                    {draft.fields.quality &&
                      !['poor', 'fair', 'good', 'great', 'excellent'].includes(
                        draft.fields.quality
                      ) && <option value={draft.fields.quality}>{draft.fields.quality}</option>}
                  </select>
                </label>
                <label className="text-sm">
                  Bedtime, optional
                  <input
                    className={input}
                    placeholder="23:00"
                    maxLength={16}
                    value={draft.fields.bedtime}
                    onChange={(e) => field('bedtime', e.target.value)}
                  />
                </label>
                <label className="text-sm">
                  Wake time, optional
                  <input
                    className={input}
                    placeholder="06:30"
                    maxLength={16}
                    value={draft.fields.wake_time}
                    onChange={(e) => field('wake_time', e.target.value)}
                  />
                </label>
              </>
            )}
            <label className="text-sm">
              {kind === 'sleep' ? 'Wake date' : 'Activity date'}
              <input
                className={input}
                type="date"
                min={addDays(today, -3650)}
                max={today}
                value={draft.fields.entry_date}
                onChange={(e) => field('entry_date', e.target.value)}
                required
              />
            </label>
          </fieldset>
          {draftPending && (
            <p role="status" className="mt-4 text-sm">
              This entry has a pending change. Sync or review it before saving another edit.
            </p>
          )}
          <div className="mt-5 flex flex-wrap gap-3">
            <button
              type="submit"
              className={cn(button, 'border-primary bg-primary text-white')}
              disabled={sending || !!draftPending || !storageReady}
              aria-describedby={error ? 'log-error' : undefined}
            >
              Save {kind}
            </button>
            <ConfirmAction
              trigger={
                <button type="button" className={button} disabled={sending}>
                  Discard draft
                </button>
              }
              title="Discard this draft?"
              description="This removes your unsaved form. Saved entries are kept."
              action="Discard draft"
              onConfirm={() => storeDraft(null)}
            />
          </div>
        </form>
      )}
      {writes.length > 0 && (
        <section aria-label="Pending changes" className="space-y-3">
          <h2 className="text-balance text-lg font-semibold">Pending changes</h2>
          {writes.map((write) => {
            const server = conflicts[write.id];
            return (
              <article
                key={write.id}
                aria-label={`Pending ${label}`}
                className="rounded-2xl border border-primary/50 p-5"
              >
                <p className="text-pretty font-medium tabular-nums">
                  {describeLog(write.snapshot, kind)} · {write.snapshot.entry_date}
                </p>
                <p role="status" className="mt-2 text-sm text-slate-300">
                  {write.intent === 'delete'
                    ? 'Deletion'
                    : write.intent === 'restore'
                      ? 'Restore'
                      : 'Entry'}{' '}
                  saved in this browser. Retry to sync.
                </p>
                {writeErrors[write.id] && (
                  <p role="alert" className="mt-2 text-pretty text-sm text-error">
                    {writeErrors[write.id]}
                  </p>
                )}
                {server ? (
                  <>
                    <p className="mt-4 text-pretty text-sm tabular-nums">
                      Saved version: {describeLog(server, kind)} · {server.entry_date}
                      {server.deleted_at ? ' · Deleted' : ''}
                    </p>
                    <div className="mt-4 flex flex-wrap gap-3">
                      <ConfirmAction
                        trigger={
                          <button className={button} disabled={sending}>
                            Use saved version
                          </button>
                        }
                        title="Use the saved version?"
                        description="This discards your pending change and keeps the version shown above."
                        action="Use saved version"
                        onConfirm={() => acceptSaved(write, server)}
                      />
                      {(!server.deleted_at || write.intent === 'restore') && (
                        <button
                          className={button}
                          disabled={sending}
                          onClick={() => applyReviewed(write, server)}
                        >
                          Apply my reviewed change
                        </button>
                      )}
                    </div>
                    {server.deleted_at && write.intent !== 'restore' && (
                      <p className="mt-3 text-sm text-slate-300">
                        This entry was deleted elsewhere. Use the saved version, then restore it
                        before editing.
                      </p>
                    )}
                  </>
                ) : (
                  <button
                    className={cn(button, 'mt-4')}
                    disabled={sending || !storageReady}
                    onClick={() => void send(write)}
                  >
                    Retry {label} change
                  </button>
                )}
              </article>
            );
          })}
        </section>
      )}
      <section aria-label="Saved entries">
        <h2 className="text-balance text-lg font-semibold">Entries for this day</h2>
        {!entries.length && !loading && (
          <p className="mt-3 text-pretty text-sm text-slate-300">
            No {kind} entries saved here for this day. Use Log {kind} to add one.
          </p>
        )}
        <ul className="mt-3 divide-y divide-white/10">
          {entries.map((row) => (
            <li key={row.client_id} className="py-5">
              <article
                aria-label={`${label}: ${kind === 'activity' ? row.activity : `${row.hours} hours`}`}
              >
                <p className="text-pretty font-medium tabular-nums">{describeLog(row, kind)}</p>
                {kind === 'activity' && (row.intensity || row.type) && (
                  <p className="mt-1 text-sm text-slate-300">
                    {[row.intensity, row.type].filter(Boolean).join(' · ')}
                  </p>
                )}
                <p role="status" className="mt-2 text-sm text-slate-300">
                  {pendingEntities.has(row.client_id)
                    ? 'Waiting to sync'
                    : row.deleted_at
                      ? 'Entry deleted'
                      : 'Synced'}
                </p>
                <div className="mt-3 flex flex-wrap gap-3">
                  {row.deleted_at ? (
                    <button
                      className={button}
                      disabled={sending || pendingEntities.has(row.client_id) || !storageReady}
                      onClick={() => restore(row)}
                    >
                      Restore {label}
                    </button>
                  ) : (
                    <>
                      <button
                        className={button}
                        disabled={
                          !!draft || sending || pendingEntities.has(row.client_id) || !storageReady
                        }
                        onClick={() => storeDraft(editDraft(row))}
                      >
                        Edit {label}
                      </button>
                      <ConfirmAction
                        trigger={
                          <button
                            className={button}
                            disabled={
                              sending ||
                              pendingEntities.has(row.client_id) ||
                              !!draft ||
                              !storageReady
                            }
                          >
                            Delete {label}
                          </button>
                        }
                        title={`Delete this ${label}?`}
                        description="It will be removed from this day's totals. You can restore it from this list."
                        action={`Delete ${label}`}
                        onConfirm={() => remove(row)}
                      />
                    </>
                  )}
                </div>
              </article>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}
