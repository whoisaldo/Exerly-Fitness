import { test, expect } from '@playwright/test';
import { randomUUID } from 'node:crypto';

test('measurements agree across the diary, reviewed conflicts, retries, undo and export', async ({
  page,
  request,
}, testInfo) => {
  const apiURL = process.env.PLAYWRIGHT_API_URL || 'http://127.0.0.1:39002';
  const password = 'Simulator-Test-123!';
  let email: string;
  let token: string;
  async function call(method: string, path: string, body?: unknown) {
    const result = await request.fetch(`${apiURL}${path}`, {
      method,
      headers: {
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        'Idempotency-Key': randomUUID(),
        'X-Test-Fixture': 'isolated-simulator',
      },
      data: body,
    });
    expect(result.ok(), `${method} ${path}: ${result.status()}`).toBeTruthy();
    return result.json();
  }
  if (process.env.PLAYWRIGHT_NATIVE_ACCOUNT === '1') {
    email = (await call('GET', '/__test/measurement-account')).email;
  } else {
    email = `web-measurement-${randomUUID()}@exerly.test`;
    token = (await call('POST', '/signup', { email, password, name: 'Browser Taylor' })).token;
    await call('POST', '/api/onboarding/complete', {
      name: 'Browser Taylor',
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
    await call('POST', '/api/measurements', {
      type: 'waist',
      value: 81.25,
      unit: 'cm',
      client_id: randomUUID(),
    });
  }
  token = (await call('POST', '/login', { email, password })).token;
  const initial = (await call('GET', '/api/measurements')).entries;
  expect(initial).toHaveLength(1);
  expect(initial[0].value).toBe(81.25);
  const id = initial[0].id;

  await page.goto('/#/login');
  await page.getByRole('button', { name: 'Login', exact: true }).first().click();
  await page.getByPlaceholder('Email Address').fill(email);
  await page.getByPlaceholder('Password', { exact: true }).fill(password);
  await page.locator('button[type="submit"]').click();
  await expect(page).toHaveURL(/dashboard/);
  await page.goto('/#/dashboard/weight');
  const section = page.getByRole('region', { name: 'Body measurements' });
  const table = section.getByRole('table');
  await expect(table).toContainText('81.25 cm');
  await section.getByRole('button', { name: 'Edit Waist measurement', exact: true }).click();
  await section.getByLabel('Value (cm)', { exact: true }).fill('80.75');
  await section.getByRole('button', { name: 'Save measurement changes', exact: true }).click();
  await expect(table).toContainText('80.75 cm');
  let row = await call('GET', `/api/measurements/${id}`);
  expect(row.value).toBe(80.75);

  await section.getByRole('button', { name: 'Edit Waist measurement', exact: true }).click();
  await section.getByLabel('Value (cm)', { exact: true }).fill('80.25');
  await call('PUT', `/api/measurements/${id}`, {
    ...row,
    value: 79.5,
    base_revision: row.revision,
  });
  await section.getByRole('button', { name: 'Save measurement changes', exact: true }).click();
  await expect(section.getByText('Review a change from another device')).toBeVisible();
  await expect(section.getByText(/Server: 79.5 cm/)).toBeVisible();
  await section.getByRole('button', { name: 'Save my reviewed changes', exact: true }).click();
  await expect(table).toContainText('80.25 cm');
  row = await call('GET', `/api/measurements/${id}`);

  let dropNextResponse = true;
  const operations: string[] = [];
  await page.route(`**/api/measurements/${id}`, async (route) => {
    if (route.request().method() !== 'PUT') {
      await route.continue();
      return;
    }
    operations.push(route.request().headers()['idempotency-key']);
    if (!dropNextResponse) {
      await route.continue();
      return;
    }
    dropNextResponse = false;
    const result = await route.fetch();
    expect(result.ok()).toBeTruthy();
    await route.abort('failed');
  });
  await section.getByRole('button', { name: 'Edit Waist measurement', exact: true }).click();
  await section.getByLabel('Value (cm)', { exact: true }).fill('80.5');
  await section.getByRole('button', { name: 'Save measurement changes', exact: true }).click();
  await expect(section.getByRole('alert')).toBeVisible();
  const committed = await call('GET', `/api/measurements/${id}`);
  expect(committed.revision).toBe(row.revision + 1);
  await page.reload();
  await expect(section.getByLabel('Value (cm)', { exact: true })).toHaveValue('80.5');
  await section.getByRole('button', { name: 'Save measurement changes', exact: true }).click();
  await expect(table).toContainText('80.5 cm');
  expect(operations).toHaveLength(2);
  expect(operations[0]).toBe(operations[1]);
  expect((await call('GET', `/api/measurements/${id}`)).revision).toBe(committed.revision);

  await section.getByRole('button', { name: 'Delete Waist measurement', exact: true }).click();
  await expect(section.getByText('Waist measurement removed.')).toBeVisible();
  expect((await call('GET', '/api/measurements')).total).toBe(0);
  await section.getByRole('button', { name: 'Undo measurement deletion', exact: true }).click();
  await expect(table).toContainText('80.5 cm');
  await section.getByRole('combobox', { name: 'Measurement', exact: true }).selectOption('arms');
  await section.getByRole('combobox', { name: 'Unit', exact: true }).selectOption('in');
  await section.getByLabel('Value (in)', { exact: true }).fill('12.5');
  await section.getByRole('button', { name: 'Save measurement', exact: true }).click();
  await expect(table).toContainText('31.75 cm');
  const exported = await call('GET', '/api/export');
  expect(exported.measurements).toHaveLength(2);
  expect(exported.measurements.find((item: { id: string }) => item.id === id).value).toBe(80.5);
  expect(exported.measurements.find((item: { type: string }) => item.type === 'arms').value).toBe(
    31.75
  );
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.screenshot({ path: testInfo.outputPath('measurements-desktop.png'), fullPage: true });
  await page.setViewportSize({ width: 390, height: 844 });
  await page.evaluate(() => window.scrollTo(0, 0));
  expect(
    await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)
  ).toBeTruthy();
  await page.screenshot({ path: testInfo.outputPath('measurements-mobile.png'), fullPage: true });
  if (process.env.PLAYWRIGHT_NATIVE_ACCOUNT === '1') {
    await call('POST', '/__test/measurement-roundtrip', { email, id });
  }
});
