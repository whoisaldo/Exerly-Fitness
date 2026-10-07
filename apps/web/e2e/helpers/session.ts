import { expect, type APIRequestContext, type Page } from '@playwright/test';
import { randomUUID } from 'node:crypto';

export const apiURL = process.env.PLAYWRIGHT_API_URL || 'http://127.0.0.1:39002';
export const sessionKey = `exerly.session.v2:${apiURL}`;
export const password = 'Simulator-Test-123!';

export async function resetFixture(request: APIRequestContext) {
  expect(
    (
      await request.post(`${apiURL}/__test/control`, {
        headers: { 'X-Test-Fixture': 'isolated-simulator' },
        data: {},
      })
    ).ok()
  ).toBeTruthy();
}

export async function account(request: APIRequestContext) {
  const email = `web-modern-${randomUUID()}@exerly.test`;
  const response = await request.post(`${apiURL}/signup`, {
    data: { email, password, name: 'Session Taylor' },
  });
  expect(response.ok()).toBeTruthy();
  const { token } = await response.json();
  expect(
    (
      await request.post(`${apiURL}/api/onboarding/complete`, {
        headers: { Authorization: `Bearer ${token}`, 'Idempotency-Key': randomUUID() },
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
      })
    ).ok()
  ).toBeTruthy();
  return { email, token };
}

export async function login(page: Page, email: string) {
  await page.goto('/#/login');
  await page.getByRole('button', { name: 'Login', exact: true }).first().click();
  await page.getByPlaceholder('Email Address').fill(email);
  await page.getByPlaceholder('Password', { exact: true }).fill(password);
  await page.locator('button[type="submit"]').click();
  await expect(page).toHaveURL(/dashboard/);
}

export async function storedSession(page: Page) {
  return page.evaluate((key) => JSON.parse(localStorage.getItem(key) || 'null'), sessionKey);
}

export async function expireSession(page: Page) {
  await page.evaluate((key) => {
    const session = JSON.parse(localStorage.getItem(key)!);
    session.expiresAt = 0;
    localStorage.setItem(key, JSON.stringify(session));
  }, sessionKey);
}
