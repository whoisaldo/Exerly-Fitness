import { test, expect } from '@playwright/test';
import { randomUUID } from 'node:crypto';
import { addDays } from '../src/lib/dates';
import {
  account,
  apiURL,
  expireSession,
  login,
  resetFixture,
  storedSession,
} from './helpers/session';

test.beforeEach(async ({ request }) => resetFixture(request));

test('a saved home summary stays visible offline when its recent log list is empty', async ({
  page,
  request,
}) => {
  const user = await account(request);
  await login(page, user.email);
  const calories = page.getByRole('link', { name: /Calories Consumed 0 calories/ });
  await expect(calories).toBeVisible();
  await page.route(`${apiURL}/**`, (route) => route.abort('failed'));
  await page.reload();
  await expect(page.getByRole('region', { name: 'Connection status' })).toContainText(
    'Offline copy'
  );
  await expect(calories).toBeVisible();
});

test('a cached diary and pending water addition survive an API outage and browser reload', async ({
  page,
  request,
}) => {
  const user = await account(request);
  const headers = { Authorization: `Bearer ${user.token}`, 'Idempotency-Key': randomUUID() };
  expect(
    (await request.post(`${apiURL}/api/water`, { headers, data: { deltaMl: 250 } })).ok()
  ).toBeTruthy();
  await login(page, user.email);
  await page.goto('/#/dashboard/diary');
  const form = page.getByRole('form', { name: 'Water logging' });
  await expect(form.getByLabel('Recorded water')).toHaveText('250 ml recorded');
  const savedURL = page.url();

  await page.route(`${apiURL}/**`, (route) => route.abort('failed'));
  await page.reload();
  await expect(page.getByRole('heading', { name: 'Diary', exact: true })).toBeVisible();
  await expect(page.getByRole('region', { name: 'Connection status' })).toContainText(
    'Offline copy'
  );
  await expect(form.getByLabel('Recorded water')).toHaveText('250 ml recorded');
  await form.getByRole('button', { name: '+250 ml', exact: true }).click();
  await expect(form.getByRole('status')).toContainText('250 ml waiting for confirmation');
  await page.reload();
  await expect(page).toHaveURL(savedURL);
  await expect(form.getByLabel('Recorded water')).toHaveText('250 ml recorded');
  await expect(form.getByRole('status')).toContainText('250 ml waiting for confirmation');

  await page.unroute(`${apiURL}/**`);
  await page.evaluate(() => window.dispatchEvent(new Event('online')));
  await form.getByRole('button', { name: 'Retry pending additions' }).click();
  await expect(form.getByRole('status')).toHaveText('Synced');
  await expect(form.getByLabel('Recorded water')).toHaveText('500 ml recorded');
  const final = await request.get(`${apiURL}/api/water`, { headers });
  expect((await final.json()).ml).toBe(500);
});

test('an expired session opens its saved diary but a confirmed revocation ends offline access', async ({
  page,
  request,
}) => {
  const user = await account(request);
  await login(page, user.email);
  await page.goto('/#/dashboard/diary');
  await expect(page.getByLabel('Recorded water')).toHaveText('0 ml recorded');
  const session = await storedSession(page);
  await expireSession(page);
  await page.route(`${apiURL}/**`, (route) => route.abort('failed'));
  await page.reload();
  await expect(page.getByRole('heading', { name: 'Diary', exact: true })).toBeVisible();
  await expect(page.getByRole('region', { name: 'Connection status' })).toContainText(
    'Offline copy'
  );
  expect((await storedSession(page)).refreshOperation).toBe(session.refreshOperation);
  expect(
    (
      await request.post(`${apiURL}/auth/logout`, {
        headers: { Authorization: `Bearer ${session.token}` },
        data: {},
      })
    ).ok()
  ).toBeTruthy();
  await page.unroute(`${apiURL}/**`);
  await page.getByRole('button', { name: 'Refresh saved data' }).click();
  await expect.poll(() => storedSession(page)).toBeNull();
  await expect(page.getByRole('heading', { name: 'Diary', exact: true })).toHaveCount(0);
  await page.route(`${apiURL}/**`, (route) => route.abort('failed'));
  await page.goto('/#/dashboard/diary');
  await expect(page.getByRole('heading', { name: 'Diary', exact: true })).toHaveCount(0);
  await expect(page).toHaveURL(/\/#\/$/);
});

test('another account cannot open the previous account copy when bootstrap is unavailable', async ({
  page,
  request,
}) => {
  const first = await account(request);
  const second = await account(request);
  await login(page, first.email);
  await page.goto('/#/dashboard/diary');
  await expect(page.getByLabel('Recorded water')).toHaveText('0 ml recorded');
  await page.getByRole('button', { name: 'Sign out', exact: true }).click();
  await page.route(`${apiURL}/api/**`, (route) => route.abort('failed'));
  await login(page, second.email);
  await expect(page.getByRole('button', { name: 'Retry account' })).toBeVisible();
  await expect(page.getByRole('region', { name: 'Connection status' })).toHaveCount(0);
  await page.reload();
  await expect(page.getByRole('button', { name: 'Retry account' })).toBeVisible();
  await expect(page.getByLabel('Recorded water')).toHaveCount(0);
  await page.unroute(`${apiURL}/api/**`);
  await page.getByRole('button', { name: 'Retry account' }).click();
  await page.goto('/#/dashboard/diary');
  await expect(page.getByLabel('Recorded water')).toHaveText('0 ml recorded');
});

test('a server outage uses the saved copy but a malformed successful bootstrap remains an error', async ({
  page,
  request,
}) => {
  const user = await account(request);
  await login(page, user.email);
  await page.goto('/#/dashboard/diary');
  await expect(page.getByLabel('Recorded water')).toHaveText('0 ml recorded');
  await page.route(`${apiURL}/api/**`, (route) =>
    route.fulfill({ status: 503, json: { message: 'Unavailable' } })
  );
  await page.reload();
  await expect(page.getByRole('region', { name: 'Connection status' })).toContainText(
    'Offline copy'
  );
  await expect(page.getByLabel('Recorded water')).toHaveText('0 ml recorded');
  await expireSession(page);
  await page.route(`${apiURL}/auth/token`, (route) =>
    route.fulfill({ status: 503, json: { message: 'Renewal unavailable' } })
  );
  await page.reload();
  await expect(page.getByLabel('Recorded water')).toHaveText('0 ml recorded');
  await page.unroute(`${apiURL}/auth/token`);
  await page.route(`${apiURL}/api/bootstrap`, (route) =>
    route.fulfill({ status: 200, json: { account: { _id: 'wrong-owner' } } })
  );
  await page.reload();
  await expect(page.getByRole('alert')).toContainText('Could not confirm your account setup');
  await expect(page.getByLabel('Recorded water')).toHaveCount(0);
  await page.unroute(`${apiURL}/api/bootstrap`);
  await page.reload();
  await expect(page.getByLabel('Recorded water')).toHaveText('0 ml recorded');
});

test('unavailable browser storage leaves online reads and local pending changes usable', async ({
  page,
  request,
}) => {
  await page.addInitScript(() => {
    IDBFactory.prototype.open = () => {
      throw new DOMException('Storage blocked for test', 'SecurityError');
    };
  });
  const user = await account(request);
  await login(page, user.email);
  await page.goto('/#/dashboard/diary');
  await expect(page.getByRole('region', { name: 'Connection status' })).toContainText(
    'Offline copies are unavailable'
  );
  const form = page.getByRole('form', { name: 'Water logging' });
  await expect(form.getByLabel('Recorded water')).toHaveText('0 ml recorded');
  await page.route(`${apiURL}/api/water`, (route) => route.abort('failed'));
  await form.getByRole('button', { name: '+250 ml', exact: true }).click();
  await expect(form.getByRole('status')).toContainText('250 ml waiting for confirmation');
  await page.reload();
  await expect(form.getByRole('status')).toContainText('250 ml waiting for confirmation');
  await page.unroute(`${apiURL}/api/water`);
  await form.getByRole('button', { name: 'Retry pending additions' }).click();
  await expect(form.getByRole('status')).toHaveText('Synced');
  await expect(form.getByLabel('Recorded water')).toHaveText('250 ml recorded');
});

test('switching dates offline keeps each saved day separate and leaves an uncached day unknown', async ({
  page,
  request,
}) => {
  const user = await account(request);
  await login(page, user.email);
  await page.goto('/#/dashboard/diary');
  await expect(page.getByLabel('Recorded water')).toHaveText('0 ml recorded');
  const today = await page.getByLabel('Pick a date').inputValue();
  const yesterday = addDays(today, -1);
  const headers = { Authorization: `Bearer ${user.token}`, 'Idempotency-Key': randomUUID() };
  expect(
    (
      await request.post(`${apiURL}/api/water`, {
        headers,
        data: { entry_date: yesterday, deltaMl: 350 },
      })
    ).ok()
  ).toBeTruthy();
  await page.getByRole('button', { name: 'Previous day', exact: true }).click();
  await expect(page.getByLabel('Recorded water')).toHaveText('350 ml recorded');
  await page.route(`${apiURL}/**`, (route) => route.abort('failed'));
  await page.reload();
  await expect(page.getByLabel('Pick a date')).toHaveValue(yesterday);
  await expect(page.getByLabel('Recorded water')).toHaveText('350 ml recorded');
  await page.getByRole('button', { name: 'Today', exact: true }).click();
  await expect(page.getByLabel('Pick a date')).toHaveValue(today);
  await expect(page.getByLabel('Recorded water')).toHaveText('0 ml recorded');
  await page.getByRole('button', { name: 'Previous day', exact: true }).click();
  await expect(page.getByLabel('Recorded water')).toHaveText('350 ml recorded');
  await page.getByRole('button', { name: 'Previous day', exact: true }).click();
  await expect(page.getByText('Could not connect.', { exact: false })).toBeVisible();
  await expect(page.getByLabel('Recorded water')).toHaveCount(0);
});

test('an unreadable saved diary stays intact and is not displayed as an empty day', async ({
  page,
  request,
}) => {
  const user = await account(request);
  await login(page, user.email);
  await page.goto('/#/dashboard/diary');
  await expect(page.getByLabel('Recorded water')).toHaveText('0 ml recorded');
  const savedKey = await page.evaluate(async () => {
    const db = await new Promise<IDBDatabase>((resolve, reject) => {
      const open = indexedDB.open('exerly-offline-v1', 1);
      open.onsuccess = () => resolve(open.result);
      open.onerror = () => reject(open.error);
    });
    try {
      return await new Promise<string>((resolve, reject) => {
        const tx = db.transaction('responses', 'readwrite');
        const store = tx.objectStore('responses');
        const request = store.getAll();
        let key = '';
        request.onsuccess = () => {
          const row = request.result.find((row) => row.path.startsWith('/api/summary?'));
          if (!row) {
            tx.abort();
            return;
          }
          key = row.key;
          store.put({ ...row, body: '{unreadable original snapshot' });
        };
        tx.oncomplete = () => resolve(key);
        tx.onabort = () => reject(tx.error);
      });
    } finally {
      db.close();
    }
  });
  await page.route(`${apiURL}/**`, (route) => route.abort('failed'));
  await page.reload();
  await expect(page.getByRole('heading', { name: 'Diary', exact: true })).toBeVisible();
  await expect(page.getByText('Could not connect.', { exact: false })).toBeVisible();
  await expect(page.getByLabel('Recorded water')).toHaveCount(0);
  expect(
    await page.evaluate(async (key) => {
      const open = indexedDB.open('exerly-offline-v1', 1);
      return new Promise((resolve, reject) => {
        open.onsuccess = () => {
          const db = open.result;
          const tx = db.transaction('responses', 'readonly');
          const get = tx.objectStore('responses').get(key);
          get.onsuccess = () => resolve(get.result.body);
          tx.oncomplete = () => db.close();
        };
        open.onerror = () => reject(open.error);
      });
    }, savedKey)
  ).toBe('{unreadable original snapshot');
});

test('returning to the app refreshes an offline copy without changing its pending addition', async ({
  page,
  request,
}) => {
  const user = await account(request);
  await login(page, user.email);
  await page.goto('/#/dashboard/diary');
  await expect(page.getByLabel('Recorded water')).toHaveText('0 ml recorded');
  await page.route(`${apiURL}/**`, (route) => route.abort('failed'));
  await page.reload();
  const form = page.getByRole('form', { name: 'Water logging' });
  await form.getByRole('button', { name: '+250 ml', exact: true }).click();
  await expect(form.getByRole('status')).toContainText('250 ml waiting for confirmation');
  expect(
    (
      await request.post(`${apiURL}/api/water`, {
        headers: { Authorization: `Bearer ${user.token}`, 'Idempotency-Key': randomUUID() },
        data: { deltaMl: 300 },
      })
    ).ok()
  ).toBeTruthy();
  await page.unroute(`${apiURL}/**`);
  await page.evaluate(() => window.dispatchEvent(new Event('focus')));
  await expect(form.getByLabel('Recorded water')).toHaveText('300 ml recorded');
  await expect(form.getByRole('status')).toContainText('250 ml waiting for confirmation');
  await expect(page.getByRole('region', { name: 'Connection status' })).toHaveCount(0);
});

test('an accepted timezone change survives an immediate offline reload', async ({
  page,
  request,
}) => {
  const user = await account(request);
  await login(page, user.email);
  await page.goto('/#/dashboard/profile');
  await expect(page.getByRole('button', { name: 'Save preferences', exact: true })).toBeVisible();
  await page.getByLabel('Time zone', { exact: true }).fill('Pacific/Kiritimati');
  await page.getByRole('button', { name: 'Save preferences', exact: true }).click();
  await expect(page.getByText('Preferences saved.', { exact: true })).toBeVisible();
  await page.route(`${apiURL}/**`, (route) => route.abort('failed'));
  await page.reload();
  await page.goto('/#/dashboard/diary');
  const response = await request.get(`${apiURL}/api/summary`, {
    headers: { Authorization: `Bearer ${user.token}` },
  });
  await expect(page.getByLabel('Pick a date')).toHaveValue((await response.json()).date);
  await expect(page.getByRole('region', { name: 'Connection status' })).toContainText(
    'Offline copy'
  );
});
