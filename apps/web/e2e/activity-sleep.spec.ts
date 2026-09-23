import { test, expect } from '@playwright/test';
import { randomUUID } from 'node:crypto';

for (const kind of ['activity', 'sleep'] as const) {
  test(`${kind} drafts, lost responses, conflicts, deletion and date moves preserve one record`, async ({
    page,
    request,
  }, testInfo) => {
    const apiURL = process.env.PLAYWRIGHT_API_URL || 'http://127.0.0.1:39002';
    const path = kind === 'activity' ? '/api/activities' : '/api/sleep';
    const route = kind === 'activity' ? 'activities' : 'sleep';
    const label = kind === 'activity' ? 'activity' : 'sleep entry';
    const password = 'Simulator-Test-123!';
    const email = `web-${kind}-${randomUUID()}@exerly.test`;
    let token = '';
    async function call(method: string, endpoint: string, data?: unknown) {
      const response = await request.fetch(apiURL + endpoint, {
        method,
        data,
        headers: {
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
          'Idempotency-Key': randomUUID(),
          'X-Test-Fixture': 'isolated-simulator',
          'X-Timezone': 'America/New_York',
        },
      });
      expect(response.ok(), `${endpoint}: ${response.status()}`).toBeTruthy();
      return response.json();
    }
    await call('POST', '/__test/control', {});
    token = (await call('POST', '/signup', { email, password, name: 'Daily Taylor' })).token;
    await call('POST', '/api/onboarding/complete', {
      name: 'Daily Taylor',
      age: 34,
      gender: 'female',
      sex: 'female',
      height: 167.5,
      weight: 72.25,
      goal: 'maintain',
      activityLevel: 'light',
      unitSystem: 'metric',
      timezone: 'America/New_York',
    });
    const day = (await call('GET', '/api/summary')).date;
    const previous = new Date(`${day}T12:00:00Z`);
    previous.setUTCDate(previous.getUTCDate() - 1);
    const yesterday = previous.toISOString().slice(0, 10);
    const older = new Date(`${day}T12:00:00Z`);
    older.setUTCDate(older.getUTCDate() - 40);
    const olderDay = older.toISOString().slice(0, 10);
    await call('POST', path, {
      ...(kind === 'activity' ? { activity: 'Older walk', duration_min: 12.5 } : { hours: 6.25 }),
      entry_date: olderDay,
      client_id: randomUUID(),
    });
    await page.goto('/#/login');
    await page.getByRole('button', { name: 'Login', exact: true }).first().click();
    await page.getByPlaceholder('Email Address').fill(email);
    await page.getByPlaceholder('Password', { exact: true }).fill(password);
    await page.locator('button[type="submit"]').click();
    await expect(page).toHaveURL(/dashboard/);
    await page.goto(`/#/dashboard/${route}?date=${day}`);
    const history = page.getByRole('region', {
      name: kind === 'activity' ? 'Activity history' : 'Sleep history',
      exact: true,
    });
    await history.getByLabel('History period').selectOption('90');
    await expect(history.getByRole('link', { name: new RegExp(olderDay) })).toBeVisible();
    await history.getByLabel('History period').selectOption('30');
    await expect(history.getByRole('link', { name: new RegExp(olderDay) })).toHaveCount(0);
    await page.getByRole('button', { name: `Log ${kind}`, exact: true }).click();
    if (kind === 'activity') await page.getByLabel('Activity name', { exact: true }).fill('Walk');
    const value = page.getByLabel(kind === 'activity' ? 'Duration (minutes)' : 'Hours slept', {
      exact: true,
    });
    await value.fill(kind === 'activity' ? '30.25' : '7.25');
    if (kind === 'sleep') {
      await page.getByLabel('Bedtime, optional', { exact: true }).fill('23:00');
      await page.getByLabel('Wake time, optional', { exact: true }).fill('06:15');
    }
    await page.reload();
    await expect(value).toHaveValue(kind === 'activity' ? '30.25' : '7.25');
    const writes: { id: string; body: string | null }[] = [];
    await page.route(`**${path}`, async (intercept) => {
      if (intercept.request().method() !== 'POST') return intercept.continue();
      writes.push({
        id: intercept.request().headers()['idempotency-key'],
        body: intercept.request().postData(),
      });
      if (writes.length !== 1) return intercept.continue();
      expect((await intercept.fetch()).ok()).toBeTruthy();
      await intercept.abort('failed');
    });
    await page.getByRole('button', { name: `Save ${kind}`, exact: true }).click();
    const pending = page.getByRole('region', { name: 'Pending changes', exact: true });
    await expect(pending.getByRole('status')).toContainText('saved in this browser');
    await page.reload();
    await pending.getByRole('button', { name: `Retry ${label} change`, exact: true }).click();
    await expect(pending).toHaveCount(0);
    expect(writes).toHaveLength(2);
    expect(writes[0]).toEqual(writes[1]);
    let rows = await call('GET', `${path}?date=${day}`);
    expect(rows).toHaveLength(1);
    const original = rows[0];
    expect(original.revision).toBe(1);
    expect(kind === 'activity' ? original.calories : original.quality).toBeNull();
    const saved = page.getByRole('region', { name: 'Saved entries', exact: true });
    await saved.getByRole('button', { name: `Edit ${label}`, exact: true }).click();
    await value.fill(kind === 'activity' ? '45.5' : '8.25');
    if (kind === 'activity') await page.getByLabel('Calories, optional', { exact: true }).fill('0');
    await call('PUT', `${path}/${original.id}`, {
      ...original,
      ...(kind === 'activity' ? { duration_min: 40 } : { hours: 7.75 }),
      base_revision: 1,
    });
    await page.getByRole('button', { name: `Save ${kind}`, exact: true }).click();
    await expect(pending.getByText('Saved version:', { exact: false })).toBeVisible();
    await page.screenshot({ path: testInfo.outputPath(`${kind}-conflict.png`), fullPage: true });
    await pending.getByRole('button', { name: 'Apply my reviewed change', exact: true }).click();
    await expect(pending).toHaveCount(0);
    await expect(saved.getByRole('status')).toHaveText('Synced');
    await saved.getByRole('button', { name: `Delete ${label}`, exact: true }).click();
    const dialog = page.getByRole('alertdialog');
    await expect(dialog).toBeVisible();
    await expect(dialog.getByRole('button', { name: 'Cancel', exact: true })).toBeFocused();
    await page.keyboard.press('Escape');
    await expect(saved.getByRole('button', { name: `Delete ${label}`, exact: true })).toBeFocused();
    await saved.getByRole('button', { name: `Delete ${label}`, exact: true }).click();
    await dialog.getByRole('button', { name: `Delete ${label}`, exact: true }).click();
    await expect(saved.getByRole('status')).toHaveText('Entry deleted');
    expect(await call('GET', `${path}?date=${day}`)).toHaveLength(0);
    await saved.getByRole('button', { name: `Restore ${label}`, exact: true }).click();
    await expect(saved.getByRole('status')).toHaveText('Synced');
    rows = await call('GET', `${path}?date=${day}`);
    expect(rows).toHaveLength(1);
    expect(rows[0].id).toBe(original.id);
    expect(rows[0].client_id).toBe(original.client_id);
    expect(rows[0].revision).toBe(5);
    expect(kind === 'activity' ? rows[0].duration_min : rows[0].hours).toBe(
      kind === 'activity' ? 45.5 : 8.25
    );
    if (kind === 'activity') expect(rows[0].calories).toBe(0);
    else {
      await page.getByRole('button', { name: 'Log sleep', exact: true }).click();
      await value.fill('0.5');
      await page.getByRole('button', { name: 'Save sleep', exact: true }).click();
      await expect(saved.getByRole('article')).toHaveCount(2);
      await expect.poll(async () => (await call('GET', '/api/summary')).sleep_hours).toBe(8.75);
      await expect(history).toContainText('8.75 hours per recorded day');
    }
    const exported = await call('GET', '/api/export');
    expect(
      exported[kind === 'activity' ? 'activities' : 'sleep'].find(
        (row: { id: string }) => row.id === original.id
      ).revision
    ).toBe(5);
    await call('PUT', `${path}/${original.id}`, {
      ...rows[0],
      entry_date: yesterday,
      base_revision: 5,
    });
    await page.getByRole('button', { name: 'Refresh entries', exact: true }).click();
    await expect(saved.getByRole('article')).toHaveCount(kind === 'activity' ? 0 : 1);
    await page.getByRole('button', { name: 'Previous day', exact: true }).click();
    await expect(saved.getByRole('article')).toHaveCount(1);
    await expect(saved).toContainText(kind === 'activity' ? '45.5 min' : '8.25 hours');
    await page.screenshot({ path: testInfo.outputPath(`${kind}-desktop.png`), fullPage: true });
    await page.setViewportSize({ width: 375, height: 812 });
    await page.screenshot({ path: testInfo.outputPath(`${kind}-mobile.png`), fullPage: true });
    expect(
      await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)
    ).toBeTruthy();
  });
}

test('native activity and sleep edits return from the browser with the same identities', async ({
  page,
  request,
}, testInfo) => {
  test.skip(
    process.env.PLAYWRIGHT_NATIVE_ACCOUNT !== '1',
    'Run scripts/test-cross-client.sh with the shared simulator account'
  );
  const apiURL = process.env.PLAYWRIGHT_API_URL || 'http://127.0.0.1:39002';
  let token = '';
  async function call(method: string, path: string, data?: unknown) {
    const response = await request.fetch(apiURL + path, {
      method,
      data,
      headers: {
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        'X-Test-Fixture': 'isolated-simulator',
        'Idempotency-Key': randomUUID(),
      },
    });
    expect(response.ok(), `${path}: ${response.status()}`).toBeTruthy();
    return response.json();
  }
  await call('POST', '/__test/control', {});
  const { email } = await call('GET', '/__test/daily-logs-account');
  const password = 'Simulator-Test-123!';
  token = (await call('POST', '/login', { email, password })).token;
  const activity = (await call('GET', '/api/activities'))[0];
  const sleep = (await call('GET', '/api/sleep')).find(
    (row: { hours: number }) => row.hours === 8.25
  );
  expect(activity.revision).toBe(5);
  expect(sleep.revision).toBe(4);
  await page.goto('/#/login');
  await page.getByRole('button', { name: 'Login', exact: true }).first().click();
  await page.getByPlaceholder('Email Address').fill(email);
  await page.getByPlaceholder('Password', { exact: true }).fill(password);
  await page.locator('button[type="submit"]').click();
  await expect(page).toHaveURL(/dashboard/);
  await page.goto(`/#/dashboard/activities?date=${activity.entry_date}`);
  await page.getByRole('button', { name: 'Edit activity', exact: true }).click();
  await expect(page.getByLabel('Duration (minutes)', { exact: true })).toHaveValue('45.5');
  await page.getByLabel('Duration (minutes)', { exact: true }).fill('63.25');
  await page.getByLabel('Calories, optional', { exact: true }).fill('');
  const writes: { id: string; body: string | null }[] = [];
  await page.route(`**/api/activities/${activity.id}`, async (route) => {
    if (route.request().method() !== 'PUT') return route.continue();
    writes.push({
      id: route.request().headers()['idempotency-key'],
      body: route.request().postData(),
    });
    if (writes.length !== 1) return route.continue();
    expect((await route.fetch()).ok()).toBeTruthy();
    await route.abort('failed');
  });
  await page.getByRole('button', { name: 'Save activity', exact: true }).click();
  await expect(page.getByRole('region', { name: 'Pending changes', exact: true })).toBeVisible();
  await page.reload();
  await page.getByRole('button', { name: 'Retry activity change', exact: true }).click();
  await expect(page.getByRole('region', { name: 'Pending changes', exact: true })).toHaveCount(0);
  expect(writes).toHaveLength(2);
  expect(writes[0]).toEqual(writes[1]);
  await page.goto(`/#/dashboard/sleep?date=${sleep.entry_date}`);
  await page
    .getByRole('article', { name: 'sleep entry: 8.25 hours', exact: true })
    .getByRole('button', { name: 'Edit sleep entry', exact: true })
    .click();
  await page.getByLabel('Hours slept', { exact: true }).fill('8.75');
  await page.getByRole('combobox', { name: 'Quality', exact: true }).selectOption('good');
  await page.getByRole('button', { name: 'Save sleep', exact: true }).click();
  await expect(
    page.getByRole('article', { name: 'sleep entry: 8.75 hours', exact: true }).getByRole('status')
  ).toHaveText('Synced');
  const summary = await call('GET', `/api/summary?entry_date=${sleep.entry_date}`);
  expect(summary.sleep_hours).toBe(9.25);
  const exported = await call('GET', '/api/export');
  expect(exported.activities).toHaveLength(1);
  expect(exported.activities[0].id).toBe(activity.id);
  expect(exported.activities[0].client_id).toBe(activity.client_id);
  expect(exported.sleep).toHaveLength(2);
  expect(exported.sleep.find((row: { id: string }) => row.id === sleep.id).client_id).toBe(
    sleep.client_id
  );
  await call('POST', '/__test/daily-logs-roundtrip', {
    email,
    activityID: activity.id,
    sleepID: sleep.id,
  });
  await page.screenshot({ path: testInfo.outputPath('sleep-native-browser.png'), fullPage: true });
});
