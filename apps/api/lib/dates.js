// Timezone-aware date helpers.
//
// A log's `entry_date` is a calendar day in the *user's* timezone, not UTC.
// The old code called `new Date().toISOString().slice(0,10)` everywhere, which
// files an 8pm dinner in Michigan (UTC-4) under the next day. Every helper here
// takes an IANA timezone and defaults to UTC only when one isn't known.

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

const formatterCache = new Map();

function formatterFor(timeZone) {
  let f = formatterCache.get(timeZone);
  if (!f) {
    f = new Intl.DateTimeFormat('en-CA', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
    formatterCache.set(timeZone, f);
  }
  return f;
}

function isValidTimeZone(tz) {
  if (typeof tz !== 'string' || !tz) return false;
  try {
    new Intl.DateTimeFormat('en-CA', { timeZone: tz });
    return true;
  } catch {
    return false;
  }
}

function normalizeTimeZone(tz) {
  return isValidTimeZone(tz) ? tz : 'UTC';
}

// 'YYYY-MM-DD' for the given instant in the given zone. en-CA formats as
// ISO-like YYYY-MM-DD, which is why it's the locale here.
function today(timeZone = 'UTC', now = new Date()) {
  return formatterFor(normalizeTimeZone(timeZone)).format(now);
}

function isValidDateStr(value) {
  if (typeof value !== 'string' || !DATE_RE.test(value)) return false;
  const d = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === value;
}

function addDays(dateStr, days) {
  const d = new Date(`${dateStr}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

function daysBetween(fromStr, toStr) {
  const a = new Date(`${fromStr}T00:00:00Z`).getTime();
  const b = new Date(`${toStr}T00:00:00Z`).getTime();
  return Math.round((b - a) / 86400000);
}

// Inclusive list of day strings, oldest first. Capped so a bad `from` can't ask
// the server to materialise a hundred thousand days.
function rangeOfDays(fromStr, toStr, maxDays = 400) {
  const out = [];
  let cursor = fromStr;
  for (let i = 0; i <= maxDays; i++) {
    out.push(cursor);
    if (cursor === toStr) return out;
    cursor = addDays(cursor, 1);
  }
  return out;
}

// The N days ending on `endStr`, oldest first.
function lastNDays(n, endStr) {
  return rangeOfDays(addDays(endStr, -(n - 1)), endStr);
}

const WEEKDAY_LABELS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

function weekdayLabel(dateStr) {
  return WEEKDAY_LABELS[new Date(`${dateStr}T00:00:00Z`).getUTCDay()];
}

// ---------- UTC helpers ----------
// Kept because a few things are genuinely timezone-independent: the AI credit
// day boundary, and anything comparing against stored ISO timestamps.

function getTodayUTC() {
  return today('UTC');
}

function getLast7UTCDates(now = new Date()) {
  return lastNDays(7, now.toISOString().slice(0, 10));
}

module.exports = {
  DATE_RE,
  isValidTimeZone,
  normalizeTimeZone,
  today,
  isValidDateStr,
  addDays,
  daysBetween,
  rangeOfDays,
  lastNDays,
  weekdayLabel,
  WEEKDAY_LABELS,
  getTodayUTC,
  getLast7UTCDates,
};
