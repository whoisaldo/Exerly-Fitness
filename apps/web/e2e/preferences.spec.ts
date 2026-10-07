import { test, expect, type APIRequestContext, type Page } from '@playwright/test';
import { randomUUID } from 'node:crypto';
import { account, apiURL, login, resetFixture } from './helpers/session';

test.beforeEach(async ({ request }) => resetFixture(request));
async function get(request: APIRequestContext, token: string, path = '/api/preferences') {
  const result = await request.get(apiURL + path, {
    headers: { Authorization: `Bearer ${token}` },
  });
  expect(result.ok(), await result.text()).toBeTruthy();
  return result.json();
}
async function patch(
  request: APIRequestContext,
  token: string,
  revision: number,
  changes: Record<string, unknown>
) {
  const result = await request.patch(apiURL + '/api/preferences', {
    headers: { Authorization: `Bearer ${token}`, 'Idempotency-Key': randomUUID() },
    data: { base_revision: revision, changes },
  });
  expect(result.ok(), await result.text()).toBeTruthy();
  return result.json();
}
async function open(page: Page, email?: string) {
  if (email) await login(page, email);
  await page.goto('/#/dashboard/profile');
  await expect(page.getByRole('form', { name: 'Profile preferences' })).toBeVisible();
  await expect(
    page.getByRole('button', { name: 'Refresh preferences', exact: true })
  ).toBeEnabled();
}
async function save(page: Page) {
  await page.getByRole('button', { name: 'Save preferences', exact: true }).click();
  await expect(page.getByRole('status').filter({ hasText: 'Preferences saved.' })).toBeVisible();
}

test('all profile preferences survive browser reload and update only accepted preference fields', async ({
  page,
  request,
}, testInfo) => {
  const user = await account(request);
  const initial = await get(request, user.token);
  const before = await get(request, user.token, '/api/export');
  await open(page, user.email);
  const fields: Record<string, string> = {
    Name: 'Preference Taylor',
    Age: '35',
    'Gender identity': 'nonbinary',
    'Height (cm)': '167.75',
    'Time zone': 'Europe/London',
    'Diet preference': 'Mediterranean',
    Allergies: 'sesame\nnuts',
    'Meals per day': '4',
    'Available equipment': 'rings\ndumbbells',
    'Preferred activities': 'hiking\nrowing',
    'Weekly workout goal': '0',
    'Sleep goal (hours)': '7.25',
    'Preferred bedtime': '22:45',
    'Preferred wake time': '06:15',
    'Meal reminder times': '08:30\n12:45',
    'Workout reminder time': '17:30',
    'Sleep reminder time': '22:00',
  };
  for (const [label, value] of Object.entries(fields))
    await page.getByLabel(label, { exact: true }).fill(value);
  await page.getByLabel('Training experience', { exact: true }).selectOption('advanced');
  await page.getByLabel('Training location', { exact: true }).selectOption('home');
  await page.getByLabel('Usual activity level', { exact: true }).selectOption('moderate');
  await page.getByLabel('Monday', { exact: true }).check();
  await page.getByLabel('Friday', { exact: true }).check();
  for (const label of ['Meal reminders', 'Workout reminders', 'Sleep reminders'])
    await page.getByLabel(label, { exact: true }).check();
  for (let i = 0; i < 4; i += 1) {
    await page.getByLabel('Display units', { exact: true }).selectOption('imperial');
    await page.getByLabel('Display units', { exact: true }).selectOption('metric');
  }
  await expect(page.getByLabel('Height (cm)', { exact: true })).toHaveValue('167.75');
  await page.reload();
  for (const [label, value] of Object.entries(fields))
    await expect(page.getByLabel(label, { exact: true })).toHaveValue(value);
  await page.getByLabel('Display units', { exact: true }).selectOption('imperial');
  await page.screenshot({ path: testInfo.outputPath('preferences-desktop.png'), fullPage: true });
  await page.setViewportSize({ width: 375, height: 812 });
  expect(
    await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)
  ).toBeTruthy();
  await page.screenshot({ path: testInfo.outputPath('preferences-mobile.png'), fullPage: true });
  await save(page);
  const current = await get(request, user.token);
  expect(current).toMatchObject({
    revision: initial.revision + 1,
    values: {
      name: 'Preference Taylor',
      age: 35,
      gender: 'nonbinary',
      height: 167.75,
      unitSystem: 'imperial',
      timezone: 'Europe/London',
      activityLevel: 'moderate',
      dietaryStyle: 'Mediterranean',
      allergies: ['sesame', 'nuts'],
      mealsPerDay: 4,
      equipment: ['rings', 'dumbbells'],
      activityTypes: ['hiking', 'rowing'],
      experienceLevel: 'advanced',
      equipmentAccess: 'home',
      workoutDaysPerWeek: 0,
      workoutDays: ['monday', 'friday'],
      sleepGoalHours: 7.25,
      bedtime: '22:45',
      wakeTime: '06:15',
      reminders: { meals: true, workouts: true, sleep: true },
      reminderTimes: { meals: ['08:30', '12:45'], workout: '17:30', sleep: '22:00' },
    },
  });
  const after = await get(request, user.token, '/api/export');
  expect(after.weights).toEqual(before.weights);
  expect(after.program).toEqual(before.program);
  expect(after.goals).toMatchObject({
    daily_calories: before.goals.daily_calories,
    weekly_workouts: 0,
    sleep_hours: 7.25,
  });
  await page.reload();
  await expect(page.getByLabel('Height (in)', { exact: true })).toHaveValue(
    String(Number((167.75 / 2.54).toFixed(8)))
  );
  await expect(page.getByLabel('Allergies', { exact: true })).toHaveValue('sesame\nnuts');
});

test('lost preference acknowledgement replays the same operation after reload without undoing a later device edit', async ({
  page,
  request,
}) => {
  const user = await account(request);
  await open(page, user.email);
  const writes: { id?: string; body: unknown }[] = [];
  await page.route('**/api/preferences', async (route) => {
    if (route.request().method() !== 'PATCH') return route.continue();
    writes.push({
      id: route.request().headers()['idempotency-key'],
      body: route.request().postDataJSON(),
    });
    const response = await route.fetch();
    if (writes.length === 1) {
      const saved = await response.json();
      expect(response.ok()).toBeTruthy();
      await patch(request, user.token, saved.revision, { dietaryStyle: 'Other device choice' });
      return route.abort('failed');
    }
    return route.fulfill({ response });
  });
  await page.getByLabel('Name', { exact: true }).fill('Lost response Taylor');
  await page.getByRole('button', { name: 'Save preferences', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Retry save', exact: true })).toBeEnabled();
  await expect(page.getByLabel('Name', { exact: true })).toBeDisabled();
  await page.reload();
  await expect(page.getByLabel('Diet preference', { exact: true })).toHaveValue(
    'Other device choice'
  );
  await expect(page.getByLabel('Name', { exact: true })).toHaveValue('Lost response Taylor');
  await expect(page.getByRole('button', { name: 'Save preferences', exact: true })).toBeEnabled();
  expect(writes).toHaveLength(2);
  expect(writes[0].id).toBeTruthy();
  expect(writes[1]).toEqual(writes[0]);
});

test('two browser tabs require review and merge only the edited fields', async ({
  page,
  context,
  request,
}, testInfo) => {
  const user = await account(request);
  await open(page, user.email);
  const other = await context.newPage();
  await open(other);
  await page.getByLabel('Name', { exact: true }).fill('First tab Taylor');
  await page.getByLabel('Weekly workout goal', { exact: true }).fill('5');
  await other.getByLabel('Name', { exact: true }).fill('Second tab Taylor');
  await other.getByLabel('Diet preference', { exact: true }).fill('Vegetarian');
  await save(page);
  await other.getByRole('button', { name: 'Save preferences', exact: true }).click();
  const conflict = other.getByRole('region', { name: 'Preference conflict' });
  await expect(conflict).toContainText('First tab Taylor');
  await expect(conflict).toContainText('Second tab Taylor');
  await expect(other.getByRole('button', { name: 'Save preferences', exact: true })).toBeDisabled();
  await other.setViewportSize({ width: 375, height: 812 });
  await other.screenshot({
    path: testInfo.outputPath('preferences-conflict-mobile.png'),
    fullPage: true,
  });
  await other.getByRole('button', { name: 'Save my edits', exact: true }).click();
  await other
    .getByRole('alertdialog')
    .getByRole('button', { name: 'Save reviewed edits', exact: true })
    .click();
  await expect(conflict).toHaveCount(0);
  await expect(other.getByRole('status').filter({ hasText: 'Preferences saved.' })).toBeVisible();
  expect((await get(request, user.token)).values).toMatchObject({
    name: 'Second tab Taylor',
    dietaryStyle: 'Vegetarian',
    workoutDaysPerWeek: 5,
  });
  await other.close();
});

test('offline preference drafts retain invalid text and can be corrected and sent after reconnecting', async ({
  page,
  context,
  request,
}) => {
  const user = await account(request);
  await open(page, user.email);
  await context.setOffline(true);
  await page.getByLabel('Name', { exact: true }).fill('Offline Taylor');
  await page.getByLabel('Sleep goal (hours)', { exact: true }).fill('7,25');
  await page.getByLabel('Height (cm)', { exact: true }).fill('167..75');
  await page.getByRole('button', { name: 'Save preferences', exact: true }).click();
  await expect(page.getByRole('alert')).toContainText('Enter a valid height');
  await context.setOffline(false);
  await page.reload();
  await expect(page.getByLabel('Height (cm)', { exact: true })).toHaveValue('167..75');
  await page.getByLabel('Height (cm)', { exact: true }).fill('167,75');
  await context.setOffline(true);
  await page.getByRole('button', { name: 'Save preferences', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Retry save', exact: true })).toBeEnabled();
  await context.setOffline(false);
  await page.reload();
  await expect(page.getByRole('button', { name: 'Save preferences', exact: true })).toBeEnabled();
  expect((await get(request, user.token)).values).toMatchObject({
    name: 'Offline Taylor',
    height: 167.75,
    sleepGoalHours: 7.25,
  });
});

test('local storage failure prevents sending and keeps the open preference answers', async ({
  page,
  request,
}) => {
  const user = await account(request);
  await open(page, user.email);
  await page.evaluate(() => {
    const original = Storage.prototype.setItem;
    (window as unknown as { restorePreferenceStorage: () => void }).restorePreferenceStorage =
      () => {
        Storage.prototype.setItem = original;
      };
    Storage.prototype.setItem = function (key, value) {
      if (key.startsWith('exerly.preferences.'))
        throw new DOMException('Storage full', 'QuotaExceededError');
      return original.call(this, key, value);
    };
  });
  let writes = 0;
  page.on('request', (request) => {
    if (request.method() === 'PATCH' && request.url().endsWith('/api/preferences')) writes += 1;
  });
  await page.getByLabel('Name', { exact: true }).fill('Storage Taylor');
  await expect(page.getByRole('alert')).toContainText('could not save your draft');
  await page.getByRole('button', { name: 'Save preferences', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Retry save', exact: true })).toBeEnabled();
  expect(writes).toBe(0);
  await expect(page.getByLabel('Name', { exact: true })).toHaveValue('Storage Taylor');
  await page.evaluate(() =>
    (window as unknown as { restorePreferenceStorage: () => void }).restorePreferenceStorage()
  );
  await page.getByRole('button', { name: 'Retry save', exact: true }).click();
  await expect(page.getByRole('status').filter({ hasText: 'Preferences saved.' })).toBeVisible();
  expect(writes).toBe(1);
});

test('an unreadable saved preference draft is kept and blocks replacement writes', async ({
  page,
  request,
}) => {
  const user = await account(request);
  await open(page, user.email);
  const key = await page.evaluate(() => {
    const key = Object.keys(localStorage).find((key) => key.startsWith('exerly.preferences.v1:'))!;
    localStorage.setItem(key, '{unreadable');
    return key;
  });
  await page.reload();
  await expect(page.getByRole('alert')).toContainText('Existing drafts have been kept');
  await expect(
    page.getByRole('button', { name: 'Refresh preferences', exact: true })
  ).toBeDisabled();
  expect(await page.evaluate((key) => localStorage.getItem(key), key)).toBe('{unreadable');
});

test('a late preference save cannot change a newly signed-in account and stays recoverable for its owner', async ({
  page,
  request,
}) => {
  const first = await account(request);
  const second = await account(request);
  await open(page, first.email);
  let release!: () => void;
  let committed!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  const ready = new Promise<void>((resolve) => {
    committed = resolve;
  });
  await page.route('**/api/preferences', async (route) => {
    if (route.request().method() !== 'PATCH') return route.continue();
    const response = await route.fetch();
    committed();
    await gate;
    await route.fulfill({ response }).catch(() => {});
  });
  await page.getByLabel('Name', { exact: true }).fill('First account saved');
  await page.getByRole('button', { name: 'Save preferences', exact: true }).click();
  await ready;
  await page.getByRole('button', { name: 'Sign out', exact: true }).click();
  await open(page, second.email);
  release();
  await expect(page.getByLabel('Name', { exact: true })).toHaveValue('Session Taylor');
  expect((await get(request, second.token)).values.name).toBe('Session Taylor');
  await page.getByRole('button', { name: 'Sign out', exact: true }).click();
  await open(page, first.email);
  await expect(page.getByLabel('Name', { exact: true })).toHaveValue('First account saved');
  await expect(page.getByRole('button', { name: 'Save preferences', exact: true })).toBeEnabled();
});

test('save clicks waiting for a refresh cannot bypass a newly discovered conflict', async ({
  page,
  request,
}) => {
  const user = await account(request);
  await open(page, user.email);
  const initial = await get(request, user.token);
  await page.getByLabel('Name', { exact: true }).fill('Waiting browser edit');
  await patch(request, user.token, initial.revision, { name: 'Newer device edit' });
  let release!: () => void;
  let entered!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  const ready = new Promise<void>((resolve) => {
    entered = resolve;
  });
  let writes = 0;
  await page.route('**/api/preferences', async (route) => {
    if (route.request().method() === 'PATCH') {
      writes += 1;
      return route.continue();
    }
    entered();
    await gate;
    return route.continue();
  });
  await page.getByRole('button', { name: 'Refresh preferences', exact: true }).click();
  await ready;
  await page.getByRole('button', { name: 'Save preferences', exact: true }).dblclick();
  release();
  await expect(page.getByRole('region', { name: 'Preference conflict' })).toContainText(
    'Newer device edit'
  );
  expect(writes).toBe(0);
  await page.getByRole('button', { name: 'Use account preferences', exact: true }).click();
  await page
    .getByRole('alertdialog')
    .getByRole('button', { name: 'Use saved preferences', exact: true })
    .click();
  await expect(page.getByLabel('Name', { exact: true })).toHaveValue('Newer device edit');
});
