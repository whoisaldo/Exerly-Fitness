import { test, expect } from '@playwright/test';
import { randomUUID } from 'node:crypto';
import { account, apiURL, resetFixture, sessionKey, storedSession } from './helpers/session';

test.beforeEach(async ({ request }) => resetFixture(request));

test('legacy upgrade replays one persisted operation across response loss, two tabs and reload', async ({
  page,
  request,
}) => {
  const user = await account(request);
  const response = await request.post(`${apiURL}/__test/legacy-session`, {
    headers: { 'X-Test-Fixture': 'isolated-simulator' },
    data: { email: user.email },
  });
  expect(response.ok()).toBeTruthy();
  const { token } = await response.json();
  const scope = randomUUID();
  await page.goto('/#/login');
  // A pre-migration envelope has no refresh operation or account-ID claim.
  await page.evaluate(
    ({ key, token, scope }) =>
      localStorage.setItem(key, JSON.stringify({ version: 2, scope, token, expiresAt: 0 })),
    { key: sessionKey, token, scope }
  );
  const attempts: { id: string; body: string | null }[] = [];
  let failResponses = true;
  await page.context().route('**/auth/refresh', async (route) => {
    attempts.push({
      id: route.request().headers()['idempotency-key'],
      body: route.request().postData(),
    });
    const committed = await route.fetch();
    expect(committed.ok()).toBeTruthy();
    if (failResponses) await route.abort('connectionreset');
    else await route.fulfill({ response: committed });
  });
  await page.goto('/#/dashboard/weight');
  await expect(page.getByRole('alert')).toContainText('Could not connect to renew');
  expect((await storedSession(page)).token).toBe(token);
  expect((await storedSession(page)).refreshOperation).toBe(`upgrade:${scope}`);
  const other = await page.context().newPage();
  await other.goto('/#/dashboard/weight');
  await expect(other.getByRole('alert')).toContainText('Could not connect to renew');
  failResponses = false;
  await page.bringToFront();
  await page.reload();
  await expect(page.getByRole('region', { name: 'Body measurements' })).toBeVisible();
  await other.bringToFront();
  await expect(other.getByRole('region', { name: 'Body measurements' })).toBeVisible();
  expect(attempts.length).toBeGreaterThanOrEqual(3);
  for (const attempt of attempts) expect(attempt).toEqual(attempts[0]);
  const saved = await storedSession(page);
  expect(saved.refreshToken).toBeTruthy();
  expect((await storedSession(other)).sessionId).toBe(saved.sessionId);
  const stats = await request.get(
    `${apiURL}/__test/session-upgrades?email=${encodeURIComponent(user.email)}`,
    { headers: { 'X-Test-Fixture': 'isolated-simulator' } }
  );
  expect((await stats.json()).count).toBe(2);
  await page.screenshot({
    path: test.info().outputPath('legacy-session-upgrade-recovered.png'),
    fullPage: true,
  });
  await other.close();
});

test('legacy upgrade waits for durable browser storage before sending a request', async ({
  page,
  request,
}) => {
  const user = await account(request);
  await page.addInitScript((key) => {
    const original = Storage.prototype.setItem;
    Storage.prototype.setItem = function (name, value) {
      if (name === key && localStorage.getItem('refuse-legacy-upgrade') === '1')
        throw new DOMException('Test quota', 'QuotaExceededError');
      return original.call(this, name, value);
    };
  }, sessionKey);
  await page.goto('/#/login');
  await page.evaluate(
    ({ key, token, scope }) => {
      localStorage.setItem(key, JSON.stringify({ version: 2, scope, token, expiresAt: 0 }));
      localStorage.setItem('refuse-legacy-upgrade', '1');
    },
    { key: sessionKey, token: user.token, scope: randomUUID() }
  );
  let attempts = 0;
  await page.route('**/auth/refresh', async (route) => {
    attempts += 1;
    await route.continue();
  });
  await page.goto('/#/dashboard/weight');
  await expect(page.getByRole('alert')).toContainText('could not save your session');
  expect(attempts).toBe(0);
  expect((await storedSession(page)).token).toBe(user.token);
  await page.evaluate(() => localStorage.removeItem('refuse-legacy-upgrade'));
  await page.getByRole('button', { name: 'Retry account' }).click();
  await expect(page.getByRole('region', { name: 'Body measurements' })).toBeVisible();
  expect(attempts).toBe(1);
});
