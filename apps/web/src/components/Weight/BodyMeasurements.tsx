import { useEffect, useRef, useState } from 'react';
import API_CONFIG from '../../config';
import { api, ApiError } from '../../lib/api';
import { operationID } from '../../lib/ids';
import { addDays, friendlyDate } from '../../lib/dates';
import { useAccountCalendar } from '../../hooks/useAccountCalendar';
import { useResource } from '../../hooks/useResource';
import { useSession } from '../../hooks/useSession';
import { ActionButton } from '../ui/ActionButton';
import { GlassCard } from '../ui/GlassCard';

interface Measurement {
  id: string;
  client_id: string;
  type: string;
  value: number;
  unit: string;
  entry_date: string;
  revision: number;
  source?: string;
  deleted_at?: string | null;
  note?: string | null;
}
interface Draft {
  id?: string;
  client_id: string;
  type: string;
  value: string;
  unit: string;
  entry_date: string;
  base_revision?: number;
  source: string;
  operationID: string;
  note?: string | null;
}
interface PendingAction {
  kind: 'delete' | 'restore';
  row: Measurement;
  operationID: string;
}
interface SavedState {
  version: 1;
  draft: Draft;
  action: PendingAction | null;
  deleted: Measurement | null;
}
const TYPES = ['waist', 'chest', 'hips', 'arms', 'thighs', 'neck', 'calves', 'body_fat'];
const label = (type: string) =>
  type.replace('_', ' ').replace(/^./, (letter) => letter.toUpperCase());
const fieldClass =
  'mt-1 min-h-11 w-full rounded-xl border border-white/15 bg-surface-2 px-3 py-2 text-base text-slate-100 focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary';
function newDraft(unit: string, today: string): Draft {
  return {
    client_id: operationID(),
    type: 'waist',
    value: '',
    unit,
    entry_date: today,
    source: 'manual',
    operationID: operationID(),
  };
}

export default function BodyMeasurements({ days }: { days: number }) {
  const { user, unitSystem } = useSession();
  const owner = user?._id;
  const storageKey = owner ? `measurements.v1:${API_CONFIG.BASE_URL}:${owner}` : null;
  // Remounting on an owner change prevents one account's draft appearing in another.
  return storageKey ? (
    <OwnedMeasurements
      key={storageKey}
      storageKey={storageKey}
      days={days}
      preferredUnit={unitSystem === 'imperial' ? 'in' : 'cm'}
    />
  ) : null;
}

function OwnedMeasurements({
  storageKey,
  days,
  preferredUnit,
}: {
  storageKey: string;
  days: number;
  preferredUnit: string;
}) {
  const { today } = useAccountCalendar();
  const [saved, setSaved] = useState<SavedState>(() => {
    try {
      const parsed = JSON.parse(localStorage.getItem(storageKey) || 'null') as SavedState | null;
      if (parsed?.version === 1 && parsed.draft?.client_id && parsed.draft?.operationID)
        return parsed;
    } catch {
      /* Preserve an unreadable stored draft until the user saves another. */
    }
    return { version: 1, draft: newDraft(preferredUnit, today), action: null, deleted: null };
  });
  const [error, setError] = useState<string | null>(null);
  const [conflict, setConflict] = useState<Measurement | null>(null);
  const [actionConflict, setActionConflict] = useState<Measurement | null>(null);
  const [pending, setPending] = useState(false);
  const busy = useRef(false);
  const mounted = useRef(true);
  const draft = saved.draft;
  const from = addDays(today, -(days - 1));
  const rows = useResource<Measurement[]>(
    async (signal) => {
      const entries: Measurement[] = [];
      let total = 1;
      while (entries.length < total) {
        const page = await api.get<{ entries: Measurement[]; total: number }>(
          `/api/measurements?from=${from}&to=${today}&limit=500&offset=${entries.length}`,
          { signal, offlineFallback: true }
        );
        entries.push(...page.entries);
        total = page.total;
        if (page.entries.length === 0) break;
      }
      return entries;
    },
    [from, today]
  );
  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);

  function persist(value: SavedState) {
    localStorage.setItem(storageKey, JSON.stringify(value));
    setSaved(value);
  }
  function change(patch: Partial<Draft>) {
    try {
      persist({ ...saved, draft: { ...draft, ...patch, operationID: operationID() } });
      setConflict(null);
      setError(null);
    } catch {
      setError('This browser could not save the draft. Free some storage before continuing.');
    }
  }
  async function submit(next = draft) {
    if (busy.current) return;
    const value = Number(next.value);
    if (!Number.isFinite(value) || value <= 0) {
      setError('Enter a valid measurement.');
      return;
    }
    busy.current = true;
    setPending(true);
    setError(null);
    const body = { ...next, value };
    try {
      persist({ ...saved, draft: next });
      if (next.id)
        await api.put(`/api/measurements/${next.id}`, body, { operationID: next.operationID });
      else await api.post('/api/measurements', body, { operationID: next.operationID });
      if (!mounted.current) return;
      persist({ ...saved, draft: newDraft(preferredUnit, today) });
      setConflict(null);
      rows.refetch();
    } catch (cause) {
      if (!mounted.current) return;
      if (cause instanceof ApiError && cause.status === 409) {
        const current = (cause.details as { current?: Measurement } | undefined)?.current;
        if (current) setConflict(current);
      }
      setError(
        cause instanceof Error
          ? cause.message
          : 'The change could not be confirmed. Your draft is saved.'
      );
    } finally {
      busy.current = false;
      if (mounted.current) setPending(false);
    }
  }
  async function performAction(action: PendingAction) {
    if (busy.current) return;
    busy.current = true;
    setPending(true);
    setError(null);
    try {
      persist({ ...saved, action });
      const options = {
        operationID: action.operationID,
        body: { base_revision: action.row.revision },
      };
      const result =
        action.kind === 'delete'
          ? await api.del<Measurement>(`/api/measurements/${action.row.id}`, options)
          : await api.post<Measurement>(
              `/api/measurements/${action.row.id}/restore`,
              options.body,
              options
            );
      if (!mounted.current) return;
      persist({ ...saved, action: null, deleted: action.kind === 'delete' ? result : null });
      setActionConflict(null);
      rows.refetch();
    } catch (cause) {
      if (mounted.current) {
        if (cause instanceof ApiError && cause.status === 409) {
          const current = (cause.details as { current?: Measurement } | undefined)?.current;
          if (current) setActionConflict(current);
        }
        setError(
          cause instanceof Error
            ? cause.message
            : 'The change could not be confirmed. Retry to check it.'
        );
      }
    } finally {
      busy.current = false;
      if (mounted.current) setPending(false);
    }
  }
  function edit(row: Measurement) {
    const unit = row.type === 'body_fat' ? '%' : preferredUnit;
    const value = unit === 'in' ? row.value / 2.54 : row.value;
    persist({
      ...saved,
      draft: {
        id: row.id,
        client_id: row.client_id,
        type: row.type,
        unit,
        value: String(Number(value.toFixed(4))),
        entry_date: row.entry_date,
        base_revision: row.revision,
        source: row.source ?? 'manual',
        note: row.note,
        operationID: operationID(),
      },
    });
    setConflict(null);
    document.getElementById('measurement-value')?.focus();
  }
  function formatted(row: Measurement) {
    const value = row.unit === 'cm' && preferredUnit === 'in' ? row.value / 2.54 : row.value;
    const unit = row.unit === 'cm' ? preferredUnit : row.unit;
    return `${new Intl.NumberFormat(undefined, { maximumFractionDigits: 2 }).format(value)} ${unit}`;
  }

  return (
    <section
      aria-labelledby="body-measurements-title"
      className="mt-8 border-t border-white/10 pt-8"
    >
      <div className="mb-5 flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 id="body-measurements-title" className="text-xl font-semibold text-slate-50">
            Body measurements
          </h2>
          <p className="mt-1 text-sm text-slate-400">
            Measurements and corrections stay in sync with your iPhone.
          </p>
        </div>
        <button
          type="button"
          className="min-h-11 rounded-lg px-3 text-sm text-slate-300 hover:bg-white/5"
          onClick={rows.refetch}
        >
          Refresh measurements
        </button>
      </div>
      <GlassCard hover={false}>
        <form
          onSubmit={(event) => {
            event.preventDefault();
            void submit();
          }}
        >
          <fieldset
            disabled={pending || saved.action != null}
            className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4"
          >
            <legend className="mb-4 font-semibold text-slate-100">
              {draft.id ? 'Edit measurement' : 'Add measurement'}
            </legend>
            <label className="text-sm text-slate-300">
              Measurement
              <select
                className={fieldClass}
                value={draft.type}
                onChange={(event) =>
                  change({
                    type: event.target.value,
                    unit: event.target.value === 'body_fat' ? '%' : preferredUnit,
                  })
                }
              >
                {TYPES.map((type) => (
                  <option key={type} value={type}>
                    {label(type)}
                  </option>
                ))}
              </select>
            </label>
            <label className="text-sm text-slate-300">
              Value ({draft.unit})
              <input
                id="measurement-value"
                className={fieldClass}
                type="number"
                inputMode="decimal"
                step="any"
                min="0.01"
                required
                value={draft.value}
                onChange={(event) => change({ value: event.target.value })}
              />
            </label>
            <label className="text-sm text-slate-300">
              Unit
              <select
                className={fieldClass}
                value={draft.unit}
                onChange={(event) => {
                  const unit = event.target.value;
                  const current = Number(draft.value);
                  change({
                    unit,
                    value:
                      draft.value && Number.isFinite(current)
                        ? String(
                            Number((unit === 'in' ? current / 2.54 : current * 2.54).toFixed(4))
                          )
                        : '',
                  });
                }}
              >
                {(draft.type === 'body_fat' ? ['%'] : ['cm', 'in']).map((unit) => (
                  <option key={unit}>{unit}</option>
                ))}
              </select>
            </label>
            <label className="text-sm text-slate-300">
              Measurement date
              <input
                className={fieldClass}
                type="date"
                required
                max={today}
                value={draft.entry_date}
                onChange={(event) => change({ entry_date: event.target.value })}
              />
            </label>
            <div className="flex flex-wrap items-center gap-3 sm:col-span-2 lg:col-span-4">
              <ActionButton type="submit" loading={pending} className="min-h-11">
                {draft.id ? 'Save measurement changes' : 'Save measurement'}
              </ActionButton>
              {(draft.id || draft.value) && (
                <button
                  type="button"
                  className="min-h-11 px-3 text-sm text-slate-300"
                  onClick={() => {
                    persist({ ...saved, draft: newDraft(preferredUnit, today) });
                    setConflict(null);
                    setError(null);
                  }}
                >
                  Discard draft
                </button>
              )}
              <span className="text-xs text-slate-400">
                Your unfinished draft stays in this browser.
              </span>
            </div>
          </fieldset>
        </form>
        {error && (
          <p role="alert" className="mt-4 text-sm text-error">
            {error}
          </p>
        )}
        {conflict && (
          <div className="mt-4 rounded-xl border border-amber-400/30 p-4 text-sm text-slate-200">
            <h3 className="font-semibold">Review a change from another device</h3>
            <p className="mt-2">
              Your draft: {draft.value} {draft.unit} on {friendlyDate(draft.entry_date, today)}.
            </p>
            <p>
              {conflict.deleted_at
                ? 'The server entry has been deleted.'
                : `Server: ${formatted(conflict)} on ${friendlyDate(conflict.entry_date, today)}.`}
            </p>
            <div className="mt-3 flex flex-wrap gap-3">
              {!conflict.deleted_at && (
                <ActionButton
                  disabled={pending}
                  variant="secondary"
                  onClick={() =>
                    void submit({
                      ...draft,
                      id: conflict.id,
                      client_id: conflict.client_id,
                      base_revision: conflict.revision,
                      operationID: operationID(),
                    })
                  }
                >
                  Save my reviewed changes
                </ActionButton>
              )}
              <button
                className="min-h-11 px-3"
                disabled={pending}
                onClick={() => {
                  persist({ ...saved, draft: newDraft(preferredUnit, today) });
                  setConflict(null);
                  setError(null);
                  rows.refetch();
                }}
              >
                Use server version
              </button>
            </div>
          </div>
        )}
      </GlassCard>
      {saved.action && (
        <div
          role="status"
          className="mt-4 flex flex-wrap items-center gap-3 text-sm text-slate-300"
        >
          <span>
            A {saved.action.kind === 'delete' ? 'removal' : 'restore'} still needs confirmation from
            the server.
          </span>
          <ActionButton
            disabled={pending}
            variant="secondary"
            onClick={() => saved.action && void performAction(saved.action)}
          >
            Retry saved change
          </ActionButton>
        </div>
      )}
      {saved.action && actionConflict && (
        <div className="mt-4 rounded-xl border border-amber-400/30 p-4 text-sm text-slate-200">
          <h3 className="font-semibold">The measurement changed before this action</h3>
          <p className="mt-2">
            {actionConflict.deleted_at
              ? 'The current server version is deleted.'
              : `${formatted(actionConflict)} on ${friendlyDate(actionConflict.entry_date, today)}.`}
          </p>
          <div className="mt-3 flex flex-wrap gap-3">
            {Boolean(actionConflict.deleted_at) === (saved.action.kind === 'restore') && (
              <ActionButton
                disabled={pending}
                variant="secondary"
                onClick={() =>
                  saved.action &&
                  void performAction({
                    kind: saved.action.kind,
                    row: actionConflict,
                    operationID: operationID(),
                  })
                }
              >
                {saved.action.kind === 'delete'
                  ? 'Delete reviewed version'
                  : 'Restore reviewed version'}
              </ActionButton>
            )}
            <button
              disabled={pending}
              className="min-h-11 px-3"
              onClick={() => {
                persist({
                  ...saved,
                  action: null,
                  deleted: actionConflict.deleted_at ? actionConflict : null,
                });
                setActionConflict(null);
                setError(null);
                rows.refetch();
              }}
            >
              Keep current server version
            </button>
          </div>
        </div>
      )}
      {!saved.action && saved.deleted && (
        <div
          role="status"
          className="mt-4 flex items-center justify-between gap-3 text-sm text-slate-300"
        >
          <span>{label(saved.deleted.type)} measurement removed.</span>
          <ActionButton
            disabled={pending}
            variant="secondary"
            onClick={() =>
              saved.deleted &&
              void performAction({
                kind: 'restore',
                row: saved.deleted,
                operationID: operationID(),
              })
            }
          >
            Undo measurement deletion
          </ActionButton>
        </div>
      )}
      {rows.error && (
        <p role="alert" className="mt-4 text-sm text-error">
          {rows.error}
        </p>
      )}
      {rows.loading && !rows.data && (
        <p role="status" className="mt-5 text-sm text-slate-400">
          Loading measurements…
        </p>
      )}
      {rows.data?.length === 0 && (
        <p className="py-8 text-sm text-slate-400">
          No body measurements in this date range. Add one above to start your history.
        </p>
      )}
      {!!rows.data?.length && (
        <div className="mt-5 overflow-x-auto">
          <table className="w-full text-left text-sm">
            <caption className="sr-only">Body measurements for the last {days} days</caption>
            <thead className="border-b border-white/10 text-xs uppercase text-slate-400">
              <tr>
                <th className="py-3 font-medium">Date</th>
                <th className="px-3 py-3 font-medium">Measurement</th>
                <th className="px-3 py-3 text-right font-medium">Value</th>
                <th className="py-3 text-right font-medium">Actions</th>
              </tr>
            </thead>
            <tbody>
              {rows.data.map((row) => (
                <tr key={row.id} className="border-b border-white/5 text-slate-200">
                  <td className="py-3 whitespace-nowrap">{friendlyDate(row.entry_date, today)}</td>
                  <th scope="row" className="px-3 py-3 font-medium">
                    {label(row.type)}
                  </th>
                  <td className="px-3 py-3 text-right whitespace-nowrap tabular-nums">
                    {formatted(row)}
                  </td>
                  <td className="py-2 text-right whitespace-nowrap">
                    <button
                      disabled={pending || saved.action != null || Boolean(draft.id || draft.value)}
                      aria-label={`Edit ${label(row.type)} measurement`}
                      className="min-h-11 rounded-lg px-3 hover:bg-white/5 disabled:opacity-50"
                      onClick={() => edit(row)}
                    >
                      Edit
                    </button>
                    <button
                      disabled={pending || saved.action != null || Boolean(draft.id || draft.value)}
                      aria-label={`Delete ${label(row.type)} measurement`}
                      className="min-h-11 rounded-lg px-3 text-slate-400 hover:bg-white/5 hover:text-error disabled:opacity-50"
                      onClick={() =>
                        void performAction({ kind: 'delete', row, operationID: operationID() })
                      }
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}
