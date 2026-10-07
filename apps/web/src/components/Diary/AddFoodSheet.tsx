import { useEffect, useState } from 'react';
import { api, type LibraryFood, type MealType, type SearchResult } from '../../lib/api';
import { useAccountCalendar } from '../../hooks/useAccountCalendar';
import {
  foodFromDraft,
  newFoodDraft,
  nutrients,
  type FoodDraft,
  type FoodEntry,
} from '../../lib/food';
import { saveFood, saveFoodDraft, type FoodOwner } from '../../lib/foodStore';
import { Modal } from '../ui/Modal';

export const foodButton =
  'min-h-11 rounded-xl border border-white/20 px-4 py-2 text-sm font-semibold text-slate-100 hover:bg-white/5 focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary disabled:opacity-50';
export const foodInput =
  'mt-1 min-h-11 w-full rounded-xl border border-white/20 bg-surface-2 px-3 py-2 text-base text-slate-100 focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary';
const labels = {
  calories: 'Calories / serving',
  protein: 'Protein (g)',
  carbs: 'Carbs (g)',
  fat: 'Fat (g)',
  fiber: 'Fibre (g)',
  sugar: 'Sugar (g)',
  sodium: 'Sodium (mg)',
  saturated_fat: 'Saturated fat (g)',
};
const units = [
  ['serving', 'Servings'],
  ['g', 'Grams'],
  ['oz', 'Ounces'],
  ['ml', 'Millilitres'],
  ['fl_oz', 'Fluid ounces'],
];
interface Props {
  owner: FoodOwner;
  date: string;
  mealType: MealType;
  original?: FoodEntry;
  savedDraft?: FoodDraft;
  onClose: () => void;
  onSaved: () => void;
}
export function AddFoodSheet({
  owner,
  date,
  mealType,
  original,
  savedDraft,
  onClose,
  onSaved,
}: Props) {
  const { today } = useAccountCalendar();
  const [tab, setTab] = useState<'recent' | 'search' | 'quick'>('recent');
  const [query, setQuery] = useState('');
  const [foods, setFoods] = useState<Array<LibraryFood | SearchResult>>([]);
  const [loading, setLoading] = useState(false);
  const [lookupError, setLookupError] = useState<string | null>(null);
  const [draft, setDraft] = useState<FoodDraft | null>(
    () => savedDraft ?? (original ? newFoodDraft(date, mealType, original) : null)
  );
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [draftStatus, setDraftStatus] = useState('');

  useEffect(() => {
    if (!draft) return;
    let active = true;
    setDraftStatus('Saving draft…');
    void saveFoodDraft(owner, draft)
      .then(() => {
        if (active) setDraftStatus('Draft saved on this browser');
      })
      .catch((caught) => {
        if (active) {
          setError(caught.message);
          setDraftStatus('Draft not saved');
        }
      });
    return () => {
      active = false;
    };
  }, [draft, owner]);

  useEffect(() => {
    if (draft || tab === 'quick' || (tab === 'search' && query.trim().length < 2)) {
      setFoods([]);
      setLookupError(null);
      setLoading(false);
      return;
    }
    const controller = new AbortController();
    setFoods([]);
    setLookupError(null);
    setLoading(true);
    const timer = window.setTimeout(
      () => {
        const lookup =
          tab === 'recent'
            ? api.get<LibraryFood[]>('/api/library/foods?limit=30', {
                signal: controller.signal,
                offlineFallback: true,
              })
            : api
                .get<{
                  library: LibraryFood[];
                  results: SearchResult[];
                }>(`/api/food/search?q=${encodeURIComponent(query.trim())}`, {
                  signal: controller.signal,
                })
                .then((result) => [...result.library, ...result.results]);
        void lookup
          .then((rows) => {
            if (!controller.signal.aborted) setFoods(rows);
          })
          .catch((caught) => {
            if (!controller.signal.aborted) setLookupError(caught.message);
          })
          .finally(() => {
            if (!controller.signal.aborted) setLoading(false);
          });
      },
      tab === 'search' ? 300 : 0
    );
    return () => {
      controller.abort();
      clearTimeout(timer);
    };
  }, [draft, tab, query]);

  function pick(item: LibraryFood | SearchResult) {
    const next = newFoodDraft(date, mealType);
    next.source = item.source;
    next.barcode = 'barcode' in item ? item.barcode : null;
    next.fields.name = item.name;
    next.fields.brand = item.brand ?? '';
    next.fields.servingSize = item.serving_size ?? '';
    next.fields.basisAmount = String(item.nutrition_basis?.amount ?? 1);
    next.fields.basisUnit = item.nutrition_basis?.unit ?? 'serving';
    for (const key of nutrients) next.fields[key] = String(item[key] ?? '');
    setDraft(next);
  }
  function field(key: keyof FoodDraft['fields'], value: string) {
    setError(null);
    setDraft(
      (current) =>
        current && {
          ...current,
          updatedAt: Date.now(),
          fields: { ...current.fields, [key]: value },
        }
    );
  }
  async function close() {
    if (saving) return;
    if (draft) {
      try {
        await saveFoodDraft(owner, draft);
      } catch (caught) {
        setError((caught as Error).message);
        return;
      }
    }
    onClose();
  }
  async function submit() {
    if (!draft || saving) return;
    setError(null);
    setSaving(true);
    try {
      const input = foodFromDraft(draft, today);
      await saveFoodDraft(owner, draft);
      await saveFood(owner, draft, input);
      onSaved();
      onClose();
    } catch (caught) {
      setError((caught as Error).message);
    } finally {
      setSaving(false);
    }
  }
  let preview: string | null = null;
  if (draft) {
    try {
      const input = foodFromDraft(draft, today);
      preview = `${Math.round(input.calories * input.servings).toLocaleString()} kcal · ${Number(input.servings.toFixed(4))} servings`;
    } catch {
      /* Show validation when the person submits. */
    }
  }
  return (
    <Modal
      title={original || draft?.original ? 'Edit food' : `Add to ${mealType}`}
      onClose={() => {
        void close();
      }}
    >
      {draft ? (
        <form
          aria-label="Food details"
          className="space-y-4 p-5"
          onSubmit={(event) => {
            event.preventDefault();
            void submit();
          }}
        >
          <p className="text-pretty text-sm text-slate-400">
            Nutrition is per serving or the basis below. Leave unknown nutrients blank.
          </p>
          <label className="block text-sm">
            Name
            <input
              autoFocus
              placeholder="What did you eat?"
              className={foodInput}
              value={draft.fields.name}
              onChange={(event) => field('name', event.target.value)}
              maxLength={200}
              required
            />
          </label>
          <label className="block text-sm">
            Brand (optional)
            <input
              className={foodInput}
              value={draft.fields.brand}
              onChange={(event) => field('brand', event.target.value)}
              maxLength={120}
            />
          </label>
          <div className="grid grid-cols-2 gap-3">
            <label className="text-sm">
              Food date
              <input
                type="date"
                max={today}
                className={foodInput}
                value={draft.fields.date}
                onChange={(event) => field('date', event.target.value)}
                required
              />
            </label>
            <label className="text-sm">
              Meal
              <select
                aria-label="Meal"
                className={`${foodInput} food-select`}
                value={draft.fields.meal}
                onChange={(event) => field('meal', event.target.value)}
              >
                {['breakfast', 'lunch', 'dinner', 'snack', 'uncategorized'].map((meal) => (
                  <option key={meal} value={meal}>
                    {meal[0].toUpperCase() + meal.slice(1)}
                  </option>
                ))}
              </select>
            </label>
          </div>
          <fieldset className="rounded-xl border border-white/10 p-3">
            <legend className="px-1 text-sm font-semibold">Nutrition basis</legend>
            <div className="grid grid-cols-2 gap-3">
              <label className="text-sm">
                Basis amount
                <input
                  inputMode="decimal"
                  className={foodInput}
                  value={draft.fields.basisAmount}
                  onChange={(event) => field('basisAmount', event.target.value)}
                  required
                />
              </label>
              <label className="text-sm">
                Basis unit
                <select
                  aria-label="Basis unit"
                  className={`${foodInput} food-select`}
                  value={draft.fields.basisUnit}
                  onChange={(event) => field('basisUnit', event.target.value)}
                >
                  {units.map(([unit, name]) => (
                    <option key={unit} value={unit}>
                      {name}
                    </option>
                  ))}
                </select>
              </label>
            </div>
            <label className="mt-3 block text-sm">
              Serving description (optional)
              <input
                className={foodInput}
                placeholder="For example, 1 cup or 1 slice"
                value={draft.fields.servingSize}
                onChange={(event) => field('servingSize', event.target.value)}
                maxLength={80}
              />
            </label>
          </fieldset>
          <div className="grid grid-cols-2 gap-3">
            {nutrients.map((key) => (
              <label key={key} className="text-sm">
                {labels[key]}
                <input
                  className={foodInput}
                  inputMode="decimal"
                  value={draft.fields[key]}
                  onChange={(event) => field(key, event.target.value)}
                  required={key === 'calories'}
                />
              </label>
            ))}
          </div>
          <div className="grid grid-cols-2 gap-3">
            <label className="text-sm">
              Quantity
              <input
                className={foodInput}
                value={draft.fields.quantity}
                onChange={(event) => field('quantity', event.target.value)}
                placeholder="1 1/2"
                required
              />
            </label>
            <label className="text-sm">
              Quantity unit
              <select
                aria-label="Quantity unit"
                className={`${foodInput} food-select`}
                value={draft.fields.unit}
                onChange={(event) => field('unit', event.target.value)}
              >
                {units.map(([unit, name]) => (
                  <option key={unit} value={unit}>
                    {name}
                  </option>
                ))}
              </select>
            </label>
          </div>
          <p className="text-pretty text-xs text-slate-400">
            Use decimals or fractions. Grams and ounces require a weight basis; millilitres and
            fluid ounces require a volume basis.
          </p>
          {preview && (
            <p aria-label="Food total" className="font-semibold tabular-nums text-slate-100">
              {preview}
            </p>
          )}
          <p role="status" className="text-xs text-slate-400">
            {draftStatus}
          </p>
          {error && (
            <p role="alert" className="text-pretty text-sm text-error">
              {error}
            </p>
          )}
          <button type="submit" disabled={saving} className={`${foodButton} w-full bg-primary/20`}>
            {saving ? 'Saving…' : draft.original ? 'Save changes' : 'Log it'}
          </button>
        </form>
      ) : (
        <div className="p-5">
          <div className="mb-4 flex flex-wrap gap-2">
            {(['recent', 'search', 'quick'] as const).map((value) => (
              <button
                key={value}
                className={foodButton}
                aria-pressed={tab === value}
                onClick={() => setTab(value)}
              >
                {value === 'quick' ? 'Quick add' : value === 'recent' ? 'Recent' : 'Search'}
              </button>
            ))}
          </div>
          {tab === 'search' && (
            <label className="block text-sm">
              Search foods
              <input
                autoFocus
                className={foodInput}
                placeholder="Search foods..."
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                maxLength={100}
              />
            </label>
          )}
          {loading && (
            <p role="status" className="mt-4 text-sm text-slate-400">
              Loading foods…
            </p>
          )}
          {lookupError && (
            <p role="alert" className="mt-4 text-pretty text-sm text-error">
              {lookupError} Use quick add to enter the food manually.
            </p>
          )}
          {!loading && !lookupError && !foods.length && tab !== 'quick' && (
            <p className="mt-4 text-pretty text-sm text-slate-400">
              {tab === 'search'
                ? query.trim().length < 2
                  ? 'Enter at least two characters.'
                  : 'No foods found. Try another name or use quick add.'
                : 'No recent foods yet. Search or use quick add.'}
            </p>
          )}
          <ul className="mt-3 divide-y divide-white/10">
            {foods.map((item, index) => (
              <li key={`${item.name}-${index}`}>
                <button
                  type="button"
                  className="flex min-h-14 w-full items-center justify-between gap-3 rounded-lg px-2 py-3 text-left hover:bg-white/5"
                  onClick={() => pick(item)}
                >
                  <span>
                    <span className="block text-sm">{item.name}</span>
                    <span className="block text-xs text-slate-400">
                      {[item.brand, item.serving_size].filter(Boolean).join(' · ') || 'Per serving'}
                    </span>
                  </span>
                  <span className="shrink-0 text-sm tabular-nums text-slate-300">
                    {item.calories == null ? 'Calories unknown' : `${item.calories} kcal`}
                  </span>
                </button>
              </li>
            ))}
          </ul>
          {tab === 'quick' && (
            <button
              type="button"
              className={`${foodButton} w-full`}
              onClick={() => setDraft(newFoodDraft(date, mealType))}
            >
              Enter macros manually
            </button>
          )}
        </div>
      )}
    </Modal>
  );
}
