// Gathers the data the expenditure estimator needs and runs it.
//
// Kept separate from the route so the dashboard, the check-in, and the program
// endpoint all compute it exactly one way.

const store = require('../data');
const dates = require('./dates');
const nutrition = require('./nutrition');
const { normalizeProfile } = require('./users');

const DEFAULT_WINDOW_DAYS = 28;

/**
 * @param {object} user a stored user document
 * @param {object} options
 * @param {string} options.today the user's local calendar day
 * @param {number} options.windowDays how far back the estimate looks
 */
async function currentExpenditure(user, { today, windowDays = DEFAULT_WINDOW_DAYS } = {}) {
  const profile = normalizeProfile(user.profile);
  const endDate = today || dates.today(user.timezone || 'UTC');
  // Pull a longer span than the window so the EWMA is already warmed up by the
  // time the window starts. A trend seeded on day one of the window would
  // under-report the change.
  const seedDays = windowDays + 21;
  const startDate = dates.addDays(endDate, -(seedDays - 1));

  const [weights, intakeRows, dayStatuses] = await Promise.all([
    store.find(
      'weights',
      { email: user.email, entry_date: { gte: startDate, lte: endDate } },
      { sort: { entry_date: 1 } }
    ),
    store.sumBy(
      'food',
      { email: user.email, entry_date: { gte: startDate, lte: endDate } },
      'entry_date',
      ['calories']
    ),
    store.find('diary_days', { email: user.email, entry_date: { gte: startDate, lte: endDate } }),
  ]);

  const intakeByDate = new Map(intakeRows.map((r) => [r.key, r.calories]));
  const trend = nutrition.trendSeries(weights, {
    days: dates.rangeOfDays(startDate, endDate),
  });

  const formula = nutrition.formulaExpenditure({
    ...profile,
    age: user.age ?? profile.age,
    gender: user.gender ?? profile.gender,
    weight: latestWeightKg(weights) ?? user.weight ?? profile.weight,
    height: user.height ?? profile.height,
  });

  const estimate = nutrition.estimateExpenditure({
    trend,
    intakeByDate,
    dayStatusByDate: new Map(dayStatuses.map((day) => [day.entry_date, day.status])),
    formula,
    windowDays,
  });

  return {
    ...estimate,
    formula,
    trend,
    trendWeightKg: trend.length ? trend[trend.length - 1].trend : null,
    latestWeightKg: latestWeightKg(weights) ?? user.weight ?? profile.weight ?? null,
    from: startDate,
    to: endDate,
  };
}

function latestWeightKg(weights) {
  for (let i = weights.length - 1; i >= 0; i--) {
    if (Number.isFinite(weights[i].weight_kg)) return weights[i].weight_kg;
  }
  return null;
}

// The program row a user gets before they've configured anything. Written on
// first read so the rest of the app can assume a program exists.
function defaultProgram(email) {
  return {
    email,
    goal_type: 'maintain',
    rate_kg_per_week: 0,
    protein_strategy: 'moderate',
    diet_type: 'balanced',
    active: true,
    created_at: new Date(),
    updated_at: new Date(),
  };
}

async function getOrCreateProgram(email) {
  return store.transaction(async () => {
    const existing = await store.findOne('programs', { email });
    if (existing) return existing;
    const user = await store.findOne('users', { email });
    if (user?.onboardingCompleted) {
      const repaired = await require('./onboarding').repairIfPossible(user);
      if (repaired.complete && repaired.program) return repaired.program;
      throw require('./errors').conflict('Finish account setup before using your program');
    }
    return store.insert('programs', defaultProgram(email));
  });
}

/**
 * Recompute targets from the current expenditure estimate and persist them.
 * Called at check-in and whenever the program settings change.
 */
async function refreshTargets(user, program, { today, windowDays } = {}) {
  const expenditure = await currentExpenditure(user, { today, windowDays });
  const profile = normalizeProfile(user.profile);

  const weightKg =
    expenditure.trendWeightKg ?? expenditure.latestWeightKg ?? user.weight ?? profile.weight;

  if (program.target_mode === 'manual') {
    const goals = await store.findOne('goals', { email: user.email });
    return { expenditure, targets: require('./targets').snapshot(program, goals), weightKg };
  }

  const targets = nutrition.computeTargets({
    expenditure: expenditure.expenditure,
    rateKgPerWeek: program.rate_kg_per_week || 0,
    weightKg,
    bodyFatPct: profile.bodyFatPct ?? null,
    dietType: program.diet_type || 'balanced',
    proteinStrategy: program.protein_strategy || 'moderate',
    sex: profile.sex ?? user.gender ?? profile.gender ?? 'female',
  });

  return { expenditure, targets, weightKg };
}

module.exports = {
  DEFAULT_WINDOW_DAYS,
  currentExpenditure,
  getOrCreateProgram,
  refreshTargets,
  defaultProgram,
};
