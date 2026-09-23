import { useState } from 'react';
import { api } from '../../lib/api';
import type { Program } from '../../lib/api';
import { displayWeight, formatCalories, kgToLb, weightLabel } from '../../lib/units';
import { friendlyDate } from '../../lib/dates';
import { useAccountCalendar } from '../../hooks/useAccountCalendar';
import { useMutation, useResource } from '../../hooks/useResource';
import { useSession } from '../../hooks/useSession';
import { AppShell } from '../ui/AppShell';
import { GlassCard } from '../ui/GlassCard';
import { ActionButton } from '../ui/ActionButton';
import { LoadingSkeleton } from '../ui/LoadingSkeleton';
import { MACRO_COLORS } from '../ui/MacroBar';

interface Checkin {
  id: string;
  entry_date: string;
  calories: number;
  previous_calories: number | null;
  expenditure: number;
  expenditure_confidence: string;
  trend_weight_kg: number | null;
  note: string | null;
}

const GOALS = [
  { value: 'lose', label: 'Lose fat' },
  { value: 'maintain', label: 'Maintain' },
  { value: 'gain', label: 'Gain muscle' },
] as const;

const DIETS = [
  { value: 'balanced', label: 'Balanced' },
  { value: 'low_carb', label: 'Lower carb' },
  { value: 'low_fat', label: 'Lower fat' },
  { value: 'high_protein', label: 'High protein' },
  { value: 'keto', label: 'Keto' },
];

const CONFIDENCE_COPY: Record<string, string> = {
  estimated: 'Estimated from your height, weight, and age. Not measured yet.',
  low: 'Measured, but from under three weeks of data. Expect it to move.',
  medium: 'Measured from three weeks of logging. Reasonably stable.',
  high: 'Measured from four or more weeks of consistent logging.',
};

export default function ProgramPage() {
  const { today } = useAccountCalendar();
  const { unitSystem } = useSession();
  const unit = weightLabel(unitSystem);

  const program = useResource<Program>(
    (signal) => api.get<Program>('/api/program', { signal, offlineFallback: true }),
    []
  );
  const checkins = useResource<Checkin[]>(
    (signal) =>
      api.get<Checkin[]>('/api/program/checkins?limit=12', { signal, offlineFallback: true }),
    []
  );

  const update = useMutation(async (patch: Record<string, unknown>) => {
    await api.put('/api/program', patch);
    program.refetch();
  });

  const checkIn = useMutation(async () => {
    await api.post('/api/program/checkin');
    program.refetch();
    checkins.refetch();
  });

  const p = program.data;

  return (
    <AppShell>
      <h1 className="text-display-sm text-slate-50">Program</h1>
      <p className="mt-1 text-base text-slate-400">
        Your targets come from what you actually ate and how your trend weight moved, not a formula.
      </p>

      {program.loading && !p && <LoadingSkeleton className="mt-6 h-64" />}
      {program.error && (
        <GlassCard className="mt-6">
          <p className="text-sm text-error">{program.error}</p>
        </GlassCard>
      )}

      {p && (
        <>
          <GlassCard className="mt-6" hover={false}>
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div>
                <p className="label">Measured expenditure</p>
                <p className="stat-value mt-1">
                  {formatCalories(p.expenditure.value)}
                  <span className="text-lg font-medium text-slate-500"> kcal/day</span>
                </p>
                <p className="mt-2 max-w-md text-xs text-slate-500">
                  {CONFIDENCE_COPY[p.expenditure.confidence]}
                  {p.expenditure.reason && ` ${p.expenditure.reason}.`}
                </p>
              </div>

              <ActionButton
                onClick={() => checkIn.run()}
                loading={checkIn.pending}
                variant={p.needs_checkin ? 'primary' : 'secondary'}
              >
                {p.needs_checkin ? 'Run check-in' : 'Check in again'}
              </ActionButton>
            </div>

            {checkIn.error && <p className="mt-3 text-sm text-error">{checkIn.error}</p>}

            {p.expenditure.measured != null && (
              <dl className="mt-5 grid grid-cols-2 gap-4 border-t border-white/[0.06] pt-4 sm:grid-cols-4">
                <Detail
                  label="Raw measurement"
                  value={`${formatCalories(p.expenditure.measured)} kcal`}
                />
                <Detail
                  label="Formula says"
                  value={`${formatCalories(p.expenditure.formula)} kcal`}
                />
                <Detail
                  label="Mean intake"
                  value={`${formatCalories(p.expenditure.mean_intake)} kcal`}
                />
                <Detail
                  label="Days logged"
                  value={`${p.expenditure.days_logged} of ${p.expenditure.window_days}`}
                />
              </dl>
            )}
          </GlassCard>

          <GlassCard className="mt-4" hover={false}>
            <h2 className="text-sm font-semibold text-slate-100">Current targets</h2>
            {p.targets.calories == null ? (
              <p className="mt-3 text-sm text-slate-500">Run a check-in to set your targets.</p>
            ) : (
              <div className="mt-4 grid grid-cols-2 gap-4 sm:grid-cols-4">
                <Target
                  label="Calories"
                  value={formatCalories(p.targets.calories)}
                  unit="kcal"
                  color="#e9ebf1"
                />
                <Target
                  label="Protein"
                  value={String(p.targets.protein_g)}
                  unit="g"
                  color={MACRO_COLORS.protein}
                />
                <Target
                  label="Carbs"
                  value={String(p.targets.carbs_g)}
                  unit="g"
                  color={MACRO_COLORS.carbs}
                />
                <Target
                  label="Fat"
                  value={String(p.targets.fat_g)}
                  unit="g"
                  color={MACRO_COLORS.fat}
                />
              </div>
            )}

            {p.suggested_targets && p.suggested_targets.calories !== p.targets.calories && (
              <p className="mt-4 rounded-xl border border-primary/25 bg-primary/[0.07] px-4 py-3 text-sm text-slate-300">
                Next check-in would set{' '}
                <strong className="text-slate-100">
                  {formatCalories(p.suggested_targets.calories)} kcal
                </strong>{' '}
                ({p.suggested_targets.calories > (p.targets.calories ?? 0) ? '+' : ''}
                {formatCalories(p.suggested_targets.calories - (p.targets.calories ?? 0))}).
              </p>
            )}
          </GlassCard>

          <GlassCard className="mt-4" hover={false}>
            <h2 className="text-sm font-semibold text-slate-100">Plan</h2>

            <div className="mt-4">
              <p className="label">Goal</p>
              <div className="mt-2 flex flex-wrap gap-2">
                {GOALS.map((g) => (
                  <button
                    key={g.value}
                    type="button"
                    onClick={() => update.run({ goalType: g.value })}
                    className={`rounded-xl px-4 py-2 text-sm font-medium transition-colors ${
                      p.goal_type === g.value
                        ? 'bg-primary text-white'
                        : 'border border-white/[0.12] text-slate-300 hover:border-white/[0.2]'
                    }`}
                  >
                    {g.label}
                  </button>
                ))}
              </div>
            </div>

            {p.goal_type !== 'maintain' && (
              <RateSlider
                key={p.goal_type}
                goal={p.goal_type}
                value={Math.abs(p.rate_kg_per_week)}
                unitSystem={unitSystem}
                onCommit={(rate) => update.run({ rateKgPerWeek: rate })}
              />
            )}

            <div className="mt-5">
              <p className="label">Macro split</p>
              <div className="mt-2 flex flex-wrap gap-2">
                {DIETS.map((d) => (
                  <button
                    key={d.value}
                    type="button"
                    onClick={() => update.run({ dietType: d.value })}
                    className={`rounded-xl px-3.5 py-1.5 text-sm font-medium transition-colors ${
                      p.diet_type === d.value
                        ? 'bg-primary/15 text-primary'
                        : 'border border-white/[0.12] text-slate-400 hover:border-white/[0.2] hover:text-slate-200'
                    }`}
                  >
                    {d.label}
                  </button>
                ))}
              </div>
            </div>

            {update.error && <p className="mt-3 text-sm text-error">{update.error}</p>}
          </GlassCard>

          {(checkins.data?.length ?? 0) > 0 && (
            <GlassCard className="mt-4" hover={false}>
              <h2 className="text-sm font-semibold text-slate-100">Check-in history</h2>
              <ul className="mt-3 divide-y divide-white/[0.06]">
                {checkins.data?.map((c) => {
                  const delta =
                    c.previous_calories == null ? null : c.calories - c.previous_calories;
                  return (
                    <li key={c.id} className="flex items-center justify-between gap-3 py-2.5">
                      <div>
                        <p className="text-sm text-slate-200">
                          {friendlyDate(c.entry_date, today)}
                        </p>
                        <p className="text-xs text-slate-500">
                          expenditure {formatCalories(c.expenditure)} · {c.expenditure_confidence}
                          {c.trend_weight_kg != null &&
                            ` · trend ${displayWeight(c.trend_weight_kg, unitSystem)} ${unit}`}
                        </p>
                      </div>
                      <div className="text-right">
                        <p className="text-sm tabular-nums text-slate-200">
                          {formatCalories(c.calories)} kcal
                        </p>
                        {delta != null && delta !== 0 && (
                          <p
                            className={`text-xs tabular-nums ${delta > 0 ? 'text-success' : 'text-warning'}`}
                          >
                            {delta > 0 ? '+' : ''}
                            {formatCalories(delta)}
                          </p>
                        )}
                      </div>
                    </li>
                  );
                })}
              </ul>
            </GlassCard>
          )}
        </>
      )}
    </AppShell>
  );
}

function RateSlider({
  goal,
  value,
  unitSystem,
  onCommit,
}: {
  goal: string;
  value: number;
  unitSystem: 'metric' | 'imperial';
  onCommit: (rate: number) => void;
}) {
  // Local state so dragging feels immediate; the request fires on release.
  const [draft, setDraft] = useState(value);
  const perWeek = unitSystem === 'imperial' ? kgToLb(draft) : draft;
  const unit = weightLabel(unitSystem);

  return (
    <div className="mt-5">
      <div className="flex items-baseline justify-between">
        <p className="label">Target rate</p>
        <p className="text-sm tabular-nums text-slate-200">
          {perWeek.toFixed(2)} {unit}/week {goal === 'lose' ? 'down' : 'up'}
        </p>
      </div>
      <input
        type="range"
        min="0"
        max="1"
        step="0.05"
        value={draft}
        onChange={(e) => setDraft(Number(e.target.value))}
        onMouseUp={() => onCommit(draft)}
        onTouchEnd={() => onCommit(draft)}
        onKeyUp={() => onCommit(draft)}
        className="mt-2 w-full accent-[#8b5cf6]"
      />
      <p className="mt-1 text-xs text-slate-500">
        {draft === 0
          ? 'No change. Same as maintaining.'
          : draft <= 0.35
            ? 'Slow and sustainable. Easiest to hold onto muscle.'
            : draft <= 0.7
              ? 'A moderate pace. This is the usual sweet spot.'
              : 'Aggressive. Expect hunger and some performance drop.'}
      </p>
    </div>
  );
}

function Detail({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="label">{label}</dt>
      <dd className="mt-1 text-sm tabular-nums text-slate-200">{value}</dd>
    </div>
  );
}

function Target({
  label,
  value,
  unit,
  color,
}: {
  label: string;
  value: string;
  unit: string;
  color: string;
}) {
  return (
    <div>
      <p className="label" style={{ color }}>
        {label}
      </p>
      <p className="mt-1 text-xl font-bold tabular-nums text-slate-50">
        {value}
        <span className="ml-1 text-sm font-medium text-slate-500">{unit}</span>
      </p>
    </div>
  );
}
