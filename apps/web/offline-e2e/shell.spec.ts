import { test, expect, type Page, type APIRequestContext } from '@playwright/test';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import { account, apiURL, login, resetFixture } from '../e2e/helpers/session';

async function connection(request: APIRequestContext, disconnected: boolean, web = true) {
  const headers = { 'X-Test-Fixture': 'isolated-simulator' };
  expect(
    (
      await request.post(`${apiURL}/__test/control`, {
        headers,
        data: { offline: disconnected, disconnect: disconnected },
      })
    ).ok()
  ).toBeTruthy();
  if (web)
    expect(
      (
        await request.post('http://127.0.0.1:3306/__test/connection', {
          headers,
          data: { disconnected },
        })
      ).ok()
    ).toBeTruthy();
}
test.beforeEach(async ({ request }) => {
  await resetFixture(request);
  await connection(request, false);
});
test.afterEach(async ({ request }) => connection(request, false));

async function controlled(page: Page) {
  await page.evaluate(async () => {
    await navigator.serviceWorker.ready;
    if (!navigator.serviceWorker.controller)
      await new Promise<void>((resolve) =>
        navigator.serviceWorker.addEventListener('controllerchange', () => resolve(), {
          once: true,
        })
      );
  });
}

test('the installed app reopens without any network and confirms its pending addition only after reconnecting', async ({
  page,
  context,
  request,
  browserName,
}, testInfo) => {
  const user = await account(request);
  expect(
    (
      await request.post(`${apiURL}/api/water`, {
        headers: { Authorization: `Bearer ${user.token}`, 'Idempotency-Key': randomUUID() },
        data: { deltaMl: 500 },
      })
    ).ok()
  ).toBeTruthy();
  await login(page, user.email);
  await page.goto('/#/dashboard/diary');
  await expect(page.getByLabel('Recorded water')).toHaveText('500 ml recorded');
  await controlled(page);
  const resources = await page.evaluate(async () => {
    const keys = [];
    for (const name of await caches.keys())
      for (const key of await (await caches.open(name)).keys()) keys.push(key.url);
    return keys;
  });
  expect(resources.some((url) => url.endsWith('/index.html'))).toBeTruthy();
  expect(resources.some((url) => /\.js$/.test(url))).toBeTruthy();
  expect(resources.some((url) => url.endsWith('/fonts/InterVariable.woff2'))).toBeTruthy();
  expect(resources.filter((url) => /\/api\/|\/auth\/|\.mp4|\/media\//.test(url))).toEqual([]);
  const url = page.url();
  await connection(request, true);
  // Confirm uncached requests really cannot reach either fixture server.
  await expect(request.get('http://127.0.0.1:3306/uncached-proof')).rejects.toThrow();
  await expect(request.get(`${apiURL}/api/summary`)).rejects.toThrow();
  if (browserName === 'chromium') await context.setOffline(true);
  await page.reload();
  await expect(page.getByRole('region', { name: 'Connection status' })).toContainText(
    'Offline copy'
  );
  await expect(page.getByLabel('Recorded water')).toHaveText('500 ml recorded');
  await page.getByRole('button', { name: '+250 ml', exact: true }).click();
  await expect(page.getByRole('form', { name: 'Water logging' }).getByRole('status')).toContainText(
    '250 ml waiting for confirmation'
  );
  await page.close();
  const reopened = await context.newPage();
  await reopened.goto(url);
  const form = reopened.getByRole('form', { name: 'Water logging' });
  await expect(form.getByLabel('Recorded water')).toHaveText('500 ml recorded');
  await expect(form.getByRole('status')).toContainText('250 ml waiting for confirmation');
  await reopened.screenshot({
    path: testInfo.outputPath('offline-diary-reopened.png'),
    fullPage: true,
  });
  // This lazy route has never loaded. Its code must be available offline too.
  await reopened.goto('/#/dashboard/weight');
  await expect(reopened.getByRole('region', { name: 'Body measurements' })).toBeVisible();
  await expect(reopened.getByText('Could not connect.', { exact: false }).first()).toBeVisible();
  await reopened.goto(url);
  await expect(form.getByRole('status')).toContainText('250 ml waiting for confirmation');
  if (browserName === 'chromium') await context.setOffline(false);
  await connection(request, false);
  await reopened.evaluate(() => window.dispatchEvent(new Event('online')));
  await form.getByRole('button', { name: 'Retry pending additions' }).click();
  await expect(form.getByRole('status')).toHaveText('Synced');
  await expect(form.getByLabel('Recorded water')).toHaveText('750 ml recorded');
  await expect(reopened.getByRole('region', { name: 'Connection status' })).toHaveCount(0);
  const final = await request.get(`${apiURL}/api/water`, {
    headers: { Authorization: `Bearer ${user.token}` },
  });
  expect((await final.json()).ml).toBe(750);
});

test('an app update waits for every old tab to close and keeps the pending operation', async ({
  page,
  context,
  request,
  browserName,
}) => {
  const user = await account(request);
  await login(page, user.email);
  await page.goto('/#/dashboard/diary');
  await expect(page.getByLabel('Recorded water')).toHaveText('0 ml recorded');
  await controlled(page);
  const form = page.getByRole('form', { name: 'Water logging' });
  await connection(request, true, false);
  await form.getByRole('button', { name: '+250 ml', exact: true }).click();
  await expect(form.getByRole('status')).toContainText('250 ml waiting for confirmation');
  const other = await context.newPage();
  await other.goto(page.url());
  const directory = path.resolve('artifacts/web-offline-dist');
  const workerPath = path.join(directory, 'offline-worker.js');
  const indexPath = path.join(directory, 'index.html');
  const originalWorker = await fs.readFile(workerPath, 'utf8');
  const originalIndex = await fs.readFile(indexPath, 'utf8');
  // A worker's JS debugging connection can disappear when its last app tab
  // closes. Observe Chromium's lifecycle events from an uncontrolled blank tab.
  const observer = browserName === 'chromium' ? await context.newPage() : null;
  const inspector = observer ? await context.newCDPSession(observer) : null;
  const versions = new Map<string, { versionId: string; status: string; scriptURL: string }>();
  inspector?.on('ServiceWorker.workerVersionUpdated', ({ versions: updates }) => {
    for (const version of updates) versions.set(version.versionId, version);
  });
  await inspector?.send('ServiceWorker.enable');
  try {
    await fs.writeFile(
      indexPath,
      originalIndex.replace('<head>', '<head><meta name="test-offline-release" content="second">')
    );
    await fs.writeFile(
      workerPath,
      originalWorker.replace(/const version = [^;]+;/, `const version = "update-${randomUUID()}";`)
    );
    await page.evaluate(async () => {
      await (await navigator.serviceWorker.ready).update();
    });
    await expect(page.getByRole('region', { name: 'Connection status' })).toContainText(
      'An app update is ready'
    );
    await expect(form.getByRole('status')).toContainText('250 ml waiting for confirmation');
    await page.reload();
    await expect(page.locator('meta[name="test-offline-release"]')).toHaveCount(0);
    await expect(form.getByRole('status')).toContainText('250 ml waiting for confirmation');
    const url = page.url();
    const waitingVersion = () =>
      [...versions.values()].find(
        (version) =>
          version.status === 'installed' &&
          version.scriptURL === new URL('/offline-worker.js', url).href
      )?.versionId;
    if (inspector) await expect.poll(waitingVersion).toBeTruthy();
    const versionID = waitingVersion();
    await other.close();
    await page.close();
    if (versionID) {
      await expect.poll(() => versions.get(versionID)?.status).toBe('activated');
    }
    const updated = await context.newPage();
    await updated.goto(url);
    await expect(updated.locator('meta[name="test-offline-release"]')).toHaveAttribute(
      'content',
      'second'
    );
    await expect(
      updated.getByRole('form', { name: 'Water logging' }).getByRole('status')
    ).toContainText('250 ml waiting for confirmation');
    await connection(request, false);
    await updated.getByRole('button', { name: 'Retry pending additions' }).click();
    await expect(updated.getByLabel('Recorded water')).toHaveText('250 ml recorded');
  } finally {
    await fs.writeFile(indexPath, originalIndex);
    await fs.writeFile(workerPath, originalWorker);
    await inspector?.detach();
    await observer?.close();
  }
});

test('food drafts and queued portions survive closed tabs with both servers disconnected', async ({
  page,
  context,
  request,
  browserName,
}, testInfo) => {
  const user = await account(request);
  await login(page, user.email);
  await page.goto('/#/dashboard/diary');
  await expect(page.getByRole('button', { name: 'Add', exact: true }).first()).toBeVisible();
  const day = await page.getByLabel('Pick a date').inputValue();
  await controlled(page);
  const url = page.url();
  await connection(request, true);
  if (browserName === 'chromium') await context.setOffline(true);
  await page.getByRole('button', { name: 'Add', exact: true }).first().click();
  await page.getByRole('button', { name: 'Quick add', exact: true }).click();
  await page.getByRole('button', { name: 'Enter macros manually', exact: true }).click();
  let dialog = page.getByRole('dialog');
  await dialog.getByPlaceholder('What did you eat?').fill('Offline oats');
  await dialog.getByLabel('Calories / serving', { exact: true }).fill('99.5');
  await dialog.getByLabel('Basis amount', { exact: true }).fill('100');
  await dialog.getByRole('combobox', { name: 'Basis unit', exact: true }).selectOption('g');
  await dialog.getByLabel('Quantity', { exact: true }).fill('35');
  await dialog.getByRole('combobox', { name: 'Quantity unit', exact: true }).selectOption('g');
  await expect(dialog.getByRole('status')).toHaveText('Draft saved on this browser');
  await page.close();
  let reopened = await context.newPage();
  await reopened.goto(url);
  await reopened.getByRole('button', { name: 'Resume draft', exact: true }).click();
  dialog = reopened.getByRole('dialog');
  await expect(dialog.getByLabel('Quantity', { exact: true })).toHaveValue('35');
  await expect(dialog.getByLabel('Food total')).toHaveText('35 kcal · 0.35 servings');
  await reopened.screenshot({ path: testInfo.outputPath('offline-food-draft-phone.png') });
  await dialog.getByRole('button', { name: 'Log it', exact: true }).click();
  await expect(dialog).toBeHidden();
  await expect(reopened.getByRole('region', { name: 'Food diary' })).toContainText(
    '1 food change saved'
  );
  await reopened.close();
  reopened = await context.newPage();
  await reopened.goto(url);
  await expect(
    reopened.getByRole('button', { name: 'Edit Offline oats', exact: true })
  ).toHaveCount(1);
  await expect(reopened.getByRole('region', { name: 'Food diary' })).toContainText(
    '1 food change saved'
  );
  await reopened.screenshot({
    path: testInfo.outputPath('offline-food-pending-phone.png'),
    fullPage: true,
  });
  await connection(request, false);
  if (browserName === 'chromium') await context.setOffline(false);
  await reopened.evaluate(() => window.dispatchEvent(new Event('online')));
  await expect(reopened.getByRole('region', { name: 'Food diary' })).toContainText('Food synced');
  const response = await request.get(`${apiURL}/api/food?date=${day}`, {
    headers: { Authorization: `Bearer ${user.token}` },
  });
  expect(response.ok()).toBeTruthy();
  const rows = await response.json();
  expect(rows).toHaveLength(1);
  expect(rows[0]).toMatchObject({
    name: 'Offline oats',
    calories: 35,
    servings: 0.35,
    nutrition_snapshot: { calories: 99.5, protein: null },
  });
  await reopened.close();
});
