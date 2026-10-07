import { useEffect, useRef, useState } from 'react';
import API_CONFIG from '../../config';
import { api, ApiError } from '../../lib/api';
import type { DiaryDay, DiaryLoggingStatus } from '../../lib/api';
import { operationID } from '../../lib/ids';
import { useSession } from '../../hooks/useSession';
import { GlassCard } from '../ui/GlassCard';
import { ActionButton } from '../ui/ActionButton';

const statuses: Record<DiaryLoggingStatus, { label: string; description: string }> = {
  in_progress: {
    label: 'In progress',
    description: 'Keep logging. This day does not count as a complete intake day.',
  },
  complete: {
    label: 'Complete',
    description:
      'All food and drinks are recorded. This day can inform your expenditure estimate when enough measurements are available.',
  },
  estimated: {
    label: 'Estimated',
    description: 'Some entries are estimates. This day stays out of the expenditure calculation.',
  },
  excluded: {
    label: 'Excluded',
    description:
      'Keep these entries for your records without using this day in the expenditure calculation.',
  },
};
interface Draft {
  entry_date: string;
  status: DiaryLoggingStatus;
  note: string;
  base_revision: number;
  operationID: string;
}
const fieldClass =
  'mt-1 min-h-11 w-full rounded-xl border border-white/15 bg-surface-2 px-3 py-2 text-base text-slate-100 focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary';

export function DayLoggingStatus({ day, onSaved }: { day: DiaryDay; onSaved: () => void }) {
  const { user } = useSession();
  const key = user?._id
    ? `diary-status.v1:${API_CONFIG.BASE_URL}:${user._id}:${day.entry_date}`
    : null;
  return key ? <OwnedDayStatus key={key} storageKey={key} day={day} onSaved={onSaved} /> : null;
}

function OwnedDayStatus({
  storageKey,
  day,
  onSaved,
}: {
  storageKey: string;
  day: DiaryDay;
  onSaved: () => void;
}) {
  const [draft, setDraft] = useState<Draft | null>(() => {
    try {
      const saved = JSON.parse(localStorage.getItem(storageKey) || 'null');
      if (
        saved &&
        saved.entry_date === day.entry_date &&
        Object.prototype.hasOwnProperty.call(statuses, saved.status) &&
        typeof saved.note === 'string' &&
        Number.isInteger(saved.base_revision) &&
        typeof saved.operationID === 'string'
      )
        return saved;
    } catch {
      /* An unreadable draft must not become a server write. */
    }
    return null;
  });
  const [conflict, setConflict] = useState<DiaryDay | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);
  const busy = useRef(false);
  const mounted = useRef(true);
  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);
  const status = draft?.status ?? day.status;
  const note = draft?.note ?? day.note ?? '';
  function persist(next: Draft | null): boolean {
    try {
      if (next) localStorage.setItem(storageKey, JSON.stringify(next));
      else localStorage.removeItem(storageKey);
      setDraft(next);
      return true;
    } catch {
      setError(
        'This browser could not save the draft. Free some storage before changing this status.'
      );
      return false;
    }
  }
  function edit(changes: Partial<Pick<Draft, 'status' | 'note'>>) {
    setError(null);
    persist({
      entry_date: day.entry_date,
      status,
      note,
      base_revision: draft?.base_revision ?? day.revision,
      ...changes,
      operationID: operationID(),
    });
  }
  async function save(value: Draft) {
    if (busy.current) return;
    busy.current = true;
    setPending(true);
    setError(null);
    try {
      const { operationID: key, ...body } = value;
      await api.put<DiaryDay>('/api/diary/day', body, { operationID: key });
      if (!mounted.current) return;
      if (persist(null)) {
        setConflict(null);
        onSaved();
      }
    } catch (err) {
      if (!mounted.current) return;
      if (err instanceof ApiError && err.status === 409) {
        const latest = (err.details as { current?: DiaryDay } | undefined)?.current;
        if (latest) setConflict(latest);
      }
      setError(
        err instanceof Error
          ? err.message
          : 'Status could not be saved. Your draft is kept on this browser.'
      );
    } finally {
      busy.current = false;
      if (mounted.current) setPending(false);
    }
  }
  return (
    <GlassCard className="mt-6" hover={false}>
      <form
        aria-label="Day logging status"
        aria-busy={pending}
        onSubmit={(event) => {
          event.preventDefault();
          if (draft) void save(draft);
        }}
      >
        <h2 className="text-balance text-lg font-semibold text-slate-50">Logging status</h2>
        <p className="mt-1 text-sm text-slate-400" role="status">
          {draft
            ? 'Draft saved on this browser. Save to sync this day.'
            : `${statuses[day.status].label} · Synced`}
        </p>
        <div className="mt-4 grid gap-4 sm:grid-cols-2">
          <label className="text-sm text-slate-300">
            Status
            <select
              className={fieldClass}
              value={status}
              disabled={pending}
              aria-describedby="day-status-help"
              onChange={(event) => edit({ status: event.target.value as DiaryLoggingStatus })}
            >
              {Object.entries(statuses).map(([value, item]) => (
                <option key={value} value={value}>
                  {item.label}
                </option>
              ))}
            </select>
          </label>
          <label className="text-sm text-slate-300">
            Optional note
            <textarea
              className={fieldClass}
              value={note}
              maxLength={500}
              rows={2}
              disabled={pending}
              onChange={(event) => edit({ note: event.target.value })}
            />
          </label>
        </div>
        <p id="day-status-help" className="mt-3 text-pretty text-sm text-slate-400">
          {statuses[status].description}
        </p>
        {error && (
          <p className="mt-3 text-sm text-error" role="alert">
            {error}
          </p>
        )}
        {conflict && (
          <div className="mt-4 border-t border-white/10 pt-4">
            <h3 className="font-semibold text-slate-100">Review this day&apos;s status</h3>
            <p className="mt-2 text-sm text-slate-300">
              Server: {statuses[conflict.status].label}
              {conflict.note ? ` · ${conflict.note}` : ''}
            </p>
            <p className="mt-1 text-sm text-slate-300">
              Your draft: {statuses[status].label}
              {note ? ` · ${note}` : ''}
            </p>
            <div className="mt-3 flex flex-wrap gap-2">
              <ActionButton
                type="button"
                className="min-h-11"
                disabled={pending || !draft}
                onClick={() => {
                  if (draft) {
                    const reviewed = {
                      ...draft,
                      base_revision: conflict.revision,
                      operationID: operationID(),
                    };
                    if (persist(reviewed)) void save(reviewed);
                  }
                }}
              >
                Save my reviewed status
              </ActionButton>
              <ActionButton
                type="button"
                variant="secondary"
                className="min-h-11"
                disabled={pending}
                onClick={() => {
                  if (persist(null)) {
                    setConflict(null);
                    setError(null);
                    onSaved();
                  }
                }}
              >
                Use server status
              </ActionButton>
            </div>
          </div>
        )}
        {!conflict && draft && (
          <div className="mt-4 flex flex-wrap gap-2">
            <ActionButton type="submit" loading={pending} className="min-h-11">
              Save status
            </ActionButton>
            <ActionButton
              type="button"
              variant="secondary"
              className="min-h-11"
              disabled={pending}
              onClick={() => {
                if (persist(null)) {
                  setError(null);
                  onSaved();
                }
              }}
            >
              Discard draft
            </ActionButton>
          </div>
        )}
      </form>
    </GlassCard>
  );
}
