const express = require('express');

const store = require('../data');
const { asyncHandler } = require('../lib/errors');
const { authenticate } = require('../lib/auth');
const v = require('../lib/validate');
const { requireUser, timezoneFor, entryDateFor, normalizeProfile } = require('../lib/users');
const dates = require('../lib/dates');
const { formulaExpenditure } = require('../lib/nutrition');

const router = express.Router();
router.use(authenticate);

const MACROS = ['calories', 'protein', 'carbs', 'fat', 'fiber', 'sugar', 'sodium'];

function totalMacros(entries) {
  const out = Object.fromEntries(MACROS.map((m) => [m, 0]));
  for (const e of entries) {
    for (const m of MACROS) out[m] += Number(e[m]) || 0;
  }
  for (const m of MACROS) out[m] = Math.round(out[m] * 10) / 10;
  out.calories = Math.round(out.calories);
  return out;
}

/**
 * Everything the diary screen needs for one day, in one request: what was
 * eaten grouped by meal, what was burned, the targets, and what's left.
 */
router.get(
  '/api/summary',
  asyncHandler(async (req, res) => {
    const user = await requireUser(req.user.email);
    const date = entryDateFor(req, user, { allowFuture: true });

    const [food, activities, sleep, water, weight, goals, program, diaryDay] = await Promise.all([
      store.find('food', { email: user.email, entry_date: date }, { sort: { id: 1 } }),
      store.find('activities', { email: user.email, entry_date: date }, { sort: { id: 1 } }),
      store.find('sleep', { email: user.email, entry_date: date }, { sort: { id: -1 } }),
      store.findOne('water', { email: user.email, entry_date: date }),
      store.findOne('weights', { email: user.email, entry_date: date }),
      store.findOne('goals', { email: user.email }),
      store.findOne('programs', { email: user.email }),
      store.findOne('diary_days', { email: user.email, entry_date: date }),
    ]);

    const consumed = totalMacros(food);
    const burned = activities.reduce((sum, a) => sum + (Number(a.calories) || 0), 0);

    const targetVersion = await require('../lib/targets').forDate(user, date, { program, goals });
    const targets = targetVersion.targets;

    const remaining = {
      calories: targets.calories == null ? null : Math.round(targets.calories - consumed.calories),
      protein_g:
        targets.protein_g == null
          ? null
          : Math.round((targets.protein_g - consumed.protein) * 10) / 10,
      carbs_g:
        targets.carbs_g == null ? null : Math.round((targets.carbs_g - consumed.carbs) * 10) / 10,
      fat_g: targets.fat_g == null ? null : Math.round((targets.fat_g - consumed.fat) * 10) / 10,
    };

    const meals = {};
    for (const type of ['breakfast', 'lunch', 'dinner', 'snack', 'uncategorized']) {
      meals[type] = { entries: [], totals: totalMacros([]) };
    }
    for (const entry of food) {
      const key = entry.meal_type || 'uncategorized';
      (meals[key] || meals.uncategorized).entries.push(entry);
    }
    for (const key of Object.keys(meals)) {
      meals[key].totals = totalMacros(meals[key].entries);
    }

    res.json({
      date,
      timezone: timezoneFor(user, req),
      consumed,
      burned: Math.round(burned),
      targets,
      target_version_id: targetVersion.version_id,
      target_source: targetVersion.source,
      remaining,
      meals,
      activities,
      sleep: sleep[0] || null,
      sleep_entries: sleep,
      sleep_hours: sleep.reduce((sum, entry) => sum + entry.hours, 0),
      water_ml: water?.ml ?? 0,
      water: { entry_date: date, ml: water?.ml ?? 0, revision: water ? (water.revision ?? 1) : 0 },
      weight: weight || null,
      entry_count: food.length + activities.length + sleep.length,
      diary_day: diaryDay ?? { entry_date: date, status: 'in_progress', note: null, revision: 0 },
    });
  })
);

/**
 * Daily totals across a range, for charts and weekly averages. One aggregate
 * query per collection rather than one per day.
 */
router.get(
  '/api/summary/range',
  asyncHandler(async (req, res) => {
    const user = await requireUser(req.user.email);
    const tz = timezoneFor(user, req);
    const to = req.query.to ? v.dateStr(req.query.to, 'to') : dates.today(tz);
    const days = Math.min(365, Math.max(2, parseInt(req.query.days, 10) || 30));
    const from = req.query.from
      ? v.dateStr(req.query.from, 'from')
      : dates.addDays(to, -(days - 1));

    const range = { gte: from, lte: to };
    const [foodRows, actRows, weightRows] = await Promise.all([
      store.sumBy('food', { email: user.email, entry_date: range }, 'entry_date', [
        'calories',
        'protein',
        'carbs',
        'fat',
        'fiber',
      ]),
      store.sumBy('activities', { email: user.email, entry_date: range }, 'entry_date', [
        'calories',
        'duration_min',
      ]),
      store.find('weights', { email: user.email, entry_date: range }, { sort: { entry_date: 1 } }),
    ]);

    const foodBy = new Map(foodRows.map((r) => [r.key, r]));
    const actBy = new Map(actRows.map((r) => [r.key, r]));
    const weightBy = new Map(weightRows.map((r) => [r.entry_date, r.weight_kg]));

    const series = dates.rangeOfDays(from, to).map((date) => {
      const f = foodBy.get(date);
      const a = actBy.get(date);
      return {
        date,
        label: dates.weekdayLabel(date),
        consumed: Math.round(f?.calories || 0),
        protein: Math.round((f?.protein || 0) * 10) / 10,
        carbs: Math.round((f?.carbs || 0) * 10) / 10,
        fat: Math.round((f?.fat || 0) * 10) / 10,
        fiber: Math.round((f?.fiber || 0) * 10) / 10,
        entries: f?.n || 0,
        burned: Math.round(a?.calories || 0),
        active_minutes: Math.round(a?.duration_min || 0),
        weight_kg: weightBy.get(date) ?? null,
      };
    });

    // Averages skip unlogged days. Including them would drag every average
    // toward zero and make a missed day look like a fast.
    const logged = series.filter((d) => d.entries > 0);
    const mean = (field) =>
      logged.length
        ? Math.round((logged.reduce((s, d) => s + d[field], 0) / logged.length) * 10) / 10
        : 0;

    res.json({
      from,
      to,
      series,
      averages: {
        days_logged: logged.length,
        days_total: series.length,
        calories: Math.round(mean('consumed')),
        protein: mean('protein'),
        carbs: mean('carbs'),
        fat: mean('fat'),
        fiber: mean('fiber'),
        burned: Math.round(mean('burned')),
      },
    });
  })
);

// ---------- endpoints the existing clients already call ----------

router.get(
  '/api/dashboard/weekly',
  asyncHandler(async (req, res) => {
    const user = await requireUser(req.user.email);
    const tz = timezoneFor(user, req);
    const days = dates.lastNDays(7, dates.today(tz));
    const range = { gte: days[0], lte: days[days.length - 1] };

    const [foodRows, actRows] = await Promise.all([
      store.sumBy('food', { email: user.email, entry_date: range }, 'entry_date', ['calories']),
      store.sumBy('activities', { email: user.email, entry_date: range }, 'entry_date', [
        'calories',
      ]),
    ]);

    const foodBy = new Map(foodRows.map((r) => [r.key, r.calories]));
    const actBy = new Map(actRows.map((r) => [r.key, r.calories]));

    res.json(
      days.map((date) => ({
        date,
        label: dates.weekdayLabel(date),
        consumed: Math.round(foodBy.get(date) || 0),
        burned: Math.round(actBy.get(date) || 0),
      }))
    );
  })
);

router.get(
  '/api/recent',
  asyncHandler(async (req, res) => {
    const user = await requireUser(req.user.email);
    const date = entryDateFor(req, user);

    const [activities, food, sleep] = await Promise.all([
      store.find('activities', { email: user.email, entry_date: date }, { sort: { id: -1 } }),
      store.find('food', { email: user.email, entry_date: date }, { sort: { id: -1 } }),
      store.find('sleep', { email: user.email, entry_date: date }, { sort: { id: -1 } }),
    ]);

    const logs = [
      ...activities.map((r) => ({ ...r, type: 'activity', entry_time: r.created_at })),
      ...food.map((r) => ({ ...r, type: 'food', entry_time: r.logged_at || r.created_at })),
      ...sleep.map((r) => ({ ...r, type: 'sleep', entry_time: r.created_at })),
    ];
    logs.sort((a, b) => new Date(b.entry_time) - new Date(a.entry_time));
    res.json(logs);
  })
);

router.get(
  '/api/dashboard-data',
  asyncHandler(async (req, res) => {
    const user = await requireUser(req.user.email);
    const date = entryDateFor(req, user);

    const [activities, food, sleep, program] = await Promise.all([
      store.find('activities', { email: user.email, entry_date: date }),
      store.find('food', { email: user.email, entry_date: date }),
      store.find('sleep', { email: user.email, entry_date: date }),
      store.findOne('programs', { email: user.email }),
    ]);

    const burned = activities.reduce((s, r) => s + (Number(r.calories) || 0), 0);
    const consumed = food.reduce((s, r) => s + (Number(r.calories) || 0), 0);
    const sleepHours = sleep.reduce((s, r) => s + (Number(r.hours) || 0), 0);

    // Prefer the measured expenditure over the formula once one exists.
    const maintenance =
      program?.expenditure ??
      formulaExpenditure({
        ...normalizeProfile(user.profile),
        age: user.age,
        gender: user.gender,
        weight: user.weight,
        height: user.height,
      });

    const cards = [
      { label: 'Total Workouts', value: activities.length, route: '/dashboard/activities' },
      {
        label: 'Calories Burned',
        value: `${Math.round(burned)} kcal`,
        route: '/dashboard/activities',
      },
      {
        label: 'Calories Consumed',
        value: `${Math.round(consumed)} kcal`,
        route: '/dashboard/food',
      },
      { label: 'Sleep (hrs)', value: `${sleepHours}`, route: '/dashboard/sleep' },
    ];

    if (req.user?.is_admin) {
      cards.unshift({ label: 'Admin', value: 'Open', route: '/dashboard/admin' });
    }
    if (maintenance) {
      cards.push({
        label: 'Maintenance (est.)',
        value: `${maintenance} kcal`,
        route: '/dashboard/profile',
      });
      cards.push({
        label: 'Net vs. Maint.',
        value: `${Math.round(consumed - burned - maintenance)} kcal`,
        route: '/dashboard/food',
      });
    }

    res.json(cards);
  })
);

// Deletes a day's logs. Returns what it removed so a client can offer an undo
// rather than making this a one-way door.
router.post(
  '/api/reset-today',
  asyncHandler(async (req, res) => {
    const user = await requireUser(req.user.email);
    const date = entryDateFor(req, user);
    const { activities, food, sleep } = await require('../lib/deleteDayLogs')(user, date);

    res.json({
      message: `Logs deleted for ${date}`,
      date,
      removed: { activities, food, sleep },
      counts: { activities: activities.length, food: food.length, sleep: sleep.length },
    });
  })
);

// Everything the account holds, as one JSON document. Nobody should be locked
// into a tracker by the cost of leaving it.
router.get(
  '/api/export',
  asyncHandler(async (req, res) => {
    const user = await requireUser(req.user.email);
    const owned = { email: user.email };

    const [
      food,
      activities,
      sleep,
      weights,
      water,
      workouts,
      goals,
      program,
      checkins,
      library,
      recipes,
      measurements,
      diaryDays,
    ] = await Promise.all([
      store.find('food', owned, { sort: { entry_date: 1 } }),
      store.find('activities', owned, { sort: { entry_date: 1 } }),
      store.find('sleep', owned, { sort: { entry_date: 1 } }),
      store.find('weights', owned, { sort: { entry_date: 1 } }),
      store.find('water', owned, { sort: { entry_date: 1 } }),
      store.find('workouts', owned),
      store.findOne('goals', owned),
      store.findOne('programs', owned),
      store.find('checkins', owned, { sort: { entry_date: 1 } }),
      store.find('library_foods', owned),
      store.find('recipes', owned),
      store.find('measurements', { account_id: user.id }, { sort: { entry_date: 1 } }),
      store.find('diary_days', owned, { sort: { entry_date: 1 } }),
    ]);

    res.set(
      'Content-Disposition',
      `attachment; filename="exerly-export-${dates.today('UTC')}.json"`
    );
    res.json({
      exported_at: new Date().toISOString(),
      version: 2,
      // `hash` is deliberately absent: an export should never carry the
      // password digest.
      account: {
        email: user.email,
        name: user.name,
        created_at: user.created_at,
        timezone: user.timezone,
        unitSystem: user.unitSystem,
        preferences_revision: user.preferences_revision ?? 0,
        profile: normalizeProfile(user.profile),
      },
      food,
      activities,
      sleep,
      weights,
      water,
      workouts,
      goals,
      program,
      checkins,
      library_foods: library,
      recipes,
      measurements,
      diary_days: diaryDays,
    });
  })
);

module.exports = router;
