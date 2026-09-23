const store = require('../data');
const dates = require('./dates');

function snapshot(program, goals) {
  return {
    calories: program?.calories ?? goals?.daily_calories ?? null,
    protein_g: program?.protein_g ?? goals?.protein_g ?? null,
    carbs_g: program?.carbs_g ?? goals?.carbs_g ?? null,
    fat_g: program?.fat_g ?? goals?.fat_g ?? null,
    fiber_g: goals?.fiber_g ?? null,
    water_ml: goals?.water_ml ?? null,
  };
}

async function forDate(user, date, { program, goals } = {}) {
  const rows = await store.find(
    'target_versions',
    {
      account_id: user.id,
      effective_date: { lte: date },
    },
    { sort: { effective_date: -1, created_at: -1, id: -1 }, limit: 1 }
  );
  if (rows.length) return { targets: rows[0].targets, version_id: rows[0].id, source: 'accepted' };
  // No historical target is safer than comparing an old entry with today's
  // plan. Older accounts retain their current targets during rollout.
  if (date >= dates.today(user.timezone || 'UTC')) {
    program ??= await store.findOne('programs', { email: user.email });
    goals ??= await store.findOne('goals', { email: user.email });
    return { targets: snapshot(program, goals), version_id: null, source: 'legacy_current' };
  }
  return { targets: snapshot(null, null), version_id: null, source: 'not_recorded' };
}

async function accept(user, targets, { date, reason, checkinID = null } = {}) {
  return store.transaction(async () => {
    const now = new Date();
    const goals = await store.upsert(
      'goals',
      { email: user.email },
      {
        daily_calories: targets.calories,
        protein_g: targets.protein_g,
        carbs_g: targets.carbs_g,
        fat_g: targets.fat_g,
        ...(targets.fiber_g != null ? { fiber_g: targets.fiber_g } : {}),
        ...(targets.water_ml != null ? { water_ml: targets.water_ml } : {}),
        updated_at: now,
      }
    );
    const program = await store.upsert(
      'programs',
      { email: user.email },
      {
        calories: targets.calories,
        protein_g: targets.protein_g,
        carbs_g: targets.carbs_g,
        fat_g: targets.fat_g,
        updated_at: now,
      }
    );
    return store.insert('target_versions', {
      account_id: user.id,
      email: user.email,
      effective_date: date || dates.today(user.timezone || 'UTC'),
      targets: snapshot(program, goals),
      reason,
      checkin_id: checkinID,
      created_at: now,
    });
  });
}

module.exports = { snapshot, forDate, accept };
