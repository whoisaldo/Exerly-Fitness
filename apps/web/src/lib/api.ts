/**
 * Typed API client.
 *
 * Every fetch in the app goes through here so token handling, error shapes, and
 * the timezone header exist in exactly one place. Components previously each
 * built their own fetch with their own error handling, which is why some pages
 * silently rendered nothing on a 401 while others redirected.
 */

import API_CONFIG from '../config';
import { ApiError } from './apiError';
import { getToken } from './sessionStorage';
import { authenticatedFetch } from './sessionNetwork';
import type { FoodEntry } from './food';
export type { FoodEntry } from './food';
export { ApiError } from './apiError';
export {
  getToken,
  setToken,
  clearToken,
  getSessionScope,
  SESSION_CHANGE_EVENT,
} from './sessionStorage';
export { authenticatedFetch, setUnauthorizedHandler } from './sessionNetwork';

// The browser knows the user's timezone; sending it means a brand new client
// files logs on the right calendar day before any setting has been saved.
export function browserTimezone(): string {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
  } catch {
    return 'UTC';
  }
}

type Method = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

interface RequestOptions {
  body?: unknown;
  signal?: AbortSignal;
  auth?: boolean;
  operationID?: string;
  offlineFallback?: boolean;
}

async function request<T>(method: Method, path: string, options: RequestOptions = {}): Promise<T> {
  const { body, signal, auth = true, operationID, offlineFallback = false } = options;
  const token = auth ? getToken() : null;

  const res = await (auth ? authenticatedFetch : fetch)(`${API_CONFIG.BASE_URL}${path}`, {
    method,
    signal,
    headers: {
      'Content-Type': 'application/json',
      'X-Timezone': browserTimezone(),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(operationID ? { 'Idempotency-Key': operationID } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
    ...(auth ? { offlineFallback } : {}),
  });

  if (res.status === 204) return undefined as T;

  const text = await res.text();
  let payload: unknown = null;
  if (text) {
    try {
      payload = JSON.parse(text);
    } catch {
      payload = text;
    }
  }

  if (!res.ok) {
    const message =
      (payload as { message?: string })?.message ||
      (typeof payload === 'string' ? payload : '') ||
      `Request failed (${res.status})`;
    throw new ApiError(res.status, message, (payload as { details?: unknown })?.details);
  }

  return payload as T;
}

export const api = {
  get: <T>(path: string, options?: RequestOptions) => request<T>('GET', path, options),
  post: <T>(path: string, body?: unknown, options?: RequestOptions) =>
    request<T>('POST', path, { ...options, body }),
  put: <T>(path: string, body?: unknown, options?: RequestOptions) =>
    request<T>('PUT', path, { ...options, body }),
  patch: <T>(path: string, body?: unknown, options?: RequestOptions) =>
    request<T>('PATCH', path, { ...options, body }),
  del: <T>(path: string, options?: RequestOptions) => request<T>('DELETE', path, options),
};

// ---------- response shapes ----------

export interface Macros {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  fiber: number;
  sugar: number;
  sodium: number;
}

export type MealType = 'breakfast' | 'lunch' | 'dinner' | 'snack';
export const MEAL_TYPES: MealType[] = ['breakfast', 'lunch', 'dinner', 'snack'];

export interface ActivityEntry {
  id: string;
  activity: string;
  duration_min: number;
  calories: number | null;
  intensity: string | null;
  entry_date: string;
}

export type DiaryLoggingStatus = 'in_progress' | 'complete' | 'estimated' | 'excluded';
export interface DiaryDay {
  entry_date: string;
  status: DiaryLoggingStatus;
  note: string | null;
  revision: number;
}

export interface WaterDay {
  entry_date: string;
  ml: number;
  revision: number;
}

export interface DaySummary {
  date: string;
  timezone: string;
  consumed: Macros;
  burned: number;
  targets: {
    calories: number | null;
    protein_g: number | null;
    carbs_g: number | null;
    fat_g: number | null;
    fiber_g: number | null;
    water_ml: number | null;
  };
  remaining: {
    calories: number | null;
    protein_g: number | null;
    carbs_g: number | null;
    fat_g: number | null;
  };
  meals: Record<string, { entries: FoodEntry[]; totals: Macros }>;
  activities: ActivityEntry[];
  sleep: { hours: number; quality: string | null } | null;
  sleep_entries?: Array<{ id: string; hours: number; quality: string | null }>;
  sleep_hours?: number;
  water_ml: number;
  water: WaterDay;
  weight: { weight_kg: number } | null;
  entry_count: number;
  diary_day: DiaryDay;
}

export interface TrendPoint {
  date: string;
  weight: number | null;
  trend: number;
}

export interface TrendResponse {
  from: string;
  to: string;
  series: TrendPoint[];
  summary: {
    current_trend_kg: number;
    current_weight_kg: number | null;
    change_kg: number;
    weekly_rate_kg: number;
    weigh_ins: number;
    days: number;
  } | null;
}

export interface Program {
  goal_type: 'lose' | 'maintain' | 'gain';
  rate_kg_per_week: number;
  target_weight_kg: number | null;
  diet_type: string;
  protein_strategy: string;
  last_checkin_date: string | null;
  needs_checkin: boolean;
  targets: {
    calories: number | null;
    protein_g: number | null;
    carbs_g: number | null;
    fat_g: number | null;
  };
  suggested_targets: {
    calories: number;
    protein_g: number;
    carbs_g: number;
    fat_g: number;
    fiber_g: number;
  } | null;
  expenditure: {
    value: number | null;
    confidence: 'estimated' | 'low' | 'medium' | 'high';
    live?: number;
    measured?: number | null;
    formula?: number | null;
    mean_intake?: number | null;
    trend_change_kg?: number | null;
    days_logged?: number;
    window_days?: number;
    reason?: string | null;
  };
}

export interface LibraryFood {
  id: string;
  name: string;
  brand: string | null;
  barcode: string | null;
  calories: number;
  protein: number | null;
  carbs: number | null;
  fat: number | null;
  fiber: number | null;
  sugar: number | null;
  serving_size: string | null;
  source: string;
  is_favorite: boolean;
  use_count: number;
  sodium?: number | null;
  saturated_fat?: number | null;
  nutrition_basis?: import('./food').NutritionBasis | null;
}

export interface SearchResult {
  food_id?: string | null;
  name: string;
  brand: string | null;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  fiber: number;
  sugar: number;
  serving_size: string;
  source: string;
  in_library?: boolean;
  sodium?: number | null;
  saturated_fat?: number | null;
  nutrition_basis?: import('./food').NutritionBasis | null;
}

export interface RangeSummary {
  from: string;
  to: string;
  series: Array<{
    date: string;
    label: string;
    consumed: number;
    protein: number;
    carbs: number;
    fat: number;
    fiber: number;
    entries: number;
    burned: number;
    weight_kg: number | null;
  }>;
  averages: {
    days_logged: number;
    days_total: number;
    calories: number;
    protein: number;
    carbs: number;
    fat: number;
    fiber: number;
    burned: number;
  };
}
