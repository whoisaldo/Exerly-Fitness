// Shared UTC date helpers used by both the production (Mongo) and local (SQLite)
// servers. Keeping them here (a) removes duplication and (b) makes the date logic
// unit-testable in isolation. Everything is UTC-based so daily boundaries are
// timezone-independent and consistent across servers and clients.

// Today's date as a 'YYYY-MM-DD' string in UTC.
function getTodayUTC() {
  return new Date().toISOString().slice(0, 10);
}

// Last 7 UTC day strings, oldest -> newest, ending today.
// e.g. ['2026-06-18', '2026-06-19', ..., '2026-06-24'].
function getLast7UTCDates(now = new Date()) {
  const days = [];
  for (let i = 6; i >= 0; i--) {
    const d = new Date(now);
    d.setUTCDate(d.getUTCDate() - i);
    days.push(d.toISOString().slice(0, 10));
  }
  return days;
}

const WEEKDAY_LABELS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

// Short weekday label for a 'YYYY-MM-DD' string, computed in UTC.
function weekdayLabel(dateStr) {
  return WEEKDAY_LABELS[new Date(dateStr + 'T00:00:00Z').getUTCDay()];
}

module.exports = { getTodayUTC, getLast7UTCDates, weekdayLabel, WEEKDAY_LABELS };
