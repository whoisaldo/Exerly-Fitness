const test = require('node:test');
const assert = require('node:assert/strict');
const { trendSeries, estimateExpenditure } = require('../lib/nutrition');
const { rangeOfDays } = require('../lib/dates');

test('audit regression: one stale weigh-in plus 28 intake days cannot imply high confidence', () => {
  const days = rangeOfDays('2026-08-01', '2026-08-28');
  const trend = trendSeries([{ entry_date: days[0], weight_kg: 80 }], { days });
  const estimate = estimateExpenditure({
    trend,
    intakeByDate: new Map(days.map((d) => [d, 2200])),
    formula: 2500,
    dayStatusByDate: new Map(days.map((d) => [d, 'complete'])),
  });
  assert.equal(estimate.confidence, 'estimated');
  assert.equal(estimate.expenditure, 2500);
  assert.match(estimate.reason, /measurement|weigh-in/i);
});

test('a snack each day is not a complete intake history', () => {
  const days = rangeOfDays('2026-08-01', '2026-08-28');
  const trend = trendSeries(days.map((entry_date) => ({ entry_date, weight_kg: 80 })));
  for (const status of ['in_progress', 'estimated', 'excluded', undefined]) {
    const estimate = estimateExpenditure({
      trend,
      intakeByDate: new Map(days.map((d) => [d, 200])),
      dayStatusByDate: new Map(days.map((d) => [d, status])),
      formula: 2500,
    });
    assert.equal(estimate.confidence, 'estimated');
    assert.equal(estimate.expenditure, 2500);
  }
});

test('sparse but recent measurements cannot reach high confidence', () => {
  const days = rangeOfDays('2026-08-01', '2026-08-28');
  const trend = trendSeries(
    [0, 7, 14, 27].map((i) => ({ entry_date: days[i], weight_kg: 80 })),
    { days }
  );
  const estimate = estimateExpenditure({
    trend,
    intakeByDate: new Map(days.map((d) => [d, 2500])),
    dayStatusByDate: new Map(days.map((d) => [d, 'complete'])),
    formula: 2500,
  });
  assert.equal(estimate.confidence, 'low');
  assert.equal(estimate.measurementCount, 4);
});
