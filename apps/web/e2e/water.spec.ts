import { test, expect } from '@playwright/test';
import { randomUUID } from 'node:crypto';

test('water replays a lost acknowledgement after reload and preserves another device and day', async ({
  page,
  request,
}, testInfo) => {
  let refreshCount = 0;
  page.context().on('request', (request) => {
    if (/\/auth\/(refresh|token)$/.test(request.url())) refreshCount += 1;
  });
  const apiURL = process.env.PLAYWRIGHT_API_URL || 'http://127.0.0.1:39002';
  const proof = await request.post(`${apiURL}/__test/control`, {
    headers: { 'X-Test-Fixture': 'isolated-simulator' },
    data: {},
  });
  expect(proof.ok()).toBeTruthy();
  const email = `web-water-${randomUUID()}@exerly.test`;
  const password = 'Simulator-Test-123!';
  let token = '';
  async function call(method: string, path: string, data?: unknown) {
    const response = await request.fetch(`${apiURL}${path}`, {
      method,
      data,
      headers: {
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        'Idempotency-Key': randomUUID(),
      },
    });
    expect(response.ok(), `${path}: ${response.status()}`).toBeTruthy();
    return response.json();
  }
  token = (await call('POST', '/signup', { email, password, name: 'Water Taylor' })).token;
  await call('POST', '/api/onboarding/complete', {
    name: 'Water Taylor',
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
  await page.goto('/#/login');
  await page.getByRole('button', { name: 'Login', exact: true }).first().click();
  await page.getByPlaceholder('Email Address').fill(email);
  await page.getByPlaceholder('Password', { exact: true }).fill(password);
  await page.locator('button[type="submit"]').click();
  await expect(page).toHaveURL(/dashboard/);
  await page.goto('/#/dashboard/diary');
  const form = page.getByRole('form', { name: 'Water logging' });
  await expect(form.getByLabel('Recorded water')).toHaveText('0 ml recorded');
  const writes: { id: string; body: string | null }[] = [];
  await page.route('**/api/water', async (route) => {
    if (route.request().method() !== 'POST') return route.continue();
    writes.push({
      id: route.request().headers()['idempotency-key'],
      body: route.request().postData(),
    });
    if (writes.length !== 1) return route.continue();
    expect((await route.fetch()).ok()).toBeTruthy();
    await route.abort('failed');
  });
  await form.getByRole('button', { name: '+250 ml', exact: true }).click();
  await expect(form.getByRole('alert')).toBeVisible();
  await expect(form.getByRole('status')).toContainText('250 ml waiting for confirmation');
  await call('POST', '/api/water', { deltaMl: 300 });
  await page.reload();
  await expect(form.getByLabel('Recorded water')).toHaveText('550 ml recorded');
  await expect(form.getByRole('status')).toContainText('250 ml waiting for confirmation');
  await form.getByRole('button', { name: 'Retry pending additions' }).click();
  await expect(form.getByRole('status')).toHaveText('Synced');
  await expect(form.getByLabel('Recorded water')).toHaveText('550 ml recorded');
  expect(writes).toHaveLength(2);
  expect(writes[0]).toEqual(writes[1]);
  await form.getByRole('spinbutton', { name: 'Amount (ml)' }).fill('500');
  await form.getByRole('button', { name: 'Add water', exact: true }).click();
  await expect(form.getByLabel('Recorded water')).toHaveText('1,050 ml recorded');
  const today = await call('GET', '/api/water');
  expect(today.ml).toBe(1050);
  expect(today.revision).toBe(3);
  await page.getByRole('button', { name: 'Previous day', exact: true }).click();
  await expect(form.getByLabel('Recorded water')).toHaveText('0 ml recorded');
  await form.getByRole('button', { name: '+500 ml', exact: true }).click();
  await expect(form.getByLabel('Recorded water')).toHaveText('500 ml recorded');
  await page.getByRole('button', { name: 'Today', exact: true }).click();
  await expect(form.getByLabel('Recorded water')).toHaveText('1,050 ml recorded');
  await page.unroute('**/api/water');
  const otherTab = await page.context().newPage();
  await otherTab.goto('/#/dashboard/diary');
  const otherForm = otherTab.getByRole('form', { name: 'Water logging' });
  await expect(otherForm.getByLabel('Recorded water')).toHaveText('1,050 ml recorded');
  await page.context().route('**/api/water', (route) => route.abort('failed'));
  await Promise.all([
    form.getByRole('button', { name: '+250 ml', exact: true }).click(),
    otherForm.getByRole('button', { name: '+500 ml', exact: true }).click(),
  ]);
  await expect(form.getByRole('status')).toContainText('750 ml waiting for confirmation');
  await expect(otherForm.getByRole('status')).toContainText('750 ml waiting for confirmation');
  await page.context().unroute('**/api/water');
  await form.getByRole('button', { name: 'Retry pending additions' }).click();
  await expect(form.getByRole('status')).toHaveText('Synced');
  await expect(otherForm.getByRole('status')).toHaveText('Synced');
  await otherTab.reload();
  await expect(otherForm.getByLabel('Recorded water')).toHaveText('1,800 ml recorded');
  await otherTab.close();
  expect(refreshCount).toBeLessThanOrEqual(5);
  await expect(form.getByLabel('Recorded water')).toHaveText('1,800 ml recorded');
  const exported = await call('GET', '/api/export');
  expect(exported.water).toHaveLength(2);
  expect(
    exported.water.find((row: { entry_date: string }) => row.entry_date === today.entry_date).ml
  ).toBe(1800);
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.screenshot({ path: testInfo.outputPath('water-desktop.png'), fullPage: true });
  await page.setViewportSize({ width: 375, height: 812 });
  await page.evaluate(() => window.scrollTo(0, 0));
  await expect(form.getByRole('button', { name: 'Add water', exact: true })).toBeVisible();
  await page.screenshot({ path: testInfo.outputPath('water-mobile.png'), fullPage: true });
});
