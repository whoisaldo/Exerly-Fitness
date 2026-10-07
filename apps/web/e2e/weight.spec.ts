import { test, expect } from '@playwright/test';
import { randomUUID } from 'node:crypto';

test('weight edits survive a lost response, review competing readings and delete with restore', async ({
  page,
  request,
}, testInfo) => {
  const apiURL = process.env.PLAYWRIGHT_API_URL || 'http://127.0.0.1:39002';
  const proof = await request.post(`${apiURL}/__test/control`, {
    headers: { 'X-Test-Fixture': 'isolated-simulator' },
    data: {},
  });
  expect(proof.ok()).toBeTruthy();
  let email = `web-weight-${randomUUID()}@exerly.test`;
  const password = 'Simulator-Test-123!';
  let token = '';
  async function call(method: string, path: string, data?: unknown) {
    const result = await request.fetch(`${apiURL}${path}`, {
      method,
      data,
      headers: {
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        'Idempotency-Key': randomUUID(),
        'X-Test-Fixture': 'isolated-simulator',
      },
    });
    expect(result.ok(), `${path}: ${result.status()}`).toBeTruthy();
    return result.json();
  }
  if (process.env.PLAYWRIGHT_NATIVE_ACCOUNT === '1') {
    email = (await call('GET', '/__test/weight-account')).email;
    token = (await call('POST', '/login', { email, password })).token;
  } else {
    token = (await call('POST', '/signup', { email, password, name: 'Weight Taylor' })).token;
    await call('POST', '/api/onboarding/complete', {
      name: 'Weight Taylor',
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
  }
  const starting = await call('GET', '/api/weight/day');
  const baseRevision = starting.revision;
  await page.goto('/#/login');
  await page.getByRole('button', { name: 'Login', exact: true }).first().click();
  await page.getByPlaceholder('Email Address').fill(email);
  await page.getByPlaceholder('Password', { exact: true }).fill(password);
  await page.locator('button[type="submit"]').click();
  await expect(page).toHaveURL(/dashboard/);
  await page.goto('/#/dashboard/weight');
  const section = page.getByRole('region', { name: 'Weight reading', exact: true });
  await expect(section.getByRole('status')).toContainText(`${starting.weight_kg.toFixed(2)} kg`);
  await section.getByRole('spinbutton', { name: 'Weight (kg)' }).fill('73.25');
  await section.getByRole('textbox', { name: 'Optional note' }).fill('Morning reading');
  const writes: { id: string; body: string | null }[] = [];
  await page.route('**/api/weight/day', async (route) => {
    if (route.request().method() !== 'PUT') return route.continue();
    writes.push({
      id: route.request().headers()['idempotency-key'],
      body: route.request().postData(),
    });
    if (writes.length !== 1) return route.continue();
    expect((await route.fetch()).ok()).toBeTruthy();
    await route.abort('failed');
  });
  await section.getByRole('button', { name: 'Save weight', exact: true }).click();
  await expect(section.getByText('Saved in this browser.', { exact: false })).toBeVisible();
  await page.reload();
  await section.getByRole('button', { name: 'Retry weight change' }).click();
  await expect(section.getByRole('button', { name: 'Retry weight change' })).toHaveCount(0);
  expect(writes).toHaveLength(2);
  expect(writes[0]).toEqual(writes[1]);
  const first = await call('GET', '/api/weight/day');
  expect(first.revision).toBe(baseRevision + 1);
  expect(first.id).toBe(starting.id);
  await section.getByRole('spinbutton', { name: 'Weight (kg)' }).fill('73.5');
  await call('PUT', '/api/weight/day', {
    weight_kg: 75,
    note: 'Other device',
    base_revision: first.revision,
  });
  await section.getByRole('button', { name: 'Save weight', exact: true }).click();
  await expect(
    section.getByText(`Server: 75.00 kg · revision ${baseRevision + 2} · Other device`)
  ).toBeVisible();
  await section.getByRole('button', { name: 'Apply my reviewed change' }).click();
  await expect(section.getByRole('status')).toContainText('73.50 kg');
  page.once('dialog', (dialog) => dialog.accept());
  await section.getByRole('button', { name: 'Delete reading', exact: true }).click();
  await expect(section.getByRole('status')).toHaveText('Reading deleted');
  expect((await call('GET', '/api/weight')).length).toBe(0);
  await section.getByRole('button', { name: 'Restore reading', exact: true }).click();
  await expect(section.getByRole('status')).toContainText('73.50 kg');
  const final = await call('GET', '/api/weight/day');
  expect(final.id).toBe(first.id);
  expect(final.revision).toBe(baseRevision + 5);
  expect((await call('GET', '/api/export')).weights[0].weight_kg).toBe(73.5);
  await page.getByRole('button', { name: 'Previous day', exact: true }).click();
  await expect(section.getByRole('status')).toHaveText('No reading for this day');
  await section.getByRole('spinbutton', { name: 'Weight (kg)' }).fill('74.25');
  await section.getByRole('button', { name: 'Save weight', exact: true }).click();
  await expect(section.getByRole('status')).toContainText('74.25 kg');
  await page.getByRole('button', { name: 'Today', exact: true }).click();
  await expect(section.getByRole('status')).toContainText('73.50 kg');
  expect((await call('GET', '/api/weight/day')).revision).toBe(baseRevision + 5);
  await call('PUT', '/api/settings', { unitSystem: 'imperial' });
  await page.reload();
  await expect(section.getByRole('spinbutton', { name: 'Weight (lb)' })).toHaveValue('162.04');
  await section.getByRole('spinbutton', { name: 'Weight (lb)' }).fill('160.50');
  await section.getByRole('button', { name: 'Save weight', exact: true }).click();
  await expect
    .poll(async () => (await call('GET', '/api/weight/day')).revision)
    .toBe(baseRevision + 6);
  expect((await call('GET', '/api/weight/day')).weight_kg).toBe(72.8);
  await call('PUT', '/api/settings', { unitSystem: 'metric' });
  await page.reload();
  await expect(section.getByRole('status')).toContainText('72.80 kg');
  if (process.env.PLAYWRIGHT_NATIVE_ACCOUNT === '1') {
    await call('POST', '/__test/weight-roundtrip', { email, id: first.id });
  }
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.screenshot({ path: testInfo.outputPath('weight-desktop.png'), fullPage: true });
  await page.setViewportSize({ width: 375, height: 812 });
  await page.evaluate(() => window.scrollTo(0, 0));
  await expect(section.getByRole('button', { name: 'Save weight', exact: true })).toBeVisible();
  await page.screenshot({ path: testInfo.outputPath('weight-mobile.png'), fullPage: true });
});
