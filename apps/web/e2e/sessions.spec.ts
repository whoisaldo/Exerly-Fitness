import { test, expect } from '@playwright/test';
import { randomUUID } from 'node:crypto';
import { storedSession, expireSession, resetFixture } from './helpers/session';

test('a delayed refresh cannot restore a signed-out account or overwrite the next account', async ({
  page,
  request,
}) => {
  await resetFixture(request);
  const apiURL = process.env.PLAYWRIGHT_API_URL || 'http://127.0.0.1:39002';
  const password = 'Simulator-Test-123!';
  async function createAccount(value: number) {
    const email = `web-session-${randomUUID()}@exerly.test`;
    const signup = await request.post(`${apiURL}/signup`, {
      data: { email, password, name: 'Session Taylor' },
    });
    expect(signup.ok()).toBeTruthy();
    const token = (await signup.json()).token;
    const headers = { Authorization: `Bearer ${token}`, 'Idempotency-Key': randomUUID() };
    const setup = await request.post(`${apiURL}/api/onboarding/complete`, {
      headers,
      data: {
        name: 'Session Taylor',
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
    expect(setup.ok()).toBeTruthy();
    const measurement = await request.post(`${apiURL}/api/measurements`, {
      headers: { ...headers, 'Idempotency-Key': randomUUID() },
      data: { type: 'waist', value, unit: 'cm', client_id: randomUUID() },
    });
    expect(measurement.ok()).toBeTruthy();
    return email;
  }
  const first = await createAccount(88.25);
  const second = await createAccount(76.5);
  async function login(email: string) {
    await page.goto('/#/login');
    await page.getByRole('button', { name: 'Login', exact: true }).first().click();
    await page.getByPlaceholder('Email Address').fill(email);
    await page.getByPlaceholder('Password', { exact: true }).fill(password);
    await page.locator('button[type="submit"]').click();
    await expect(page).toHaveURL(/dashboard/);
  }
  let release!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  let started!: () => void;
  const firstRequest = new Promise<void>((resolve) => {
    started = resolve;
  });
  let finished!: () => void;
  const oldResponse = new Promise<void>((resolve) => {
    finished = resolve;
  });
  let refreshes = 0;
  await page.route('**/auth/token', async (route) => {
    refreshes += 1;
    if (refreshes !== 1) return route.continue();
    const result = await route.fetch();
    expect(result.ok()).toBeTruthy();
    started();
    await gate;
    await route.fulfill({ response: result });
    finished();
  });
  try {
    await login(first);
    await page.goto('/#/dashboard/weight');
    await expect(
      page.getByRole('region', { name: 'Body measurements' }).getByRole('table')
    ).toContainText('88.25 cm');
    await expireSession(page);
    await page.reload();
    await firstRequest;
    await page.getByRole('button', { name: 'Sign out', exact: true }).click();
    await expect(page).toHaveURL(/\/#\/$/);
    expect(await storedSession(page)).toBeNull();
    await login(second);
    await page.goto('/#/dashboard/weight');
    const section = page.getByRole('region', { name: 'Body measurements' });
    await expect(section.getByRole('table')).toContainText('76.5 cm');
    const newToken = (await storedSession(page)).token;
    release();
    await oldResponse;
    // Let both fetch and React process the released response before asserting.
    await page.evaluate(
      () => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)))
    );
    expect((await storedSession(page)).token).toBe(newToken);
    expect(refreshes).toBe(1);
    await expect(section.getByRole('table')).toContainText('76.5 cm');
    await expect(section.getByRole('table')).not.toContainText('88.25 cm');
    await section.getByRole('button', { name: 'Refresh measurements' }).click();
    await expect(section.getByRole('table')).toContainText('76.5 cm');
  } finally {
    release();
  }
});
