const test = require('node:test');
const assert = require('node:assert/strict');
const { getTodayUTC, getLast7UTCDates, weekdayLabel } = require('../utils/dateUtils');

test('getTodayUTC returns a YYYY-MM-DD string', () => {
  const today = getTodayUTC();
  assert.match(today, /^\d{4}-\d{2}-\d{2}$/);
  assert.equal(today, new Date().toISOString().slice(0, 10));
});

test('getLast7UTCDates returns 7 ascending days ending today', () => {
  const now = new Date('2026-06-24T12:00:00Z');
  const days = getLast7UTCDates(now);
  assert.equal(days.length, 7);
  assert.deepEqual(days, [
    '2026-06-18', '2026-06-19', '2026-06-20',
    '2026-06-21', '2026-06-22', '2026-06-23', '2026-06-24',
  ]);
  // strictly ascending
  for (let i = 1; i < days.length; i++) {
    assert.ok(days[i] > days[i - 1]);
  }
});

test('getLast7UTCDates crosses month boundaries correctly', () => {
  const days = getLast7UTCDates(new Date('2026-03-02T00:30:00Z'));
  assert.deepEqual(days, [
    '2026-02-24', '2026-02-25', '2026-02-26',
    '2026-02-27', '2026-02-28', '2026-03-01', '2026-03-02',
  ]);
});

test('weekdayLabel maps dates to UTC weekday labels', () => {
  assert.equal(weekdayLabel('2026-06-24'), 'Wed');
  assert.equal(weekdayLabel('2026-06-21'), 'Sun');
  assert.equal(weekdayLabel('2026-06-20'), 'Sat');
});
