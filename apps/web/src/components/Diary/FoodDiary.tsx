import { useEffect, useState } from 'react';
import type { MealType } from '../../lib/api';
import { addDays } from '../../lib/dates';
import { useAccountCalendar } from '../../hooks/useAccountCalendar';
import { nutrients, perServing, type FoodDraft, type FoodEntry } from '../../lib/food';
import {
  changeFood,
  correctFood,
  copyFoods,
  discardFoodDraft,
  readFoods,
  refreshFoods,
  resumeFoodDraft,
  retryFoods,
  reviewFood,
  resolveFood,
  visibleFoods,
  type FoodDocument,
  type FoodOperation,
  type FoodOwner,
} from '../../lib/foodStore';
import { formatCalories, formatGrams } from '../../lib/units';
import { GlassCard } from '../ui/GlassCard';
import { Modal } from '../ui/Modal';
import { ConfirmAction } from '../ui/ConfirmAction';
import { AddFoodSheet, foodButton, foodInput } from './AddFoodSheet';

const meals: Record<string, string> = {
  breakfast: 'Breakfast',
  lunch: 'Lunch',
  dinner: 'Dinner',
  snack: 'Snacks',
  uncategorized: 'Other',
};
export function FoodDiary({
  owner,
  doc,
  entries,
  date,
  onSaved,
}: {
  owner: FoodOwner;
  doc: FoodDocument;
  entries: FoodEntry[];
  date: string;
  onSaved: () => void;
}) {
  const { today } = useAccountCalendar();
  const [editor, setEditor] = useState<{
    meal: MealType;
    date: string;
    original?: FoodEntry;
    draft?: FoodDraft;
  } | null>(null);
  const [copy, setCopy] = useState<{ source: string; meal?: string } | null>(null);
  const [review, setReview] = useState<{ operation: FoodOperation; remote: FoodEntry } | null>(
    null
  );
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const run = async (work: () => Promise<unknown>) => {
    if (busy) return;
    setError(null);
    setBusy(true);
    try {
      await work();
    } catch (caught) {
      setError((caught as Error).message);
    } finally {
      setBusy(false);
    }
  };
  const live = entries.filter((row) => !row.deleted_at && row.entry_date === date);
  const deleted = entries.filter((row) => row.deleted_at && row.entry_date === date);
  const drafts = Object.values(doc.drafts)
    .filter((draft) => draft.fields.date === date)
    .sort((a, b) => b.updatedAt - a.updatedAt);
  return (
    <section aria-label="Food diary" className="mt-6 space-y-3">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h2 className="text-lg font-semibold text-slate-100">Food</h2>
        <button
          type="button"
          className={foodButton}
          disabled={date > today}
          onClick={() => setCopy({ source: addDays(date, -1) })}
        >
          Copy yesterday
        </button>
      </div>
      <p role="status" className="text-sm text-slate-400">
        {doc.operations.length
          ? `${doc.operations.length} food ${doc.operations.length === 1 ? 'change' : 'changes'} saved on this browser, waiting to sync`
          : 'Food synced'}
      </p>
      {!!doc.operations.length && (
        <button
          type="button"
          className={foodButton}
          disabled={busy}
          onClick={() => {
            void run(() => retryFoods(owner));
          }}
        >
          Retry food sync
        </button>
      )}
      {error && (
        <p role="alert" className="text-pretty text-sm text-error">
          {error}
        </p>
      )}
      {doc.operations
        .filter((op) => op.error)
        .map((op) => (
          <div key={op.id} className="rounded-xl border border-warning/30 p-4">
            <p className="text-sm text-slate-100">
              {op.copies[0].name} · {op.copies[0].entry_date}
            </p>
            <p role="alert" className="mt-1 text-pretty text-sm text-warning">
              {op.error}
            </p>
            {op.attention && op.status === 400 && op.kind === 'save' && (
              <button
                type="button"
                className={`${foodButton} mt-3`}
                disabled={busy}
                onClick={() => {
                  void run(async () => {
                    const draft = await correctFood(owner, op.id);
                    setEditor({
                      date: draft.fields.date,
                      meal: (draft.fields.meal === 'uncategorized'
                        ? 'snack'
                        : draft.fields.meal) as MealType,
                      draft,
                    });
                  });
                }}
              >
                Correct queued food
              </button>
            )}
            {op.attention && op.base !== 0 && (
              <button
                type="button"
                className={`${foodButton} mt-3`}
                disabled={busy}
                onClick={() => {
                  void run(async () =>
                    setReview({
                      operation: {
                        ...op,
                        copies:
                          [...doc.operations]
                            .reverse()
                            .find((item) => item.copies.some((row) => row.client_id === op.entity))
                            ?.copies ?? op.copies,
                      },
                      remote: await reviewFood(owner, op),
                    })
                  );
                }}
              >
                Review food conflict
              </button>
            )}
          </div>
        ))}
      {Object.entries(meals)
        .filter(([meal]) => meal !== 'uncategorized' || live.some((row) => !row.meal_type))
        .map(([meal, label]) => {
          const rows = live.filter((row) => (row.meal_type || 'uncategorized') === meal);
          return (
            <GlassCard key={meal} hover={false}>
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div>
                  <h3 className="text-sm font-semibold text-slate-100">{label}</h3>
                  <p className="mt-1 text-xs tabular-nums text-slate-400">
                    {formatCalories(rows.reduce((total, row) => total + row.calories, 0))} kcal
                  </p>
                </div>
                <div className="flex flex-wrap gap-2">
                  {!!rows.length && (
                    <button
                      type="button"
                      className={foodButton}
                      disabled={date > today}
                      aria-label={`Copy ${label.toLowerCase()}`}
                      onClick={() => setCopy({ source: date, meal })}
                    >
                      Copy
                    </button>
                  )}
                  {meal !== 'uncategorized' && (
                    <button
                      type="button"
                      className={foodButton}
                      disabled={date > today}
                      onClick={() => setEditor({ date, meal: meal as MealType })}
                    >
                      Add
                    </button>
                  )}
                </div>
              </div>
              {!!rows.length && (
                <ul className="mt-3 divide-y divide-white/10">
                  {rows.map((row) => (
                    <li key={row.client_id} className="py-3">
                      <div className="flex items-start justify-between gap-3">
                        <div className="min-w-0">
                          <p className="break-words text-sm text-slate-100">{row.name}</p>
                          <p className="mt-1 text-xs tabular-nums text-slate-400">
                            {Number(row.servings.toFixed(4))} servings
                            {row.serving_size && ` · ${row.serving_size}`}
                          </p>
                          <p className="mt-1 text-xs tabular-nums text-slate-400">
                            {formatGrams(row.protein)} P · {formatGrams(row.carbs)} C ·{' '}
                            {formatGrams(row.fat)} F
                          </p>
                          {row.local_operation && (
                            <p className="mt-1 text-xs text-warning">Waiting to sync</p>
                          )}
                        </div>
                        <span className="shrink-0 text-sm tabular-nums text-slate-200">
                          {formatCalories(row.calories)} kcal
                        </span>
                      </div>
                      <div className="mt-2 flex flex-wrap gap-2">
                        <button
                          type="button"
                          className={foodButton}
                          aria-label={`Edit ${row.name}`}
                          onClick={() =>
                            setEditor({
                              date: row.entry_date,
                              meal: row.meal_type ?? 'snack',
                              original: row,
                            })
                          }
                        >
                          Edit
                        </button>
                        <button
                          type="button"
                          className={foodButton}
                          disabled={busy}
                          aria-label={`Remove ${row.name}`}
                          onClick={() => {
                            void run(() => changeFood(owner, row, 'delete'));
                          }}
                        >
                          Remove
                        </button>
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </GlassCard>
          );
        })}
      {!!deleted.length && (
        <details className="rounded-xl border border-white/10 p-4" open>
          <summary className="min-h-11 cursor-pointer text-sm font-semibold text-slate-200">
            Removed foods ({deleted.length})
          </summary>
          <ul className="space-y-2">
            {deleted.map((row) => (
              <li
                key={row.client_id}
                className="flex flex-wrap items-center justify-between gap-3 text-sm text-slate-300"
              >
                <span>
                  {row.name}
                  {row.local_operation ? ' · Removal waiting to sync' : ' · Removed'}
                </span>
                <button
                  type="button"
                  className={foodButton}
                  disabled={busy}
                  aria-label={`Undo removal of ${row.name}`}
                  onClick={() => {
                    void run(() => changeFood(owner, row, 'restore'));
                  }}
                >
                  Undo
                </button>
              </li>
            ))}
          </ul>
        </details>
      )}
      {!!drafts.length && !editor && (
        <div className="rounded-xl border border-white/10 p-4">
          <h3 className="text-sm font-semibold text-slate-200">Saved food drafts</h3>
          <ul className="mt-2 space-y-3">
            {drafts.map((draft) => (
              <li
                key={draft.id}
                className="flex flex-wrap items-center justify-between gap-3 text-sm text-slate-300"
              >
                <span>
                  {draft.fields.name || 'Untitled food'} · {draft.fields.date}
                </span>
                <div className="flex gap-2">
                  <button
                    type="button"
                    className={foodButton}
                    disabled={busy}
                    onClick={() => {
                      void run(async () => {
                        const branch = await resumeFoodDraft(owner, draft.id);
                        setEditor({
                          date: branch.fields.date,
                          meal: branch.fields.meal as MealType,
                          draft: branch,
                        });
                      });
                    }}
                  >
                    Resume draft
                  </button>
                  <ConfirmAction
                    trigger={
                      <button type="button" className={foodButton} disabled={busy}>
                        Discard draft
                      </button>
                    }
                    title="Discard this food draft?"
                    description="This removes the unfinished draft from this browser. Logged food entries are kept."
                    action="Discard draft"
                    onConfirm={() => {
                      void run(() => discardFoodDraft(owner, draft.id));
                    }}
                  />
                </div>
              </li>
            ))}
          </ul>
        </div>
      )}
      {editor && (
        <AddFoodSheet
          owner={owner}
          date={editor.date}
          mealType={editor.meal}
          original={editor.original}
          savedDraft={editor.draft}
          onClose={() => setEditor(null)}
          onSaved={onSaved}
        />
      )}
      {copy && (
        <CopyFoods
          owner={owner}
          source={copy.source}
          meal={copy.meal}
          destination={date}
          onClose={() => setCopy(null)}
          onSaved={onSaved}
        />
      )}
      {review && (
        <FoodConflict
          owner={owner}
          operation={review.operation}
          remote={review.remote}
          onClose={() => setReview(null)}
        />
      )}
    </section>
  );
}

function CopyFoods({
  owner,
  source,
  meal,
  destination,
  onClose,
  onSaved,
}: {
  owner: FoodOwner;
  source: string;
  meal?: string;
  destination: string;
  onClose: () => void;
  onSaved: () => void;
}) {
  const { today } = useAccountCalendar();
  const [rows, setRows] = useState<FoodEntry[]>([]);
  const [selected, setSelected] = useState<string[]>([]);
  const [date, setDate] = useState(destination);
  const [targetMeal, setTargetMeal] = useState('keep');
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  useEffect(() => {
    let active = true;
    void (async () => {
      let failed = false;
      try {
        await refreshFoods(owner, source);
      } catch {
        failed = true;
      }
      const doc = await readFoods(owner.account);
      if (!active) return;
      if (failed && !doc.days[source])
        throw new Error(
          'This day is not saved on this browser. Connect to load its foods before copying.'
        );
      const available = visibleFoods(doc).filter(
        (row) =>
          row.entry_date === source &&
          !row.deleted_at &&
          (!meal || (row.meal_type || 'uncategorized') === meal)
      );
      setRows(available);
      setSelected(available.slice(0, 50).map((row) => row.client_id));
      if (failed)
        setNotice(
          'Using the saved copy of this day. Recent changes on other devices may be missing.'
        );
    })()
      .catch((caught) => {
        if (active) setError(caught.message);
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [owner, source, meal]);
  async function submit() {
    if (busy) return;
    setError(null);
    setBusy(true);
    try {
      if (!date || date > today) throw new Error('Choose today or a previous day.');
      await copyFoods(
        owner,
        rows
          .filter((row) => selected.includes(row.client_id))
          .map((row) => ({
            ...perServing(row),
            entry_date: date,
            meal_type: targetMeal === 'keep' ? row.meal_type : (targetMeal as MealType),
          }))
      );
      onSaved();
      onClose();
    } catch (caught) {
      setError((caught as Error).message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <Modal
      title={`Copy foods from ${source}`}
      onClose={() => {
        if (!busy) onClose();
      }}
    >
      <form
        className="space-y-4 p-5"
        onSubmit={(event) => {
          event.preventDefault();
          void submit();
        }}
      >
        {loading && <p role="status">Loading foods…</p>}
        {notice && <p className="text-pretty text-sm text-warning">{notice}</p>}
        {!loading && !error && !rows.length && (
          <p className="text-sm text-slate-300">No foods logged on this day.</p>
        )}
        <ul className="divide-y divide-white/10">
          {rows.map((row) => (
            <li key={row.client_id}>
              <label className="flex min-h-11 items-center gap-3 py-2 text-sm">
                <input
                  type="checkbox"
                  className="size-5 accent-violet-500"
                  checked={selected.includes(row.client_id)}
                  onChange={(event) =>
                    setSelected((current) =>
                      event.target.checked
                        ? [...current, row.client_id]
                        : current.filter((id) => id !== row.client_id)
                    )
                  }
                />
                <span>
                  {row.name} · {row.servings} servings · {row.calories} kcal
                </span>
              </label>
            </li>
          ))}
        </ul>
        <label className="block text-sm">
          Copy to date
          <input
            type="date"
            className={foodInput}
            max={today}
            required
            value={date}
            onChange={(event) => setDate(event.target.value)}
          />
        </label>
        <label className="block text-sm">
          Copy to meal
          <select
            aria-label="Copy to meal"
            className={`${foodInput} food-select`}
            value={targetMeal}
            onChange={(event) => setTargetMeal(event.target.value)}
          >
            <option value="keep">Keep original meals</option>
            {Object.entries(meals)
              .filter(([key]) => key !== 'uncategorized')
              .map(([key, label]) => (
                <option key={key} value={key}>
                  {label}
                </option>
              ))}
          </select>
        </label>
        <p className="text-pretty text-sm text-slate-400">
          Choose up to 50 foods. Copies keep their original portions and nutrition.
        </p>
        {error && (
          <p role="alert" className="text-pretty text-sm text-error">
            {error}
          </p>
        )}
        <button
          type="submit"
          className={`${foodButton} w-full`}
          disabled={loading || busy || !selected.length || selected.length > 50}
        >
          {busy ? 'Saving…' : `Copy ${selected.length} ${selected.length === 1 ? 'food' : 'foods'}`}
        </button>
      </form>
    </Modal>
  );
}

function FoodConflict({
  owner,
  operation,
  remote: initial,
  onClose,
}: {
  owner: FoodOwner;
  operation: FoodOperation;
  remote: FoodEntry;
  onClose: () => void;
}) {
  const [remote, setRemote] = useState(initial);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const mine = operation.copies[0];
  async function resolve(choice: 'server' | 'mine') {
    setBusy(true);
    setError(null);
    try {
      await resolveFood(owner, operation.id, choice, remote);
      onClose();
    } catch (caught) {
      setError((caught as Error).message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <Modal
      title="Review food conflict"
      onClose={() => {
        if (!busy) onClose();
      }}
    >
      <div className="space-y-4 p-5">
        <p className="text-pretty text-sm text-slate-300">
          This entry changed on another device. Choose which copy to keep. Related pending edits for
          this entry are included in your choice.
        </p>
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <caption className="sr-only">Food versions</caption>
            <thead>
              <tr>
                <th className="py-2">Field</th>
                <th className="p-2">Your copy</th>
                <th className="p-2">Server copy</th>
              </tr>
            </thead>
            <tbody>
              {['name', 'entry_date', 'meal_type', 'servings', ...nutrients, 'deleted_at'].map(
                (field) => (
                  <tr key={field} className="border-t border-white/10">
                    <th className="py-2 pr-3 font-normal text-slate-400">
                      {field.replace(/_/g, ' ')}
                    </th>
                    {[mine, remote].map((row, index) => (
                      <td key={index} className="p-2 tabular-nums">
                        {field === 'deleted_at'
                          ? row.deleted_at
                            ? 'Removed'
                            : 'Logged'
                          : String(row[field as keyof FoodEntry] ?? 'Unknown')}
                      </td>
                    ))}
                  </tr>
                )
              )}
            </tbody>
          </table>
        </div>
        {remote.deleted_at && !mine.deleted_at && (
          <p className="text-pretty text-sm text-warning">
            Keeping your copy will restore the food that was removed on the server.
          </p>
        )}
        {error && (
          <p role="alert" className="text-pretty text-sm text-error">
            {error}
          </p>
        )}
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            className={foodButton}
            disabled={busy}
            onClick={() => {
              void resolve('server');
            }}
          >
            Keep server copy
          </button>
          <button
            type="button"
            className={foodButton}
            disabled={busy}
            onClick={() => {
              void resolve('mine');
            }}
          >
            Keep my copy
          </button>
          <button
            type="button"
            className={foodButton}
            disabled={busy}
            onClick={() => {
              setBusy(true);
              void reviewFood(owner, operation)
                .then(setRemote)
                .catch((caught) => setError(caught.message))
                .finally(() => setBusy(false));
            }}
          >
            Refresh comparison
          </button>
        </div>
      </div>
    </Modal>
  );
}
