const test = require('node:test');
const assert = require('node:assert/strict');
const { startServer, signUp } = require('./helpers/server');

let api;
test.before(async () => {
  api = await startServer();
});
test.after(async () => api.close());

const answers = {
  name: 'Taylor',
  age: 30,
  gender: 'nonbinary',
  sex: 'male',
  height: 180,
  weight: 85,
  goal: 'weight_loss',
  nutritionGoal: 'lose',
  activityLevel: 'moderate',
  targetWeight: 78,
  timezone: 'America/New_York',
  unitSystem: 'imperial',
  experienceLevel: 'beginner',
  workoutDaysPerWeek: 3,
  equipmentAccess: 'home',
  dietType: 'balanced',
  allergies: ['peanuts'],
  mealsPerDay: 3,
  activityTypes: ['strength'],
  equipment: ['dumbbells'],
  sleepGoalHours: 8,
  bedtime: '23:00',
  wakeTime: '07:00',
  workoutDays: ['monday', 'wednesday', 'friday'],
  reminders: { meals: true, workouts: false },
};

test('audit regression: completion initializes the selected program and matching diary targets', async () => {
  const user = await signUp(api);
  const done = await api.post('/api/user/onboarding', answers, { token: user.token });
  assert.equal(done.status, 200);
  const program = await api.get('/api/program', { token: user.token });
  assert.equal(program.body.goal_type, 'lose');
  assert.ok(program.body.targets.calories > 0);
  const goals = await api.get('/api/goals', { token: user.token });
  const summary = await api.get('/api/summary', { token: user.token });
  assert.equal(goals.body.daily_calories, program.body.targets.calories);
  assert.equal(summary.body.targets.calories, program.body.targets.calories);
  assert.equal(done.body.user.unitSystem, 'imperial');
  assert.equal(done.body.user.name, 'Taylor');
  const weights = await api.get('/api/weight', { token: user.token });
  assert.equal(weights.body.length, 1);
  assert.equal(weights.body[0].weight_kg, 85);
});

test('concurrent completion and lost acknowledgements return one initialized account', async () => {
  const user = await signUp(api);
  const options = { token: user.token, headers: { 'Idempotency-Key': 'setup-retry-0001' } };
  const results = await Promise.all(
    Array.from({ length: 6 }, () => api.post('/api/onboarding/complete', answers, options))
  );
  for (const result of results) {
    assert.equal(result.status, 200);
    assert.deepEqual(result.body, results[0].body);
  }
  assert.equal(await api.store.count('weights', { email: user.email }), 1);
  assert.equal(await api.store.count('target_versions', { email: user.email }), 1);
  assert.equal(await api.store.count('operations', { account_id: user.user._id }), 1);
  const status = await api.get('/api/onboarding/status', { token: user.token });
  assert.equal(status.body.complete, true);
  const changed = await api.post('/api/onboarding/complete', { ...answers, weight: 90 }, options);
  assert.equal(changed.status, 409);
});

test('a storage failure rolls back every setup record and permits a retry', async () => {
  const user = await signUp(api);
  const insert = api.store.insert;
  api.store.insert = async (collection, doc) => {
    if (collection === 'target_versions') throw new Error('Injected storage failure');
    return insert(collection, doc);
  };
  let failed;
  try {
    failed = await api.post('/api/onboarding/complete', answers, {
      token: user.token,
      headers: { 'Idempotency-Key': 'setup-rollback-01' },
    });
  } finally {
    api.store.insert = insert;
  }
  assert.equal(failed.status, 500);
  assert.equal((await api.get('/api/me', { token: user.token })).body.onboardingCompleted, false);
  for (const collection of ['weights', 'goals', 'programs', 'target_versions']) {
    assert.equal(await api.store.count(collection, { email: user.email }), 0, collection);
  }
  const retry = await api.post('/api/onboarding/complete', answers, {
    token: user.token,
    headers: { 'Idempotency-Key': 'setup-rollback-01' },
  });
  assert.equal(retry.status, 200);
});

test('drafts enforce ownership and revision and reject stale completion', async () => {
  const user = await signUp(api);
  const other = await signUp(api);
  const draft = { schema_version: 1, revision: 0, last_valid_step: 3, answers };
  assert.equal((await api.put('/api/onboarding/draft', draft, { token: user.token })).status, 200);
  assert.equal((await api.put('/api/onboarding/draft', draft, { token: user.token })).status, 409);
  assert.equal((await api.get('/api/onboarding/draft', { token: other.token })).body.draft, null);
  const result = await api.post(
    '/api/onboarding/complete',
    { ...answers, draftRevision: 0 },
    { token: user.token, headers: { 'Idempotency-Key': 'stale-draft-0001' } }
  );
  assert.equal(result.status, 409);
});

test('new completion rejects minors and requires explicit physiology or manual targets', async () => {
  const user = await signUp(api);
  for (const invalid of [
    { ...answers, age: 17 },
    { ...answers, sex: undefined },
    { ...answers, timezone: 'not/a/zone' },
  ]) {
    assert.equal(
      (await api.post('/api/user/onboarding', invalid, { token: user.token })).status,
      400
    );
  }
  const manual = await api.post(
    '/api/user/onboarding',
    {
      ...answers,
      sex: undefined,
      targetMode: 'manual',
      manualTargets: { calories: 2300, protein_g: 140, carbs_g: 270, fat_g: 70 },
    },
    { token: user.token }
  );
  assert.equal(manual.status, 200);
  assert.equal(manual.body.targets.calories, 2300);
});

test('all collected preferences survive completion and a repeat cannot overwrite a program', async () => {
  const user = await signUp(api);
  await api.post('/api/user/onboarding', answers, { token: user.token });
  const stored = await api.store.findOne('users', { email: user.email });
  assert.deepEqual(stored.profile.allergies, ['peanuts']);
  assert.deepEqual(stored.profile.workoutDays, answers.workoutDays);
  assert.deepEqual(stored.profile.reminders, { meals: true, workouts: false, sleep: false });
  await api.put('/api/program', { goalType: 'maintain' }, { token: user.token });
  await api.post('/api/user/onboarding', answers, { token: user.token });
  assert.equal((await api.get('/api/program', { token: user.token })).body.goal_type, 'maintain');
});

test('bootstrap repairs legacy target records without replacing a manual program or seeding a fresh measurement', async () => {
  const user = await signUp(api);
  await api.store.update('users', { id: user.user._id }, { onboardingCompleted: true });
  await api.store.insert('programs', {
    email: user.email,
    goal_type: 'gain',
    target_mode: 'manual',
    calories: 2750,
    protein_g: 150,
    carbs_g: 350,
    fat_g: 80,
  });
  const bootstrap = await api.get('/api/bootstrap', { token: user.token });
  assert.equal(bootstrap.body.onboarding.complete, true);
  assert.equal(bootstrap.body.targets.calories, 2750);
  assert.equal(bootstrap.body.onboarding.program.goal_type, 'gain');
  assert.equal(await api.store.count('weights', { email: user.email }), 0);
  const again = await api.get('/api/bootstrap', { token: user.token });
  assert.equal(again.body.onboarding.complete, true);
  assert.equal(await api.store.count('target_versions', { account_id: user.user._id }), 1);
});

test('legacy repair holds when required facts are missing', async () => {
  const user = await signUp(api);
  await api.store.update(
    'users',
    { id: user.user._id },
    { onboardingCompleted: true, goal: 'lose_weight' }
  );
  const bootstrap = await api.get('/api/bootstrap', { token: user.token });
  assert.equal(bootstrap.body.onboarding.complete, false);
  assert.equal(bootstrap.body.onboarding.needs_repair, true);
  assert.match(bootstrap.body.onboarding.repair_reason, /age/);
  assert.equal(await api.store.count('programs', { email: user.email }), 0);
  assert.equal(await api.store.count('weights', { email: user.email }), 0);
});

test('an early program read cannot replace a legacy goal before account repair', async () => {
  const user = await signUp(api);
  await api.store.update(
    'users',
    { id: user.user._id },
    {
      onboardingCompleted: true,
      goal: 'lose_weight',
    }
  );
  const program = await api.get('/api/program', { token: user.token });
  assert.equal(program.status, 409);
  assert.equal(await api.store.count('programs', { email: user.email }), 0);
  const bootstrap = await api.get('/api/bootstrap', { token: user.token });
  assert.equal(bootstrap.body.onboarding.needs_repair, true);
  assert.equal(bootstrap.body.onboarding.repair_answers.goal, 'lose_weight');
});
