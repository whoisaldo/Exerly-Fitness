/**
 * Calendar-day helpers for the browser.
 *
 * Dates are 'YYYY-MM-DD' strings throughout, matching what the API stores.
 * Constructing a Date from one of those and reading local getters is the usual
 * off-by-one trap, so everything here works on the string or pins UTC.
 */

export function normalizeTimeZone(value: string): string {
  try {
    if (!value) return 'UTC';
    new Intl.DateTimeFormat('en', { timeZone: value });
    return value;
  } catch {
    return 'UTC';
  }
}

export function todayString(timeZone: string, now = new Date()): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    calendar: 'gregory',
    numberingSystem: 'latn',
    timeZone: normalizeTimeZone(timeZone),
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(now);
  const part = (type: string) => parts.find((item) => item.type === type)!.value;
  return `${part('year').padStart(4, '0')}-${part('month')}-${part('day')}`;
}

export function isCalendarDay(value: string | null): value is string {
  if (!value || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00Z`);
  return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

export function addDays(dateStr: string, days: number): string {
  if (!isCalendarDay(dateStr) || !Number.isInteger(days)) throw new Error('Invalid calendar day');
  const d = new Date(`${dateStr}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  const result = d.toISOString().slice(0, 10);
  if (!isCalendarDay(result)) throw new Error('Calendar day is outside the supported range');
  return result;
}

export function daysBetween(from: string, to: string): number {
  if (!isCalendarDay(from) || !isCalendarDay(to)) throw new Error('Invalid calendar day');
  const a = new Date(`${from}T00:00:00Z`).getTime();
  const b = new Date(`${to}T00:00:00Z`).getTime();
  return Math.round((b - a) / 86400000);
}

export function isToday(dateStr: string, today: string): boolean {
  return dateStr === today;
}

export function isFuture(dateStr: string, today: string): boolean {
  return dateStr > today;
}

const WEEKDAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const MONTHS = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

export function friendlyDate(dateStr: string, today: string): string {
  if (!isCalendarDay(dateStr)) return dateStr;
  if (dateStr === today) return 'Today';
  if (dateStr === addDays(today, -1)) return 'Yesterday';
  if (dateStr === addDays(today, 1)) return 'Tomorrow';

  const d = new Date(`${dateStr}T00:00:00Z`);
  const weekday = WEEKDAYS[d.getUTCDay()];
  const month = MONTHS[d.getUTCMonth()];
  const day = d.getUTCDate();

  // Within the past week the weekday alone is the most readable label.
  if (daysBetween(dateStr, today) < 7 && daysBetween(dateStr, today) > 0) {
    return weekday;
  }
  const year = d.getUTCFullYear();
  const suffix = String(year) === today.slice(0, 4) ? '' : ` ${year}`;
  return `${weekday.slice(0, 3)} ${day} ${month.slice(0, 3)}${suffix}`;
}

export function shortDate(dateStr: string): string {
  const d = new Date(`${dateStr}T00:00:00Z`);
  return `${d.getUTCDate()} ${MONTHS[d.getUTCMonth()].slice(0, 3)}`;
}
