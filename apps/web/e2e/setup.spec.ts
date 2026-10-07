import { test, expect, type APIRequestContext, type Page } from '@playwright/test';
import { randomUUID } from 'node:crypto';
import { apiURL, password, resetFixture, storedSession } from './helpers/session';

test.beforeEach(async ({ request }) => resetFixture(request));

async function newAccount(request: APIRequestContext) {
  const email = `setup-${randomUUID()}@exerly.test`;
  const response = await request.post(`${apiURL}/signup`, {
    data: { email, password, name: 'Setup Taylor' },
  });
  expect(response.ok()).toBeTruthy();
  return { email, token: (await response.json()).token };
}

async function openSetup(page: Page, email: string) {
  await page.goto('/#/login');
  await page.getByRole('button', { name: 'Login', exact: true }).first().click();
  await page.getByLabel('Email address', { exact: true }).fill(email);
  await page.getByLabel('Password', { exact: true }).fill(password);
  await page.locator('button[type="submit"]').click();
  await expect(page).toHaveURL(/\/#\/onboarding$/);
  await expect(page.getByRole('form', { name: 'Account setup' })).toBeVisible();
}

async function call(request: APIRequestContext, token: string, path: string, data?: unknown) {
  const headers = { Authorization: `Bearer ${token}`, 'Idempotency-Key': randomUUID() };
  const response =
    data === undefined
      ? await request.get(apiURL + path, { headers })
      : await request.put(apiURL + path, { headers, data });
  expect(response.ok(), await response.text()).toBeTruthy();
  return response.json();
}

function cloudAnswers(name = 'Cloud Taylor') {
  return {
    name,
    age: 34,
    gender: 'nonbinary',
    sex: null,
    height: 167.5,
    weight: 72.25,
    goal: 'gain_muscle',
    nutritionGoal: 'lose',
    targetWeight: 68.5,
    activityLevel: 'light',
    targetMode: 'manual',
    manualTargets: { calories: 2180, protein_g: 133, carbs_g: 246, fat_g: 66, fiber_g: 27 },
    timezone: 'America/New_York',
    unitSystem: 'metric',
    experienceLevel: 'intermediate',
    workoutDaysPerWeek: 4,
    equipmentAccess: 'home',
    equipment: ['bodyweight', 'rings'],
    activityTypes: ['hiking'],
    dietaryStyle: 'mediterranean',
    allergies: ['sesame', 'nuts'],
    mealsPerDay: 4,
    sleepGoalHours: 7.25,
    bedtime: '22:45',
    wakeTime: '06:15',
    workoutDays: ['monday', 'wednesday', 'friday', 'sunday'],
    timelineWeeks: 16,
    reminders: { meals: true, workouts: false, sleep: true },
    rateKgPerWeek: -0.2,
    dietType: 'balanced',
  };
}

test('signup setup survives each step, converts units without drift and resolves a lost completion acknowledgement', async ({
  page,
  request,
}, testInfo) => {
  const email = `setup-signup-${randomUUID()}@exerly.test`;
  await page.goto('/#/login');
  await page.getByLabel('Full name', { exact: true }).fill('Taylor Setup');
  await page.getByLabel('Email address', { exact: true }).fill(email);
  await page.getByLabel('Password', { exact: true }).fill(password);
  await page.locator('button[type="submit"]').click();
  await expect(page.getByRole('heading', { name: 'Your name', exact: true })).toBeVisible();
  await page.getByLabel('Name', { exact: true }).fill('Taylor Persisted');
  await page.reload();
  await expect(page.getByLabel('Name', { exact: true })).toHaveValue('Taylor Persisted');
  await page.getByRole('button', { name: 'Continue', exact: true }).click();
  await page.getByLabel('Age', { exact: true }).fill('34');
  await page.getByLabel('Gender identity', { exact: true }).selectOption('other');
  await page.getByLabel('Height (cm)', { exact: true }).fill('167.5');
  await page.getByLabel('Weight (kg)', { exact: true }).fill('72.25');
  await page.getByLabel('Calculation parameter', { exact: true }).selectOption('female');
  await page.reload();
  await expect(page.getByLabel('Weight (kg)', { exact: true })).toHaveValue('72.25');
  for (let i = 0; i < 3; i += 1) {
    await page.getByLabel('Display units', { exact: true }).selectOption('imperial');
    await page.getByLabel('Display units', { exact: true }).selectOption('metric');
  }
  await expect(page.getByLabel('Height (cm)', { exact: true })).toHaveValue('167.5');
  await expect(page.getByLabel('Weight (kg)', { exact: true })).toHaveValue('72.25');
  await page.getByRole('button', { name: 'Continue', exact: true }).click();
  await page.getByLabel('Fitness goal', { exact: true }).selectOption('gain_muscle');
  await page.getByLabel('Nutrition goal', { exact: true }).selectOption('lose');
  await page.getByLabel('Target weight (kg)', { exact: true }).fill('68.5');
  await page.reload();
  await expect(page.getByLabel('Fitness goal', { exact: true })).toHaveValue('gain_muscle');
  await expect(page.getByLabel('Nutrition goal', { exact: true })).toHaveValue('lose');
  await page.getByRole('button', { name: 'Back', exact: true }).click();
  await expect(page.getByLabel('Age', { exact: true })).toHaveValue('34');
  await page.getByRole('button', { name: 'Continue', exact: true }).click();
  await page.getByRole('button', { name: 'Continue', exact: true }).click();
  await page.getByLabel('Usual activity level', { exact: true }).selectOption('light');
  await page.getByLabel('Time zone', { exact: true }).fill('America/New_York');
  await page.reload();
  await expect(page.getByLabel('Usual activity level', { exact: true })).toHaveValue('light');
  let preview: { targets: Record<string, number> } = { targets: {} };
  page.on('response', async (response) => {
    if (response.url().endsWith('/api/onboarding/preview') && response.ok())
      preview = await response.json();
  });
  await page.getByRole('button', { name: 'Continue', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Finish setup', exact: true })).toBeEnabled();
  await page.reload();
  await expect(page.getByRole('button', { name: 'Finish setup', exact: true })).toBeEnabled();
  await page.screenshot({ path: testInfo.outputPath('setup-review-desktop.png'), fullPage: true });
  await page.setViewportSize({ width: 375, height: 812 });
  expect(
    await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)
  ).toBeTruthy();
  await page.screenshot({ path: testInfo.outputPath('setup-review-mobile.png'), fullPage: true });
  let submissions = 0;
  await page.route('**/api/onboarding/complete', async (route) => {
    submissions += 1;
    expect(route.request().headers()['idempotency-key']).toBeTruthy();
    expect((await route.fetch()).ok()).toBeTruthy();
    await route.abort('failed');
  });
  await page.getByRole('button', { name: 'Finish setup', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Retry finish', exact: true })).toBeEnabled();
  await expect(page.getByRole('button', { name: 'Back', exact: true })).toBeDisabled();
  await page.getByRole('button', { name: 'Retry finish', exact: true }).click();
  await expect(page).toHaveURL(/\/#\/dashboard$/);
  await page.route(`${apiURL}/api/**`, (route) => route.abort('failed'));
  await page.reload();
  await expect(page).toHaveURL(/\/#\/dashboard$/);
  await expect(page.getByRole('region', { name: 'Connection status' })).toContainText(
    'Offline copy'
  );
  await expect(page.getByRole('form', { name: 'Account setup' })).toHaveCount(0);
  await page.unroute(`${apiURL}/api/**`);
  expect(submissions).toBe(1);
  const { token } = await storedSession(page);
  const status = await call(request, token, '/api/onboarding/status');
  expect(status).toMatchObject({
    complete: true,
    targets: preview.targets,
    user: { name: 'Taylor Persisted', goal: 'gain_muscle', height: 167.5, weight: 72.25 },
  });
  const exported = await call(request, token, '/api/export');
  expect(exported.weights).toHaveLength(1);
  expect(exported.weights[0].weight_kg).toBe(72.25);
  const program = await call(request, token, '/api/program');
  expect(program.goal_type).toBe('lose');
  await page.goto('/#/onboarding');
  await expect(page).toHaveURL(/\/#\/dashboard$/);
});

test('cloud setup keeps optional preferences and requires review before replacing a newer draft', async ({
  page,
  request,
}, testInfo) => {
  const user = await newAccount(request);
  const original = cloudAnswers();
  await call(request, user.token, '/api/onboarding/draft', {
    revision: 0,
    schema_version: 2,
    last_valid_step: 4,
    answers: original,
  });
  await openSetup(page, user.email);
  await expect(page.getByRole('heading', { name: 'Review targets', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Finish setup', exact: true })).toBeEnabled();
  const { draft } = await call(request, user.token, '/api/onboarding/draft');
  await call(request, user.token, '/api/onboarding/draft', {
    ...draft,
    answers: { ...original, name: 'Other Device' },
  });
  await page.getByRole('button', { name: 'Back', exact: true }).click();
  await page.getByLabel('Usual activity level', { exact: true }).selectOption('moderate');
  await page.getByRole('button', { name: 'Retry sync', exact: true }).click();
  const conflict = page.getByRole('region', { name: 'Setup conflict' });
  await expect(conflict).toContainText('Other Device');
  await expect(conflict).toContainText('Cloud Taylor');
  await page.setViewportSize({ width: 375, height: 812 });
  expect(
    await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)
  ).toBeTruthy();
  await page.screenshot({ path: testInfo.outputPath('setup-conflict-mobile.png'), fullPage: true });
  await page.getByRole('button', { name: 'Keep these browser answers', exact: true }).click();
  await page
    .getByRole('alertdialog')
    .getByRole('button', { name: 'Use browser answers', exact: true })
    .click();
  await expect(conflict).toHaveCount(0);
  await page.getByRole('button', { name: 'Continue', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Finish setup', exact: true })).toBeEnabled();
  await page.getByText('Saved preferences', { exact: true }).click();
  await expect(page.getByText('sesame, nuts', { exact: true })).toBeVisible();
  let completed: Record<string, unknown> | undefined;
  await page.route('**/api/onboarding/complete', async (route) => {
    completed = route.request().postDataJSON();
    await route.continue();
  });
  await page.getByRole('button', { name: 'Finish setup', exact: true }).click();
  await expect(page).toHaveURL(/\/#\/dashboard$/);
  expect(completed).toMatchObject({ ...original, activityLevel: 'moderate' });
  const status = await call(request, user.token, '/api/onboarding/status');
  expect(status.targets).toEqual(original.manualTargets);
  const exported = await call(request, user.token, '/api/export');
  expect(exported.account.profile).toMatchObject({
    nutritionGoal: 'lose',
    allergies: original.allergies,
    equipment: original.equipment,
    dietaryStyle: original.dietaryStyle,
    bedtime: '22:45',
    wakeTime: '06:15',
  });
});

test('legacy account repair asks for missing activity and preserves preferences without adding a new weigh-in', async ({
  page,
  request,
}) => {
  const user = await newAccount(request);
  expect(
    (
      await request.post(`${apiURL}/__test/control`, {
        headers: { 'X-Test-Fixture': 'isolated-simulator' },
        data: { repairLegacyEmail: user.email },
      })
    ).ok()
  ).toBeTruthy();
  await openSetup(page, user.email);
  await expect(page.getByRole('heading', { name: 'Daily activity', exact: true })).toBeVisible();
  await expect(
    page.getByText('Complete your saved account · Step 1 of 2', { exact: true })
  ).toBeVisible();
  await page.getByLabel('Usual activity level', { exact: true }).selectOption('light');
  await page.getByRole('button', { name: 'Continue', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Finish setup', exact: true })).toBeEnabled();
  await page.getByRole('button', { name: 'Finish setup', exact: true }).click();
  await expect(page).toHaveURL(/\/#\/dashboard$/);
  const exported = await call(request, user.token, '/api/export');
  expect(exported.weights).toHaveLength(0);
  expect(exported.account.profile.allergies).toEqual(['nuts']);
});

test('lost draft acknowledgement replays its original operation before later edits and storage failure keeps open answers', async ({
  page,
  request,
}) => {
  const user = await newAccount(request);
  await page.addInitScript(() => {
    const original = Storage.prototype.setItem;
    Storage.prototype.setItem = function (name, value) {
      if (
        name.startsWith('exerly.setup.v2:') &&
        localStorage.getItem('refuse-setup-storage') === '1'
      )
        throw new DOMException('Test quota', 'QuotaExceededError');
      return original.call(this, name, value);
    };
  });
  await openSetup(page, user.email);
  await expect(page.getByRole('status')).toHaveText('Saved on your account.');
  const writes: { id: string; body: unknown }[] = [];
  await page.route('**/api/onboarding/draft', async (route) => {
    if (route.request().method() !== 'PUT') return route.continue();
    writes.push({
      id: route.request().headers()['idempotency-key'],
      body: route.request().postDataJSON(),
    });
    if (writes.length > 1) return route.continue();
    expect((await route.fetch()).ok()).toBeTruthy();
    await route.abort('failed');
  });
  await page.getByLabel('Name', { exact: true }).fill('First saved name');
  await expect(page.getByRole('alert')).toBeVisible();
  await page.getByLabel('Name', { exact: true }).fill('Later saved name');
  await page.reload();
  await expect(page.getByLabel('Name', { exact: true })).toHaveValue('Later saved name');
  await expect(page.getByRole('status')).toHaveText('Saved on your account.');
  expect(writes).toHaveLength(3);
  expect(writes[1]).toEqual(writes[0]);
  expect(writes[2].id).not.toBe(writes[0].id);
  expect((await call(request, user.token, '/api/onboarding/draft')).draft.answers.name).toBe(
    'Later saved name'
  );
  await page.evaluate(() => localStorage.setItem('refuse-setup-storage', '1'));
  await page.getByLabel('Name', { exact: true }).fill('Open after quota failure');
  await expect(page.getByRole('alert')).toContainText('could not save your answers');
  await expect(page.getByLabel('Name', { exact: true })).toHaveValue('Open after quota failure');
  await page.getByRole('button', { name: 'Retry sync', exact: true }).click();
  await expect(page.getByRole('alert')).toContainText('could not save your answers');
  expect(writes).toHaveLength(3);
  expect((await call(request, user.token, '/api/onboarding/draft')).draft.answers.name).toBe(
    'Later saved name'
  );
  await page.evaluate(() => localStorage.removeItem('refuse-setup-storage'));
  await page.getByRole('button', { name: 'Retry sync', exact: true }).click();
  await expect(page.getByRole('status')).toHaveText('Saved on your account.');
  expect((await call(request, user.token, '/api/onboarding/draft')).draft.answers.name).toBe(
    'Open after quota failure'
  );
});

test('two tabs keep separate local drafts and a reviewed cloud choice survives reload', async ({
  page,
  request,
}) => {
  const user = await newAccount(request);
  await call(request, user.token, '/api/onboarding/draft', {
    revision: 0,
    schema_version: 2,
    last_valid_step: 3,
    answers: cloudAnswers(),
  });
  await openSetup(page, user.email);
  await expect(page.getByLabel('Usual activity level', { exact: true })).toHaveValue('light');
  const other = await page.context().newPage();
  try {
    await other.goto('/#/onboarding');
    await expect(other.getByLabel('Usual activity level', { exact: true })).toHaveValue('light');
    await expect(other.getByRole('status')).toHaveText('Saved on your account.');
    let offline = true;
    await other.route('**/api/onboarding/draft', (route) =>
      offline ? route.abort('failed') : route.continue()
    );
    await other.getByLabel('Usual activity level', { exact: true }).selectOption('active');
    await page.getByLabel('Usual activity level', { exact: true }).selectOption('moderate');
    await page.getByRole('button', { name: 'Retry sync', exact: true }).click();
    await expect(page.getByRole('status')).toHaveText('Saved on your account.');
    await expect(other.getByRole('alert')).toBeVisible();
    const drafts = await page.evaluate(() =>
      Object.keys(localStorage)
        .filter((key) => key.startsWith('exerly.setup.v2:'))
        .map((key) => JSON.parse(localStorage.getItem(key)!))
    );
    expect(drafts.some((draft) => draft.content.answers.activityLevel === 'active')).toBeTruthy();
    expect(drafts.some((draft) => draft.content.answers.activityLevel === 'moderate')).toBeTruthy();
    offline = false;
    await other.getByRole('button', { name: 'Retry sync', exact: true }).click();
    await expect(other.getByRole('region', { name: 'Setup conflict' })).toBeVisible();
    await other.getByRole('button', { name: 'Use saved account answers', exact: true }).click();
    await other
      .getByRole('alertdialog')
      .getByRole('button', { name: 'Use account answers', exact: true })
      .click();
    await expect(other.getByRole('region', { name: 'Setup conflict' })).toHaveCount(0);
    await expect(other.getByLabel('Usual activity level', { exact: true })).toHaveValue('moderate');
    await other.reload();
    await expect(other.getByLabel('Usual activity level', { exact: true })).toHaveValue('moderate');
    await expect(page.getByLabel('Usual activity level', { exact: true })).toHaveValue('moderate');
  } finally {
    await other.close();
  }
});

test('an immutable completion survives reload before commit and resolves a lost committed response on bootstrap', async ({
  page,
  request,
}) => {
  const user = await newAccount(request);
  await call(request, user.token, '/api/onboarding/draft', {
    revision: 0,
    schema_version: 2,
    last_valid_step: 4,
    answers: cloudAnswers(),
  });
  await openSetup(page, user.email);
  await expect(page.getByRole('button', { name: 'Finish setup', exact: true })).toBeEnabled();
  const submissions: { id: string; body: unknown }[] = [];
  await page.route('**/api/onboarding/complete', async (route) => {
    submissions.push({
      id: route.request().headers()['idempotency-key'],
      body: route.request().postDataJSON(),
    });
    if (submissions.length > 1) expect((await route.fetch()).ok()).toBeTruthy();
    await route.abort('failed');
  });
  await page.getByRole('button', { name: 'Finish setup', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Retry finish', exact: true })).toBeEnabled();
  await page.reload();
  await expect(page.getByRole('button', { name: 'Retry finish', exact: true })).toBeEnabled();
  await expect(page.getByRole('button', { name: 'Back', exact: true })).toBeDisabled();
  await page.getByRole('button', { name: 'Retry finish', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Retry finish', exact: true })).toBeEnabled();
  await page.reload();
  await expect(page).toHaveURL(/\/#\/dashboard$/);
  expect(submissions).toHaveLength(2);
  expect(submissions[1]).toEqual(submissions[0]);
  expect((await call(request, user.token, '/api/export')).weights).toHaveLength(1);
});

test('saved setup stays scoped to its API and account after sign out', async ({
  page,
  request,
}) => {
  const first = await newAccount(request);
  const second = await newAccount(request);
  await openSetup(page, first.email);
  await page.getByLabel('Name', { exact: true }).fill('First account local name');
  await page.evaluate(() =>
    localStorage.setItem('exerly.setup.v2:https://unrelated.example:a:draft', '{unsupported}')
  );
  await page.getByRole('button', { name: 'Sign out', exact: true }).click();
  await openSetup(page, second.email);
  await expect(page.getByLabel('Name', { exact: true })).toHaveValue('Setup Taylor');
  await expect(page.getByRole('alert')).toHaveCount(0);
  await page.getByLabel('Name', { exact: true }).fill('Second account name');
  await page.getByRole('button', { name: 'Sign out', exact: true }).click();
  await openSetup(page, first.email);
  await expect(page.getByLabel('Name', { exact: true })).toHaveValue('First account local name');
  expect(
    await page.evaluate(() =>
      localStorage.getItem('exerly.setup.v2:https://unrelated.example:a:draft')
    )
  ).toBe('{unsupported}');
});

test('a stalled draft write times out and can replay the same committed operation', async ({
  page,
  request,
}) => {
  const user = await newAccount(request);
  await openSetup(page, user.email);
  await expect(page.getByRole('status')).toHaveText('Saved on your account.');
  await page.clock.install();
  let release!: () => void;
  let committed!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  const started = new Promise<void>((resolve) => {
    committed = resolve;
  });
  const writes: { id: string; body: unknown }[] = [];
  await page.route('**/api/onboarding/draft', async (route) => {
    if (route.request().method() !== 'PUT') return route.continue();
    writes.push({
      id: route.request().headers()['idempotency-key'],
      body: route.request().postDataJSON(),
    });
    if (writes.length > 1) return route.continue();
    const response = await route.fetch();
    expect(response.ok()).toBeTruthy();
    committed();
    await gate;
    await route.fulfill({ response }).catch(() => {});
  });
  try {
    await page.getByLabel('Name', { exact: true }).fill('Connection timeout draft');
    await page.getByRole('button', { name: 'Retry sync', exact: true }).click();
    await started;
    await page.clock.fastForward(15001);
    await expect(page.getByRole('alert')).toContainText('connection took too long');
    await expect(page.getByRole('button', { name: 'Retry sync', exact: true })).toBeEnabled();
    release();
    await page.getByRole('button', { name: 'Retry sync', exact: true }).click();
    await expect(page.getByRole('status')).toHaveText('Saved on your account.');
    expect(writes).toHaveLength(2);
    expect(writes[1]).toEqual(writes[0]);
  } finally {
    release();
  }
});
