import { useEffect, useRef, useState } from 'react';
import API_CONFIG from '../../config';
import { api, ApiError, getSessionScope } from '../../lib/api';
import { operationID } from '../../lib/ids';
import { displayWeight, lbToKg } from '../../lib/units';
import type { UnitSystem } from '../../lib/units';
import { useSession } from '../../hooks/useSession';
import { useResource } from '../../hooks/useResource';
import { GlassCard } from '../ui/GlassCard';
import { ActionButton } from '../ui/ActionButton';

interface Reading {
  entry_date: string;
  weight_kg: number | null;
  revision: number;
  id?: string;
  source?: string;
  note?: string | null;
  body_fat_pct?: number | null;
  deleted_at?: string | null;
}
interface Pending {
  id: string;
  method: 'PUT' | 'POST' | 'DELETE';
  path: string;
  body: Record<string, unknown>;
  label: string;
  replaces?: string;
}
const changedEvent = 'exerly-weight-pending';
const fields =
  'mt-1 min-h-11 w-full rounded-xl border border-white/15 bg-surface-2 px-3 py-2 text-base text-slate-100 focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary';
function pendingWrites(prefix: string): Pending[] {
  const rows: Pending[] = [];
  for (let i = 0; i < localStorage.length; i++) {
    const key = localStorage.key(i);
    if (!key?.startsWith(prefix)) continue;
    const row = JSON.parse(localStorage.getItem(key) || 'null');
    if (
      !row ||
      typeof row.id !== 'string' ||
      key !== prefix + row.id ||
      !['PUT', 'POST', 'DELETE'].includes(row.method) ||
      typeof row.path !== 'string' ||
      !row.path.startsWith('/api/weight') ||
      !row.body ||
      !Number.isInteger(row.body.base_revision)
    ) {
      throw new Error(
        'A pending weight change could not be read. It is still stored in this browser.'
      );
    }
    rows.push(row);
  }
  const replaced = new Set(rows.map((row) => row.replaces));
  return rows.filter((row) => !replaced.has(row.id));
}

export default function WeightLogging({ date, onSaved }: { date: string; onSaved: () => void }) {
  const { user, unitSystem } = useSession();
  const prefix = user?._id ? `weight-writes.v1:${API_CONFIG.BASE_URL}:${user._id}:${date}:` : null;
  return prefix ? (
    <OwnedWeight key={prefix} date={date} prefix={prefix} units={unitSystem} onSaved={onSaved} />
  ) : null;
}

function OwnedWeight({
  date,
  prefix,
  units,
  onSaved,
}: {
  date: string;
  prefix: string;
  units: UnitSystem;
  onSaved: () => void;
}) {
  const current = useResource<Reading>(
    (signal) => api.get(`/api/weight/day?entry_date=${date}`, { signal, offlineFallback: true }),
    [date]
  );
  const [value, setValue] = useState<string | null>(null);
  const [note, setNote] = useState<string | null>(null);
  const [base, setBase] = useState<number | null>(null);
  const [pending, setPending] = useState<Pending[]>([]);
  const [conflicts, setConflicts] = useState<Record<string, Reading>>({});
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const busy = useRef(false);
  const mounted = useRef(true);
  const unit = units === 'imperial' ? 'lb' : 'kg';
  useEffect(() => {
    mounted.current = true;
    const update = () => {
      try {
        setPending(pendingWrites(prefix));
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Pending changes could not be read.');
      }
    };
    update();
    window.addEventListener('storage', update);
    window.addEventListener(changedEvent, update);
    return () => {
      mounted.current = false;
      window.removeEventListener('storage', update);
      window.removeEventListener(changedEvent, update);
    };
  }, [prefix]);
  function persist(operation: Pending) {
    localStorage.setItem(prefix + operation.id, JSON.stringify(operation));
    if (operation.replaces) localStorage.removeItem(prefix + operation.replaces);
    window.dispatchEvent(new Event(changedEvent));
  }
  function remove(id: string) {
    localStorage.removeItem(prefix + id);
    window.dispatchEvent(new Event(changedEvent));
  }
  function refresh() {
    setValue(null);
    setNote(null);
    setBase(null);
    current.refetch();
    onSaved();
  }
  async function send(operation: Pending) {
    if (busy.current) return;
    busy.current = true;
    setSaving(true);
    setError(null);
    const credential = getSessionScope();
    try {
      persist(operation);
      if (operation.method === 'PUT')
        await api.put(operation.path, operation.body, { operationID: operation.id });
      else if (operation.method === 'POST')
        await api.post(operation.path, operation.body, { operationID: operation.id });
      else await api.del(operation.path, { body: operation.body, operationID: operation.id });
      remove(operation.id);
      if (mounted.current && getSessionScope() === credential) refresh();
    } catch (err) {
      if (!mounted.current || getSessionScope() !== credential) return;
      if (err instanceof ApiError && err.status === 409) {
        const server = (err.details as { current?: Reading } | undefined)?.current;
        if (server) setConflicts((previous) => ({ ...previous, [operation.id]: server }));
      }
      setError(
        err instanceof Error
          ? err.message
          : 'This change is saved in this browser. Retry when connected.'
      );
    } finally {
      busy.current = false;
      if (mounted.current) setSaving(false);
    }
  }
  function save() {
    const row = current.data;
    if (!row) return;
    const number = Number(
      value ?? (row.weight_kg == null ? '' : displayWeight(row.weight_kg, units, 4))
    );
    const kg = units === 'imperial' ? lbToKg(number) : number;
    if (!Number.isFinite(kg) || kg < 20 || kg > 500) {
      setError('Enter a weight from 20 to 500 kg, or the equivalent in pounds.');
      return;
    }
    void send({
      id: operationID(),
      method: 'PUT',
      path: '/api/weight/day',
      label: `Save ${displayWeight(kg, units, 2)} ${unit} for ${date}`,
      body: {
        entry_date: date,
        weight_kg: Number(kg.toFixed(2)),
        note: note ?? row.note ?? '',
        body_fat_pct: row.body_fat_pct ?? null,
        source: 'manual',
        base_revision: base ?? row.revision,
      },
    });
  }
  const row = current.data;
  const disabled = saving || pending.length > 0 || !row;
  return (
    <GlassCard className="mt-6" hover={false}>
      <section aria-label="Weight reading">
        <h2 className="text-balance text-base font-semibold text-slate-100">Weight for {date}</h2>
        {row && (
          <p role="status" className="mt-2 text-sm tabular-nums text-slate-300">
            {row.deleted_at
              ? 'Reading deleted'
              : row.weight_kg == null
                ? 'No reading for this day'
                : `${displayWeight(row.weight_kg, units, 2)} ${unit} recorded · ${row.source ?? 'manual'}`}
          </p>
        )}
        {current.loading && !row && <p role="status">Loading this day&apos;s reading…</p>}
        {current.error && (
          <p role="alert" className="mt-2 text-error">
            {current.error}
          </p>
        )}
        {row && !row.deleted_at && (
          <form
            aria-label="Log weight"
            onSubmit={(event) => {
              event.preventDefault();
              save();
            }}
            className="mt-4 space-y-3"
          >
            <label className="block text-sm text-slate-300">
              Weight ({unit})
              <input
                type="number"
                inputMode="decimal"
                step="0.01"
                required
                min={units === 'imperial' ? 44.1 : 20}
                max={units === 'imperial' ? 1102.31 : 500}
                value={
                  value ?? (row.weight_kg == null ? '' : displayWeight(row.weight_kg, units, 2))
                }
                onChange={(event) => {
                  setValue(event.target.value);
                  setBase(base ?? row.revision);
                }}
                disabled={disabled}
                className={fields}
              />
            </label>
            <label className="block text-sm text-slate-300">
              Optional note
              <input
                maxLength={280}
                value={note ?? row.note ?? ''}
                onChange={(event) => {
                  setNote(event.target.value);
                  setBase(base ?? row.revision);
                }}
                disabled={disabled}
                className={fields}
              />
            </label>
            <div className="flex flex-wrap gap-2">
              <ActionButton
                type="submit"
                variant="secondary"
                className="min-h-11"
                disabled={disabled}
              >
                Save weight
              </ActionButton>
              {row.id && (
                <ActionButton
                  type="button"
                  variant="ghost"
                  className="min-h-11"
                  disabled={disabled}
                  onClick={() => {
                    if (window.confirm('Delete this weight reading? You can restore it afterward.'))
                      void send({
                        id: operationID(),
                        method: 'DELETE',
                        path: `/api/weight/${row.id}`,
                        body: { base_revision: row.revision },
                        label: `Delete reading for ${date}`,
                      });
                  }}
                >
                  Delete reading
                </ActionButton>
              )}
            </div>
          </form>
        )}
        {row?.deleted_at && (
          <ActionButton
            type="button"
            variant="secondary"
            className="mt-3 min-h-11"
            disabled={disabled}
            onClick={() =>
              void send({
                id: operationID(),
                method: 'POST',
                path: `/api/weight/${row.id}/restore`,
                body: { base_revision: row.revision },
                label: `Restore reading for ${date}`,
              })
            }
          >
            Restore reading
          </ActionButton>
        )}
        {pending.map((operation) => {
          const server = conflicts[operation.id];
          return (
            <div key={operation.id} className="mt-4 rounded-xl border border-white/15 p-4">
              <p className="text-pretty text-sm text-slate-100">{operation.label}</p>
              <p className="mt-1 text-pretty text-sm text-slate-300">
                Saved in this browser.{' '}
                {server ? 'Review the competing reading.' : 'Waiting for confirmation.'}
              </p>
              {server ? (
                <>
                  <p className="mt-2 text-sm tabular-nums text-slate-100">
                    Server:{' '}
                    {server.deleted_at
                      ? 'Deleted'
                      : server.weight_kg == null
                        ? 'No reading'
                        : `${displayWeight(server.weight_kg, units, 2)} ${unit}`}{' '}
                    · revision {server.revision}
                    {server.note ? ` · ${server.note}` : ''}
                  </p>
                  <div className="mt-3 flex flex-wrap gap-2">
                    {(!server.deleted_at || operation.method === 'POST') && (
                      <ActionButton
                        type="button"
                        variant="secondary"
                        disabled={saving}
                        onClick={() =>
                          void send({
                            ...operation,
                            id: operationID(),
                            replaces: operation.id,
                            body: { ...operation.body, base_revision: server.revision },
                          })
                        }
                      >
                        Apply my reviewed change
                      </ActionButton>
                    )}
                    <ActionButton
                      type="button"
                      variant="secondary"
                      disabled={saving}
                      onClick={() => {
                        try {
                          remove(operation.id);
                          setError(null);
                          refresh();
                        } catch {
                          setError('The pending change could not be removed from this browser.');
                        }
                      }}
                    >
                      Keep server reading
                    </ActionButton>
                  </div>
                </>
              ) : (
                <ActionButton
                  type="button"
                  variant="secondary"
                  className="mt-3 min-h-11"
                  disabled={saving}
                  onClick={() => void send(operation)}
                >
                  Retry weight change
                </ActionButton>
              )}
            </div>
          );
        })}
        {error && (
          <p role="alert" className="mt-3 text-pretty text-sm text-error">
            {error}
          </p>
        )}
      </section>
    </GlassCard>
  );
}
