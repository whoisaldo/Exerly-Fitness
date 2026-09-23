import { useState } from 'react';
import { api } from '../../lib/api';
import type { TrendResponse } from '../../lib/api';
import { useSelectedDay } from '../../hooks/useAccountCalendar';
import { displayRate, displayWeight, weightLabel } from '../../lib/units';
import { useResource } from '../../hooks/useResource';
import { useSession } from '../../hooks/useSession';
import { AppShell } from '../ui/AppShell';
import { DateNav } from '../ui/DateNav';
import { GlassCard } from '../ui/GlassCard';
import { TrendChart } from '../ui/TrendChart';
import { LoadingSkeleton } from '../ui/LoadingSkeleton';
import BodyMeasurements from './BodyMeasurements';
import WeightLogging from './WeightLogging';

const RANGES = [
  { days: 30, label: '30d' },
  { days: 90, label: '90d' },
  { days: 180, label: '6m' },
  { days: 365, label: '1y' },
];

export default function WeightPage() {
  const { date, setDate } = useSelectedDay();
  const { unitSystem } = useSession();
  const [days, setDays] = useState(90);

  const trend = useResource<TrendResponse>(
    (signal) =>
      api.get<TrendResponse>(`/api/weight/trend?days=${days}`, { signal, offlineFallback: true }),
    [days]
  );

  const summary = trend.data?.summary;
  const unit = weightLabel(unitSystem);

  return (
    <AppShell>
      <h1 className="text-display-sm text-slate-50">Weight & measurements</h1>
      <p className="mt-1 text-base text-slate-400">
        Review recorded weights, trends, and body measurements.
      </p>

      <DateNav date={date} onChange={setDate} className="mt-5" />
      <WeightLogging date={date} onSaved={trend.refetch} />

      {summary && (
        <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
          <Stat
            label="Trend now"
            value={`${displayWeight(summary.current_trend_kg, unitSystem, 1)} ${unit}`}
          />
          <Stat
            label="Last scale"
            value={
              summary.current_weight_kg != null
                ? `${displayWeight(summary.current_weight_kg, unitSystem, 1)} ${unit}`
                : '--'
            }
          />
          <Stat
            label={`Change (${days}d)`}
            value={`${summary.change_kg > 0 ? '+' : ''}${displayWeight(summary.change_kg, unitSystem, 2)} ${unit}`}
          />
          <Stat label="Rate" value={displayRate(summary.weekly_rate_kg, unitSystem)} />
        </div>
      )}

      <GlassCard className="mt-4" hover={false}>
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-semibold text-slate-100">Trend</h2>
          <div className="flex gap-1">
            {RANGES.map((r) => (
              <button
                key={r.days}
                type="button"
                onClick={() => setDays(r.days)}
                className={`rounded-lg px-2.5 py-1 text-xs font-semibold transition-colors ${
                  days === r.days
                    ? 'bg-primary/12 text-primary'
                    : 'text-slate-500 hover:bg-white/[0.06] hover:text-slate-200'
                }`}
              >
                {r.label}
              </button>
            ))}
          </div>
        </div>

        {trend.loading && !trend.data ? (
          <LoadingSkeleton className="mt-4 h-56" />
        ) : (
          <TrendChart series={trend.data?.series ?? []} unitSystem={unitSystem} className="mt-4" />
        )}

        {summary && (
          <p className="mt-2 text-xs text-slate-500">
            {summary.weigh_ins} weigh-ins across {summary.days} days
          </p>
        )}
      </GlassCard>
      <BodyMeasurements days={days} />
    </AppShell>
  );
}

function Stat({
  label,
  value,
  tone = 'flat',
}: {
  label: string;
  value: string;
  tone?: 'up' | 'down' | 'flat';
}) {
  const color =
    tone === 'down' ? 'text-success' : tone === 'up' ? 'text-warning' : 'text-slate-100';
  return (
    <div className="glass p-4">
      <p className="label">{label}</p>
      <p className={`mt-1 text-lg font-bold tabular-nums ${color}`}>{value}</p>
    </div>
  );
}
