import { isCalendarDay } from './dates';
import { operationID } from './ids';

export type FoodUnit = 'serving' | 'g' | 'oz' | 'ml' | 'fl_oz';
export interface NutritionBasis {
  amount: number;
  unit: FoodUnit;
}
export const nutrients = [
  'calories',
  'protein',
  'carbs',
  'fat',
  'fiber',
  'sugar',
  'sodium',
  'saturated_fat',
] as const;
export type Nutrient = (typeof nutrients)[number];
export type Nutrition = Record<Nutrient, number | null> & { calories: number };
export interface FoodInput extends Nutrition {
  name: string;
  brand: string | null;
  barcode: string | null;
  source: string | null;
  servings: number;
  serving_size: string | null;
  serving_unit?: string | null;
  nutrition_basis: NutritionBasis | null;
  entered_quantity?: NutritionBasis | null;
  meal_type: 'breakfast' | 'lunch' | 'dinner' | 'snack' | null;
  entry_date: string;
}
export interface FoodEntry extends FoodInput {
  id: string;
  _id?: string;
  client_id: string;
  account_id?: string;
  revision: number;
  nutrition_snapshot: (Nutrition & { basis?: NutritionBasis | null }) | null;
  deleted_at?: string | null;
  logged_at?: string;
  updated_at?: string;
  local_operation?: string;
}
export interface FoodDraft {
  id: string;
  entity: string;
  original: FoodEntry | null;
  updatedAt: number;
  replaces?: string;
  fields: Record<
    | Nutrient
    | 'name'
    | 'brand'
    | 'date'
    | 'meal'
    | 'quantity'
    | 'unit'
    | 'basisAmount'
    | 'basisUnit'
    | 'servingSize',
    string
  >;
  source: string | null;
  barcode: string | null;
}
export function normalizeFood(raw: FoodEntry): FoodEntry {
  if (
    !raw ||
    !raw.id ||
    typeof raw.name !== 'string' ||
    !isCalendarDay(raw.entry_date) ||
    !Number.isFinite(raw.calories) ||
    !Number.isFinite(raw.servings) ||
    raw.servings <= 0 ||
    !Number.isInteger(raw.revision ?? 1) ||
    (raw.revision ?? 1) < 0
  )
    throw new Error('This food entry could not be read. Its original copy is preserved.');
  if (
    raw.nutrition_snapshot &&
    (!Number.isFinite(raw.nutrition_snapshot.calories) ||
      nutrients.some(
        (key) =>
          raw.nutrition_snapshot![key] != null && !Number.isFinite(raw.nutrition_snapshot![key])
      ))
  )
    throw new Error(
      'This food’s nutrition snapshot could not be read. Its original copy is preserved.'
    );
  return {
    ...raw,
    id: String(raw.id),
    client_id: raw.client_id || `legacy-${raw.id}`,
    revision: raw.revision ?? 1,
    sodium: raw.sodium ?? null,
    saturated_fat: raw.saturated_fat ?? null,
    nutrition_snapshot: raw.nutrition_snapshot ?? null,
  };
}
export function perServing(food: FoodEntry): FoodInput {
  const nutrition = Object.fromEntries(
    nutrients.map((key) => [
      key,
      food.nutrition_snapshot
        ? food.nutrition_snapshot[key]
        : food[key] == null
          ? null
          : food[key]! / food.servings,
    ])
  ) as Nutrition;
  return {
    ...nutrition,
    name: food.name,
    brand: food.brand,
    barcode: food.barcode,
    source: food.source,
    servings: food.servings,
    serving_size: food.serving_size,
    serving_unit: food.serving_unit,
    nutrition_basis: food.nutrition_basis,
    entered_quantity: food.entered_quantity,
    meal_type: food.meal_type,
    entry_date: food.entry_date,
  };
}
export function snapshot(input: FoodInput, entity: string, previous?: FoodEntry | null): FoodEntry {
  const totals = Object.fromEntries(
    nutrients.map((key) => [
      key,
      input[key] == null
        ? null
        : key === 'calories'
          ? Math.round(input[key]! * input.servings)
          : Math.round(input[key]! * input.servings * 100) / 100,
    ])
  ) as Nutrition;
  const nutrition = Object.fromEntries(nutrients.map((key) => [key, input[key]])) as Nutrition;
  return {
    ...input,
    ...totals,
    id: previous?.id ?? `local-${entity}`,
    client_id: entity,
    revision: previous?.revision ?? 0,
    nutrition_snapshot: { ...nutrition, basis: input.nutrition_basis },
    deleted_at: null,
  };
}
export function quantity(value: string): number {
  const trimmed = value.trim();
  if (/^(?:\d+(?:\.\d*)?|\.\d+)$/.test(trimmed) && Number.isFinite(Number(trimmed)))
    return Number(trimmed);
  const fraction = trimmed.match(/^(?:(\d+)\s+)?(\d+)\/(\d+)$/);
  if (
    fraction &&
    Number(fraction[3]) > 0 &&
    fraction.slice(1).every((part) => Number.isFinite(Number(part || 0)))
  ) {
    const result = Number(fraction[1] || 0) + Number(fraction[2]) / Number(fraction[3]);
    if (Number.isFinite(result)) return result;
  }
  throw new Error('Enter a number or fraction, such as 1.5 or 1 1/2.');
}
export function servingsFor(amount: number, unit: FoodUnit, basis: NutritionBasis): number {
  if (unit === 'serving') return amount;
  const weight: Partial<Record<FoodUnit, number>> = { g: 1, oz: 28.349523125 };
  const volume: Partial<Record<FoodUnit, number>> = { ml: 1, fl_oz: 29.5735295625 };
  const factors = weight[unit] && weight[basis.unit] ? weight : volume;
  if (!factors[unit] || !factors[basis.unit])
    throw new Error('This food does not provide the weight or volume needed for that unit.');
  return (amount * factors[unit]!) / (basis.amount * factors[basis.unit]!);
}
export function newFoodDraft(date: string, meal = 'snack', food?: FoodEntry): FoodDraft {
  const input = food ? perServing(food) : null;
  const basis = input?.nutrition_basis ?? { amount: 1, unit: 'serving' };
  let unit = 'serving';
  let amount = input?.servings ?? 1;
  if (input?.entered_quantity) {
    amount = input.entered_quantity.amount;
    unit = input.entered_quantity.unit;
  } else if (input?.serving_unit && ['g', 'oz', 'ml', 'fl_oz'].includes(input.serving_unit)) {
    try {
      amount = Number(
        (amount / servingsFor(1, input.serving_unit as FoodUnit, basis)).toPrecision(12)
      );
      unit = input.serving_unit;
    } catch {
      /* Older entries without a convertible basis retain serving counts. */
    }
  }
  return {
    id: operationID(),
    entity: food?.client_id ?? operationID(),
    original: food ?? null,
    updatedAt: Date.now(),
    source: input?.source ?? 'custom',
    barcode: input?.barcode ?? null,
    fields: {
      ...(Object.fromEntries(nutrients.map((key) => [key, String(input?.[key] ?? '')])) as Record<
        Nutrient,
        string
      >),
      name: input?.name ?? '',
      brand: input?.brand ?? '',
      date: input?.entry_date ?? date,
      meal: input ? (input.meal_type ?? 'uncategorized') : meal,
      quantity: String(amount),
      unit,
      basisAmount: String(basis.amount),
      basisUnit: basis.unit,
      servingSize: input?.serving_size ?? '',
    },
  };
}
export function foodFromDraft(draft: FoodDraft, today: string): FoodInput {
  const f = draft.fields;
  if (!f.name.trim() || f.name.trim().length > 200)
    throw new Error('Enter a food name of up to 200 characters.');
  if (f.brand.trim().length > 120 || f.servingSize.trim().length > 80)
    throw new Error('Shorten the brand or serving description.');
  if (!isCalendarDay(f.date) || f.date > today) throw new Error('Choose today or a previous day.');
  if (!['breakfast', 'lunch', 'dinner', 'snack', 'uncategorized'].includes(f.meal))
    throw new Error('Choose a meal.');
  const basis = { amount: quantity(f.basisAmount), unit: f.basisUnit as FoodUnit };
  if (
    !(basis.amount >= 0.01) ||
    basis.amount > 100000 ||
    !['serving', 'g', 'oz', 'ml', 'fl_oz'].includes(basis.unit) ||
    !['serving', 'g', 'oz', 'ml', 'fl_oz'].includes(f.unit)
  )
    throw new Error('Enter a valid nutrition basis.');
  const enteredAmount = quantity(f.quantity);
  if (enteredAmount < 0.000001 || enteredAmount > 100000)
    throw new Error('Enter a quantity between 0.000001 and 100,000.');
  const servings = servingsFor(enteredAmount, f.unit as FoodUnit, basis);
  if (!Number.isFinite(servings) || servings < 0.01 || servings > 100)
    throw new Error('The quantity must be between 0.01 and 100 servings.');
  const values = Object.fromEntries(
    nutrients.map((key) => {
      if (!f[key].trim() && key !== 'calories') return [key, null];
      const value = quantity(f[key]);
      if (value < 0 || value > (key === 'calories' ? 30000 : 100000))
        throw new Error(`Enter a valid ${key.replace('_', ' ')} value.`);
      return [key, value];
    })
  ) as Nutrition;
  return {
    ...values,
    name: f.name.trim(),
    brand: f.brand.trim() || null,
    barcode: draft.barcode,
    source: draft.source,
    servings,
    serving_size: f.servingSize.trim() || `${basis.amount} ${basis.unit}`,
    serving_unit: f.unit,
    nutrition_basis: basis,
    entered_quantity: { amount: enteredAmount, unit: f.unit as FoodUnit },
    meal_type: f.meal === 'uncategorized' ? null : (f.meal as FoodInput['meal_type']),
    entry_date: f.date,
  };
}
