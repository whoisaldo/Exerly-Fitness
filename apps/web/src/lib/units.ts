/**
 * Unit conversion and formatting.
 *
 * The API speaks kilograms and centimetres exclusively. Anything imperial is a
 * display concern that lives here, which is what stops pounds leaking into the
 * database.
 */

export type UnitSystem = 'metric' | 'imperial';

const LB_PER_KG = 2.20462262;
const CM_PER_INCH = 2.54;

export const kgToLb = (kg: number): number => kg * LB_PER_KG;
export const lbToKg = (lb: number): number => lb / LB_PER_KG;

export function weightLabel(system: UnitSystem): string {
  return system === 'imperial' ? 'lb' : 'kg';
}

export function displayWeight(
  kg: number | null | undefined,
  system: UnitSystem,
  places = 1
): string {
  if (kg == null || !Number.isFinite(kg)) return '--';
  const value = system === 'imperial' ? kgToLb(kg) : kg;
  return value.toFixed(places);
}

// Rate of change carries a sign that matters, so it is always shown.
export function displayRate(kgPerWeek: number | null | undefined, system: UnitSystem): string {
  if (kgPerWeek == null || !Number.isFinite(kgPerWeek)) return '--';
  const value = system === 'imperial' ? kgToLb(kgPerWeek) : kgPerWeek;
  const sign = value > 0 ? '+' : '';
  return `${sign}${value.toFixed(2)} ${weightLabel(system)}/wk`;
}

export function cmToFeetInches(cm: number): { feet: number; inches: number } {
  const totalInches = cm / CM_PER_INCH;
  return { feet: Math.floor(totalInches / 12), inches: Math.round(totalInches % 12) };
}

export function feetInchesToCm(feet: number, inches: number): number {
  return (feet * 12 + inches) * CM_PER_INCH;
}

export function displayHeight(cm: number | null | undefined, system: UnitSystem): string {
  if (cm == null) return '--';
  if (system === 'metric') return `${Math.round(cm)} cm`;
  const { feet, inches } = cmToFeetInches(cm);
  return `${feet}'${inches}"`;
}

const ML_PER_CUP = 236.588;

export function displayVolume(ml: number, system: UnitSystem): string {
  if (system === 'imperial') return `${(ml / ML_PER_CUP).toFixed(1)} cups`;
  return ml >= 1000 ? `${(ml / 1000).toFixed(1)} L` : `${Math.round(ml)} ml`;
}

export function formatCalories(value: number | null | undefined): string {
  if (value == null || !Number.isFinite(value)) return '--';
  return Math.round(value).toLocaleString();
}

export function formatGrams(value: number | null | undefined, places = 0): string {
  if (value == null || !Number.isFinite(value)) return '--';
  return `${value.toFixed(places)}g`;
}
