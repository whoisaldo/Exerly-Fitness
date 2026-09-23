const test = require('node:test');
const assert = require('node:assert');
const {
  trendSeries,
  estimateExpenditure,
  computeTargets,
  mifflinStJeor,
  formulaExpenditure,
  KCAL_PER_KG,
} = require('../lib/nutrition');
const { lastNDays } = require('../lib/dates');

// Deterministic pseudo-random noise so a failure is reproducible.
function makeNoise(seed) {
  let s = seed;
  return () => {
    s = (s * 1103515245 + 12345) % 2147483648;
    return s / 2147483648 - 0.5;
  };
}

// Simulate someone whose real expenditure is `tdee`, eating `intake` per day.
// Scale weight follows true weight plus water-weight noise.
function simulate({ days, startKg, tdee, intake, noiseKg = 1.2, seed = 7 }) {
  const noise = makeNoise(seed);
  const dates = lastNDays(days, '2026-08-29');
  const dailyChangeKg = (intake - tdee) / KCAL_PER_KG;

  const weights = [];
  const intakeByDate = new Map();
  dates.forEach((date, i) => {
    const trueKg = startKg + dailyChangeKg * i;
    weights.push({ entry_date: date, weight_kg: trueKg + noise() * noiseKg });
    intakeByDate.set(date, intake);
  });

  return { dates, weights, intakeByDate };
}

test('trendSeries smooths scale noise toward the real value', () => {
  const { dates, weights } = simulate({ days: 60, startKg: 85, tdee: 2600, intake: 2600 });
  const series = trendSeries(weights, { days: dates });

  assert.equal(series.length, 60);
  // True weight is flat at 85. The trend should sit much closer to it than the
  // noisy readings do.
  const trendError = Math.abs(series.at(-1).trend - 85);
  const scaleError = Math.abs(series.at(-1).weight - 85);
  assert.ok(trendError < 0.5, `trend off by ${trendError.toFixed(2)}kg`);
  assert.ok(trendError < scaleError, 'trend should beat the raw reading');
});

test('trendSeries carries the trend across days with no weigh-in', () => {
  const series = trendSeries(
    [
      { entry_date: '2026-08-01', weight_kg: 80 },
      { entry_date: '2026-08-05', weight_kg: 80 },
    ],
    { days: ['2026-08-01', '2026-08-02', '2026-08-03', '2026-08-04', '2026-08-05'] }
  );

  assert.equal(series.length, 5);
  assert.equal(series[1].weight, null, 'gap day has no scale reading');
  assert.equal(series[1].trend, 80, 'gap day carries the trend forward');
});

test('trendSeries ignores leading days before the first weigh-in', () => {
  const series = trendSeries([{ entry_date: '2026-08-03', weight_kg: 80 }], {
    days: ['2026-08-01', '2026-08-02', '2026-08-03'],
  });
  assert.equal(series.length, 1);
  assert.equal(series[0].date, '2026-08-03');
});

test('estimateExpenditure recovers a known TDEE from a simulated cut', () => {
  const TRUE_TDEE = 2600;
  const { dates, weights, intakeByDate } = simulate({
    days: 56,
    startKg: 85,
    tdee: TRUE_TDEE,
    intake: 2100,
  });

  const trend = trendSeries(weights, { days: dates });
  const result = estimateExpenditure({
    trend,
    intakeByDate,
    dayStatusByDate: new Map(dates.map((d) => [d, 'complete'])),
    formula: 2400,
    windowDays: 42,
  });

  const error = Math.abs(result.expenditure - TRUE_TDEE);
  assert.ok(error < 150, `expected ~${TRUE_TDEE}, got ${result.expenditure} (off by ${error})`);
  assert.equal(result.confidence, 'high');
  assert.equal(result.meanIntake, 2100);
});

test('estimateExpenditure recovers a known TDEE from a simulated bulk', () => {
  const TRUE_TDEE = 2800;
  const { dates, weights, intakeByDate } = simulate({
    days: 56,
    startKg: 70,
    tdee: TRUE_TDEE,
    intake: 3100,
    seed: 99,
  });

  const trend = trendSeries(weights, { days: dates });
  const result = estimateExpenditure({
    trend,
    intakeByDate,
    dayStatusByDate: new Map(dates.map((d) => [d, 'complete'])),
    formula: 2700,
    windowDays: 42,
  });

  assert.ok(
    Math.abs(result.expenditure - TRUE_TDEE) < 150,
    `expected ~${TRUE_TDEE}, got ${result.expenditure}`
  );
});

test('estimateExpenditure falls back to the formula below the minimum window', () => {
  const { dates, weights, intakeByDate } = simulate({
    days: 10,
    startKg: 85,
    tdee: 2600,
    intake: 2100,
  });
  const trend = trendSeries(weights, { days: dates });
  const result = estimateExpenditure({
    trend,
    intakeByDate,
    dayStatusByDate: new Map(dates.map((d) => [d, 'complete'])),
    formula: 2400,
    windowDays: 28,
  });

  assert.equal(result.expenditure, 2400);
  assert.equal(result.confidence, 'estimated');
  assert.match(result.reason, /14 days/);
});

test('estimateExpenditure refuses to guess when food logging is patchy', () => {
  const { dates, weights, intakeByDate } = simulate({
    days: 30,
    startKg: 85,
    tdee: 2600,
    intake: 2100,
  });
  // Wipe half the food logs.
  dates.forEach((d, i) => i % 2 === 0 && intakeByDate.delete(d));

  const trend = trendSeries(weights, { days: dates });
  const result = estimateExpenditure({
    trend,
    intakeByDate,
    dayStatusByDate: new Map(dates.map((d) => [d, 'complete'])),
    formula: 2400,
    windowDays: 28,
  });

  assert.equal(result.confidence, 'estimated');
  assert.match(result.reason, /Food logged on/);
});

test('estimateExpenditure clamps an absurd result to the formula range', () => {
  // A 22 kg "loss" in 28 days is a broken scale or a unit mix-up, not a diet.
  // Taken at face value it implies an expenditure over 6000. The clamp holds
  // it to 2x the formula so one bad batch of data can't wreck the targets.
  const dates = lastNDays(28, '2026-08-29');
  const weights = dates.map((date, i) => ({ entry_date: date, weight_kg: 90 - i * 0.8 }));
  const intakeByDate = new Map(dates.map((d) => [d, 2000]));

  const trend = trendSeries(weights, { days: dates });
  const result = estimateExpenditure({
    trend,
    intakeByDate,
    dayStatusByDate: new Map(dates.map((d) => [d, 'complete'])),
    formula: 2400,
    windowDays: 28,
  });

  assert.equal(result.expenditure, 4800, 'clamped to 2x formula');
  assert.ok(result.measured > 5000, 'raw measurement is preserved for display');
});

test('mifflinStJeor matches the published formula', () => {
  // 80kg, 180cm, 30y male: 10*80 + 6.25*180 - 5*30 + 5 = 1780
  assert.equal(mifflinStJeor({ sex: 'male', weightKg: 80, heightCm: 180, age: 30 }), 1780);
  // Same numbers, female offset: 1780 - 5 - 161 = 1614
  assert.equal(mifflinStJeor({ sex: 'female', weightKg: 80, heightCm: 180, age: 30 }), 1614);
  assert.equal(mifflinStJeor({ sex: 'male', weightKg: 0, heightCm: 180, age: 30 }), null);
});

test('formulaExpenditure applies the activity multiplier', () => {
  const profile = { gender: 'male', weight: 80, height: 180, age: 30, activityLevel: 'moderate' };
  assert.equal(formulaExpenditure(profile), Math.round(1780 * 1.55));
});

test('computeTargets puts a cut below expenditure and macros add up', () => {
  const t = computeTargets({
    expenditure: 2600,
    rateKgPerWeek: -0.5,
    weightKg: 85,
    sex: 'male',
  });

  assert.ok(t.calories < 2600, 'a cut eats below expenditure');
  assert.ok(t.calories >= 2600 * 0.75, 'but not below the 25% deficit cap');

  const fromMacros = t.protein_g * 4 + t.carbs_g * 4 + t.fat_g * 9;
  assert.ok(
    Math.abs(fromMacros - t.calories) <= 25,
    `macros sum to ${fromMacros}, target is ${t.calories}`
  );
});

test('computeTargets raises protein on a deficit', () => {
  const cut = computeTargets({ expenditure: 2600, rateKgPerWeek: -0.5, weightKg: 85 });
  const maintain = computeTargets({ expenditure: 2600, rateKgPerWeek: 0, weightKg: 85 });
  assert.ok(cut.protein_g > maintain.protein_g);
});

test('computeTargets respects the absolute calorie floor', () => {
  const t = computeTargets({
    expenditure: 1500,
    rateKgPerWeek: -1.5,
    weightKg: 55,
    sex: 'female',
  });
  assert.ok(t.calories >= 1200, `floor breached: ${t.calories}`);
});

test('computeTargets caps a bulk surplus at 700 kcal', () => {
  const t = computeTargets({ expenditure: 2600, rateKgPerWeek: 1.5, weightKg: 70 });
  assert.ok(t.calories <= 3300, `surplus too large: ${t.calories}`);
});

test('computeTargets keeps keto carbs low and macros consistent', () => {
  const t = computeTargets({
    expenditure: 2400,
    rateKgPerWeek: -0.25,
    weightKg: 80,
    dietType: 'keto',
  });
  assert.ok(t.carbs_g <= 50, `keto carbs too high: ${t.carbs_g}`);
  const fromMacros = t.protein_g * 4 + t.carbs_g * 4 + t.fat_g * 9;
  assert.ok(Math.abs(fromMacros - t.calories) <= 40);
});

test('computeTargets uses lean mass for protein when body fat is known', () => {
  const lean = computeTargets({
    expenditure: 2600,
    rateKgPerWeek: 0,
    weightKg: 120,
    bodyFatPct: 40,
  });
  const unknown = computeTargets({ expenditure: 2600, rateKgPerWeek: 0, weightKg: 120 });
  assert.ok(lean.protein_g < unknown.protein_g, 'fat mass should not drive protein');
});
