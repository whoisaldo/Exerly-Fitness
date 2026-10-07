import { useEffect, useRef, useState } from 'react';
import API_CONFIG from '../../config';
import { api, getSessionScope } from '../../lib/api';
import type { WaterDay } from '../../lib/api';
import { operationID } from '../../lib/ids';
import { useAccountCalendar } from '../../hooks/useAccountCalendar';
import { useSession } from '../../hooks/useSession';
import { GlassCard } from '../ui/GlassCard';
import { ActionButton } from '../ui/ActionButton';

type Addition = { operationID: string; entry_date: string; deltaMl: number };
const changedEvent = 'exerly-water-pending';

export function WaterLogging({ day, onSaved }: { day: WaterDay; onSaved: () => void }) {
  const { user } = useSession();
  const prefix = user?._id
    ? `water-additions.v1:${API_CONFIG.BASE_URL}:${user._id}:${day.entry_date}:`
    : null;
  return prefix ? <OwnedWater key={prefix} prefix={prefix} day={day} onSaved={onSaved} /> : null;
}

function readPending(prefix: string, date: string): Addition[] {
  const result: Addition[] = [];
  for (let i = 0; i < localStorage.length; i++) {
    const key = localStorage.key(i);
    if (!key?.startsWith(prefix)) continue;
    const row = JSON.parse(localStorage.getItem(key) || 'null');
    if (
      !row ||
      typeof row.operationID !== 'string' ||
      key !== prefix + row.operationID ||
      row.entry_date !== date ||
      !Number.isInteger(row.deltaMl) ||
      row.deltaMl < 1 ||
      row.deltaMl > 5000
    ) {
      throw new Error(
        'A saved water addition could not be read. It is still stored in this browser.'
      );
    }
    result.push(row);
  }
  return result.sort((a, b) => a.operationID.localeCompare(b.operationID));
}

function OwnedWater({
  prefix,
  day,
  onSaved,
}: {
  prefix: string;
  day: WaterDay;
  onSaved: () => void;
}) {
  const { today } = useAccountCalendar();
  const [amount, setAmount] = useState('250');
  const [pending, setPending] = useState<Addition[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [acknowledged, setAcknowledged] = useState<WaterDay | null>(null);
  const busy = useRef(false);
  const mounted = useRef(true);
  useEffect(() => {
    mounted.current = true;
    const refresh = () => {
      try {
        setPending(readPending(prefix, day.entry_date));
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Saved additions could not be read.');
      }
    };
    refresh();
    window.addEventListener('storage', refresh);
    window.addEventListener(changedEvent, refresh);
    return () => {
      mounted.current = false;
      window.removeEventListener('storage', refresh);
      window.removeEventListener(changedEvent, refresh);
    };
  }, [prefix, day.entry_date]);

  async function save(ml?: number) {
    if (busy.current) return;
    busy.current = true;
    setSaving(true);
    setError(null);
    const credential = getSessionScope();
    try {
      const queue = readPending(prefix, day.entry_date);
      if (ml !== undefined) {
        if (!Number.isInteger(ml) || ml < 1 || ml > 5000)
          throw new Error('Enter a whole number from 1 to 5,000 ml.');
        const addition = { operationID: operationID(), entry_date: day.entry_date, deltaMl: ml };
        // One key per operation prevents another tab from overwriting this addition.
        localStorage.setItem(prefix + addition.operationID, JSON.stringify(addition));
        queue.push(addition);
        window.dispatchEvent(new Event(changedEvent));
      }
      for (const addition of queue) {
        if (!mounted.current || getSessionScope() !== credential) return;
        const { operationID: id, ...body } = addition;
        const result = await api.post<WaterDay>('/api/water', body, { operationID: id });
        // This exact operation is acknowledged even if the user left the page.
        localStorage.removeItem(prefix + id);
        window.dispatchEvent(new Event(changedEvent));
        if (!mounted.current || getSessionScope() !== credential) return;
        setAcknowledged((old) => (!old || result.revision > old.revision ? result : old));
      }
      if (mounted.current) onSaved();
    } catch (err) {
      if (mounted.current)
        setError(
          err instanceof Error
            ? err.message
            : 'Water could not sync. Your addition is saved in this browser.'
        );
    } finally {
      busy.current = false;
      if (mounted.current) setSaving(false);
    }
  }
  const current = acknowledged && acknowledged.revision > day.revision ? acknowledged : day;
  const totalPending = pending.reduce((sum, row) => sum + row.deltaMl, 0);
  const future = day.entry_date > today;
  return (
    <GlassCard className="mt-6" hover={false}>
      <form
        aria-label="Water logging"
        onSubmit={(event) => {
          event.preventDefault();
          void save(Number(amount));
        }}
      >
        <div className="flex flex-wrap items-baseline justify-between gap-3">
          <h2 className="text-balance text-base font-semibold text-slate-100">Water</h2>
          <p className="tabular-nums text-slate-100" aria-label="Recorded water">
            {current.ml.toLocaleString()} ml recorded
          </p>
        </div>
        <p role="status" className="mt-2 text-pretty text-sm text-slate-300">
          {pending.length
            ? `${totalPending.toLocaleString()} ml waiting for confirmation. Saved in this browser.`
            : 'Synced'}
        </p>
        <div className="mt-3 flex flex-wrap gap-2">
          <ActionButton
            type="button"
            variant="secondary"
            className="min-h-11"
            disabled={saving || future}
            onClick={() => void save(250)}
          >
            +250 ml
          </ActionButton>
          <ActionButton
            type="button"
            variant="secondary"
            className="min-h-11"
            disabled={saving || future}
            onClick={() => void save(500)}
          >
            +500 ml
          </ActionButton>
        </div>
        <div className="mt-3 flex flex-wrap items-end gap-3">
          <label className="text-sm text-slate-300">
            Amount (ml)
            <input
              type="number"
              inputMode="numeric"
              required
              min={1}
              max={5000}
              step={1}
              value={amount}
              onChange={(event) => setAmount(event.target.value)}
              disabled={saving || future}
              aria-describedby="water-help water-error"
              className="mt-1 block min-h-11 w-36 rounded-xl border border-white/15 bg-surface-2 px-3 py-2 text-base tabular-nums text-slate-100 focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary"
            />
          </label>
          <ActionButton
            type="submit"
            variant="secondary"
            className="min-h-11"
            disabled={saving || future}
          >
            Add water
          </ActionButton>
          {pending.length > 0 && (
            <ActionButton
              type="button"
              variant="secondary"
              className="min-h-11"
              loading={saving}
              onClick={() => void save()}
            >
              Retry pending additions
            </ActionButton>
          )}
        </div>
        <p id="water-help" className="mt-2 text-pretty text-sm text-slate-400">
          {future
            ? 'Water can be logged for today or an earlier date.'
            : 'Enter 1 to 5,000 ml to add to the selected day.'}
        </p>
        <p id="water-error" role={error ? 'alert' : undefined} className="mt-2 text-sm text-error">
          {error}
        </p>
      </form>
    </GlassCard>
  );
}
