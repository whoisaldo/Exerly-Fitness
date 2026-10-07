import { test, expect } from '@playwright/test';
import { randomUUID } from 'node:crypto';
import {
  account,
  apiURL,
  expireSession,
  login,
  resetFixture,
  sessionKey,
  storedSession,
} from './helpers/session';

test.beforeEach(async ({ request }) => resetFixture(request));

test('malformed refresh responses and storage failures retain the original recovery operation', async ({
  page,
  request,
}) => {
  const user = await account(request);
  await page.addInitScript((key) => {
    const original = Storage.prototype.setItem;
    Storage.prototype.setItem = function (name, value) {
      if (name === key && localStorage.getItem('test-refuse-session-write') === '1')
        throw new DOMException('Test storage quota', 'QuotaExceededError');
      return original.call(this, name, value);
    };
  }, sessionKey);
  await login(page, user.email);
  await page.goto('/#/dashboard/weight');
  await expect(page.getByRole('region', { name: 'Body measurements' })).toBeVisible();
  const initial = await storedSession(page);
  const attempts: { id: string; body: string | null }[] = [];
  await page.route('**/auth/token', async (route) => {
    attempts.push({
      id: route.request().headers()['idempotency-key'],
      body: route.request().postData(),
    });
    if (attempts.length > 1) return route.continue();
    expect((await route.fetch()).ok()).toBeTruthy();
    await route.fulfill({ status: 200, contentType: 'application/json', body: '{' });
  });
  await expireSession(page);
  await page.reload();
  await expect(page.getByRole('alert')).toContainText('response was incomplete');
  expect((await storedSession(page)).refreshToken).toBe(initial.refreshToken);
  await page.evaluate(() => localStorage.setItem('test-refuse-session-write', '1'));
  await page.getByRole('button', { name: 'Retry account' }).click();
  await expect(page.getByRole('alert')).toContainText('could not save your session');
  expect((await storedSession(page)).refreshToken).toBe(initial.refreshToken);
  expect((await storedSession(page)).refreshOperation).toBe(initial.refreshOperation);
  await page.evaluate(() => localStorage.removeItem('test-refuse-session-write'));
  await page.reload();
  await expect(page.getByRole('region', { name: 'Body measurements' })).toBeVisible();
  expect(attempts).toHaveLength(3);
  expect(attempts[1]).toEqual(attempts[0]);
  expect(attempts[2]).toEqual(attempts[0]);
  expect((await storedSession(page)).refreshToken).not.toBe(initial.refreshToken);
});

test('browser signup creates one rotating session and opens unfinished setup', async ({
  page,
  request,
}) => {
  await page.goto('/#/login');
  await page.getByLabel('Full name', { exact: true }).fill('New Taylor');
  await page
    .getByLabel('Email address', { exact: true })
    .fill(`web-signup-${randomUUID()}@exerly.test`);
  await page.getByLabel('Password', { exact: true }).fill('Simulator-Test-123!');
  let submissions = 0;
  let release!: () => void;
  let started!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  const received = new Promise<void>((resolve) => {
    started = resolve;
  });
  await page.route('**/signup', async (route) => {
    submissions += 1;
    expect(route.request().headers()['x-session-protocol']).toBe('2');
    const response = await route.fetch();
    expect(response.ok()).toBeTruthy();
    started();
    await gate;
    await route.fulfill({ response });
  });
  try {
    await page.locator('button[type="submit"]').dblclick();
    await received;
    await expect(page.locator('button[type="submit"]')).toBeDisabled();
    release();
    await expect(page).toHaveURL(/\/#\/onboarding$/);
    const session = await storedSession(page);
    expect(session.refreshToken).toBeTruthy();
    expect(submissions).toBe(1);
    const status = await request.get(`${apiURL}/api/onboarding/status`, {
      headers: { Authorization: `Bearer ${session.token}` },
    });
    expect(await status.json()).toMatchObject({
      complete: false,
      targets: null,
      user: { name: 'New Taylor', onboardingCompleted: false },
    });
  } finally {
    release();
  }
});

test('another tab signing in and out invalidates an earlier anonymous login response', async ({
  page,
  request,
}, testInfo) => {
  const first = await account(request);
  const second = await account(request);
  let release!: () => void;
  let started!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  const received = new Promise<void>((resolve) => {
    started = resolve;
  });
  await page.route('**/login', async (route) => {
    const response = await route.fetch();
    started();
    await gate;
    await route.fulfill({ response });
  });
  const other = await page.context().newPage();
  try {
    await page.goto('/#/login');
    await page.getByRole('button', { name: 'Login', exact: true }).first().click();
    await page.getByLabel('Email address', { exact: true }).fill(first.email);
    await page.getByLabel('Password', { exact: true }).fill('Simulator-Test-123!');
    await page.locator('button[type="submit"]').click();
    await received;
    await login(other, second.email);
    await other.goto('/#/dashboard/weight');
    await expect(other.getByRole('region', { name: 'Body measurements' })).toBeVisible();
    const revoked = other.waitForResponse((response) => response.url().endsWith('/auth/logout'));
    await other.getByRole('button', { name: 'Sign out', exact: true }).click();
    expect((await revoked).ok()).toBeTruthy();
    release();
    await expect(page.getByRole('alert')).toContainText('Your session changed in another tab');
    expect(await storedSession(page)).toBeNull();
    await page.setViewportSize({ width: 375, height: 812 });
    await expect(page.getByLabel('Email address', { exact: true })).toBeVisible();
    expect(
      await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)
    ).toBeTruthy();
    await page.screenshot({
      path: testInfo.outputPath('login-account-change-mobile.png'),
      fullPage: true,
    });
  } finally {
    release();
    await other.close();
  }
});

test('offline sign-out reports that server revocation could not be confirmed', async ({
  page,
  request,
}) => {
  const user = await account(request);
  await login(page, user.email);
  await page.goto('/#/dashboard/weight');
  await expect(page.getByRole('region', { name: 'Body measurements' })).toBeVisible();
  await page.route('**/auth/logout', (route) => route.abort('failed'));
  await page.getByRole('button', { name: 'Sign out', exact: true }).click();
  await expect(page.getByRole('status')).toContainText('We could not reach the server');
  expect(await storedSession(page)).toBeNull();
});

test('leaving sign-in cannot apply its delayed response', async ({ page, request }) => {
  const user = await account(request);
  let release!: () => void;
  let started!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  const received = new Promise<void>((resolve) => {
    started = resolve;
  });
  await page.route('**/login', async (route) => {
    const response = await route.fetch();
    started();
    await gate;
    await route.fulfill({ response });
  });
  try {
    await page.goto('/#/login');
    await page.getByRole('button', { name: 'Login', exact: true }).first().click();
    await page.getByLabel('Email address', { exact: true }).fill(user.email);
    await page.getByLabel('Password', { exact: true }).fill('Simulator-Test-123!');
    await page.locator('button[type="submit"]').click();
    await received;
    await page.getByRole('link', { name: 'Back to Landing Page' }).click();
    release();
    await page.evaluate(
      () => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)))
    );
    await expect(page).toHaveURL(/\/#\/$/);
    expect(await storedSession(page)).toBeNull();
  } finally {
    release();
  }
});

test('a rejected password confirmation preserves the valid signed-in session', async ({
  page,
  request,
}) => {
  const user = await account(request);
  await login(page, user.email);
  await page.goto('/#/dashboard/weight');
  await expect(page.getByRole('region', { name: 'Body measurements' })).toBeVisible();
  const initial = await storedSession(page);
  const result = await page.evaluate(async () => {
    const { api } = await import('/src/lib/api.ts');
    try {
      await api.post('/api/change-password', {
        currentPassword: 'wrong-password',
        newPassword: 'New-Password-123!',
      });
      return { status: 200 };
    } catch (error) {
      return { status: error.status, message: error.message };
    }
  });
  expect(result).toMatchObject({ status: 401, message: 'Current password is incorrect' });
  expect((await storedSession(page)).scope).toBe(initial.scope);
  await expect(page.getByRole('region', { name: 'Body measurements' })).toBeVisible();
});

test('two tabs share one refresh operation and keep the same server session', async ({
  page,
  request,
}) => {
  const user = await account(request);
  const refreshes: { id: string; body: string | null }[] = [];
  let compatibility = 0;
  page.context().on('request', (req) => {
    if (req.url().endsWith('/auth/refresh')) compatibility += 1;
  });
  await login(page, user.email);
  await page.goto('/#/dashboard/diary');
  await expect(page.getByRole('form', { name: 'Water logging' })).toBeVisible();
  const initial = await storedSession(page);
  const claims = JSON.parse(Buffer.from(initial.token.split('.')[1], 'base64url').toString());
  expect(claims.exp - claims.iat).toBe(900);
  expect(initial.refreshToken).toBeTruthy();
  const other = await page.context().newPage();
  await other.goto('/#/dashboard/diary');
  await expect(other.getByRole('form', { name: 'Water logging' })).toBeVisible();
  expect(compatibility).toBe(0);
  let release!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  await page.context().route('**/auth/token', async (route) => {
    refreshes.push({
      id: route.request().headers()['idempotency-key'],
      body: route.request().postData(),
    });
    await gate;
    await route.continue();
  });
  try {
    await expireSession(page);
    await Promise.all([page.reload(), other.reload()]);
    await expect.poll(() => refreshes.length).toBe(2);
    release();
    await expect(page.getByRole('form', { name: 'Water logging' })).toBeVisible();
    await expect(other.getByRole('form', { name: 'Water logging' })).toBeVisible();
    expect(refreshes[0]).toEqual(refreshes[1]);
    const rotated = await storedSession(page);
    expect(rotated.scope).toBe(initial.scope);
    expect(rotated.sessionId).toBe(initial.sessionId);
    expect(rotated.refreshToken).not.toBe(initial.refreshToken);
    expect(await storedSession(other)).toEqual(rotated);
    await Promise.all([page.reload(), other.reload()]);
    await expect(page.getByRole('form', { name: 'Water logging' })).toBeVisible();
    await expect(other.getByRole('form', { name: 'Water logging' })).toBeVisible();
    expect(refreshes).toHaveLength(2);
    const sessions = await request.get(`${apiURL}/api/sessions`, {
      headers: { Authorization: `Bearer ${rotated.token}` },
    });
    expect(
      (await sessions.json()).filter(
        (row: { device_name: string }) => row.device_name === 'Exerly web'
      )
    ).toHaveLength(1);
  } finally {
    release();
    await other.close();
  }
});

test('a lost refresh response survives reload and preserves an unfinished activity draft', async ({
  page,
  request,
}, testInfo) => {
  const user = await account(request);
  await login(page, user.email);
  await page.goto('/#/dashboard/activities');
  await page.getByRole('button', { name: 'Log activity', exact: true }).click();
  await page.getByLabel('Activity name', { exact: true }).fill('Evening walk');
  await page.getByLabel('Duration (minutes)', { exact: true }).fill('30.25');
  const initial = await storedSession(page);
  const attempts: { id: string; body: string | null }[] = [];
  let connected = false;
  await page.route('**/auth/token', async (route) => {
    attempts.push({
      id: route.request().headers()['idempotency-key'],
      body: route.request().postData(),
    });
    if (connected) return route.continue();
    if (attempts.length === 1) expect((await route.fetch()).ok()).toBeTruthy();
    await route.abort('failed');
  });
  await expireSession(page);
  await page.reload();
  await expect(page.getByRole('region', { name: 'Connection status' })).toContainText(
    'Offline copy'
  );
  await expect(page.getByLabel('Activity name', { exact: true })).toHaveValue('Evening walk');
  expect((await storedSession(page)).refreshToken).toBe(initial.refreshToken);
  expect((await storedSession(page)).refreshOperation).toBe(initial.refreshOperation);
  await page.screenshot({ path: testInfo.outputPath('refresh-response-lost.png'), fullPage: true });
  connected = true;
  await page.reload();
  await expect(page.getByLabel('Activity name', { exact: true })).toHaveValue('Evening walk');
  await expect(page.getByLabel('Duration (minutes)', { exact: true })).toHaveValue('30.25');
  expect(attempts.length).toBeGreaterThanOrEqual(2);
  for (const attempt of attempts) expect(attempt).toEqual(attempts[0]);
  expect((await storedSession(page)).refreshToken).not.toBe(initial.refreshToken);
  await page.getByRole('button', { name: 'Save activity', exact: true }).click();
  await expect(
    page.getByRole('article', { name: 'activity: Evening walk' }).getByRole('status')
  ).toHaveText('Synced');
  await page.setViewportSize({ width: 375, height: 812 });
  await page.screenshot({
    path: testInfo.outputPath('draft-after-session-recovery.png'),
    fullPage: true,
  });
});

test('access rejection retries an unchanged write once after refresh', async ({
  page,
  request,
}) => {
  const user = await account(request);
  await login(page, user.email);
  await page.goto('/#/dashboard/diary');
  const form = page.getByRole('form', { name: 'Water logging' });
  await expect(form).toBeVisible();
  const writes: { id: string; body: string | null }[] = [];
  const initial = await storedSession(page);
  await page.route('**/api/water', async (route) => {
    if (route.request().method() !== 'POST') return route.continue();
    writes.push({
      id: route.request().headers()['idempotency-key'],
      body: route.request().postData(),
    });
    if (writes.length > 1) return route.continue();
    await route.fulfill({ status: 401, json: { message: 'Session expired. Log in again.' } });
  });
  await form.getByRole('button', { name: '+250 ml', exact: true }).click();
  await expect(form.getByLabel('Recorded water')).toHaveText('250 ml recorded');
  await expect(form.getByRole('status')).toHaveText('Synced');
  expect(writes).toHaveLength(2);
  expect(writes[0]).toEqual(writes[1]);
  expect((await storedSession(page)).refreshToken).not.toBe(initial.refreshToken);
  const saved = await request.get(`${apiURL}/api/water`, {
    headers: { Authorization: `Bearer ${user.token}` },
  });
  expect(await saved.json()).toMatchObject({ ml: 250, revision: 1 });
});

test('sign-out revokes the browser session and remote revocation clears every tab', async ({
  page,
  request,
}) => {
  const user = await account(request);
  await login(page, user.email);
  await page.goto('/#/dashboard/weight');
  await expect(page.getByRole('region', { name: 'Body measurements' })).toBeVisible();
  const first = await storedSession(page);
  const revoked = page.waitForResponse((response) => response.url().endsWith('/auth/logout'));
  await page.getByRole('button', { name: 'Sign out', exact: true }).click();
  expect((await revoked).ok()).toBeTruthy();
  expect(await storedSession(page)).toBeNull();
  expect(
    (
      await request.get(`${apiURL}/api/me`, { headers: { Authorization: `Bearer ${first.token}` } })
    ).status()
  ).toBe(401);
  expect(
    (
      await request.post(`${apiURL}/auth/token`, {
        data: { refreshToken: first.refreshToken },
        headers: { 'Idempotency-Key': randomUUID() },
      })
    ).status()
  ).toBe(401);
  await login(page, user.email);
  await page.goto('/#/dashboard/weight');
  await expect(page.getByRole('region', { name: 'Body measurements' })).toBeVisible();
  const second = await storedSession(page);
  const other = await page.context().newPage();
  await other.goto('/#/dashboard/diary');
  await expect(other.getByRole('form', { name: 'Water logging' })).toBeVisible();
  expect(
    (
      await request.delete(`${apiURL}/api/sessions/${second.sessionId}`, {
        headers: { Authorization: `Bearer ${user.token}` },
      })
    ).ok()
  ).toBeTruthy();
  await page.reload();
  await expect.poll(() => storedSession(page)).toBeNull();
  await expect(other).toHaveURL(/\/#\/$/);
  await other.close();
});

test('credentials are isolated by API and a scoped legacy session upgrades once', async ({
  page,
  request,
}) => {
  const user = await account(request);
  await page.goto('/#/login');
  const unrelated = 'exerly.session.v2:https://another-api.example';
  await page.evaluate(
    ({ unrelated }) => {
      localStorage.setItem('token', 'unscoped-old-environment-token');
      localStorage.setItem(unrelated, 'other-environment-saved-session');
    },
    { unrelated }
  );
  const sent: string[] = [];
  page.on('request', (req) => {
    if (req.headers().authorization) sent.push(req.headers().authorization);
  });
  await page.goto('/#/dashboard/weight');
  await expect(page).toHaveURL(/\/#\/$/);
  expect(sent.some((value) => value.includes('unscoped-old-environment-token'))).toBeFalsy();
  let upgrades = 0;
  await page.route('**/auth/refresh', async (route) => {
    upgrades += 1;
    expect(route.request().headers()['x-session-protocol']).toBe('2');
    await route.continue();
  });
  await page.evaluate(async (token) => {
    const storage = await import('/src/lib/sessionStorage.ts');
    storage.setToken(token);
  }, user.token);
  await page.goto('/#/dashboard/weight');
  await expect(page.getByRole('region', { name: 'Body measurements' })).toBeVisible();
  expect((await storedSession(page)).refreshToken).toBeTruthy();
  await page.reload();
  await expect(page.getByRole('region', { name: 'Body measurements' })).toBeVisible();
  expect(upgrades).toBe(1);
  await page.getByRole('button', { name: 'Sign out', exact: true }).click();
  expect(await page.evaluate((key) => localStorage.getItem(key), sessionKey)).toBeNull();
  expect(await page.evaluate((key) => localStorage.getItem(key), unrelated)).toBe(
    'other-environment-saved-session'
  );
});
