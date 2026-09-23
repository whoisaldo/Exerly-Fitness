import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../../lib/api';
import type { DaySummary, Macros } from '../../lib/api';
import { normalizeFood } from '../../lib/food';
import { useFoods } from '../../hooks/useFoods';
import { cacheFoods, refreshFoods, visibleFoods, FOOD_SYNCED } from '../../lib/foodStore';
import { subscribeToReconnect } from '../../lib/offlineCache';
import { useSelectedDay } from '../../hooks/useAccountCalendar';
import { formatCalories } from '../../lib/units';
import { useResource } from '../../hooks/useResource';
import { AppShell } from '../ui/AppShell';
import { DateNav } from '../ui/DateNav';
import { MacroBar, MACRO_COLORS } from '../ui/MacroBar';
import { GlassCard } from '../ui/GlassCard';
import { LoadingSkeleton } from '../ui/LoadingSkeleton';
import { FoodDiary } from './FoodDiary';
import { DayLoggingStatus } from './DayLoggingStatus';
import { WaterLogging } from './WaterLogging';

export default function Diary() {
  const { date, setDate } = useSelectedDay();
  const { owner, doc, error: storageError } = useFoods();
  const [foodError, setFoodError] = useState<string | null>(null);

  const summary = useResource<DaySummary>(
    (signal) =>
      api.get<DaySummary>(`/api/summary?entry_date=${date}`, { signal, offlineFallback: true }),
    [date]
  );

  const refetch = summary.refetch;
  const serverDay = summary.data?.date === date ? summary.data : null;
  const parsedFood = useMemo(() => {
    try {
      const rows = Object.values(serverDay?.meals ?? {})
        .flatMap((meal) => meal.entries)
        .map(normalizeFood);
      return { rows, error: null };
    } catch {
      return {
        rows: [],
        error: 'The food response could not be read. Your saved entries and changes are preserved.',
      };
    }
  }, [serverDay]);
  useEffect(() => {
    if (!owner || !serverDay || parsedFood.error) return;
    let active = true;
    void cacheFoods(owner, parsedFood.rows, date).catch((error) => {
      if (active) setFoodError(error.message);
    });
    return () => {
      active = false;
    };
  }, [owner, serverDay, parsedFood, date]);
  useEffect(() => {
    if (!owner) return;
    let active = true;
    const refresh = () => {
      void refreshFoods(owner, date)
        .then(() => {
          if (active) setFoodError(null);
        })
        .catch(() => {
          if (active)
            setFoodError(
              'Could not refresh food. Saved entries and pending changes are still shown.'
            );
        });
    };
    refresh();
    const unsubscribe = subscribeToReconnect(refresh);
    const synced = (event: Event) => {
      if ((event as CustomEvent).detail === owner.account) refetch();
    };
    window.addEventListener(FOOD_SYNCED, synced);
    return () => {
      active = false;
      unsubscribe();
      window.removeEventListener(FOOD_SYNCED, synced);
    };
  }, [owner, date, refetch]);
  const foodRows = new Map(parsedFood.rows.map((row) => [row.client_id, row]));
  const serverKeys = new Map(parsedFood.rows.map((row) => [row.id, row.client_id]));
  if (doc)
    for (const row of visibleFoods(doc)) {
      const previousKey = serverKeys.get(row.id);
      if (previousKey && previousKey !== row.client_id) foodRows.delete(previousKey);
      foodRows.set(row.client_id, row);
      serverKeys.set(row.id, row.client_id);
    }
  const entries = [...foodRows.values()];
  const activeFoods = entries.filter((row) => row.entry_date === date && !row.deleted_at);
  const coverage = (nutrient: 'protein' | 'carbs' | 'fat' | 'fiber') => ({
    incomplete: activeFoods.some((row) => row[nutrient] == null),
    known: !activeFoods.length || activeFoods.some((row) => row[nutrient] != null),
  });
  const consumed = Object.fromEntries(
    ['calories', 'protein', 'carbs', 'fat', 'fiber', 'sugar', 'sodium'].map((nutrient) => [
      nutrient,
      entries
        .filter((row) => row.entry_date === date && !row.deleted_at)
        .reduce((total, row) => total + (row[nutrient as keyof Macros] ?? 0), 0),
    ])
  ) as unknown as Macros;
  const day = serverDay
    ? {
        ...serverDay,
        consumed,
        remaining: {
          ...serverDay.remaining,
          calories:
            serverDay.targets.calories == null
              ? null
              : serverDay.targets.calories - consumed.calories,
        },
      }
    : null;

  return (
    <AppShell>
      <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <h1 className="text-display-sm text-slate-50">Diary</h1>
        <DateNav date={date} onChange={setDate} />
      </div>

      {summary.loading && !day && <LoadingSkeleton className="mt-6 h-64" />}
      {summary.error && (
        <GlassCard className="mt-6">
          <p className="text-sm text-error">{summary.error}</p>
        </GlassCard>
      )}

      {day && (
        <>
          <GlassCard className="mt-6" hover={false}>
            <div className="flex flex-wrap items-baseline justify-between gap-3">
              <div>
                <p className="label">Calories</p>
                <p className="stat-value mt-1">
                  {formatCalories(day.consumed.calories)}
                  {day.targets.calories != null && (
                    <span className="text-lg font-medium text-slate-500">
                      {' '}
                      / {formatCalories(day.targets.calories)}
                    </span>
                  )}
                </p>
              </div>

              <div className="text-right">
                {day.remaining.calories != null ? (
                  <>
                    <p className="label">
                      {day.remaining.calories >= 0 ? 'Remaining' : 'Over budget'}
                    </p>
                    <p
                      className={`mt-1 text-2xl font-bold tabular-nums ${
                        day.remaining.calories >= 0 ? 'text-slate-100' : 'text-warning'
                      }`}
                    >
                      {formatCalories(Math.abs(day.remaining.calories))}
                    </p>
                  </>
                ) : (
                  <p className="text-sm text-slate-500">No target set yet</p>
                )}
              </div>
            </div>

            <div className="mt-5 grid grid-cols-2 gap-4 sm:grid-cols-4">
              <MacroBar
                label="Protein"
                {...coverage('protein')}
                value={day.consumed.protein}
                target={day.targets.protein_g}
                color={MACRO_COLORS.protein}
              />
              <MacroBar
                label="Carbs"
                {...coverage('carbs')}
                value={day.consumed.carbs}
                target={day.targets.carbs_g}
                color={MACRO_COLORS.carbs}
              />
              <MacroBar
                label="Fat"
                {...coverage('fat')}
                value={day.consumed.fat}
                target={day.targets.fat_g}
                color={MACRO_COLORS.fat}
              />
              <MacroBar
                label="Fibre"
                {...coverage('fiber')}
                value={day.consumed.fiber}
                target={day.targets.fiber_g}
                color={MACRO_COLORS.fiber}
              />
            </div>

            {day.burned > 0 && (
              <p className="mt-4 text-xs text-slate-500">
                {formatCalories(day.burned)} kcal burned in {day.activities.length} logged{' '}
                {day.activities.length === 1 ? 'activity' : 'activities'}
              </p>
            )}
          </GlassCard>

          <WaterLogging key={`water-${date}`} day={day.water} onSaved={summary.refetch} />

          <DayLoggingStatus key={date} day={day.diary_day} onSaved={summary.refetch} />

          <div className="mt-6 grid gap-3 sm:grid-cols-2">
            <Link
              to={`/dashboard/activities?date=${date}`}
              className="rounded-2xl border border-white/10 bg-surface-1 p-5 text-slate-100"
            >
              <h2 className="text-balance font-semibold">Activity</h2>
              <p className="mt-2 text-sm tabular-nums text-slate-300">
                {day.activities.length
                  ? `${day.activities.reduce((total, row) => total + row.duration_min, 0).toLocaleString()} minutes logged`
                  : 'Log movement for this day'}
              </p>
            </Link>
            <Link
              to={`/dashboard/sleep?date=${date}`}
              className="rounded-2xl border border-white/10 bg-surface-1 p-5 text-slate-100"
            >
              <h2 className="text-balance font-semibold">Sleep</h2>
              <p className="mt-2 text-sm tabular-nums text-slate-300">
                {day.sleep
                  ? `${(day.sleep_hours ?? day.sleep.hours).toLocaleString()} hours logged`
                  : 'Log sleep for this day'}
              </p>
            </Link>
          </div>
        </>
      )}

      {(storageError || parsedFood.error || foodError) && (
        <p role="alert" className="mt-4 text-pretty text-sm text-warning">
          {storageError || parsedFood.error || foodError}
        </p>
      )}
      {owner && doc && (
        <FoodDiary
          key={owner.account}
          owner={owner}
          doc={doc}
          entries={entries}
          date={date}
          onSaved={summary.refetch}
        />
      )}
    </AppShell>
  );
}
