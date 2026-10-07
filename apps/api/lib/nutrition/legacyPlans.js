// Accounts set up before nutrition plans existed keep their targets in the
// legacy tables: target_versions (accepted versions, by effective date), then
// programs and goals. The new diary reads nutrition_plan documents, so those
// accounts would see no targets. The first time the app asks, each target
// version becomes a manual nutrition_plan with exactly the same numbers. Manual
// plans are never recomputed or proposed, so nothing changes until the person
// changes it.
//
// Idempotent: nothing happens once the account has any nutrition_plan, even a
// deleted one, and the plan IDs are derived from the account and version, so
// two devices asking at once write the same documents.

const { createHash } = require('node:crypto');
const store = require('../../data');
const docs = require('../documents');
const dates = require('../dates');
const { snapshot } = require('../targets');

const NAMESPACE = '8F3B1C2E-6A4D-4E7B-9C21-5D0A7E6F4B13';
const DIETS = { balanced: 'balanced', low_carb: 'lowCarb', low_fat: 'lowFat', keto: 'keto' };
const MAXIMUM_RATE = { lose: 0.01, gain: 0.005 };
const DEFAULT_RATE = { lose: 0.005, gain: 0.0025 };

/** A name-based (version 5) UUID, uppercase as ExerlyCore writes it. */
function uuid5(name, namespace = NAMESPACE) {
  const space = Buffer.from(namespace.replace(/-/g, ''), 'hex');
  const hash = createHash('sha1').update(space).update(name).digest();
  hash[6] = (hash[6] & 0x0f) | 0x50;
  hash[8] = (hash[8] & 0x3f) | 0x80;
  const hex = hash.subarray(0, 16).toString('hex').toUpperCase();
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

const usable = (t) =>
  Number(t?.calories) > 0 && [t.protein_g, t.fat_g, t.carbs_g].every((v) => Number(v) >= 0);

/** The goal as ExerlyCore's NutritionGoal: direction, weekly rate as a share of bodyweight, goal weight. */
function goalFrom(program, user) {
  const direction = ['lose', 'maintain', 'gain'].includes(program?.goal_type)
    ? program.goal_type
    : 'maintain';
  const goal = { direction, weeklyRate: 0 };
  if (direction !== 'maintain') {
    const weight = Number(user.profile?.weight_kg ?? user.profile?.weight);
    const share = Math.abs(Number(program?.rate_kg_per_week)) / weight;
    goal.weeklyRate =
      share > 0 && share <= MAXIMUM_RATE[direction]
        ? Math.round(share * 10000) / 10000
        : DEFAULT_RATE[direction];
  }
  if (Number(program?.target_weight_kg) > 0) {
    goal.goalWeight = { value: Number(program.target_weight_kg), unit: 'kg' };
  }
  return goal;
}

function planFrom(user, program, { key, startDate, targets, createdAt }) {
  const day = {
    energy: Number(targets.calories),
    protein: Number(targets.protein_g),
    fat: Number(targets.fat_g),
    carbohydrate: Number(targets.carbs_g),
  };
  const plan = {
    id: uuid5(`${user.id}/legacy-targets/${key}`),
    startDate,
    createdAt: new Date(createdAt).toISOString(),
    goal: goalFrom(program, user),
    mode: 'manual',
    diet: DIETS[program?.diet_type] ?? 'balanced',
    protein:
      program?.diet_type === 'high_protein'
        ? 'high'
        : ['low', 'moderate', 'high'].includes(program?.protein_strategy)
          ? program.protein_strategy
          : 'moderate',
    weekdayWeights: [1, 1, 1, 1, 1, 1, 1],
    checkInDay: 2,
    allowBelowFloor: false,
    targets: Array.from({ length: 7 }, () => ({ ...day })),
  };
  if (Number(targets.fiber_g) > 0)
    plan.nutrientGoals = { fiber: { target: Number(targets.fiber_g) } };
  return plan;
}

/**
 * Turns the account's legacy targets into nutrition_plan documents, unless it
 * already has one. Returns the plans written, and why when there are none.
 */
async function adoptLegacyTargets(user, { now = new Date() } = {}) {
  return store.transaction(async () => {
    const existing = await store.find('documents', { account_id: user.id, kind: 'nutrition_plan' });
    if (existing.length) return { plans: [], reason: 'has_plan' };
    const program = await store.findOne('programs', { email: user.email });
    const goals = await store.findOne('goals', { email: user.email });
    const versions = await store.find(
      'target_versions',
      { account_id: user.id },
      { sort: { effective_date: 1, created_at: 1, id: 1 } }
    );
    const timezone = user.timezone || 'UTC';
    const sources = versions.length
      ? versions.map((v) => ({
          key: v.id,
          startDate: v.effective_date,
          targets: v.targets,
          createdAt: v.created_at ?? now,
        }))
      : [
          {
            key: 'current',
            startDate: dates.today(timezone, new Date(user.created_at ?? now)),
            targets: snapshot(program, goals),
            createdAt: user.created_at ?? now,
          },
        ];
    const plans = sources.filter((s) => usable(s.targets)).map((s) => planFrom(user, program, s));
    if (!plans.length) return { plans: [], reason: 'no_targets' };
    for (const plan of plans) {
      const row = await store.insert('documents', {
        account_id: user.id,
        kind: 'nutrition_plan',
        document_id: plan.id,
        revision: 1,
        payload: plan,
        deleted_at: null,
        created_at: now,
        updated_at: now,
      });
      await docs.record(user, row);
    }
    await docs.appendAudit(user, {
      action: 'directWrite',
      actor: { kind: 'builtIn', name: 'Exerly' },
      targets: plans.map((p) => ({ kind: 'nutrition_plan', id: p.id })),
      note: 'Your saved targets, kept as manual nutrition plans.',
    });
    return { plans, reason: 'adopted' };
  });
}

const planOrder = (a, b) =>
  a.startDate !== b.startDate
    ? a.startDate.localeCompare(b.startDate)
    : a.createdAt !== b.createdAt
      ? a.createdAt.localeCompare(b.createdAt)
      : a.id.localeCompare(b.id);

/**
 * After a legacy screen accepts new targets (`version`, a target_versions
 * row): when the plan in force on its date is one this bridge made, add a plan
 * version with the new numbers, so the diary follows. A plan the person made
 * in the app is never overridden, and an account that hasn't adopted yet is
 * left for adoption, which reads every version.
 */
async function followLegacyVersion(user, version, { now = new Date() } = {}) {
  const rows = await store.find('documents', { account_id: user.id, kind: 'nutrition_plan' });
  const live = rows.filter((row) => !row.deleted_at && row.payload).map((row) => row.payload);
  const inForce = live
    .filter((plan) => plan.startDate <= version.effective_date)
    .sort(planOrder)
    .at(-1);
  if (!inForce || !usable(version.targets)) return null;
  const versions = await store.find('target_versions', { account_id: user.id });
  const bridged = new Set(
    [...versions.map((v) => v.id), 'current'].map((key) =>
      uuid5(`${user.id}/legacy-targets/${key}`)
    )
  );
  if (!bridged.has(inForce.id)) return null;
  const program = await store.findOne('programs', { email: user.email });
  const plan = planFrom(user, program, {
    key: version.id,
    startDate: version.effective_date,
    targets: version.targets,
    createdAt: version.created_at ?? now,
  });
  if (rows.some((row) => row.document_id === plan.id)) return null;
  const row = await store.insert('documents', {
    account_id: user.id,
    kind: 'nutrition_plan',
    document_id: plan.id,
    revision: 1,
    payload: plan,
    deleted_at: null,
    created_at: now,
    updated_at: now,
  });
  await docs.record(user, row);
  await docs.appendAudit(user, {
    action: 'directWrite',
    actor: { kind: 'builtIn', name: 'Exerly' },
    targets: [{ kind: 'nutrition_plan', id: plan.id }],
    note: 'Targets changed on the Program screen, kept as a new manual plan version.',
  });
  return plan;
}

module.exports = { adoptLegacyTargets, followLegacyVersion, planFrom, uuid5 };
