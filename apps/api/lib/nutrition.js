// Trend weight, adaptive expenditure, and macro targets.
//
// This is the part of the app that has to be right. Everything else is CRUD.
// The two ideas:
//
//   1. Scale weight swings 1-3 kg on water and gut content. Reacting to a single
//      reading is noise-chasing, so we smooth it into a trend first.
//   2. Once there's a trend, energy balance gives a *measured* expenditure:
//      whatever you ate, minus the energy that went into or came out of storage.
//      That number beats any BMR formula because it accounts for NEAT, activity,
//      adaptation, and how badly you estimate portions, all at once.

// Energy density of body mass change. 7700 kcal/kg is the conventional figure
// (3500 kcal/lb). It's an approximation: real tissue change is a mix of fat,
// lean mass, and glycogen. Good enough at the resolution we're working at.
const KCAL_PER_KG = 7700;

// EWMA smoothing constant. 0.1 gives roughly a 10-day half-life, which is the
// range Hacker's Diet and MacroFactor both land in. Higher reacts faster and
// is noisier; lower is smoother and lags real change.
const DEFAULT_ALPHA = 0.1;

// Expenditure needs this many days of overlapping weight and intake data before
// the measured component is trusted at all.
const MIN_WINDOW_DAYS = 14;
// Days at which the measured value fully replaces the formula estimate.
const FULL_TRUST_DAYS = 28;
// Fraction of days in the window that need food logged for the mean to mean anything.
const MIN_LOG_COVERAGE = 0.8;

// ---------- BMR / formula estimate ----------

// Mifflin-St Jeor. Used as the day-one estimate and as the anchor the measured
// value is clamped against, never as the final answer once data exists.
function mifflinStJeor({ sex, weightKg, heightCm, age }) {
  const w = Number(weightKg);
  const h = Number(heightCm);
  const a = Number(age);
  if (!w || !h || !a) return null;
  const offset = String(sex).toLowerCase() === 'male' ? 5 : -161;
  return Math.round(10 * w + 6.25 * h - 5 * a + offset);
}

const ACTIVITY_MULTIPLIERS = {
  sedentary: 1.2,
  light: 1.375,
  lightly_active: 1.375,
  moderate: 1.55,
  moderately_active: 1.55,
  active: 1.725,
  very_active: 1.9,
  'very active': 1.9,
  extra_active: 2.0,
};

function activityMultiplier(level) {
  return ACTIVITY_MULTIPLIERS[String(level || '').toLowerCase()] || 1.2;
}

// Formula TDEE: BMR times a self-reported activity multiplier. Everyone
// overestimates their activity level, which is exactly why this gets replaced.
function formulaExpenditure(profile) {
  if (
    !(profile.age >= 18 && profile.age <= 120) ||
    !['male', 'female'].includes(String(profile.sex ?? profile.gender).toLowerCase())
  )
    return null;
  const bmr = mifflinStJeor({
    sex: profile.sex ?? profile.gender,
    weightKg: profile.weightKg ?? profile.weight_kg ?? profile.weight,
    heightCm: profile.heightCm ?? profile.height_cm ?? profile.height,
    age: profile.age,
  });
  if (!bmr) return null;
  return Math.round(bmr * activityMultiplier(profile.activityLevel ?? profile.activity_level));
}

// ---------- trend weight ----------

/**
 * Exponentially weighted moving average over a daily series.
 *
 * Days with no scale reading carry the previous trend forward rather than
 * interpolating, so a week away from the scale doesn't invent measurements it
 * then treats as real.
 *
 * @param {Array<{entry_date: string, weight_kg: number}>} entries any order
 * @param {{alpha?: number, days?: string[]}} options `days` fills gaps across an
 *        explicit calendar range; omit it to emit only days that have a reading.
 * @returns {Array<{date: string, weight: number|null, trend: number}>} oldest first
 */
function trendSeries(entries, { alpha = DEFAULT_ALPHA, days = null } = {}) {
  const byDate = new Map();
  for (const e of entries) {
    const kg = Number(e.weight_kg);
    if (!Number.isFinite(kg) || kg <= 0) continue;
    // Last write wins if a day somehow has two readings.
    byDate.set(e.entry_date, kg);
  }

  const dates = days || [...byDate.keys()].sort();
  if (dates.length === 0) return [];

  const out = [];
  let trend = null;

  for (const date of dates) {
    const weight = byDate.has(date) ? byDate.get(date) : null;
    if (trend === null) {
      // Seed on the first actual reading. Leading empty days are dropped rather
      // than reported as a trend of zero.
      if (weight === null) continue;
      trend = weight;
    } else if (weight !== null) {
      trend = trend + alpha * (weight - trend);
    }
    out.push({ date, weight, trend: round(trend, 2) });
  }

  return out;
}

// ---------- adaptive expenditure ----------

/**
 * Estimate daily energy expenditure from logged intake and trend weight movement.
 *
 * expenditure = mean_intake - (trend_change_kg * 7700 / days)
 *
 * Losing weight means stored energy came out, so expenditure was higher than
 * intake by exactly that amount. That's the whole idea.
 *
 * @param {object} args
 * @param {Array<{date, trend}>} args.trend output of trendSeries, oldest first
 * @param {Map<string, number>|object} args.intakeByDate calories per day
 * @param {number|null} args.formula formula TDEE, used as the prior and the clamp anchor
 * @param {number} args.windowDays how far back to look
 */
function estimateExpenditure({
  trend,
  intakeByDate,
  dayStatusByDate,
  formula = null,
  windowDays = 28,
}) {
  const intake =
    intakeByDate instanceof Map ? intakeByDate : new Map(Object.entries(intakeByDate || {}));
  const statuses =
    dayStatusByDate instanceof Map
      ? dayStatusByDate
      : new Map(Object.entries(dayStatusByDate || {}));

  const window = trend.slice(-windowDays);
  const measurements = window.filter((d) => Number.isFinite(d.weight) && d.weight > 0);
  const lastMeasurement = measurements.at(-1)?.date ?? null;
  const recency = lastMeasurement
    ? Math.round((Date.parse(window.at(-1).date) - Date.parse(lastMeasurement)) / 86400000)
    : null;
  const evidence = {
    measurementCount: measurements.length,
    lastMeasurementDate: lastMeasurement,
    measurementAgeDays: recency,
  };
  const insufficient = (reason) => ({
    ...evidence,
    expenditure: formula,
    confidence: 'estimated',
    reason,
    measured: null,
    meanIntake: null,
    trendChangeKg: null,
    daysLogged: 0,
    windowDays: window.length,
  });

  if (window.length < MIN_WINDOW_DAYS) {
    return insufficient(`Needs ${MIN_WINDOW_DAYS} days of history, has ${window.length}`);
  }

  if (
    measurements.length < 4 ||
    recency > 7 ||
    !window.slice(0, 7).some((d) => Number.isFinite(d.weight))
  ) {
    return insufficient(
      'Needs at least four actual weigh-ins, a measurement in the first week, and one in the last seven days'
    );
  }
  const logged = window
    .filter((d) => statuses.get(d.date) === 'complete')
    .map((d) => intake.get(d.date))
    .filter((v) => Number.isFinite(v) && v > 0);
  const coverage = logged.length / window.length;
  if (coverage < MIN_LOG_COVERAGE) {
    return insufficient(
      `Food logged on ${logged.length} complete days of ${window.length}; needs ${Math.ceil(MIN_LOG_COVERAGE * window.length)}`
    );
  }

  const meanIntake = logged.reduce((a, b) => a + b, 0) / logged.length;
  const trendChangeKg = window[window.length - 1].trend - window[0].trend;
  // Change over N samples spans N-1 day-to-day intervals.
  const spanDays = window.length - 1;
  const measured = meanIntake - (trendChangeKg * KCAL_PER_KG) / spanDays;

  // Blend toward the measured value as the window grows. At the 14-day minimum
  // it only gets 35% of the say, which stops week three from swinging wildly.
  let value = measured;
  if (formula) {
    const growth = (window.length - MIN_WINDOW_DAYS) / (FULL_TRUST_DAYS - MIN_WINDOW_DAYS);
    const weight = clamp(0.35 + 0.65 * growth, 0.35, 1);
    value = weight * measured + (1 - weight) * formula;
    // A week of bad logging can produce nonsense. Refuse to believe an
    // expenditure less than half or more than double the formula.
    value = clamp(value, formula * 0.5, formula * 2);
  }

  return {
    ...evidence,
    expenditure: Math.round(value),
    confidence: confidenceFor(window.length, coverage, measurements.length, recency),
    reason: null,
    measured: Math.round(measured),
    meanIntake: Math.round(meanIntake),
    trendChangeKg: round(trendChangeKg, 3),
    daysLogged: logged.length,
    windowDays: window.length,
  };
}

// Tiers are keyed to the default 28-day window. An earlier cut required 35 days
// for "high", which the default window could never reach, so every estimate
// capped out at "medium" no matter how long someone had been logging.
function confidenceFor(days, coverage, measurements, recency) {
  if (days >= FULL_TRUST_DAYS && coverage >= 0.9 && measurements >= 14 && recency <= 3)
    return 'high';
  if (days >= 21 && measurements >= 8 && recency <= 5) return 'medium';
  return 'low';
}

// ---------- macro targets ----------

const DIET_TYPES = ['balanced', 'low_carb', 'low_fat', 'keto', 'high_protein'];
const PROTEIN_STRATEGIES = { low: 1.4, moderate: 1.8, high: 2.2 };

/**
 * Turn an expenditure and a goal rate into daily calorie and macro targets.
 *
 * @param {object} args
 * @param {number} args.expenditure kcal/day
 * @param {number} args.rateKgPerWeek negative to lose, positive to gain
 * @param {number} args.weightKg current trend weight
 * @param {number|null} args.bodyFatPct used for lean-mass protein when known
 * @param {string} args.dietType one of DIET_TYPES
 * @param {string} args.proteinStrategy low | moderate | high
 * @param {string} args.sex used only for the absolute calorie floor
 */
function computeTargets({
  expenditure,
  rateKgPerWeek = 0,
  weightKg,
  bodyFatPct = null,
  dietType = 'balanced',
  proteinStrategy = 'moderate',
  sex = 'female',
}) {
  if (!expenditure || !weightKg) return null;

  const rate = Number(rateKgPerWeek) || 0;
  let calories = expenditure + (rate * KCAL_PER_KG) / 7;

  // Two floors, whichever is higher. The percentage floor keeps aggressive
  // rates from producing a starvation target for a large person; the absolute
  // floor does the same for a small one.
  const absoluteFloor = String(sex).toLowerCase() === 'male' ? 1500 : 1200;
  calories = Math.max(calories, expenditure * 0.75, absoluteFloor);
  // Cap the surplus too. Gaining faster than ~700 kcal/day over maintenance is
  // mostly fat, whatever the training looks like.
  calories = Math.min(calories, expenditure + 700);
  calories = Math.round(calories / 10) * 10;

  // Protein scales off lean mass when body fat is known, because a 120 kg
  // person at 40% fat doesn't need protein for the fat.
  const leanKg = bodyFatPct ? weightKg * (1 - bodyFatPct / 100) : null;
  const proteinBase = leanKg ? leanKg * 1.15 : weightKg;
  let gPerKg = PROTEIN_STRATEGIES[proteinStrategy] || PROTEIN_STRATEGIES.moderate;
  // A deficit is when protein matters most, for holding onto muscle.
  if (rate < 0) gPerKg += 0.2;
  let proteinG = Math.round(proteinBase * gPerKg);

  // Protein above 40% of calories is unnecessary and crowds out everything else.
  proteinG = Math.min(proteinG, Math.round((calories * 0.4) / 4));

  let fatG;
  let carbsG;

  switch (dietType) {
    case 'keto':
      carbsG = 30;
      fatG = Math.round((calories - proteinG * 4 - carbsG * 4) / 9);
      break;
    case 'low_carb':
      carbsG = Math.round((calories * 0.15) / 4);
      fatG = Math.round((calories - proteinG * 4 - carbsG * 4) / 9);
      break;
    case 'low_fat':
      fatG = Math.max(Math.round((calories * 0.2) / 9), Math.round(weightKg * 0.5));
      carbsG = Math.round((calories - proteinG * 4 - fatG * 9) / 4);
      break;
    case 'high_protein':
      proteinG = Math.min(Math.round(proteinBase * 2.4), Math.round((calories * 0.4) / 4));
      fatG = Math.round((calories * 0.25) / 9);
      carbsG = Math.round((calories - proteinG * 4 - fatG * 9) / 4);
      break;
    default:
      // Essential fatty acids need roughly 0.5 g/kg as a hard floor, whatever
      // the percentage split says.
      fatG = Math.max(Math.round((calories * 0.275) / 9), Math.round(weightKg * 0.5));
      carbsG = Math.round((calories - proteinG * 4 - fatG * 9) / 4);
  }

  // If the split went negative, the calorie target is too low for this macro
  // combination. Give carbs a small floor and pull it back out of fat.
  if (carbsG < 20) {
    carbsG = Math.max(carbsG, dietType === 'keto' ? 20 : 50);
    fatG = Math.round((calories - proteinG * 4 - carbsG * 4) / 9);
  }
  if (fatG < Math.round(weightKg * 0.4)) {
    fatG = Math.round(weightKg * 0.4);
    carbsG = Math.round((calories - proteinG * 4 - fatG * 9) / 4);
  }

  return {
    calories,
    protein_g: proteinG,
    carbs_g: Math.max(0, carbsG),
    fat_g: Math.max(0, fatG),
    // Fibre isn't a macro target so much as a health floor: 14 g per 1000 kcal
    // is the Institute of Medicine's recommendation.
    fiber_g: Math.round((calories / 1000) * 14),
  };
}

// ---------- helpers ----------

function clamp(v, lo, hi) {
  return Math.min(hi, Math.max(lo, v));
}

function round(v, places) {
  const f = 10 ** places;
  return Math.round(v * f) / f;
}

module.exports = {
  KCAL_PER_KG,
  DEFAULT_ALPHA,
  MIN_WINDOW_DAYS,
  DIET_TYPES,
  PROTEIN_STRATEGIES,
  ACTIVITY_MULTIPLIERS,
  mifflinStJeor,
  activityMultiplier,
  formulaExpenditure,
  trendSeries,
  estimateExpenditure,
  computeTargets,
  clamp,
};
