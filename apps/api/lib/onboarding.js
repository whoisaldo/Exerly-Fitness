const store = require('../data');
const v = require('./validate');
const { badRequest, conflict } = require('./errors');
const { requireUser, serializeUser, normalizeProfile } = require('./users');
const dates = require('./dates');
const nutrition = require('./nutrition');

const VERSION = 1;
const GOALS = {
  lose: 'lose',
  lose_weight: 'lose',
  weight_loss: 'lose',
  maintain: 'maintain',
  general_health: 'maintain',
  improve_endurance: 'maintain',
  gain: 'gain',
  gain_muscle: 'gain',
  muscle_gain: 'gain',
};

function stringList(value, field, max = 32) {
  if (value == null) return [];
  if (!Array.isArray(value) || value.length > max)
    throw badRequest(`${field} must be a list of at most ${max} values`);
  return [...new Set(value.map((item) => v.str(item, field, { max: 80 })))];
}

function validateAnswers(body, user = {}) {
  const age = v.int(body.age, 'age', { min: 18, max: 120 });
  const gender = v.str(body.gender, 'gender', { max: 32 });
  const height = v.num(body.height, 'height', { min: 50, max: 280 });
  const weight = v.num(body.weight, 'weight', { min: 20, max: 500 });
  const intention = v.str(body.goal, 'goal', { max: 64 }).toLowerCase();
  if (!GOALS[intention]) throw badRequest('Choose a supported fitness goal');
  const goal = v.oneOf(body.nutritionGoal ?? GOALS[intention], 'nutritionGoal', [
    'lose',
    'maintain',
    'gain',
  ]);
  const mode = v.oneOf(body.targetMode ?? 'estimated', 'targetMode', ['estimated', 'manual']);
  const sex = v.oneOf(
    body.sex ?? (['male', 'female'].includes(gender) ? gender : null),
    'sex',
    ['male', 'female'],
    { required: mode !== 'manual' }
  );
  const activityLevel = v.oneOf(
    body.activityLevel ?? body.activity_level,
    'activityLevel',
    Object.keys(nutrition.ACTIVITY_MULTIPLIERS)
  );
  const timezone = body.timezone ?? user.timezone ?? 'UTC';
  if (!dates.isValidTimeZone(timezone)) throw badRequest('Choose a valid timezone');
  const unitSystem = v.oneOf(body.unitSystem ?? user.unitSystem ?? 'metric', 'unitSystem', [
    'metric',
    'imperial',
  ]);
  const targetWeight = v.num(body.targetWeight, 'targetWeight', {
    required: false,
    min: 20,
    max: 500,
  });
  if (
    targetWeight != null &&
    ((goal === 'lose' && targetWeight > weight) || (goal === 'gain' && targetWeight < weight))
  ) {
    throw badRequest('Target weight must agree with the nutrition goal');
  }
  const rawRate = v.num(
    body.rateKgPerWeek ?? (goal === 'lose' ? -0.25 : goal === 'gain' ? 0.15 : 0),
    'rateKgPerWeek',
    { min: -1.5, max: 1.5 }
  );
  const rate = goal === 'lose' ? -Math.abs(rawRate) : goal === 'gain' ? Math.abs(rawRate) : 0;
  const dietaryStyle = v.str(body.dietaryStyle ?? 'standard', 'dietaryStyle', { max: 64 });
  const dietType = v.oneOf(
    body.dietType ?? (dietaryStyle === 'keto' ? 'keto' : 'balanced'),
    'dietType',
    nutrition.DIET_TYPES
  );
  const reminders = {};
  for (const key of ['meals', 'workouts', 'sleep']) {
    reminders[key] = v.bool(body.reminders?.[key], `reminders.${key}`) ?? false;
  }
  const workoutDays = stringList(body.workoutDays, 'workoutDays', 7);
  for (const day of workoutDays)
    v.oneOf(day, 'workoutDays', [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ]);
  const time = (value, field) => {
    if (value == null) return null;
    if (typeof value !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d$/.test(value))
      throw badRequest(`${field} must use HH:mm`);
    return value;
  };
  const profile = {
    ...normalizeProfile(user.profile),
    age,
    gender,
    sex,
    height,
    height_cm: height,
    weight,
    weight_kg: weight,
    goal: intention,
    nutritionGoal: goal,
    targetMode: mode,
    activityLevel,
    activity_level: activityLevel,
    targetWeight,
    target_weight: targetWeight,
    dietaryStyle,
    dietType,
    allergies: stringList(body.allergies, 'allergies'),
    mealsPerDay: v.int(body.mealsPerDay ?? 3, 'mealsPerDay', { min: 1, max: 10 }),
    activityTypes: stringList(body.activityTypes, 'activityTypes'),
    equipment: stringList(body.equipment, 'equipment'),
    workoutDays,
    reminders,
    sleepGoalHours: v.num(body.sleepGoalHours ?? 8, 'sleepGoalHours', { min: 1, max: 16 }),
    bedtime: time(body.bedtime, 'bedtime'),
    wakeTime: time(body.wakeTime, 'wakeTime'),
    timelineWeeks: v.int(body.timelineWeeks, 'timelineWeeks', {
      required: false,
      min: 1,
      max: 520,
    }),
  };
  const maintenance = sex ? nutrition.formulaExpenditure(profile) : null;
  const targets =
    mode === 'manual'
      ? {
          calories: v.num(body.manualTargets?.calories, 'manualTargets.calories', {
            min: 800,
            max: 10000,
          }),
          protein_g: v.num(body.manualTargets?.protein_g, 'manualTargets.protein_g', {
            min: 0,
            max: 500,
          }),
          carbs_g: v.num(body.manualTargets?.carbs_g, 'manualTargets.carbs_g', {
            min: 0,
            max: 1500,
          }),
          fat_g: v.num(body.manualTargets?.fat_g, 'manualTargets.fat_g', { min: 0, max: 500 }),
          fiber_g: v.num(body.manualTargets?.fiber_g ?? 30, 'manualTargets.fiber_g', {
            min: 0,
            max: 100,
          }),
        }
      : nutrition.computeTargets({
          expenditure: maintenance,
          rateKgPerWeek: rate,
          weightKg: weight,
          sex,
          dietType,
        });
  return {
    updates: {
      name: v.str(body.name ?? user.name, 'name', { max: 80 }),
      age,
      gender,
      height,
      weight,
      goal: intention,
      timezone,
      unitSystem,
      profile,
      experienceLevel: v.oneOf(body.experienceLevel ?? 'beginner', 'experienceLevel', [
        'beginner',
        'intermediate',
        'advanced',
      ]),
      workoutDaysPerWeek: v.int(body.workoutDaysPerWeek ?? 3, 'workoutDaysPerWeek', {
        min: 0,
        max: 7,
      }),
      equipmentAccess: v.str(body.equipmentAccess ?? 'bodyweight', 'equipmentAccess', { max: 64 }),
    },
    program: {
      goal_type: goal,
      rate_kg_per_week: rate,
      target_weight_kg: targetWeight,
      diet_type: dietType,
      protein_strategy: 'moderate',
      target_mode: mode,
    },
    targets,
    maintenance,
  };
}

async function status(user) {
  const program = await store.findOne('programs', { email: user.email });
  const goals = await store.findOne('goals', { email: user.email });
  const complete =
    !!user.onboardingCompleted &&
    Number(program?.calories) > 0 &&
    Number(goals?.daily_calories) > 0;
  return {
    complete,
    needs_repair: !!user.onboardingCompleted && !complete,
    version: user.onboarding_version ?? 0,
    user: serializeUser(user),
    program,
    targets: program?.calories
      ? {
          calories: program.calories,
          protein_g: program.protein_g,
          carbs_g: program.carbs_g,
          fat_g: program.fat_g,
          fiber_g: goals?.fiber_g,
        }
      : null,
  };
}

async function complete(email, body) {
  return store.transaction(async () => {
    const user = await requireUser(email);
    const existing = await status(user);
    if (existing.complete) return { ...existing, message: 'Setup already complete' };
    if (body.draftRevision != null) {
      const draft = await store.findOne('onboarding_drafts', { account_id: user.id });
      if ((draft?.revision ?? 0) !== body.draftRevision)
        throw conflict(
          'Setup changed on another device. Review the saved answers before finishing.'
        );
    }
    const { updates, program, targets, maintenance } = validateAnswers(body, user);
    const now = new Date();
    const today = dates.today(updates.timezone);
    const filter = { email: user.email };
    await store.update(
      'users',
      { id: user.id },
      {
        ...updates,
        preferences_revision: (user.preferences_revision ?? 0) + 1,
        preferences_updated_at: now,
      }
    );
    if (
      !existing.needs_repair &&
      !(await store.findOne('weights', { ...filter, entry_date: today }))
    ) {
      const initialWeight = await store.insert('weights', {
        ...filter,
        entry_date: today,
        weight_kg: updates.weight,
        account_id: user.id,
        revision: 1,
        source: 'onboarding',
        created_at: now,
      });
      await require('./sync').change(user, 'weight', { ...initialWeight, client_id: today });
    }
    // A legacy configured program is a deliberate user choice. Fill missing
    // targets while retaining that choice during a repair.
    const current = existing.program;
    const selected = current?.calories > 0 ? current : { ...program, ...targets };
    await store.upsert('programs', filter, {
      ...selected,
      expenditure: current?.expenditure ?? maintenance,
      expenditure_confidence: current?.expenditure_confidence ?? 'estimated',
      active: true,
      created_at: current?.created_at ?? now,
      updated_at: now,
    });
    await store.upsert('goals', filter, {
      daily_calories: selected.calories,
      protein_g: selected.protein_g,
      carbs_g: selected.carbs_g,
      fat_g: selected.fat_g,
      fiber_g: targets.fiber_g,
      weekly_workouts: updates.workoutDaysPerWeek,
      sleep_hours: updates.profile.sleepGoalHours,
      updated_at: now,
    });
    await store.insert('target_versions', {
      ...filter,
      account_id: user.id,
      effective_date: today,
      targets: {
        ...targets,
        calories: selected.calories,
        protein_g: selected.protein_g,
        carbs_g: selected.carbs_g,
        fat_g: selected.fat_g,
      },
      reason: existing.needs_repair ? 'setup_repair' : 'setup',
      created_at: now,
    });
    await store.update(
      'users',
      { id: user.id },
      {
        onboardingCompleted: true,
        onboarding_version: VERSION,
        onboarding_completed_at: user.onboarding_completed_at ?? now,
      }
    );
    await store.remove('onboarding_drafts', { account_id: user.id });
    return { ...(await status(await requireUser(email))), maintenance, message: 'Setup complete' };
  });
}

async function repairIfPossible(user) {
  return store.transaction(async () => {
    const current = await requireUser(user.email);
    const state = await status(current);
    if (!state.needs_repair) return state;
    const profile = normalizeProfile(current.profile);
    const program = state.program;
    const goals = await store.findOne('goals', { email: current.email });
    if (program?.calories > 0) {
      await require('./targets').accept(current, require('./targets').snapshot(program, goals), {
        reason: 'legacy_program_repair',
      });
      await store.update('users', { id: current.id }, { onboarding_version: VERSION });
      return status(await requireUser(current.email));
    }
    const intention = current.goal ?? profile.goal;
    const goalType = program?.goal_type ?? GOALS[intention];
    const manual = goals?.daily_calories > 0;
    const body = {
      ...profile,
      name: current.name,
      age: current.age ?? profile.age,
      gender: current.gender ?? profile.gender,
      sex: profile.sex ?? current.gender ?? profile.gender,
      height: current.height ?? profile.height ?? profile.height_cm,
      weight: current.weight ?? profile.weight ?? profile.weight_kg,
      goal: intention,
      nutritionGoal: goalType,
      activityLevel: profile.activityLevel ?? profile.activity_level,
      targetMode: manual ? 'manual' : (profile.targetMode ?? 'estimated'),
      manualTargets: manual
        ? {
            calories: goals.daily_calories,
            protein_g: goals.protein_g,
            carbs_g: goals.carbs_g,
            fat_g: goals.fat_g,
            fiber_g: goals.fiber_g,
          }
        : undefined,
      rateKgPerWeek: program?.rate_kg_per_week,
      dietType: program?.diet_type ?? profile.dietType,
      unitSystem: current.unitSystem,
      timezone: current.timezone,
      experienceLevel: current.experienceLevel,
      workoutDaysPerWeek: current.workoutDaysPerWeek,
      equipmentAccess: current.equipmentAccess,
    };
    try {
      validateAnswers(body, current);
    } catch (error) {
      if (!error.expected || error.status !== 400) throw error;
      return { ...state, repair_reason: error.message, repair_answers: body };
    }
    return complete(current.email, body);
  });
}

module.exports = { VERSION, GOALS, validateAnswers, status, complete, repairIfPossible };
