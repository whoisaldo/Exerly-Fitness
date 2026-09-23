import { test, expect } from '@playwright/test';
import { randomUUID } from 'node:crypto';

test('diary status preserves drafts, reviews conflicts and replays a lost acknowledgement once', async ({
  page,
  request,
}, testInfo) => {
  const apiURL = process.env.PLAYWRIGHT_API_URL || 'http://127.0.0.1:39002';
  const email = `web-diary-${randomUUID()}@exerly.test`;
  const password = 'Simulator-Test-123!';
  let token = '';
  async function call(method: string, path: string, data?: unknown) {
    const result = await request.fetch(`${apiURL}${path}`, {
      method,
      data,
      headers: {
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        'Idempotency-Key': randomUUID(),
      },
    });
    expect(result.ok(), `${path}: ${result.status()}`).toBeTruthy();
    return result.json();
  }
  token = (await call('POST', '/signup', { email, password, name: 'Diary Taylor' })).token;
  await call('POST', '/api/onboarding/complete', {
    name: 'Diary Taylor',
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
  const form = page.getByRole('form', { name: 'Day logging status' });
  await expect(form.getByRole('status')).toContainText('In progress');
  await form.getByRole('combobox', { name: 'Status', exact: true }).selectOption('complete');
  await form.getByRole('textbox', { name: 'Optional note' }).fill('All meals recorded');
  await page.reload();
  await expect(form.getByRole('combobox', { name: 'Status', exact: true })).toHaveValue('complete');
  await expect(form.getByRole('textbox', { name: 'Optional note' })).toHaveValue(
    'All meals recorded'
  );
  await form.getByRole('button', { name: 'Save status', exact: true }).click();
  await expect(form.getByRole('status')).toHaveText('Complete · Synced');
  const first = await call('GET', '/api/diary/day');
  expect(first.revision).toBe(1);
  await form.getByRole('combobox', { name: 'Status', exact: true }).selectOption('estimated');
  await call('PUT', '/api/diary/day', {
    entry_date: first.entry_date,
    status: 'excluded',
    note: 'Missing lunch',
    base_revision: 1,
  });
  await form.getByRole('button', { name: 'Save status', exact: true }).click();
  await expect(form.getByText('Server: Excluded · Missing lunch')).toBeVisible();
  await form.getByRole('button', { name: 'Save my reviewed status' }).click();
  await expect(form.getByRole('status')).toHaveText('Estimated · Synced');
  const before = await call('GET', '/api/diary/day');
  const operations: string[] = [];
  await page.route('**/api/diary/day', async (route) => {
    if (route.request().method() !== 'PUT') return route.continue();
    operations.push(route.request().headers()['idempotency-key']);
    if (operations.length > 1) return route.continue();
    expect((await route.fetch()).ok()).toBeTruthy();
    await route.abort('failed');
  });
  await form.getByRole('combobox', { name: 'Status', exact: true }).selectOption('complete');
  await form.getByRole('button', { name: 'Save status', exact: true }).click();
  await expect(form.getByRole('alert')).toBeVisible();
  await page.reload();
  await form.getByRole('button', { name: 'Save status', exact: true }).click();
  await expect(form.getByRole('status')).toHaveText('Complete · Synced');
  expect(operations).toHaveLength(2);
  expect(operations[0]).toBe(operations[1]);
  const result = await call('GET', '/api/diary/day');
  expect(result.revision).toBe(before.revision + 1);
  const summary = await call('GET', '/api/summary');
  expect(summary.diary_day.status).toBe('complete');
  const exported = await call('GET', '/api/export');
  expect(exported.diary_days).toHaveLength(1);
  expect(exported.diary_days[0].revision).toBe(result.revision);
  let releaseDay!: () => void;
  const dayGate = new Promise<void>((resolve) => {
    releaseDay = resolve;
  });
  let requestedDay!: () => void;
  const dayRequested = new Promise<void>((resolve) => {
    requestedDay = resolve;
  });
  await page.route('**/api/summary?entry_date=*', async (route) => {
    if (new URL(route.request().url()).searchParams.get('entry_date') === first.entry_date)
      return route.continue();
    requestedDay();
    await dayGate;
    await route.continue();
  });
  try {
    await page.getByRole('button', { name: 'Previous day', exact: true }).click();
    await dayRequested;
    await expect(form).not.toBeVisible();
  } finally {
    releaseDay();
  }
  await expect(form.getByRole('status')).toHaveText('In progress · Synced');
  await form.getByRole('combobox', { name: 'Status', exact: true }).selectOption('excluded');
  await form.getByRole('button', { name: 'Save status', exact: true }).click();
  await expect(form.getByRole('status')).toHaveText('Excluded · Synced');
  expect((await call('GET', '/api/diary/day')).revision).toBe(result.revision);
  await page.getByRole('button', { name: 'Today', exact: true }).click();
  await expect(form.getByRole('status')).toHaveText('Complete · Synced');
  await form.scrollIntoViewIfNeeded();
  await page.screenshot({ path: testInfo.outputPath('diary-status-desktop.png'), fullPage: true });
  await page.setViewportSize({ width: 390, height: 844 });
  expect(
    await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)
  ).toBeTruthy();
  await page.screenshot({ path: testInfo.outputPath('diary-status-mobile.png'), fullPage: true });
});
