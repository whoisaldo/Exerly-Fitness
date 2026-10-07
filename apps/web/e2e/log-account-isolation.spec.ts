import { test, expect } from '@playwright/test';
import { randomUUID } from 'node:crypto';

test('a delayed log acknowledgement stays with its account after signing out', async ({
  page,
  request,
}) => {
  const apiURL = process.env.PLAYWRIGHT_API_URL || 'http://127.0.0.1:39002';
  const control = await request.post(`${apiURL}/__test/control`, {
    headers: { 'X-Test-Fixture': 'isolated-simulator' },
    data: {},
  });
  expect(control.ok()).toBeTruthy();
  const password = 'Simulator-Test-123!';
  const emails = [`logs-a-${randomUUID()}@exerly.test`, `logs-b-${randomUUID()}@exerly.test`];
  for (const email of emails) {
    const signup = await request.post(`${apiURL}/signup`, {
      data: { email, password, name: 'Daily Taylor' },
    });
    expect(signup.ok()).toBeTruthy();
    const { token } = await signup.json();
    const setup = await request.post(`${apiURL}/api/onboarding/complete`, {
      headers: { Authorization: `Bearer ${token}`, 'Idempotency-Key': randomUUID() },
      data: {
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
      },
    });
    expect(setup.ok(), await setup.text()).toBeTruthy();
  }
  async function login(email: string) {
    await page.goto('/#/login');
    await page.getByRole('button', { name: 'Login', exact: true }).first().click();
    await page.getByPlaceholder('Email Address').fill(email);
    await page.getByPlaceholder('Password', { exact: true }).fill(password);
    await page.locator('button[type="submit"]').click();
    await expect(page).toHaveURL(/dashboard/);
    await page.goto('/#/dashboard/activities');
    await expect(page.getByRole('button', { name: 'Refresh entries', exact: true })).toBeEnabled();
  }
  await login(emails[0]);
  await page.getByRole('button', { name: 'Log activity', exact: true }).click();
  await page.getByLabel('Activity name', { exact: true }).fill('Private morning walk');
  await page.getByLabel('Duration (minutes)', { exact: true }).fill('15.25');
  let release!: () => void;
  let committed!: () => void;
  const held = new Promise<void>((resolve) => {
    release = resolve;
  });
  const arrived = new Promise<void>((resolve) => {
    committed = resolve;
  });
  await page.route('**/api/activities', async (route) => {
    if (route.request().method() !== 'POST') return route.continue();
    const response = await route.fetch();
    expect(response.ok()).toBeTruthy();
    committed();
    await held;
    await route.fulfill({ response });
  });
  try {
    await page.getByRole('button', { name: 'Save activity', exact: true }).click();
    await arrived;
    await page.getByRole('button', { name: 'Sign out', exact: true }).click();
    await login(emails[1]);
    const saved = page.getByRole('region', { name: 'Saved entries', exact: true });
    await expect(saved.getByRole('article')).toHaveCount(0);
    await expect(page.getByRole('region', { name: 'Pending changes', exact: true })).toHaveCount(0);
    release();
    await page.getByRole('button', { name: 'Refresh entries', exact: true }).click();
    await expect(page.getByRole('button', { name: 'Refresh entries', exact: true })).toBeEnabled();
    await expect(saved.getByRole('article')).toHaveCount(0);
    await page.getByRole('button', { name: 'Sign out', exact: true }).click();
    await login(emails[0]);
    await expect(saved.getByRole('article')).toHaveCount(1);
    await expect(saved).toContainText('Private morning walk · 15.25 min');
    await expect(saved.getByRole('status')).toHaveText('Synced');
    await expect(page.getByRole('region', { name: 'Pending changes', exact: true })).toHaveCount(0);
  } finally {
    release();
  }
});
